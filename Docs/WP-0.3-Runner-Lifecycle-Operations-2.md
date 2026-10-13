# WP-0.3 — Runner Lifecycle Operations — Round 2

**Role Authority:** Implementation Tool
**Date:** 2026-10-12
**Project:** ThisByte Action Runner (AR)
**Version:** 2
**Status:** Round 2 implementation operations note; independent delta review and registered lifecycle testing pending.
**Scope:** F-1, A-1, A-2 from REVIEW-action-runner-004.md. This version supersedes the operational guidance in the immutable Round 1 note; it does not amend governance.

## Storage and lifecycle

The Compose service mounts only the protected runner-state named volume at /runner-state. The mount is required, runner-owned, mode 0700; regular state files must be mode 0600. Valid identity files link into the versioned distribution at runtime. Binaries and /actions-runner/_work are not persisted in that volume. _work survives stopping one container but is disposable on recreation.

Explicit bootstrap is permitted only after separate Owner registration/token authorization. It creates a durable in-progress marker before attempting configuration. The pinned runner generates ordinary configuration files; handled completion or failure moves them into protected state. Success validates the complete identity before starting the listener. Failure/interruption preserves state and diagnostics and requires administrative recovery.

Normal run requires valid state and no registration token. The entrypoint holds the identity lock while supervising the listener under Docker init, forwards TERM/INT directly to the listener PID, waits for actual listener exit, validates the complete runtime state, and persists valid newly created/replaced state files through protected same-volume staging. It restores links, syncs state, and clears .listener-active only after successful finalization. Listener exit status is propagated. Normal stop never deregisters; job processes do not inherit a shell cleanup trap. Restart policy remains no automatic restart; operators must start the service after Docker/host restart.

Decommission is a separately requested administrative operation requiring confirmation matching RUNNER_NAME, a separately authorized removal token, valid state, and an exclusive lock. GitHub removal precedes controlled local state removal. Round 2 tested negative decommission guards using synthetic inputs and mocks, proving refusal before configuration/removal. Real decommission remains untested and unauthorized.

## Verification and future operator protocol

Run these commands from C:\Development\action-runner for noncredentialed validation:

```powershell
docker compose config
docker compose build
.\tests\validate-containers.ps1
git diff --check
```

The container validation creates only randomly named isolated test containers/volume, uses network none, derives synthetic state, and removes those exact resources. It does not perform GitHub registration or decommission. See README.md for explicit future bootstrap, ordinary service, stop/restart, and decommission commands; those credentialed operations require separate Owner authorization.

## Limitations and administrative recovery

Local schema/RSA consistency validation cannot prove GitHub record existence, credential acceptance, or real listener reconnection. Real Online/Offline transitions, Docker Desktop/WSL2/Windows restarts, abnormal host recovery, stale-record handling, decommission/re-registration, and a harmless CI job remain DEFERRED.

Dangling identity links are intentionally not created: the pinned .NET runner can consider them existing files and fail to read their targets. Forced termination during configuration may leave partial files in the interrupted container layer. Preserve that container, protected diagnostics, and the durable volume marker for administrative review; do not automatically recreate/retry it. Valid completed state survives recreation. Unknown state or unsupported credentials fail closed.

Bootstrap/removal input is unset before listener startup or operation completion; Docker administrators can still inspect the one-off container's creation environment while it exists. Remove successful one-off administrative containers promptly and clear the operator environment. Preserve failed containers securely for diagnosis. Do not store runtime tokens in permanent .env files, images, source control, or public logs.

Do not delete the state volume, reuse the old runner-work volume as identity state, or silently clear recovery markers. No old volumes, existing artifacts, or GitHub records were migrated/deleted by this implementation.

## Governance

The Owner's instruction, "This is your authorization to proceed with WP-03 implementation", followed the proposal to create codex/wp-0.3-lifecycle and apply a scoped exception to the missing scope timestamp because approved WP-0.2 and WP-0.3 define the implementation scope. Work proceeded on that basis. This is scoped to WP-0.3; alignment.md was not amended. Branch creation in Round 1 was the only Git mutation across WP-0.3; Round 2 performed no Git mutation. Commit/push/merge remain Owner-controlled. The prior scoped timestamp exception remains recorded for the same WP-0.3; no new governance exception or amendment is asserted.

Google Drive mirroring remains due at the once-per-session documentation sync before end-of-day session context. No end-of-day record or Drive sync was performed as part of this work package.

## Runtime migration state (F-1)

.runner_migrated is RunnerSettings-shaped identity/configuration and is subject to the same repository/name, numeric identity fields, HTTPS server, _work, persistent-mode and disableUpdate constraints as .runner. .credentials_migrated retains the existing OAuth credential validation. Both are recognized state, linked when already present, captured if newly created or atomically replaced during listener execution, protected as runner-owned 0600 files, and retained across normal stop/start and recreation. Both participate in explicit decommission's known-state collection; normal shutdown does not call removal.

A durable .listener-active marker is established before starting the listener. After exit, known file paths/owners/links are checked, newly written regular files are protected, and the complete container-side state is validated before any promotion. Files are copied to .pending<filename> inside the volume, synced, atomically committed, and linked back. The marker blocks startup throughout a mixed-generation transfer. Rejected state is not adopted as valid identity and remains in the stopped container; .listener-active/.listener-state-error block later startup. No automatic repair, marker clearance, re-registration or replacement occurs.

The local pinned binaries reference GetMigratedSettings/SaveMigratedSettings and GetMigratedCredentials/SaveMigratedCredential. They also reference .setup_info, JitConfig/SetupInfo, .service and service methods; neither JIT nor service configuration is enabled in this lifecycle. Those two filenames are not assumed to be ordinary listener migration state and are refused if encountered, with evidence preserved for architecture/administrative review. This implements local persistence and validation, not GitHub migration policy.

Four synthetic migration generations passed across actual Docker TERM/INT, same-container stop/start, and recreation. Base identity hashes remained unchanged; migrated files had expected content/ownership/mode; no bootstrap/removal mock was called. _work remained in the same container and was absent on recreation. Malformed newly written or persisted migration files failed closed. Real migration timing, authentication, endpoint behavior, job draining and abnormal host recovery remain DEFERRED until separately authorized registered-runner testing.

## Administrative Recovery — Inspect, Preserve, Decide, Authorize, Revalidate, Resume

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
| Listener finalization interrupted but complete persisted and container-side state is confirmed identical/valid, with no unresolved pending files | Owner may approve clearing `.listener-active` and any backed-up error marker. Revalidate before ordinary run. An invalid or unpersisted migrated file does not satisfy this condition. |

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


