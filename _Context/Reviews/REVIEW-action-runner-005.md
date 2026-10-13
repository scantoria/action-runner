# Review — WP-0.3 Round 2 Delta (F-1, A-1, A-2)

**Authority exercised:** Review Tool role, per alignment.md Section 2.
**Date:** 2026-10-13
**Reviewer:** Claude (Opus 5.5), acting as Review Tool
**Reviewed artifact:** `_Context/Executions/WP-0.3-round-2-handoff-20261012.md` (Implementation Tool)
**Reviewed implementation:** uncommitted working tree on `codex/wp-0.3-lifecycle` (base `1f671e6`). Round 2 delta: `entrypoint.sh` (LF-normalized SHA-256 `25229fc2…cfa2`), `validate-state.py` (`9700d226…839e`), `tests/lifecycle.sh`, `tests/container-listener.sh`, `tests/validate-containers.ps1`, `README.md`, and the new `Docs/WP-0.3-Runner-Lifecycle-Operations-2.md`.
**Scope:** a delta review of F-1, A-1 and A-2 from `REVIEW-action-runner-004.md`, plus regressions those changes introduce. Under the Round 2 prompt, the rest of Round 1 is the accepted baseline.

**Disposition: CHANGES REQUIRED, limited to new finding F-2.** F-2 is a regression introduced by the F-1 fix. It can be closed by a code change, or by the Owner (with the Chief Architect, since it bears on WP-0.2 principle 4) explicitly accepting manual recovery after every ungraceful stop.

| Prior item | Status |
|---|---|
| F-1 (runtime state persistence) | **RESOLVED**, with synthetic evidence. Real GitHub migration remains a named registration-gate test (DEFERRED). |
| A-1 (recovery procedure) | **RESOLVED** (documentation). |
| A-2 (decommission guard tests) | **RESOLVED**. |
| A-3 to A-7 | Unchanged and out of scope, as the handoff states. |

Runner registration remains **NOT AUTHORIZED**. This review authorizes nothing.

---

## 1. Independent verification performed

| Check | Result |
|---|---|
| Governance and immutable inputs | `alignment.md` `a782dbbd…1e4d` and `project-specification.md` `3890c449…e59b` are unchanged. `REVIEW-action-runner-004.md` still carries its original disposition. The Round 1 operations note was kept, and version 2 is a separate file, consistent with alignment.md §6. |
| Git | Still `1f671e6` with no new commits, and the branch is unchanged. This matches the handoff. |
| `docker compose config --quiet` / `docker compose build --quiet` | exit 0 / exit 0. |
| `.\tests\validate-containers.ps1` | exit 0. Every PASS line in the handoff was reproduced (40 unique PASS/Cleanup lines), including the F-1 generation 1–4 checks for stop/start and recreation, the A-2 guards, and the malformed-migration refusals. |
| `git diff --check` | exit 0. |
| Code reading | All of `entrypoint.sh` and the `validate-state.py` delta. Also the `tests/lifecycle.sh` A-2 block (lines 249–269), the `container-listener.sh` changes, and the README "Administrative Recovery" section. |
| **Ungraceful-stop experiment (reviewer-run)** | Run in disposable containers with network `none`, on a fresh volume seeded by `tests/lifecycle.sh`. The stub listener was passed inline; it changes no state and simply waits. Results below; all resources were removed afterwards. |

Ungraceful-stop experiment output:

```text
[graceful] stop exit code: 143
[graceful] volume after stop: .credentials .credentials_rsaparams .env .lifecycle-lock .path .runner
[graceful] same-container restart reached listener: True; state: running exit=0
[sigkill] stop exit code: 137
[sigkill] volume after stop: .credentials .credentials_rsaparams .env .lifecycle-lock .listener-active .path .runner
[sigkill] same-container restart reached listener: False; state: exited exit=1
[sigkill] log: Runner lifecycle stopped: Listener state preservation did not complete. Preserve the stopped container and volume for explicit recovery.
cleanup: removed rev005-graceful-8205edcb, rev005-sigkill-8205edcb and rev005-state-8205edcb
```

