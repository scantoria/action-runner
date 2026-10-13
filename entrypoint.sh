#!/usr/bin/env bash
set -euo pipefail
umask 077

# Normal listener shutdown only forwards signals, validates, and persists state.
# It never enters administrative removal; only the supervisor performs finalizing.
cd /actions-runner
state_dir=/runner-state
continuity_file=/actions-runner/.listener-session
mode="${1:-run}"
repo_url="https://github.com/${GITHUB_OWNER:-}/${GITHUB_REPOSITORY:-}"
runner_name="${RUNNER_NAME:-thisbyte-hp-runner}"
state_files=(.runner .credentials .credentials_rsaparams .env .path .credentials_migrated .runner_migrated)

fail() {
    printf 'Runner lifecycle stopped: %s\n' "$*" >&2
    printf 'Preserve /runner-state. Review local state and GitHub records before administrative recovery.\n' >&2
    exit 1
}

[[ $# -le 1 ]] || fail 'Expected one operation: run, bootstrap, or decommission.'
case "$mode" in run|bootstrap|decommission) ;; *) fail 'Unknown operation. Use run, bootstrap, or decommission.' ;; esac
[[ "$(id -u)" != 0 ]] || fail 'Root execution is prohibited.'
[[ "${GITHUB_OWNER:-}" =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]] || fail 'Set a valid GITHUB_OWNER.'
[[ "${GITHUB_REPOSITORY:-}" =~ ^[A-Za-z0-9_.-]+$ ]] || fail 'Set a valid GITHUB_REPOSITORY.'
[[ -n "$runner_name" ]] || fail 'Set RUNNER_NAME.'
[[ "${RUNNER_WORKDIR:-_work}" == _work ]] || fail 'RUNNER_WORKDIR must be _work; workspace architecture changes require review.'
[[ -d "$state_dir" && ! -L "$state_dir" && -w "$state_dir" ]] || fail 'Mount a writable runner-owned state volume at /runner-state.'
mountpoint -q "$state_dir" || fail 'Persistent state must be a separate mount at /runner-state.'
[[ "$(stat -c %u "$state_dir")" == "$(id -u)" && "$(stat -c %a "$state_dir")" == 700 ]] || fail 'State directory must belong to the runner and have mode 0700.'

# Lock identity across bootstrap, listener, and decommission. Do not truncate an
# existing file; reject symlink locks before opening them.
[[ ! -L "$state_dir/.lifecycle-lock" ]] || fail 'State lock must not be a symlink.'
exec 9>>"$state_dir/.lifecycle-lock"
flock -n 9 || fail 'Another process is using this runner identity. Stop it before continuing.'

validate_state() {
    for file in .runner .credentials .credentials_rsaparams .env .path; do
        [[ -f "$state_dir/$file" && ! -L "$state_dir/$file" ]] || fail "Partial configuration: $file is missing."
        [[ "$(stat -c %a "$state_dir/$file")" == 600 ]] || fail "Insecure permissions on $file."
    done
    python3 /validate-state.py "$state_dir" "$repo_url" "$runner_name" || fail 'Local state validation failed; no registration or repair was attempted.'
}


