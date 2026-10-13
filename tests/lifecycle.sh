#!/usr/bin/env bash
# Noncredentialed, network-isolated lifecycle tests. Never call real config.sh.
set -euo pipefail
umask 077
cd /actions-runner
test_root=$(mktemp -d)
export TEST_ROOT="$test_root"
export GITHUB_OWNER=scantoria GITHUB_REPOSITORY=thisbyte-website
export RUNNER_NAME=thisbyte-hp-runner RUNNER_WORKDIR=_work
unset RUNNER_TOKEN RUNNER_REMOVE_TOKEN

pass() { printf 'PASS: %s\n' "$*"; }
die() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
expect_failure() {
    local diagnostic=$1
    shift
    if "$@" >"$test_root/output" 2>&1; then die 'Expected failure'; fi
    grep -Fq "$diagnostic" "$test_root/output" || { cat "$test_root/output"; die 'Missing expected diagnostic'; }
}
reset_state() {
    # These paths are confined to this disposable test container; no live volume.
    find /runner-state -mindepth 1 -maxdepth 1 -type f -delete
    rm -f /actions-runner/.listener-session /actions-runner/.listener-session.new
    for file in .runner .runner_migrated .credentials .credentials_rsaparams .credentials_migrated .env .path; do
        [[ ! -e "$file" && ! -L "$file" ]] || rm "$file"
    done
    chmod 700 /runner-state
    rm -f "$test_root/config-called" "$test_root/listener-started"
    unset RUNNER_TOKEN RUNNER_REMOVE_TOKEN MOCK_CONFIG_FAIL MOCK_CONFIG_WAIT MOCK_LISTENER_WAIT MOCK_LISTENER_MIGRATE MOCK_RUNTIME_INVALID MOCK_LISTENER_EXIT MOCK_EARLY_TERM_EXIT
}
fixture() {
    cat > /runner-state/.runner <<'JSON'
{"agentId":123,"poolId":1,"agentName":"thisbyte-hp-runner","gitHubUrl":"https://github.com/scantoria/thisbyte-website","serverUrl":"https://example.invalid/runner","workFolder":"_work","disableUpdate":true,"ephemeral":false}
JSON
    cat > /runner-state/.credentials <<'JSON'
{"scheme":"OAuth","data":{"clientId":"synthetic-fixture","authorizationUrl":"https://example.invalid/oauth"}}
JSON
    # Deterministic, publicly derivable test data, unrelated to GitHub identity.
    # The validator checks key arithmetic; this fixture is never authenticated.
    python3 - <<'PY'
import base64, json, math, pathlib
p, q, e = (1 << 1279) - 1, (1 << 2203) - 1, 65537
d = pow(e, -1, math.lcm(p - 1, q - 1))
key = dict(p=p, q=q, exponent=e, d=d, dp=d % (p - 1), dq=d % (q - 1), inverseQ=pow(q, -1, p), modulus=p*q)
key = {k: base64.b64encode(v.to_bytes((v.bit_length()+7)//8, 'big')).decode() for k, v in key.items()}
pathlib.Path('/runner-state/.credentials_rsaparams').write_text(json.dumps(key))
PY
    : > /runner-state/.env
    : > /runner-state/.path
}
snapshot() {
    sha256sum /runner-state/.runner /runner-state/.credentials /runner-state/.credentials_rsaparams /runner-state/.env /runner-state/.path
}

if [[ "${1:-}" == seed ]]; then
    [[ $(id -u) != 0 && -z "$(find /runner-state -mindepth 1 -maxdepth 1 -print -quit)" ]] || die 'Seed requires an empty isolated volume and non-root execution'
    fixture
    pass 'Seeded only synthetic identity into an empty isolated fixture volume'
    exit 0
fi

[[ $(id -u) != 0 ]] || die 'Test must run as non-root'
bash -n /entrypoint.sh
./bin/Runner.Listener --version
pass 'Non-root execution, shell syntax, real pinned listener loads with ICU'

# Preserve originals only in this container's disposable layer. The entrypoint
# retains its production paths; stubs replace external effects, not its logic.
mv config.sh config.sh.real
mv bin/Runner.Listener bin/Runner.Listener.real
cat > config.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$TEST_ROOT/config-called"
[[ ${1:-} != remove ]] || { echo 'Removal must never execute in WP-0.3 tests' >&2; exit 99; }
[[ ${MOCK_CONFIG_FAIL:-0} == 0 ]] || { echo 'Synthetic bootstrap diagnostic'; exit 23; }
if [[ ${MOCK_CONFIG_WAIT:-0} == 1 ]]; then
    printf '{}' > .runner
    touch "$TEST_ROOT/config-ready"
    trap 'exit 42' TERM INT
    while :; do sleep 0.1; done
fi
# Simulate the pinned distribution creating ordinary configuration files.
for file in .runner .credentials .credentials_rsaparams .env .path; do
    cat "$TEST_ROOT/fixture/$file" > "$file"
done
SH
cat > bin/Runner.Listener <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ -z ${RUNNER_TOKEN:-} && -z ${RUNNER_REMOVE_TOKEN:-} ]] || exit 90
if [[ ${MOCK_LISTENER_MIGRATE:-0} == 1 ]]; then
    python3 - <<'PY'
import json, os, pathlib
root = pathlib.Path('/actions-runner')
for filename, original in [('.runner_migrated','.runner'),('.credentials_migrated','.credentials')]:
    current = root / filename
    value = json.loads((current if current.exists() else root / original).read_text())
    value['fixtureGeneration'] = value.get('fixtureGeneration', 0) + 1
    if os.environ.get('MOCK_RUNTIME_INVALID') == filename:
        value = {'invalid': True}
    temp = root / (filename + '.fixture-new')
    temp.write_text(json.dumps(value))
    temp.chmod(0o644)
    temp.replace(current)  # Exercise atomic file replacement, including links.
PY
fi
if [[ ${MOCK_LISTENER_WAIT:-0} == 1 ]]; then
    trap 'printf "TERM\n" > "$TEST_ROOT/signal"; exit 0' TERM
    trap 'printf "INT\n" > "$TEST_ROOT/signal"; exit 0' INT
    printf 'started\n' > "$TEST_ROOT/listener-started"
    while :; do sleep 0.1; done
fi
if [[ ${MOCK_EARLY_TERM_EXIT:-0} == 1 ]]; then
    trap 'exit 17' TERM
    printf 'started\n' > "$TEST_ROOT/listener-started"
    while :; do sleep 0.1; done
fi
printf 'started\n' > "$TEST_ROOT/listener-started"
exit "${MOCK_LISTENER_EXIT:-0}"
SH
chmod 755 config.sh bin/Runner.Listener
mkdir "$test_root/fixture"
fixture
    cp /runner-state/.* "$test_root/fixture/" 2>/dev/null || true
reset_state

expect_failure 'No registration state' /entrypoint.sh
[[ ! -e "$test_root/config-called" && ! -e "$test_root/listener-started" ]] || die 'Missing state invoked external operation'
pass 'AC-03: absent state fails closed without configuration/listener'

expect_failure 'requires a runtime short-lived registration token' /entrypoint.sh bootstrap
[[ ! -e "$test_root/config-called" ]] || die 'Missing token called config'
pass 'AC-04: explicit bootstrap without token fails closed'

printf '{}' > /runner-state/.runner
expect_failure 'Partial configuration' /entrypoint.sh
expect_failure 'Partial configuration' env RUNNER_TOKEN=synthetic-not-a-token /entrypoint.sh bootstrap
[[ $(cat /runner-state/.runner) == '{}' && ! -e "$test_root/config-called" ]] || die 'Partial state changed or triggered config'
pass 'AC-08: partial state preserved and cannot trigger bootstrap'

reset_state
fixture
printf '{invalid-json' > /runner-state/.runner
expect_failure 'Malformed .runner' /entrypoint.sh
pass 'AC-08: malformed runner JSON fails closed'

reset_state
fixture
printf '{"agentId":1,"agentId":2}' > /runner-state/.runner
expect_failure 'Malformed .runner' /entrypoint.sh
printf '{}\n{}\n' > /runner-state/.runner
expect_failure 'Malformed .runner' /entrypoint.sh
pass 'AC-08: duplicate JSON properties and multiple objects fail closed'

reset_state
fixture
python3 -c 'import json; v=json.load(open("/runner-state/.runner")); v["disableUpdate"]=False; print(json.dumps(v))' > "$test_root/changed"
cat "$test_root/changed" > /runner-state/.runner
expect_failure 'Malformed or inconsistent .runner' /entrypoint.sh
pass 'AC-08/11: automatic-update state rejected'

reset_state
fixture
python3 -c 'import json; v=json.load(open("/runner-state/.runner")); v["gitHubUrl"]="https://github.com/another/repository"; print(json.dumps(v))' > "$test_root/changed"
cat "$test_root/changed" > /runner-state/.runner
expect_failure 'Malformed or inconsistent .runner' /entrypoint.sh
pass 'AC-08: repository mismatch fails closed'

reset_state
fixture
printf '{}' > /runner-state/.credentials
expect_failure 'Malformed .credentials' /entrypoint.sh
printf '{}' > /runner-state/.credentials_rsaparams
cp "$test_root/fixture/.credentials" /runner-state/.credentials
expect_failure 'Malformed RSA' /entrypoint.sh
pass 'AC-08: incomplete OAuth/RSA state fails closed'

reset_state
fixture
python3 -c 'import json; v=json.load(open("/runner-state/.credentials_rsaparams")); v["modulus"]="YQ=="; print(json.dumps(v))' > "$test_root/changed"
cat "$test_root/changed" > /runner-state/.credentials_rsaparams
expect_failure 'Malformed RSA' /entrypoint.sh
pass 'AC-08: syntactically valid but inconsistent RSA state fails closed'

reset_state
fixture
chmod 644 /runner-state/.credentials
expect_failure 'mode 0600' /entrypoint.sh
chmod 600 /runner-state/.credentials
touch /runner-state/unexpected
expect_failure 'Unrecognized state file' /entrypoint.sh
pass 'AC-08/13: insecure permissions and unexpected state rejected'

reset_state
fixture
ln -s /tmp /runner-state/foreign-link
expect_failure 'symlink' /entrypoint.sh
rm /runner-state/foreign-link
pass 'AC-08: state symlinks rejected without deletion'

before=$(snapshot)
/entrypoint.sh > "$test_root/output" 2>&1
[[ -e "$test_root/listener-started" && ! -e "$test_root/config-called" && $(snapshot) == "$before" ]] || die 'Valid state not reused intact'
pass 'AC-02/06: valid synthetic persisted identity starts listener without token or config'
expect_failure 'Already configured' env RUNNER_TOKEN=synthetic-not-a-token /entrypoint.sh bootstrap
expect_failure 'must not receive a bootstrap token' env RUNNER_TOKEN=synthetic-not-a-token /entrypoint.sh run
[[ ! -e "$test_root/config-called" ]] || die 'Existing identity invoked config'
pass 'AC-05/09: existing identity never bootstraps or replaces itself'

reset_state
env RUNNER_TOKEN=synthetic-not-a-token /entrypoint.sh bootstrap > "$test_root/output" 2>&1
grep -Fxq -- '--disableupdate' "$test_root/config-called" || die 'Missing disableupdate'
! grep -Fxq -- '--replace' "$test_root/config-called" || die 'Silent replacement'
[[ ! -e /runner-state/.bootstrap-in-progress && -e "$test_root/listener-started" ]] || die 'Successful stubbed bootstrap did not start listener'
! grep -Rq 'synthetic-not-a-token' /runner-state || die 'Synthetic bootstrap input persisted'
for file in .runner .credentials .credentials_rsaparams .env .path; do
    [[ -L "$file" && $(stat -c %a "/runner-state/$file") == 600 ]] || die 'State boundary or permissions changed'
done
pass 'AC-05/06/11: stubbed bootstrap writes through state links, disables update, and discards synthetic input'

reset_state
expect_failure 'Bootstrap failed' env MOCK_CONFIG_FAIL=1 RUNNER_TOKEN=synthetic-not-a-token /entrypoint.sh bootstrap
[[ -f /runner-state/.bootstrap-in-progress && -f /runner-state/.bootstrap-output ]] || die 'Failure diagnostics/marker missing'
cp "$test_root/config-called" "$test_root/first-call"
expect_failure 'administrative operation' env RUNNER_TOKEN=synthetic-not-a-token /entrypoint.sh bootstrap
cmp "$test_root/config-called" "$test_root/first-call" || die 'Interrupted bootstrap retried'
pass 'AC-08/12: failed bootstrap diagnostics retained; durable marker prevents retry'

reset_state
env --default-signal=INT MOCK_CONFIG_WAIT=1 RUNNER_TOKEN=synthetic-not-a-token /entrypoint.sh bootstrap > "$test_root/output" 2>&1 &
bootstrap_pid=$!
for attempt in {1..100}; do
    [[ ! -e "$test_root/config-ready" ]] || break
    sleep 0.05
done
[[ -e "$test_root/config-ready" ]] || die 'Synthetic config did not start'
kill -TERM "$bootstrap_pid"
if wait "$bootstrap_pid"; then die 'Interrupted bootstrap succeeded'; fi
[[ -f /runner-state/.bootstrap-in-progress && $(cat /runner-state/.runner) == '{}' ]] || die 'Interrupted partial state not preserved'
expect_failure 'administrative operation' /entrypoint.sh
pass 'AC-08/12: interrupted bootstrap preserves partial state and requires recovery'

reset_state
fixture
for signal in TERM INT; do
    rm -f "$test_root/listener-started" "$test_root/signal"
    before=$(snapshot)
    env --default-signal=INT MOCK_LISTENER_WAIT=1 /entrypoint.sh > "$test_root/output" 2>&1 &
    listener_pid=$!
    for attempt in {1..100}; do
        [[ ! -e "$test_root/listener-started" ]] || break
        sleep 0.05
    done
    [[ -e "$test_root/listener-started" ]] || die 'Listener did not start'
    expect_failure 'Another process' /entrypoint.sh
    kill -"$signal" "$listener_pid"
    wait "$listener_pid"
    [[ $(cat "$test_root/signal") == "$signal" && $(snapshot) == "$before" && ! -e "$test_root/config-called" ]] || die 'Signal handling changed identity or invoked config'
done
pass 'AC-01/06: TERM and INT reach listener without config/removal or state changes; concurrent identity use blocked'

# A-2: all paths must refuse before the mock config.sh could reach remove.
reset_state
fixture
before=$(snapshot)
expect_failure 'RUNNER_DECOMMISSION_CONFIRM' env RUNNER_DECOMMISSION_CONFIRM=wrong RUNNER_REMOVE_TOKEN=synthetic-remove-input /entrypoint.sh decommission
expect_failure 'removal token' env RUNNER_DECOMMISSION_CONFIRM=thisbyte-hp-runner /entrypoint.sh decommission
expect_failure 'bootstrap token is not a removal credential' env RUNNER_DECOMMISSION_CONFIRM=thisbyte-hp-runner RUNNER_REMOVE_TOKEN=synthetic-remove-input RUNNER_TOKEN=synthetic-not-a-token /entrypoint.sh decommission
expect_failure 'only by explicit decommission' env RUNNER_REMOVE_TOKEN=synthetic-remove-input /entrypoint.sh run
[[ ! -e "$test_root/config-called" && $(snapshot) == "$before" && ! -e /runner-state/.decommission-in-progress ]] || die 'Decommission guard reached config or changed identity'
pass 'A-2/AC-10: incorrect confirmation, absent removal token, conflicting tokens and removal token on run refuse before config'
reset_state
expect_failure 'No local identity' env RUNNER_DECOMMISSION_CONFIRM=thisbyte-hp-runner RUNNER_REMOVE_TOKEN=synthetic-remove-input /entrypoint.sh decommission
printf '{}' > /runner-state/.runner
expect_failure 'Partial configuration' env RUNNER_DECOMMISSION_CONFIRM=thisbyte-hp-runner RUNNER_REMOVE_TOKEN=synthetic-remove-input /entrypoint.sh decommission
[[ ! -e "$test_root/config-called" ]] || die 'Absent/partial decommission invoked config'
reset_state
fixture
printf '{}' > /runner-state/.credentials
expect_failure 'Malformed .credentials' env RUNNER_DECOMMISSION_CONFIRM=thisbyte-hp-runner RUNNER_REMOVE_TOKEN=synthetic-remove-input /entrypoint.sh decommission
[[ ! -e "$test_root/config-called" ]] || die 'Invalid decommission invoked config'
pass 'A-2/AC-10: absent, partial and malformed identity refuse before config; no removal mock was invoked'

# F-1: runtime-created migration files and atomic replacements are validated,
# protected, and persisted, not merely allow-listed.
reset_state
fixture
before=$(snapshot)
env MOCK_LISTENER_MIGRATE=1 /entrypoint.sh > "$test_root/output" 2>&1
for file in .runner_migrated .credentials_migrated; do
    [[ -L "$file" && -f /runner-state/$file && $(stat -c %a /runner-state/$file) == 600 && $(stat -c %u /runner-state/$file) == $(id -u) ]] || die 'Migrated state not protected/persisted'
done
[[ $(snapshot) == "$before" && ! -e "$test_root/config-called" && ! -e /runner-state/.listener-active ]] || die 'Runtime migration modified base identity or configured'
python3 -c 'import json; assert all(json.load(open("/runner-state/"+f))["fixtureGeneration"] == 1 for f in [".runner_migrated",".credentials_migrated"])'
/entrypoint.sh > "$test_root/output" 2>&1
env MOCK_LISTENER_MIGRATE=1 /entrypoint.sh > "$test_root/output" 2>&1
python3 -c 'import json; assert all(json.load(open("/runner-state/"+f))["fixtureGeneration"] == 2 for f in [".runner_migrated",".credentials_migrated"])'
[[ ! -e "$test_root/config-called" ]] || die 'Migrated restart bootstrapped'
pass 'F-1/AC-02/06: runtime-created and atomically replaced migration files survive termination and same-layer restart at mode 0600/runner ownership'
if env MOCK_LISTENER_EXIT=17 /entrypoint.sh > "$test_root/output" 2>&1; then die 'Listener error not propagated'; else [[ $? == 17 ]] || die 'Incorrect listener status'; fi
[[ ! -e /runner-state/.listener-active && ! -e "$test_root/config-called" ]] || die 'Listener exit cleanup wrong'
pass 'F-1/AC-01: listener exit status 17 propagated after valid state preservation, with no removal'

# B-1: fixture-only copy injects an early parent TERM before the primary wait.
# No test hook or injection is built into the production entrypoint.
for early_point in before-loop before-wait; do
rm -f "$test_root/listener-started"
python3 - "$test_root/early-signal.sh" "$early_point" <<'PY'
import pathlib, sys
source = pathlib.Path('/entrypoint.sh').read_text()
anchor = ('while true; do\n    listener_status=0' if sys.argv[2] == 'before-loop'
          else '    wait -n -p completed_pid "$listener_pid" 2>/dev/null || listener_status=$?')
assert source.count(anchor) == 1
hook = 'while [[ ! -f "$TEST_ROOT/listener-started" ]]; do sleep 0.01; done\nkill -TERM $$\n'
pathlib.Path(sys.argv[1]).write_text(source.replace(anchor, hook + anchor))
PY
if env MOCK_EARLY_TERM_EXIT=1 bash "$test_root/early-signal.sh" > "$test_root/output" 2>&1; then die 'Early TERM lost listener error'; else [[ $? == 17 ]] || { cat "$test_root/output"; die 'Early TERM did not propagate 17'; }; fi
[[ ! -e /runner-state/.listener-active && ! -e "$test_root/config-called" ]] || die 'Early TERM finalization regressed'
done
pass 'B-1: deterministic TERM before loop and immediately before primary wait propagates listener status 17, not 127'

for invalid in .runner_migrated .credentials_migrated; do
    reset_state
    fixture
    expect_failure 'Malformed' env MOCK_LISTENER_MIGRATE=1 MOCK_RUNTIME_INVALID="$invalid" /entrypoint.sh
    [[ -f /runner-state/.listener-active && -f /runner-state/.listener-state-error && ! -e /runner-state/$invalid && -f "$invalid" ]] || die 'Rejected runtime state silently promoted or evidence lost'
    expect_failure 'state preservation did not complete' /entrypoint.sh
    [[ ! -e "$test_root/config-called" ]] || die 'Rejected migrated state invoked config'
done
pass 'F-1/AC-08: malformed runtime migration is not promoted; durable marker blocks restart and preserves rejected container evidence'
reset_state
fixture
cp /runner-state/.runner /runner-state/.runner_migrated
printf '{}' > /runner-state/.runner_migrated
expect_failure 'Malformed or inconsistent .runner_migrated' /entrypoint.sh
reset_state
fixture
printf '{}' > /runner-state/.credentials_migrated
expect_failure 'Malformed .credentials_migrated' /entrypoint.sh
pass 'F-1/AC-08: malformed persisted migration files fail closed before listener startup'
for unsupported in .setup_info .service; do
    reset_state
    fixture
    printf '{}' > "$unsupported"
    expect_failure 'Unsupported runner-managed' /entrypoint.sh
    [[ ! -e "$test_root/listener-started" && ! -e "$test_root/config-called" && -f "$unsupported" ]] || die 'Unsupported state was ignored or destroyed'
    rm "$unsupported"
done
pass 'F-1 state model: unsupported JIT/service state refuses startup and is preserved for review'
reset_state
fixture
/entrypoint.sh > "$test_root/output" 2>&1
./bin/Runner.Listener.real --version
pass 'Pinned real listener version command reads linked synthetic state without network access'
mkdir -p /actions-runner/_work
touch /actions-runner/_work/wp03-disposable-marker
printf 'PASS: Local fixture suite complete; real registration, real decommission, and GitHub behavior NOT EXECUTED.\n'
