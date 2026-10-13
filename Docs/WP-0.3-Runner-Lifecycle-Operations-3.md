# WP-0.3 Runner Lifecycle Operations — Version 3

Date: 2026-10-13  
Role Authority: Implementation Tool  
Scope: Round 3 F-2 and B-1 remediation under Review 005. Supersedes operations version 2 for current implementation; earlier artifacts remain immutable. Registration and administrative credentialed actions require separate Owner authorization.

## Persistent Identity and Disposable Workspace

The `runner-state` named volume is mounted at `/runner-state`. It intentionally
holds sensitive runner identity/configuration, independent of the disposable
container filesystem and `/actions-runner/_work`. Docker initializes the volume
from the image's runner-owned directory (mode `0700`). Files use mode `0600`.
Existing bind mounts or volumes with incorrect ownership/permissions fail closed;
the entrypoint does not silently repair them.

The distribution's existing `.runner`, `.credentials`, `.credentials_rsaparams`,
`.env`, `.path`, and optional `.credentials_migrated` / `.runner_migrated` paths link
into that volume. Migrated settings have the same RunnerSettings constraints as
`.runner`; migrated credentials use the same OAuth validation as `.credentials`. Here
`.env` means the runner-generated environment snapshot, not the host's Compose
configuration file. Binaries remain in the versioned image. Job workspace data is
disposable by default: it survives stopping the same container, but not recreation.
Use explicit caching/artifacts for future performance needs.

A lock prevents two containers from using one identity concurrently. Interrupted
bootstrap/decommission leaves a durable marker requiring administrative review.
Malformed, partial, mismatched, insecure, or unexpected state stops startup without
registration, replacement, deregistration, or state destruction. Local validation
checks structure and configured identity; it cannot establish that the GitHub record
still exists or that GitHub accepts the persisted credentials.

Do not run `docker compose down --volumes` against an identity you intend to keep.
Do not reuse the old `runner-work` volume as registration state. Existing volumes
are not migrated, renamed, or deleted by this implementation. Protect state backups
as credentials, never commit/copy them into images, and restrict host/backup access.

## Startup, Shutdown, and Restart

After separately authorized registration has established valid state:

```powershell
docker compose up -d
docker compose stop
docker compose start
```

Normal SIGTERM/SIGINT, container stop, and host lifecycle events never deregister.
The entrypoint supervises the listener under Docker's init and forwards TERM/INT
to the listener, without the upstream shell retry/update loop. The default stop
grace period is 60 seconds. After the listener exits, the supervisor validates the
complete runtime state, protects newly created files, copies validated regular
files through same-volume staging into `/runner-state`, and restores links. This
also captures atomic replacement of existing links by the runner. Only then does
it clear `.listener-active` and return the listener's exit status. The identity
lock remains held through finalization; shutdown never enters decommission.

Each listener session records the same versioned nonce and current container
hostname in `/runner-state/.listener-active` and container-local
`/actions-runner/.listener-session`, both runner-owned at mode `0600`. This nonce is
local transaction evidence, not a GitHub credential. Local evidence is synced
before the durable marker is published and before the listener starts.

After SIGKILL, token-free `run` can finish interrupted finalization **only** when
those protected records are valid, equal, and identify the current retained
container. It acquires the identity lock, inspects paths, validates the effective
state, completes the same stage/sync/promote/relink/revalidate transaction, and
clears the old evidence only after completion. A valid unchanged set of volume
links needs zero regular-file promotions. Relinking is atomic, avoiding a missing
state-path window if completion is interrupted again. A leftover complete staging
file must exactly match its validated retained-layer source; partial/different
staging is rejected, not guessed at or overwritten as valid identity.

