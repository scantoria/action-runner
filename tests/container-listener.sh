#!/usr/bin/env bash
# Docker stop/recreation fixture only; refuses any non-synthetic credentials.
set -euo pipefail
cd /actions-runner
rm -f /tmp/wp03-ready
fixture_start=$(cat /tmp/wp03-start-count 2>/dev/null || printf 0)
fixture_start=$((fixture_start + 1))
printf '%s\n' "$fixture_start" > /tmp/wp03-start-count
export WP03_FIXTURE_START="$fixture_start"
python3 - <<'PY'
import json
c = json.load(open('/runner-state/.credentials'))
assert c['data']['clientId'] == 'synthetic-fixture'
assert c['data']['authorizationUrl'] == 'https://example.invalid/oauth'
PY
if [[ -e /tmp/wp03-container-initialized ]]; then
    test -e _work/wp03-disposable-marker
    echo 'PASS: Same-container stop/start retained its workspace.'
else
    test ! -e _work/wp03-disposable-marker
    echo 'PASS: Previous container workspace is absent after recreation.'
    touch /tmp/wp03-container-initialized
fi
mkdir -p _work
touch _work/wp03-disposable-marker
cat > config.sh <<'SH'
#!/usr/bin/env bash
touch /tmp/wp03-config-called
echo 'FAIL: ordinary migrated restart must not configure or remove.' >&2
exit 99
SH
chmod 755 config.sh
cat > bin/Runner.Listener <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ -z ${RUNNER_TOKEN:-} && -z ${RUNNER_REMOVE_TOKEN:-} ]]
trap 'rm /tmp/wp03-ready; echo "PASS: Synthetic listener received TERM; no configuration or removal."; exit 0' TERM
trap 'rm /tmp/wp03-ready; echo "PASS: Synthetic listener received INT; no configuration or removal."; exit 0' INT
if [[ ${WP03_FIXTURE_MIGRATE:-1} == 1 && ( ${WP03_FIXTURE_MIGRATE_ONCE:-0} == 0 || "$WP03_FIXTURE_START" == 1 ) ]]; then
python3 - <<'PY'
import json, pathlib
root = pathlib.Path('/actions-runner')
for filename, original in [('.runner_migrated','.runner'),('.credentials_migrated','.credentials')]:
    current = root / filename
    value = json.loads((current if current.exists() else root / original).read_text())
    value['fixtureGeneration'] = value.get('fixtureGeneration', 0) + 1
    temp = root / (filename + '.fixture-new')
    temp.write_text(json.dumps(value))
    temp.chmod(0o644)
    temp.replace(current)
print('PASS: Synthetic listener created/updated both migrated files at runtime.')
PY
fi
echo 'PASS: Synthetic listener started using retained state without a token.'
printf '%s\n' "$WP03_FIXTURE_START" > /tmp/wp03-ready
while :; do sleep 0.1; done
SH
chmod 755 bin/Runner.Listener
# Test E only: block after a complete pending copy was synced during recovery.
# This wrapper is container-local; no production fault-injection hook is added.
if [[ ${WP03_FIXTURE_INTERRUPT_RECOVERY:-0} == 1 && "$fixture_start" == 2 ]]; then
    mkdir -p /tmp/wp03-tools
    cat > /tmp/wp03-tools/sync <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == -f && ${2:-} == /runner-state/.pending.credentials_migrated ]]; then
    /usr/bin/sync "$@"
    touch /tmp/wp03-recovery-checkpoint
    while :; do sleep 0.1; done
fi
exec /usr/bin/sync "$@"
SH
    chmod 755 /tmp/wp03-tools/sync
    export PATH="/tmp/wp03-tools:$PATH"
fi
exec /entrypoint.sh
