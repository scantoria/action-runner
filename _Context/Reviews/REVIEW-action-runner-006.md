# Review — WP-0.3 Round 3 Delta (F-2, B-1)

**Authority exercised:** Review Tool role, per alignment.md Section 2.
**Date:** 2026-10-13
**Reviewer:** Claude (Opus 5.5), acting as Review Tool
**Reviewed artifact:** `_Context/Executions/WP-0.3-round-3-handoff-20261013.md` (Implementation Tool)
**Governing prompt:** `_Context/Work-Packages/WP-0.3-Round-3-Codex-Prompt-20261013.md`
**Reviewed implementation:** uncommitted working tree on `codex/wp-0.3-lifecycle` (base `1f671e6`). Round 3 delta:
- `entrypoint.sh`, LF-normalized SHA-256 `aa6dcd93…f1a9`, identical to `/entrypoint.sh` in the rebuilt image;
- `validate-state.py`, `9700d226…839e`, unchanged since Round 2;
- `tests/lifecycle.sh`, `tests/container-listener.sh`, `tests/validate-containers.ps1`, and the new `tests/validate-recovery.ps1`;
- `README.md` and the new `Docs/WP-0.3-Runner-Lifecycle-Operations-3.md`.

**Scope:** Per the Round 3 prompt §15: closure of F-2 and B-1, preservation of F-1/A-1/A-2, Round 3 regressions, and the DEFERRED treatment of B-2.

**Disposition: APPROVED WITH ADVISORIES.**

| Item | Status |
|---|---|
| F-2 (ungraceful stop blocks restart) | **RESOLVED**, with synthetic evidence plus a reviewer-run reproduction. Real Docker Desktop, WSL2 and Windows shutdown behavior is DEFERRED. |
| B-1 (exit-status race) | **RESOLVED** |
| F-1, A-1, A-2 | **Preserved** (regression suite reproduced) |
| B-2 (real TERM drain and grace period) | Correctly **DEFERRED** as named gate test `B2-RUNNER-2.328.0-TERM-DRAIN-60S-ESCALATION` |
| A-3 to A-7 | Unchanged. No new regression evidence. |

This approval completes the WP-0.3 independent-review step. It **does not authorize runner registration**, token acquisition, decommission, or any Git operation. The next step is Owner review, then the separate registration authorization gate (WP-0.3 §8).

---

## 1. Independent verification performed

| Check | Result |
|---|---|
| Governance | `git diff --exit-code -- alignment.md project-specification.md` exit 0. Hashes unchanged (`a782dbbd…`, `3890c449…`). |
| Prior immutable artifacts | Operations note v1 `21eef9bf…` and the Round 1 handoff `1ad60dc0…` match the hashes recorded in earlier reviews. `REVIEW-action-runner-005.md` still carries its original disposition. Round 3 documentation is a new `-3` file, so prior versions were not edited (alignment.md §6). |
| Git | HEAD is still `1f671e6`. No commit or branch change, which matches the handoff. |
| `docker compose config --quiet` / `docker compose build --quiet` | exit 0 / exit 0 |
| `.\tests\validate-containers.ps1`, which now also runs `validate-recovery.ps1` | exit 0, with 75 PASS lines. These include the B-1 deterministic timing cases; F-2 Tests A, B, C, D (8 variants) and E (complete and partial); all Round 1/2 regressions; and the F-1 generation 1–4 cycle. Both cleanup lines are present. |
| `git diff --check` | exit 0 |
| Isolation | Every `docker run` and `docker create` in both harness scripts uses `--network none`. Test E interrupts recovery with a PATH-shadowed `sync` wrapper that exists only in the fixture. A grep of `entrypoint.sh`, `validate-state.py` and `Dockerfile` finds no fixture hooks in production files. |
| Code reading | All of `entrypoint.sh` (349 lines) and the `validate-recovery.ps1` structure. Also operations note v3 §continuity. |
| **Reviewer-run experiment** | Disposable containers and volumes, network `none`, seeded with `tests/lifecycle.sh seed`. The stub listeners were passed inline (no files written). This includes the exact Review 005 SIGKILL scenario. Output below. |

Reviewer experiment output:

```text
[nochange] after SIGKILL: exited exit=137; volume: .credentials .credentials_rsaparams .env .lifecycle-lock .listener-active .path .runner
[nochange] restart (same container) reached listener: True; running exit=0
[nochange] log: Proven same-container interrupted finalization completed; resuming token-free startup.
[nochange] after graceful stop: exited exit=143; volume: .credentials .credentials_rsaparams .env .lifecycle-lock .path .runner
[recreate] after SIGKILL: exited exit=137; volume: ... .listener-active ...
[recreate] restart (NEW container) reached listener: False; exited exit=1
[recreate] log: Runner lifecycle stopped: Listener state preservation did not complete: missing, malformed or mismatched continuity evidence. Preserve the original container and volume for administrative recovery.
[malformed] after SIGKILL: exited exit=137; volume: ... .listener-active ...
[malformed] restart (same container) reached listener: False; exited exit=1; volume: ... .listener-active .listener-state-error ...   (no .credentials_migrated promoted)
[malformed] log: Runner lifecycle stopped: Listener state rejected or could not be preserved. Keep this stopped container and /runner-state; no recovery or deregistration was attempted.
cleanup: removed 4 containers, 3 volumes (suffix 4f44b20f)
```

This reverses the Review 005 result. A same-container restart after SIGKILL with unchanged state now recovers without a token. Recreation still fails closed. A malformed runtime file in the retained layer is refused and is not promoted. In the "nochange" case the second `.listener-active` belongs to the new session and is cleared by the graceful stop that follows.

## 2. F-2: resolved

The design meets each requirement in Round 3 prompt §3:

- **Deterministic association.** `record_listener_session` (`entrypoint.sh:78–104`) writes `{version:1, nonce:<64 hex>, container:<hostname>}`. It writes the container-layer `.listener-session` *first* and the durable `.listener-active` *second*. Each file is created exclusively with `open('x')`, set to 0600, fsynced, renamed atomically, and its directory fsynced. A kill between the two writes leaves no durable marker, so there is nothing to recover.
- **Strict continuity check.** `validate_continuity` (lines 47–76) uses `lstat`: both records must be regular files owned by the runner, mode 0600, between 1 and 2048 bytes. It applies duplicate-rejecting JSON, requires the exact key set, version 1, and a 64-character hex nonce, and requires both records to be equal and to match the current `hostname`. Every failure exits non-zero, and it uses no Python `assert`.
- **Recovery is limited to token-free `run`** (line 193). Bootstrap, decommission, or any token present while the marker exists is refused. `.listener-state-error` still always blocks (line 186). A `.pending*` file with no marker is refused (line 202).
- **It reuses the F-1 transaction rather than bypassing it** (`finalize_listener_state`, lines 106–174). It inspects every known path, validates the effective state *before* promoting anything, and requires each leftover pending copy to be byte-identical to its validated retained-layer source (`cmp`). It then stages, syncs, promotes and relinks atomically through `.relink*`, which removes Round 2's brief window where the path was missing, and revalidates. Only after that does it clear the durable marker and then the local evidence, with a sync at each step. TERM and INT are ignored while this runs (lines 197–199).
- **No unsafe operations.** No path calls `config.sh`, `remove`, or `--replace`, or deletes identity. The only deletion is a redundant pending copy that has already been proven equal (lines 160–164).
- **Tests A–E** map one-to-one onto prompt §5 and were reproduced. The reviewer experiment independently reproduces A, C, and a malformed variant of B.

## 3. B-1: resolved

The stale `wait_interrupted` flag has been removed. `wait -n -p completed_pid` (line 330) distinguishes a real child completion from a wait that a signal interrupted. If the child had already exited before `wait -n` was called (status 127 with the PID unset), one explicit `wait` retrieves the cached real status (lines 334–339). The deterministic fixture injects TERM both before the loop and immediately before the primary wait, and in both cases status 17 propagates (reproduced). Bash 5.2 in Ubuntu 24.04 supports `-p`.

## 4. Preservation and B-2

- **F-1:** migrations written at runtime and by atomic replacement still persist through TERM, INT, stop/start, and recreation (generations 1–4, 0600, owned by the runner). Malformed migrations and unsupported `.setup_info`/`.service` files are still refused (reproduced).
- **A-1:** operations note v3 keeps the full recovery procedure and adds the distinction between a provable same-container restart and a recreated or unknown container.
- **A-2:** the seven decommission guard refusals are reproduced.
- **B-2:** carried forward unresolved as named gate test `B2-RUNNER-2.328.0-TERM-DRAIN-60S-ESCALATION`. No synthetic claim is made. The real-migration test (F-1 gate test) is also still DEFERRED.

## 5. Advisories (non-blocking)

- **C-1, document the Compose recreation trap.** Recovery works only in the *same* container. After an ungraceful stop, these all recreate the container and land on the fail-closed path:
  - `docker compose up -d` after the image was rebuilt or `compose.yaml` changed;
  - `docker compose up --force-recreate`;
  - `docker compose down` followed by `up`.

  Operations note v3 says recreation fails closed, but it never tells the operator what to do instead: run `docker compose start` (or `up -d` with nothing changed) first, let finalization complete, stop gracefully, and only then rebuild or recreate. Add this to the next operations version, or record it as a registration-gate checklist item.
