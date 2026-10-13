# WP-0.3 — Runner Lifecycle Operations

**Role Authority:** Implementation Tool
**Date:** 2026-10-12
**Project:** ThisByte Action Runner (AR)
**Status:** Implementation operations note; independent review and registered lifecycle testing remain pending.

## Storage and lifecycle

The Compose service mounts only the protected runner-state named volume at /runner-state. The mount is required, runner-owned, mode 0700; regular state files must be mode 0600. Valid identity files link into the versioned distribution at runtime. Binaries and /actions-runner/_work are not persisted in that volume. _work survives stopping one container but is disposable on recreation.

Explicit bootstrap is permitted only after separate Owner registration/token authorization. It creates a durable in-progress marker before attempting configuration. The pinned runner generates ordinary configuration files; handled completion or failure moves them into protected state. Success validates the complete identity before starting the listener. Failure/interruption preserves state and diagnostics and requires administrative recovery.

Normal run requires valid state, needs no registration token, holds an exclusive identity lock, and executes the listener directly under Docker init. Normal stop never deregisters. Restart policy is deliberately no automatic restart, preventing unattended registration/configuration loops. Operators must start the service after Docker/host restart.

Decommission is a separately requested administrative operation requiring confirmation matching RUNNER_NAME, a separately authorized removal token, valid state, and an exclusive lock. GitHub removal precedes controlled local state removal. Its execution was not tested or performed during WP-0.3.

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

The Owner's instruction, "This is your authorization to proceed with WP-03 implementation", followed the proposal to create codex/wp-0.3-lifecycle and apply a scoped exception to the missing scope timestamp because approved WP-0.2 and WP-0.3 define the implementation scope. Work proceeded on that basis. This is scoped to WP-0.3; alignment.md was not amended. Branch creation was the only Git mutation; commit/push/merge remain Owner-controlled.

Google Drive mirroring remains due at the once-per-session documentation sync before end-of-day session context. No end-of-day record or Drive sync was performed as part of this work package.