## 2. F-1: resolved (synthetic)

- `.runner_migrated` is now in `state_files` (line 12) and the allow-list (line 42). The validator checks it against the same RunnerSettings constraints as `.runner` (`validate-state.py:46–61`), and it is handled by bootstrap preservation and by decommission removal. This treats it according to its meaning, not as a filename added only to suppress an error.
- The listener now runs as a supervised child (lines 158–187). After it is reaped, finalization (lines 193–232) does the following:
  - refuses unexpected `.setup_info`/`.service` files;
  - checks the owner, mode and target of every link;
  - sets newly written files to 0600 without trusting their contents;
  - validates the complete effective state set *before* promoting anything;
  - stages each file as `.pending<name>` on the volume, syncs it, renames it into place, re-links it, revalidates, and only then clears `.listener-active`.
- Nothing in this path touches `config.sh`, removal, `--replace`, or state deletion.
- The test suite shows that migrated files written while running, including files replaced by atomic rename, survive termination by TERM and INT, survive same-container stop/start and recreation (generations 1→4), end up at mode 0600 and owned by the runner, and that malformed migrations are not promoted. I reproduced all of this.
- Whether 2.328.0 actually writes these files during a real GitHub migration is still DEFERRED to the named registration-gate test, as the handoff correctly states.

## 3. F-2: every ungraceful stop now blocks ordinary restart (CHANGES REQUIRED; verdict: CONFIRMED for SIGKILL, PLAUSIBLE for host events)

`.listener-active` is written at every listener start (line 158) and cleared only by a fully completed graceful finalization (line 231). Any stop that skips finalization leaves it behind, and on the next start the scan at line 44 refuses to run. That includes SIGKILL, Docker's stop-timeout kill, OOM, Docker Desktop or WSL2 termination, Windows shutdown or update reboots, and power loss. This happens **even when the listener changed no state at all**, which is the usual case. The reviewer experiment above confirms this for SIGKILL with an unchanged state set.

Why it matters:
- WP-0.3 §2.2 names Docker Desktop shutdown, WSL2 shutdown and Windows shutdown as normal shutdown events. Their expected outcome is "registered but Offline", and WP-0.2 principle 4 says ordinary restarts reuse persisted identity.
- On a Docker Desktop workstation, containers commonly end without a graceful stop when the host or VM goes down (they show as `Exited (255)` or `(137)`). That would put the runner into the README's manual recovery procedure (the "Listener finalization interrupted" row) after most host reboots.
- The Round 1 baseline did not have this behavior. The F-1 fix introduced it.
- It fails closed and is never destructive, so this is an availability and operations regression, not a safety defect.

Possible remediations (the implementer chooses):
- **Finish finalization automatically when the container layer is still present.** Write a nonce or the container ID (the default `hostname`) into both `.listener-active` and a container-layer sentinel. At startup, if the marker matches the current container, the unpersisted files are still there, so the existing finalization routine can run (validate → stage → promote → clear) before the listener starts. This is completing an interrupted commit, not destructive recovery. A recreated container whose marker doesn't match must still fail closed, as it does now.
- Optionally, when the marker matches and the container layer holds no regular state files at all, nothing was lost and the marker can be cleared after validation.
- Add tests for SIGKILL followed by same-container restart, both with and without a pending runtime migration, and for SIGKILL followed by recreation (which must stay blocked).

If the Owner instead accepts the current behavior, record that decision. Also record the registration-gate test that observes what actually happens to the container on Docker Desktop, WSL2 and Windows shutdown.

## 4. A-1 and A-2

- **A-1, resolved.** README.md and operations note version 2 now set out an inspect → preserve → decide → authorize → revalidate → resume procedure. It includes read-only inspection commands, a decision table covering every marker and remote-record condition, and a constrained marker-clearance example that takes the identity lock and validates before clearing. Identity files are never deleted. Failed removal is not treated as proof that the remote record is gone.
- **A-2, resolved.** `tests/lifecycle.sh:249–269` covers seven refusal paths: wrong confirmation, missing removal token, both tokens supplied, removal token on `run`, absent state, partial state, and malformed credentials. Each is checked for no `config.sh` call, unchanged identity hashes, and no decommission marker. I reproduced this.