validate_continuity() {
    python3 - "$state_dir/.listener-active" "$continuity_file" "$(hostname)" <<'PY'
import json, os, pathlib, re, stat, sys
def require(condition):
    if not condition:
        raise ValueError('invalid continuity')
def unique(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError('duplicate')
        value[key] = item
    return value
def read(filename):
    path = pathlib.Path(filename)
    info = path.lstat()
    require(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid())
    require(stat.S_IMODE(info.st_mode) == 0o600 and 0 < info.st_size <= 2048)
    value = json.loads(path.read_text(), object_pairs_hook=unique)
    require(type(value) is dict and set(value) == {'version', 'nonce', 'container'})
    require(type(value['version']) is int and value['version'] == 1)
    require(type(value['nonce']) is str and re.fullmatch('[0-9a-f]{64}', value['nonce']))
    require(value['container'] == sys.argv[3])
    return value
try:
    require(read(sys.argv[1]) == read(sys.argv[2]))
except (AssertionError, ValueError, OSError, UnicodeError, TypeError):
    sys.exit(1)
PY
}

record_listener_session() {
    python3 - "$state_dir/.listener-active" "$continuity_file" "$(hostname)" <<'PY'
import json, os, pathlib, secrets, sys
value = {'version': 1, 'nonce': secrets.token_hex(32), 'container': sys.argv[3]}
payload = json.dumps(value, sort_keys=True) + '\n'
try:
    # Local evidence must be durable before the volume marker can authorize a
    # later recovery. Exclusive staging creation refuses unexplained leftovers.
    for filename in (sys.argv[2], sys.argv[1]):
        path = pathlib.Path(filename)
        staging = path.with_name(path.name + '.new')
        with staging.open('x') as stream:
            stream.write(payload)
            stream.flush()
            os.fchmod(stream.fileno(), 0o600)
            os.fsync(stream.fileno())
        staging.replace(path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
except OSError:
    print('Unable to record listener continuity; preserve local and volume evidence.', file=sys.stderr)
    sys.exit(1)
PY
}

finalize_listener_state() {
    validate_continuity || fail 'Listener state preservation did not complete: missing, malformed or mismatched continuity evidence. Use administrative recovery.'
    listener_state_failure() {
        : >"$state_dir/.listener-state-error"
        sync -f "$state_dir"
        fail 'Listener state rejected or could not be preserved. Keep this stopped container and /runner-state; no recovery or deregistration was attempted.'
    }
    for file in .setup_info .service; do
        [[ ! -e "$file" && ! -L "$file" ]] || listener_state_failure
    done
    for file in "${state_files[@]}"; do
        if [[ -L "$file" ]]; then
            [[ "$(readlink "$file")" == "$state_dir/$file" && -f "$state_dir/$file" && ! -L "$state_dir/$file" ]] || listener_state_failure
            [[ "$(stat -c %u "$state_dir/$file")" == "$(id -u)" && "$(stat -c %a "$state_dir/$file")" == 600 ]] || listener_state_failure
        elif [[ -e "$file" ]]; then
            [[ -f "$file" && "$(stat -c %u "$file")" == "$(id -u)" ]] || listener_state_failure
            # Protect newly written files, without adopting their contents as valid.
            chmod 600 "$file" || listener_state_failure
        elif [[ -e "$state_dir/$file" ]]; then
            # Do not guess whether a missing runtime path meant intentional removal.
            listener_state_failure
        fi
    done
    python3 /validate-state.py /actions-runner "$repo_url" "$runner_name" || listener_state_failure
    # A complete staged copy is resumable only if it equals the validated source
    # in this proven container layer. A partial/different copy stays fail closed.
    for pending_file in "$state_dir"/.pending*; do
        file="${pending_file##*/}"
        file="${file#.pending}"
        case "$file" in .runner|.runner_migrated|.credentials|.credentials_migrated|.credentials_rsaparams|.env|.path) ;; *) listener_state_failure ;; esac
        [[ -f "$pending_file" && ! -L "$pending_file" && -f "$file" ]] || listener_state_failure
        cmp -s -- "$pending_file" "$file" || listener_state_failure
    done
    promoted_files=0
    for file in "${state_files[@]}"; do
        if [[ -f "$file" && ! -L "$file" ]]; then
            # Copy to a protected same-volume staging file, then atomically replace
            # the known validated target. Until all commits finish the marker blocks
            # startup; a crash cannot silently use a mixed generation.
            pending_file="$state_dir/.pending$file"
            cp -- "$file" "$pending_file" || listener_state_failure
            chmod 600 "$pending_file" || listener_state_failure
            sync -f "$pending_file" || listener_state_failure
            mv -f -- "$pending_file" "$state_dir/$file" || listener_state_failure
            # Atomically relink without a missing-path window if recovery itself
            # is killed. Never guess about unexplained local staging links.
            relink_file=".relink$file"
            if [[ -e "$relink_file" || -L "$relink_file" ]]; then
                [[ -L "$relink_file" && "$(readlink "$relink_file")" == "$state_dir/$file" ]] || listener_state_failure
            else
                ln -s "$state_dir/$file" "$relink_file" || listener_state_failure
            fi
            mv -Tf -- "$relink_file" "$file" || listener_state_failure
            promoted_files=$((promoted_files + 1))
        elif [[ -e "$state_dir/.pending$file" ]]; then
            # Exact equality was proved above; this is a redundant staged copy,
            # not identity deletion or destructive state repair.
            rm -- "$state_dir/.pending$file" || listener_state_failure
        fi
    done
    validate_state || listener_state_failure
    sync -f "$state_dir" || listener_state_failure
    rm -- "$state_dir/.listener-active" || listener_state_failure
    sync -f "$state_dir" || listener_state_failure
    rm -- "$continuity_file" || listener_state_failure
    sync -f /actions-runner || listener_state_failure
    printf 'Validated interrupted/runtime state; promoted_regular_files=%s.\n' "$promoted_files"

}