- **C-2, narrow windows that stay stuck in a fail-closed state.** A SIGKILL during `record_listener_session` can leave `.listener-session.new` in the container layer, or `.listener-active.new` in the volume. The first makes every later start of *that* container refuse with "continuity was not recorded", because `open('x')` will not overwrite it. The second is refused as an unrecognized state file. Both fail closed and are recoverable with A-1, and the windows are microseconds wide. Recorded for completeness; no change required.
- **C-3, the continuity nonce is not a security boundary.** The handoff states this correctly: anyone with Docker administrative access could fabricate both records. This matches the existing trust model (A-4) and is not a defect.

## 6. Acceptance-criterion regression accounting

| ID | Reviewer disposition | Basis |
|---|---|---|
| AC-01 | PASS local; DEFERRED registered (B-2) | TERM/INT forwarding with no removal path; exit status propagates in both B-1 timing cases. |
| AC-02 | PASS local; DEFERRED registered | Token-free restart works after a graceful stop, after recreation, **and now after SIGKILL in the same container** (Test A plus the reviewer experiment). This reverses Review 005's regression. |
| AC-03 / AC-04 | PASS | Regression fixtures reproduced. |
| AC-05 | PASS local; DEFERRED credentialed | Unchanged. Recovery refuses any token (line 193). |
| AC-06 | PASS local; DEFERRED registered | F-1 persistence plus recovery of an interrupted commit in the same container (Tests B and E). |
| AC-07 | PASS | `_work` survives in the same container and is absent after recreation. |
| AC-08 | PASS local | Continuity defects (Test D ×8), partial staging (Test E/partial), and malformed runtime files (reviewer experiment) fail closed and preserve evidence. |
| AC-09 | PASS | No `--replace`, and no automatic remote operation. |
| AC-10 | PASS local | Seven guards reproduced. Decommission is refused while the marker exists. Never executed. |
| AC-11 | PASS local | Unchanged validator; `--disableupdate` retained. |
| AC-12 | PASS | `restart: "no"` unchanged. Recovery runs only when an operator starts the container and never retries automatically. |
| AC-13 | PASS | Image, user and security design unchanged; no hooks in production files. |
| AC-14 | PASS | Config and build reproduced. |
| AC-15 | PASS | Registered-runner, real-migration, host-shutdown and B-2 tests are all DEFERRED. |
| AC-16 | PASS | The Round 3 handoff gives one-to-one evidence for Tests A–E, B-1 and every AC, labelled LOCAL, SYNTHETIC, STATIC or DEFERRED. It satisfies the alignment.md §1 handoff rule. |

## 7. Governance observations

- Round 3 stayed within its authorized scope: F-2, B-1, tests, `README.md`, and a new operations version. `validate-state.py` was correctly left unchanged, because the continuity check lives in the entrypoint.
- No Git operation was performed. No registration, token, PAT, decommission, `station-01` or deployment action was taken.
- The reviewer experiments used only disposable, network-isolated resources and removed exactly what they created. No project file was written other than this review.
- Before any commit, the Owner should note that WP-0.3 now spans three rounds of uncommitted changes. When this branch is committed, alignment.md §6 and advisory A-7 require it to contain only WP-0.3 files. The pre-existing relocations and session records belong in a separate change.
- No IRP incident was identified.

## 8. Registration-gate carry-forward (DEFERRED, for the Owner's gate plan)

1. `B2-RUNNER-2.328.0-TERM-DRAIN-60S-ESCALATION`: real TERM/INT handling, draining an active job, the exit status, whether the 60-second grace period is enough, Docker's escalation to SIGKILL, and recovery in the retained container afterwards.
2. F-1 gate test: a real GitHub credential migration, followed by stop/start and then recreation.
3. What actually happens to the container on Docker Desktop, WSL2 and Windows shutdown, and same-container recovery afterwards (C-1 procedure).
4. Real registration-state schema acceptance by `validate-state.py`; this is the first real bootstrap.
5. Advisories A-4 (fork pull-request workflows must not reach this runner), A-5 (decision on the `restart: "no"` availability trade-off), and A-6 (token visibility, which feeds the token-acquisition decision).

---

*Delivered as a saved, durable artifact per alignment.md Section 6. Final on creation; any correction or re-review produces `REVIEW-action-runner-007.md`, not an edit to this file.*
