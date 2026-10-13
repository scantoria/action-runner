# Review — WP-0.3 Runner Lifecycle Implementation / Remediation

**Authority exercised:** Review Tool role, per alignment.md Section 2.
**Date:** 2026-10-12
**Reviewer:** Claude (Opus 5.5), acting as Review Tool
**Reviewed artifact:** `_Context/Executions/WP-0.3-handoff-20261012.md`, produced by the platform performing the Implementation Tool role.
**Reviewed implementation:** uncommitted working tree on branch `codex/wp-0.3-lifecycle` (base `1f671e6`): `entrypoint.sh`, `validate-state.py`, `Dockerfile`, `compose.yaml`, `.env.example`, `.gitignore`, `.dockerignore`, `README.md`, `tests/lifecycle.sh`, `tests/container-listener.sh`, `tests/validate-containers.ps1`, and `Docs/WP-0.3-Runner-Lifecycle-Operations.md`.
**Governing scope:** `_Context/Work-Packages/WP-0.3-Runner-Lifecycle-Implementation-Remediation.md`, the approved WP-0.2, and project-specification.md Revision 2.

**Disposition: CHANGES REQUIRED, limited to finding F-1.** Every other acceptance criterion is supported by the evidence (see Section 3). F-1 can be closed by a code change, or by the Owner explicitly accepting it as a registration-gate risk with a named test. Either way, it must be closed before ordinary registered operation.

Runner registration remains **NOT AUTHORIZED**. This review authorizes nothing.

---

## 1. Independent verification performed

| Check | Result |
|---|---|
| Governance files unchanged | `sha256sum alignment.md project-specification.md` gives `a782dbbd…1e4d` and `3890c449…e59b`, matching the handoff. |
| Branch | `codex/wp-0.3-lifecycle` at `1f671e67`. The handoff reports branch creation only, with no commits, and `git status` confirms that. |
| `docker compose config --format json` | exit 0. `restart: no`, `init: true`, `stop_grace_period: 1m0s`; no privileged option, no ports, no `env_file`; the only volume is `runner-state` mounted at `/runner-state`; the environment contains only `GITHUB_OWNER, GITHUB_REPOSITORY, RUNNER_LABELS, RUNNER_NAME, RUNNER_WORKDIR`. |
| `docker compose build --quiet` | exit 0 (fully cached). |
| `.\tests\validate-containers.ps1` | exit 0. All 26 PASS lines reproduced exactly as listed in the handoff, and cleanup completed. |
| `git diff --check` | exit 0. |
| Image matches source | `/entrypoint.sh` and `/validate-state.py` inside `thisbyte/actions-runner:2.328.0` hash to `de3adeb6…aeca` and `67616a38…7604`, identical to the working tree with CRLF line endings normalized. |
| Image ID | Local `docker image inspect` reports `sha256:8e9fe5b3…`, while the handoff reports `sha256:10d5ea12…`. Every layer's creation time (21:04:35–21:06:05 EDT) matches the handoff's build, and the script content matches. This is consistent with Docker Desktop's containerd store reporting the image ID differently. **Not material**, but future handoffs should state which ID form they record. |
| Runner state-file names | An offline scan of the pinned 2.328.0 DLLs found these runner-managed filenames in `Runner.Common.dll`: `.runner`, `.credentials`, `.credentials_rsaparams`, `.credentials_migrated`, `.runner_migrated`, `.setup_info`, `.service`. `.runner_migrated` also appears in `Runner.Listener.dll`. This is the basis for F-1. |

I also read every line of `entrypoint.sh`, `validate-state.py`, and the three test scripts, and the README and operations-note changes, against WP-0.3 §2.1–§2.10.

## 2. Findings

### F-1 — State files the listener creates at runtime are not persisted, and they block a same-container restart (CHANGES REQUIRED; verdict: PLAUSIBLE)

`entrypoint.sh:48–63` links a state file from the distribution into `/runner-state` **only if that file already exists in the volume**, because a dangling link breaks the pinned runner. Any state file the listener first creates *while running* is therefore written as an ordinary file in the container layer, not in the volume.

The pinned runner manages at least two such files: `.credentials_migrated` and `.runner_migrated` (see Section 1). The implementation already expects `.credentials_migrated` to appear: it is in `state_files`, in the allow-list, and in the validator. But there is no path by which it reaches the volume after a runtime migration, and `.runner_migrated` is absent from `state_files`, the allow-list, and the validator.