Recreation has no original local evidence and remains fail closed. Missing,
malformed, mismatched, insecure, duplicate, wrong-container, or legacy empty
continuity records also remain fail closed. Do not fabricate or copy continuity
evidence to force recovery. Malformed runtime migration is not promoted as valid
identity; `.listener-state-error` still requires the manual recovery procedure.
Preserve the stopped container and volume for those cases. `.setup_info` and
`.service` are not supported in this lifecycle, which does not enable JIT or service
configuration; if encountered, stop for administrative/architecture review instead of discarding
or adopting them. Real credential migration and abnormal host recovery remain
DEFERRED to authorized registered-runner tests.
Shutdown does not require a token. Valid state reconnects on restart without one.
Expected GitHub status after stop is registered but Offline; actual registered
lifecycle behavior remains deferred to authorized testing.

`restart: "no"` deliberately replaces `unless-stopped`. An operator must start the
container after host/Docker restart or listener failure. This prevents unattended
configuration/error loops and keeps failures diagnosable. It does not change the
persistent identity model. An availability/restart policy can be reviewed later.

## Explicit Bootstrap — Execution Not Authorized by WP-0.3

WP-0.3 implements this mechanism but does not authorize obtaining tokens or
registering a runner. Only after separate Owner authorization, the operator supplies
an authorized short-lived repository registration token through their process
environment, then runs:

```powershell
docker compose run --name thisbyte-runner-bootstrap --no-deps --env RUNNER_TOKEN runner bootstrap
```

The exact token-acquisition mechanism is not selected here. Do not type tokens as
command-line literals or save them in `.env`. `--env RUNNER_TOKEN` copies an existing
process environment variable; clear it from the operator environment after use:

```powershell
Remove-Item Env:RUNNER_TOKEN -ErrorAction SilentlyContinue
```

Bootstrap only accepts absent state, uses `--disableupdate`, and never uses silent
replacement. Its one-off container starts the listener after successful configuration.
The runner generates ordinary configuration files during bootstrap. Completion or
handled failure moves available files to protected storage before linking them back
into the distribution. Forced termination during configuration can leave partial
files only in the interrupted container layer; preserve that container and review
it alongside the durable marker and GitHub record. Do not blindly recreate/retry it.
After successful bootstrap, stop and remove the one-off container before starting
the ordinary service; this also removes its Docker environment metadata:

```powershell
docker stop thisbyte-runner-bootstrap
docker rm thisbyte-runner-bootstrap
docker compose up -d
```

Preserve a failed bootstrap container instead of running those commands. Restart
uses `run` (the default), not `bootstrap`. Docker admins can inspect one-off container
environment while it exists; bootstrap is therefore an explicit, short-lived,
operator-controlled operation. The bootstrap token is unset before listener startup
and is not normal persistent configuration. The image controls runner upgrades.

Failure preserves `.bootstrap-in-progress` and protected `.bootstrap-output` in the
state volume, plus upstream `_diag` in the stopped container. Upstream output is
not sent to container logs. Preserve diagnostic files before removing a failed
container; bootstrap deliberately omits `--rm`. Administrative
diagnostics are sensitive and must not be copied into source control or public logs.
If failure occurs even before identity files exist, the marker blocks automatic
retry. Review GitHub/local disagreement before any recovery; do not blindly erase
the marker or configuration. An existing identity rejects bootstrap even with a token.

## Explicit Decommission — Separate Administrative Operation

Not executable under WP-0.3's authorization. After separate Owner authorization,
stop the listener and preserve a protected backup before deliberate removal.
Supply a short-lived repository **removal** token as `RUNNER_REMOVE_TOKEN` in the
operator environment, then explicitly confirm the intended runner name:

```powershell
docker compose stop
docker compose run --name thisbyte-runner-decommission --no-deps --env RUNNER_REMOVE_TOKEN --env RUNNER_DECOMMISSION_CONFIRM=thisbyte-hp-runner runner decommission
Remove-Item Env:RUNNER_REMOVE_TOKEN -ErrorAction SilentlyContinue
```