shopt -s nullglob dotglob
interrupted_listener=false
pending_state=false
for path in "$state_dir"/*; do
    [[ -f "$path" && ! -L "$path" ]] || fail 'State contains a directory, symlink, or non-regular file.'
    [[ "$(stat -c %u "$path")" == "$(id -u)" && "$(stat -c %a "$path")" == 600 ]] || fail 'State files must belong to the runner and have mode 0600.'
    case "${path##*/}" in
        .runner|.runner_migrated|.credentials|.credentials_rsaparams|.credentials_migrated|.env|.path|.lifecycle-lock) ;;
        .bootstrap-in-progress|.decommission-in-progress) fail 'An interrupted administrative operation requires explicit recovery.' ;;
        .listener-active) interrupted_listener=true ;;
        .listener-state-error) fail 'Listener state preservation did not complete: rejected state requires explicit administrative recovery.' ;;
        .pending.runner|.pending.runner_migrated|.pending.credentials|.pending.credentials_migrated|.pending.credentials_rsaparams|.pending.env|.pending.path) pending_state=true ;;
        *) fail 'Unrecognized state file; review this state before continuing.' ;;
    esac
done

if [[ "$interrupted_listener" == true ]]; then
    [[ "$mode" == run && -z "${RUNNER_TOKEN:-}" && -z "${RUNNER_REMOVE_TOKEN:-}" ]] || fail 'Interrupted listener finalization accepts only token-free run; no administrative operation is attempted.'
    validate_continuity || fail 'Listener state preservation did not complete: missing, malformed or mismatched continuity evidence. Preserve the original container and volume for administrative recovery.'
    # The identity lock is already held. Only finish the proven interrupted
    # transaction; do not bootstrap, remove, or bypass rejected-state markers.
    trap '' INT TERM
    finalize_listener_state
    trap - INT TERM
    printf 'Proven same-container interrupted finalization completed; resuming token-free startup.\n'
elif [[ "$pending_state" == true ]]; then
    fail 'Pending state has no corresponding listener session; explicit administrative recovery is required.'
fi

# Create links only to existing files: this pinned .NET runner can consider a
# dangling symlink an existing configuration and then fail to read its target.
# Never overwrite an unexpected distribution-side file.
for file in .setup_info .service; do
    [[ ! -e "$file" && ! -L "$file" ]] || fail "Unsupported runner-managed $file; preserve it for administrative/architecture review."
done
for file in "${state_files[@]}"; do
    if [[ -e "$state_dir/$file" ]]; then
        if [[ -L "$file" ]]; then
            [[ "$(readlink "$file")" == "$state_dir/$file" ]] || fail "Distribution state link $file is inconsistent. Recreate the container."
        elif [[ -e "$file" ]]; then
            fail "Unexpected distribution-side $file. Preserve this container for administrative review."
        else
            ln -s "$state_dir/$file" "$file"
        fi
    else
        [[ ! -e "$file" && ! -L "$file" ]] || fail "Unexpected or dangling distribution-side $file. Recreate only after administrative review."
    fi
done

state_present=false
for file in "${state_files[@]}"; do
    [[ ! -e "$state_dir/$file" ]] || state_present=true
done


if [[ "$mode" == decommission ]]; then
    [[ "${RUNNER_DECOMMISSION_CONFIRM:-}" == "$runner_name" ]] || fail 'Explicit removal requires RUNNER_DECOMMISSION_CONFIRM equal to RUNNER_NAME.'
    [[ "$state_present" == true ]] || fail 'No local identity to decommission; inspect GitHub records separately.'
    validate_state
    [[ -n "${RUNNER_REMOVE_TOKEN:-}" ]] || fail 'Supply a separately authorized short-lived removal token at runtime.'
    [[ -z "${RUNNER_TOKEN:-}" ]] || fail 'A bootstrap token is not a removal credential.'
    : >"$state_dir/.decommission-in-progress"
    # Never remove from a shutdown trap. Protect upstream output from logs.
    if ./config.sh remove --unattended --token "$RUNNER_REMOVE_TOKEN" >"$state_dir/.decommission-output" 2>&1; then
        unset RUNNER_REMOVE_TOKEN
        for file in "${state_files[@]}"; do
            rm -f -- "$state_dir/$file"
        done
        rm -f -- "$state_dir/.decommission-output" "$state_dir/.decommission-in-progress"
        printf 'Explicit decommission completed. GitHub deregistration preceded local state removal.\n'
        exit 0
    fi
    unset RUNNER_REMOVE_TOKEN
    fail 'Decommission failed. Preserve the marker and protected .decommission-output plus runner _diag for operator review.'
fi