Failure scenario, if GitHub migrates the runner's credentials while the listener is running:
1. The listener writes `/actions-runner/.credentials_migrated` (and possibly `.runner_migrated`) into the container layer.
2. `docker compose stop` then `docker compose start` reuses the same container. Line 61 then finds a regular `.credentials_migrated` in the distribution with no matching file in the volume, and stops with "Unexpected or dangling distribution-side .credentials_migrated". This fails closed, but the runner cannot restart without administrative action.
3. Recreating the container discards the migrated files. The runner falls back to the original `.credentials`. If GitHub has already stopped accepting those, the persistent identity is lost and re-registration is required. That defeats the WP-0.2 persistent-identity model this package exists to implement (WP-0.3 §2.3, AC-02, AC-06).

The verdict is PLAUSIBLE rather than CONFIRMED because whether and when 2.328.0 writes these files at runtime cannot be observed without a registered runner. The filenames are confirmed in the binaries, and the implementation's own handling of `.credentials_migrated` shows it was anticipated.

Possible remediations (the implementer chooses):
- Run the listener as a child process instead of with `exec`. When it exits, move any new regular state files into the volume, reusing the `preserve_bootstrap_state` logic. Removal must still never happen on signal. Alternatively, rework persistence so that runtime-created files land on the volume directly.
- Add `.runner_migrated` to `state_files`, the allow-list, and the validator (it has the same shape as `.runner`).
- Add a fixture test in which the stub listener creates `.credentials_migrated` and `.runner_migrated`, then verify that both survive container recreation and that a same-container restart succeeds.

If the Owner instead accepts this as a deferred risk, the registration-gate test plan must include a forced or observed credential migration followed by stop/start and by recreation.

### Advisories (non-blocking)

- **A-1, no recovery procedure for marker states.** A failed or interrupted bootstrap or decommission correctly blocks every later operation (`entrypoint.sh:43`), including `decommission`. That is safe, but neither README.md nor the operations note gives the actual administrative recovery steps: what to inspect, when it is safe to clear the marker, or how to proceed when GitHub holds a record but local state is rejected. The same gap applies when the GitHub record is already gone, since `config.sh remove` then fails and leaves `.decommission-in-progress`. The diagnostics say recovery is required but not how, so AC-08's "actionable" is only partly met. Define the procedure before the registration gate.
- **A-2, decommission guards are untested.** AC-10 is PASS on code reading alone. The refusal paths can be tested with the existing mock (which exits 99 on `remove`) without ever executing removal: mismatched `RUNNER_DECOMMISSION_CONFIRM`, a missing removal token, `RUNNER_TOKEN` supplied alongside a removal token, `RUNNER_REMOVE_TOKEN` supplied to `run`, and absent state. These are cheap and would turn AC-10 into local PASS evidence.
- **A-3, AC-13 runtime evidence is indirect.** The "Runtime inspect" checks in `validate-containers.ps1` inspect the harness's own `docker create` container (its own flags plus the image's `USER`), not the Compose-defined service. Together with the compose-config inspection (verified above), the evidence is sufficient. Note, though, that the runtime check proves the image's properties and the compose check proves the service's.
- **A-4, persistent credentials are readable by job code.** Workflow steps run as the same `runner` UID that owns `/runner-state`, so a malicious workflow could read `.credentials_rsaparams` and impersonate the runner beyond the job's lifetime. This is inherent to the persistent model WP-0.2 approved and is not an implementation defect. It is reduced by repository scoping and a private repository. Before registration, the Owner should confirm that workflows from fork pull requests cannot target this runner. A related side effect: lock FD 9 is inherited by job processes, which is harmless because they already have the same UID.
- **A-5, `restart: "no"` affects availability.** This is justified under WP-0.3 §2.10 and documented. Consequences for the Owner: the runner stays offline after any Windows, WSL2, or Docker restart, and after any listener exit, until someone starts it manually. Because `run.sh` is bypassed, upstream's retry on retryable exit codes is gone too. This is consistent with spec §17 but should be an explicit Owner decision.
- **A-6, bootstrap token visibility.** The token is passed to `config.sh` as a command-line argument, so it is visible in `/proc/*/cmdline` inside the container while configuration runs. It is also visible in the one-off container's `docker inspect` environment, which is documented. Both are upstream or Docker limitations that are acceptable for a short-lived token. This is recorded so the token-acquisition decision can take it into account.
- **A-7, commit hygiene.** The branch was created from `governance/spec-rev2-review`, not `main`, so merging it also brings in that governance commit. Keep the branches in dependency order. Per alignment.md §6, the Owner-controlled commit should contain only the WP-0.3 files listed in the handoff. Leave out the pre-existing artifact relocations and session records, as the handoff itself notes.