The path requires valid local state, confirmation matching `RUNNER_NAME`, a separate
removal token, and an exclusive identity lock. GitHub removal must succeed before
explicit removal of the known local identity files.
After success, remove the one-off container with `docker rm thisbyte-runner-decommission`.
Preserve it on failure. Failure preserves a
`.decommission-in-progress` marker and protected `.decommission-output`, blocking
ordinary startup until reviewed. Never invoke this for ordinary shutdown. Unknown,
stale, duplicate, or damaged state requires deliberate administrative recovery;
there is no automatic `--replace`, local-only removal, or token acquisition.

## Administrative Recovery — Inspect, Preserve, Decide, Authorize, Revalidate, Resume

This version records the current Round 3 recovery procedure.

This is an operator procedure for a future authorized administrative gate, not
an automatic recovery feature and not permission to register or remove a runner.
Keep the failed/stopped container until evidence and state have been preserved.

1. **Inspect without changing identity.** From the project root, identify the
   affected container and volume using the commands below. Do not dump full
   `docker inspect` environment data or credential files into public logs.
   Note the marker, exit status, exact files present, ownership/modes, and whether
   known identity files were only in the stopped container or in `/runner-state`.
2. **Preserve.** Stop all processes using that identity; do not remove their
   containers. Save protected copies of the volume and existing container-side
   state/diagnostics. Record backup hashes. An incomplete `.pending*` transfer or
   rejected runtime file is evidence, not an instruction to finish a migration.
3. **Determine local/remote condition.** Validate copies offline. At the future
   Owner-authorized GitHub administrative gate, inspect the target repository's
   Settings > Actions > Runners and match runner name/identity to the preserved
   records. Determine whether the record exists, is duplicated, or is already
   absent. Local validation alone cannot establish this or credential acceptance.
4. **Authorize a specific action.** Record the confirmed condition, exact identity,
   backup reference, files/markers affected, and Owner approval. Use the decision
   table below. Do not clear a marker or overwrite, delete, replace, or re-register
   uncertain state merely because it prevents startup.
5. **Revalidate.** After the approved action, recheck complete local state,
   permissions, absence of unexpected/pending files, and local/remote consistency.
   A remaining error or ambiguity stops recovery. Remote authentication is a
   future registered-runner test, not an offline PASS.
6. **Resume only the approved mode.** A verified retained identity uses ordinary
   `run` without tokens. A fresh unregistered identity requires separate explicit
   bootstrap/token authorization. Confirm Online and a harmless job only at that
   future gate; stop/review before any deployment credentials.

Read-only inspection (substitute the container ID/name found here):

```powershell
docker compose ps -a
docker ps -a --filter volume=action-runner_runner-state
docker compose logs --tail 100 runner
$affectedContainer = Read-Host 'Affected stopped container ID/name'
docker inspect --format '{{json .State}} {{json .Mounts}}' $affectedContainer
docker volume inspect action-runner_runner-state
# Continue only after confirming this is the affected, existing volume.
docker run --rm --network none --entrypoint bash --mount type=volume,source=action-runner_runner-state,target=/runner-state,readonly thisbyte/actions-runner:2.328.0 -c 'find /runner-state -mindepth 1 -maxdepth 1 -printf "%f %u %m\n"; python3 /validate-state.py /runner-state https://github.com/scantoria/thisbyte-website thisbyte-hp-runner'
```

The maintenance command bypasses the lifecycle entrypoint; it does not acquire
tokens, configure a runner, or clear markers. Adjust repository/name only to the
Owner-confirmed non-secret identity. Missing/malformed state is an expected
validation failure; it must not trigger a recovery action by itself.

Protected evidence backup, after confirming no process is writing this volume:

```powershell
$backupDir = Join-Path $PWD ('runner-state\recovery-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $backupDir
$recoveryOwner = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
icacls $backupDir /inheritance:r /grant:r "${recoveryOwner}:(OI)(CI)F"
$evidenceContainer = 'runner-recovery-evidence-' + (Get-Date -Format 'yyyyMMddHHmmss')
docker run --name $evidenceContainer --network none --entrypoint bash --mount type=volume,source=action-runner_runner-state,target=/source,readonly thisbyte/actions-runner:2.328.0 -c 'umask 077; tar -czf /tmp/state-evidence.tar.gz -C /source .'
docker cp "${evidenceContainer}:/tmp/state-evidence.tar.gz" (Join-Path $backupDir 'state-evidence.tar.gz')
Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $backupDir 'state-evidence.tar.gz')
$recoveryFiles = @('.runner','.runner_migrated','.credentials','.credentials_migrated','.credentials_rsaparams','.env','.path','.setup_info','.service')
foreach ($file in $recoveryFiles) {
    docker cp "${affectedContainer}:/actions-runner/$file" (Join-Path $backupDir ($file + '.container-copy'))
}
docker cp "${affectedContainer}:/actions-runner/_diag" (Join-Path $backupDir 'container-diag')
```

Record which container files were absent instead of substituting invented files.
Check every command's exit status and verify copied-file hashes before proceeding.
Keep the evidence container until its archive is verified. Its later removal must
target that exact container, never the affected runner/volume by accident. The
`runner-state/` host directory is excluded from Git and Docker context; restrict
backup access and retention as credential-bearing material. No backup is made by
the implementation task itself.

| Condition established from evidence and future GitHub inspection | Authorized recovery decision |
| --- | --- |
| Failed bootstrap before complete usable local state, no remote record | Preserve incomplete state/marker; retire the old local identity context and prepare a fresh separate volume. Bootstrap only after new explicit token/registration authorization. |
| Failed/interrupted bootstrap but remote record exists and local identity is complete, matches, and is approved for retention | Validate the entire local set and determine whether the apparent failure happened after successful configuration. Clear only the specifically approved marker/output artifacts, then ordinary token-free run. |
| Interrupted bootstrap, partial/malformed local state, remote record may exist | Do not clear the marker to force startup. Preserve the container and volume, establish the record's identity at the future gate, and obtain explicit approval to retire it or restore a verified complete matching snapshot. If a usable matching snapshot is unavailable, Owner-controlled remote retirement must precede authorized fresh bootstrap. |
| Failed/interrupted decommission, remote record still exists and complete matching local state is usable | Owner chooses either retaining the identity (approved marker clearance and ordinary run) or another separately authorized administrative removal attempt. A bootstrap token cannot substitute for a removal token. |
| Failed/interrupted decommission, remote record is already confirmed absent | Do not repeatedly call removal or infer absence from a failed command. Owner approves retirement of the old local context; retain evidence and use a fresh separate volume if a replacement runner is separately authorized. |
| Stale local state, duplicate remote records, rejected runtime migration, mixed `.pending*` transfer, or unknown remote status | Keep all markers and files. Resolve the exact intended record/state generation administratively at the future gate; no silent replacement. Restore only a specifically verified complete matching snapshot under an approved recovery plan, or explicitly retire the confirmed remote identity and use fresh storage. |
| Listener finalization interrupted, original container layer retained, continuity records protected/valid/equal and current, effective state valid | Ordinary token-free `run` completes the proven interrupted transaction before listener startup. No manual marker deletion is needed. Exact complete staging can resume; mismatched staging or a rejected-state marker still stops recovery. |
| Listener finalization interrupted, original layer unavailable or continuity missing/malformed/mismatched/legacy | Keep the marker and evidence; use the explicit administrative process. Never invent local continuity evidence. Owner may approve a specifically verified retained snapshot/identity and exact manual cleanup, or approved retirement/fresh storage at the future gate. |

**Marker clearance example: complete retained identity only.** Execute this only
after steps 1–4 establish valid matching identity and the Owner approves exactly
the listed marker/output files. Preserve their backup first. The lock prevents
clearance while another process uses the identity; local validation runs before
any removal. This example is for a confirmed completed bootstrap, not partial or
ambiguous state:

```powershell
docker run --rm --network none --entrypoint bash --mount type=volume,source=action-runner_runner-state,target=/runner-state thisbyte/actions-runner:2.328.0 -c 'set -e; exec 9>>/runner-state/.lifecycle-lock; flock -n 9; python3 /validate-state.py /runner-state https://github.com/scantoria/thisbyte-website thisbyte-hp-runner; rm -f -- /runner-state/.bootstrap-in-progress /runner-state/.bootstrap-output; sync -f /runner-state'
```

For a retained identity after another confirmed condition, obtain approval for
the exact `.decommission-in-progress` / `.decommission-output` or
`.listener-active` / `.listener-state-error` artifact names before making the
equivalent explicit clearance. Do not remove identity files or unresolved staging
files through this marker procedure. Afterwards inspect the full allow-list and
revalidate; any remaining marker or unexpected file blocks resume.
The normal provable same-container completion path does not use this manual
clearance procedure. It performs full validation and persistence first; merely
deleting `.listener-active` is never the implementation's SIGKILL recovery.

**Fresh context example: old remote identity absent or explicitly retired.**
After its absence has been established at the future gate and the Owner has
approved fresh storage, select an unused project name and confirm its volume does
not already exist. Preserve the old volume and stopped container. This creates
new empty storage without deleting or relabeling old evidence:

```powershell
docker volume inspect action-runner-recovery-001_runner-state
# Continue only if the volume is confirmed absent and this name is approved.
docker compose --project-name action-runner-recovery-001 create runner
```

New storage is unregistered and ordinary startup must fail closed. Do not
bootstrap it until separately authorized. Use the approved new project name
consistently with all subsequent Compose commands, including any future explicit
bootstrap. The exact token-acquisition mechanism remains undecided. No remote
inspection, recovery, marker clearance, credentialed removal or bootstrap was
executed in Round 2.

## Local Noncredentialed Tests

```powershell
docker compose config
docker compose build
docker run --rm --network none --entrypoint bash --mount type=volume,target=/runner-state --mount "type=bind,source=$PWD,target=/project,readonly" thisbyte/actions-runner:2.328.0 /project/tests/lifecycle.sh
.\tests\validate-containers.ps1
```

The tests use disposable, synthetic state and stubbed configuration/listener
processes with no network access or real credentials. They establish local control
flow, persistence links, locks, failure preservation, and signal routing; they do not
prove GitHub Online/Offline transitions or real registered-runner reconnection.
The full suite includes actual Docker SIGKILL with synthetic listeners: retained
unchanged state, retained pending migration, recreation refusal, invalid continuity,
and a second kill during recovery with complete versus mismatched staging. These
tests do not establish Docker Desktop/WSL2/Windows shutdown or real runner behavior.

**Named registration-gate test B2-RUNNER-2.328.0-TERM-DRAIN-60S-ESCALATION — DEFERRED:**
after separate Owner authorization, test the actual runner 2.328.0 TERM/INT handling,
active-job drain and exit status, sufficiency of the 60-second grace period, Docker
escalation to SIGKILL, and subsequent retained-container continuity. Keep real
GitHub migration plus stop/start/recreation as a separate named DEFERRED test.

## Supervision and evidence limits

B-1 uses completion-aware Bash wait: completed child PID identifies its true result; an already-exited child is retrieved once through cached wait status. Interrupted waits retry without a stale flag. Deterministic synthetic TERM tests before the loop and before primary wait both return listener status 17.

Continuity is a local transaction association, not authentication against a hostile container administrator. Both records must be regular runner-owned 0600 files, bounded strict JSON without duplicate keys, with exact version/nonce/container fields and matching current hostname. Unknown staging and interrupted record publication remain fail closed. Complete equal pending state can resume; partial/different staging cannot. No continuity evidence may be fabricated or transplanted to force recovery.

LOCAL and SYNTHETIC evidence demonstrates container control flow only. Registered GitHub, Windows/WSL2/Docker Desktop host lifecycle and actual runner job drain remain DEFERRED. No recovery/backup or credentialed operation in this document was executed by this implementation task.