[[ -z "${RUNNER_REMOVE_TOKEN:-}" ]] || fail 'Removal tokens are accepted only by explicit decommission.'
if [[ "$state_present" == true ]]; then
    validate_state
    [[ "$mode" == run ]] || fail 'Already configured; use run. Bootstrap never replaces an existing identity.'
    [[ -z "${RUNNER_TOKEN:-}" ]] || fail 'Ordinary restart must not receive a bootstrap token.'
else
    [[ "$mode" == bootstrap ]] || fail 'No registration state. Explicit bootstrap is required after separate Owner authorization.'
    [[ -n "${RUNNER_TOKEN:-}" ]] || fail 'Explicit bootstrap requires a runtime short-lived registration token.'
    # A durable marker prevents a retry even if registration fails before
    # creating .runner, or the host dies during configuration.
    : >"$state_dir/.bootstrap-in-progress"
    bootstrap_pid=''
    preserve_bootstrap_state() {
        for file in "${state_files[@]}"; do
            if [[ -f "$file" && ! -L "$file" ]]; then
                chmod 600 "$file"
                mv -- "$file" "$state_dir/$file"
                ln -s "$state_dir/$file" "$file"
            fi
        done
    }
    stop_bootstrap() {
        trap '' TERM INT
        if [[ -n "$bootstrap_pid" ]]; then
            kill -TERM -- "-$bootstrap_pid" 2>/dev/null || true
            wait "$bootstrap_pid" 2>/dev/null || true
        fi
        unset RUNNER_TOKEN
        fail 'Bootstrap interrupted. Marker and partial state are preserved; explicit recovery is required.'
    }
    trap preserve_bootstrap_state EXIT
    trap stop_bootstrap TERM INT
    setsid ./config.sh --unattended --url "$repo_url" --token "$RUNNER_TOKEN" \
        --name "$runner_name" --labels "${RUNNER_LABELS:-self-hosted,linux,x64,thisbyte}" \
        --work _work --disableupdate >"$state_dir/.bootstrap-output" 2>&1 &
    bootstrap_pid=$!
    if ! wait "$bootstrap_pid"; then
        unset RUNNER_TOKEN
        fail 'Bootstrap failed. Preserve the marker and protected .bootstrap-output plus runner _diag for operator review; do not retry automatically.'
    fi
    bootstrap_pid=''
    unset RUNNER_TOKEN
    preserve_bootstrap_state
    trap - EXIT TERM INT
    validate_state
    rm -f -- "$state_dir/.bootstrap-output" "$state_dir/.bootstrap-in-progress"
    printf 'Bootstrap completed; persisted identity validated. Bootstrap token discarded.\n'
fi

unset RUNNER_TOKEN RUNNER_REMOVE_TOKEN
printf 'Starting listener using persisted identity; normal shutdown never deregisters.\n'

# Bind any interrupted finalization to this retained container layer. Unknown
# continuity fails closed; proven continuity can finish the validated commit.
# No job process inherits a shell cleanup trap.
record_listener_session || fail 'Listener continuity was not recorded; no listener was started.'
listener_pid=''
last_signal=''
forward_listener_signal() {
    last_signal="$1"
    if [[ -n "$listener_pid" ]]; then
        kill -"$1" "$listener_pid" 2>/dev/null || true
    fi
}
trap 'forward_listener_signal TERM' TERM
trap 'forward_listener_signal INT' INT
# Background Bash children otherwise inherit ignored SIGINT. Restore its default
# before execing the listener; the real listener owns job shutdown/draining.
env --default-signal=INT ./bin/Runner.Listener run &
listener_pid=$!
if [[ -n "$last_signal" ]]; then
    kill -"$last_signal" "$listener_pid" 2>/dev/null || true
fi
while true; do
    listener_status=0
    unset completed_pid
    # -p distinguishes an actual child completion from a signal-interrupted
    # wait, even when a trap ran before the primary wait (B-1).
    wait -n -p completed_pid "$listener_pid" 2>/dev/null || listener_status=$?
    if [[ -n "${completed_pid:-}" ]]; then
        break
    fi
    if [[ "$listener_status" == 127 ]]; then
        # A child that exited before wait -n is already in Bash's status cache.
        # This explicit, nonblocking wait retrieves it exactly once.
        listener_status=0
        wait "$listener_pid" || listener_status=$?
        break
    fi
done
# Once the listener is reaped, repeated signals must not interrupt the protected
# finalization or signal a reused PID. Docker's grace timeout still bounds it.
listener_pid=''
trap '' TERM INT

finalize_listener_state
printf 'Listener stopped; validated runtime identity state preserved. No deregistration performed.\n'
exit "$listener_status"