## 3. Acceptance-criterion accounting (reviewer's disposition)

| ID | Reviewer disposition | Basis |
|---|---|---|
| AC-01 | PASS local; DEFERRED registered | No EXIT or signal trap on the run path. `exec` hands signals to the listener under tini. TERM and INT were verified both in the fixture and through Docker stop and SIGINT, with state hashes unchanged. |
| AC-02 | PASS local; DEFERRED registered; **at risk from F-1** | A valid synthetic state starts the listener with no token or config call, and survives recreation. Persistence of identity changes made at runtime is not covered. |
| AC-03 | PASS | Reproduced by the fixture; the handoff also shows the real image's output. |
| AC-04 | PASS | Reproduced. |
| AC-05 | PASS local; DEFERRED credentialed | `.env.example` has no token; no `env_file`. A token is rejected on `run` (line 103) and unset before `exec`. The suite confirms no persisted synthetic input. A-6 noted. |
| AC-06 | PASS local, **conditional on F-1** | A separate mount is required, with owner and mode checks (0700 directory, 0600 files) and the allow-list. Files created at bootstrap persist. Files created at runtime do not (F-1). |
| AC-07 | PASS | No `_work` volume. The marker is absent after recreation. `RUNNER_WORKDIR` is pinned to `_work`. |
| AC-08 | PASS local; A-1 noted | Comprehensive malformed, partial, and insecure-state fixtures, all reproduced. State is preserved. |
| AC-09 | PASS | No `--replace` anywhere. An existing identity rejects bootstrap. |
| AC-10 | PASS (code reading); A-2 noted | Removal exists only in `decommission`, behind confirmation, valid state, the lock, and a separate token. Remote removal precedes local deletion. Not executed. |
| AC-11 | PASS local; DEFERRED real | `--disableupdate` was recorded by the stub. The validator requires `disableUpdate: true`. The version is pinned at 2.328.0. |
| AC-12 | PASS | `restart: no`, plus the durable in-progress marker that blocks retries (reproduced). A-5 noted. |
| AC-13 | PASS; A-3 and A-4 noted | `USER runner`; root execution is refused (line 22); not privileged; no socket, no ports; no credentials in the image. `.dockerignore` excludes state and tests. The added packages (`python3`, `util-linux`, `libicu74`) are each justified, which satisfies spec §7. |
| AC-14 | PASS | Compose config and build were both reproduced with exit 0. |
| AC-15 | PASS | Registered-runner tests are listed as DEFERRED in the handoff, README, and operations note. |
| AC-16 | PASS | The handoff gives one-to-one evidence for AC-01–AC-15 and covers every item in the alignment.md §1 handoff rule, including the Owner exception statement carried forward (alignment.md §8). |

## 4. Governance observations

- The scoped Owner exception (the missing Scope/Phases/Sprints reconciliation timestamp) is stated in the handoff and in the operations note, as alignment.md §8 requires.
- No Git operation other than branch creation was performed, and no registration, token, PAT, deployment credential, or `station-01` action was taken. This is consistent with WP-0.3 §6.
- The Drive sync is still pending and the handoff says so. That is not a failure under alignment.md §1.
- No IRP incident was identified.

## 5. Path to approval

1. Resolve F-1 with a code change and a fixture test, or record the Owner's acceptance of it as a deferred registration-gate risk with a named test.
2. Optional, recommended before the registration gate: A-1 (recovery procedure) and A-2 (decommission guard tests).
3. Re-review, as `REVIEW-action-runner-005.md`, covering the delta only.

---

*Delivered as a saved, durable artifact per alignment.md Section 6. Final on creation; any correction or re-review produces `REVIEW-action-runner-005.md`, not an edit to this file.*