## 5. Advisories (non-blocking)

- **B-1, edge case in exit status.** If TERM or INT arrives after `&` but before `wait` starts, the early trap leaves `wait_interrupted=true`. The loop then waits a second time on a PID that has already been reaped and returns 127 instead of the listener's real status (lines 170–187). This is harmless under `restart: "no"`. Fix it by resetting `wait_interrupted=false` immediately before the loop, after line 178.
- **B-2, TERM vs INT at the gate.** Upstream `run.sh` (with `RUNNER_MANUALLY_TRAP_SIG`) translates TERM into INT for the listener. The supervisor forwards TERM unchanged. Confirm at the registration gate that 2.328.0 drains and exits gracefully on TERM within the 60-second grace period. If it doesn't, Docker escalates to SIGKILL, which triggers F-2.
- **B-3, the image ID changed as expected.** It is now `sha256:5820711f…` in the handoff, because the scripts changed. The handoff now says which ID form it records, which resolves the note in review 004.

## 6. Acceptance-criterion regression accounting

| ID | Reviewer disposition | Basis |
|---|---|---|
| AC-01 | PASS local; DEFERRED registered | TERM/INT forwarding reproduced with no removal path. Status propagation is tested (17), with the B-1 edge case noted. |
| AC-02 | PASS local after graceful stop; **regressed after ungraceful stop (F-2)**; DEFERRED registered | Token-free restart is reproduced for graceful stops and recreation. Restart after SIGKILL is blocked (reviewer experiment). |
| AC-03 / AC-04 | PASS | Regression fixtures reproduced. |
| AC-05 | PASS local | Unchanged; the token is rejected on `run` and unset before the supervisor launches the listener. |
| AC-06 | PASS local (F-1 resolved) | State changed at runtime is persisted with validation, staging and a marker. |
| AC-07 | PASS | `_work` is kept on same-container restart and absent after recreation (reproduced). |
| AC-08 | PASS local | Original regressions plus malformed-migration refusals; A-1 makes the diagnostics actionable. |
| AC-09 | PASS | No `--replace`, and no automatic remote operation. |
| AC-10 | PASS local (A-2 resolved) | Seven guard refusals reproduced; never executed. |
| AC-11 | PASS local | Both settings files require `disableUpdate: true`; the bootstrap argument check is retained. |
| AC-12 | PASS | `restart: "no"` is unchanged and markers prevent automatic attempts. F-2 is the opposite problem, too few restarts rather than too many. |
| AC-13 | PASS | Image, user and security design unchanged; the harness inspect and compose config were reproduced. |
| AC-14 | PASS | Config and build reproduced. |
| AC-15 | PASS | Registered-runner tests and real migration are DEFERRED. |
| AC-16 | PASS | The Round 2 handoff accounts for each F-1 outcome and each AC individually. It also covers every item in the alignment.md §1 handoff rule. |

## 7. Governance observations

- Round 2 stayed within its authorized scope (F-1, A-1, A-2). A-3 to A-7 were left untouched, and the dependency on them was reported rather than acted on.
- No Git operation was performed. No registration, token, PAT, credential, `station-01` or deployment action was taken.
- The reviewer experiment used only disposable, network-isolated containers and a volume. It wrote no file to the project or outside it, and it removed exactly the resources it created.
- No IRP incident was identified.

## 8. Path to approval

1. Resolve F-2 with a code change and tests, or record Owner and Chief Architect acceptance together with a named gate test.
2. Optional: B-1 (a one-line fix).
3. Re-review the delta only, as `REVIEW-action-runner-006.md`.

---

*Delivered as a saved, durable artifact per alignment.md Section 6. Final on creation; any correction or re-review produces `REVIEW-action-runner-006.md`, not an edit to this file.*
