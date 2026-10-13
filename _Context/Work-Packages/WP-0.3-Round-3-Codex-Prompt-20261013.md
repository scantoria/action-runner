# WP-0.3 Round 3 --- Ungraceful Stop Recovery Remediation

**Assigned Role:** Implementation Tool\
**Project:** ThisByte Action Runner\
**Project ID:** `AR`\
**Project Root / Area of Operation:** `C:\Development\action-runner`\
**Work Package:** WP-0.3 --- Runner Lifecycle Implementation /
Remediation\
**Round:** 3 --- Review Finding Remediation\
**Date:** 2026-10-13

## Owner Authorization

The Owner authorizes **WP-0.3 Round 3 remediation** to resolve F-2 from
`_Context/Reviews/REVIEW-action-runner-005.md`.

This is a narrow delta remediation. Round 2 successfully resolved F-1,
A-1, and A-2; those results are the accepted baseline.

**Mandatory:** resolve F-2.\
**Also authorized:** resolve B-1 while modifying listener supervision.\
**B-2 is not implementation scope:** preserve it as a named
registration-gate test.

Runner registration remains **NOT AUTHORIZED**.

## 1. Governing Inputs

Before editing, read `alignment.md`, `project-specification.md`, WP-0.2,
WP-0.3, the Round 2 prompt, both prior WP-0.3 handoffs,
`REVIEW-action-runner-004.md`, `REVIEW-action-runner-005.md`, and
`Docs/WP-0.3-Runner-Lifecycle-Operations-2.md`.

Continue on `codex/wp-0.3-lifecycle`. Do not create another branch
unless explicitly authorized. Review 005 is authoritative for this
remediation.

## 2. Mandatory Remediation --- F-2

Round 2 introduced `.listener-active` to protect runtime state
persistence. It is written at listener start and cleared only after
successful graceful finalization.

Review 005 independently confirmed that after SIGKILL the marker remains
and a same-container restart fails closed even when the listener changed
no identity state. This is an availability regression against the
approved persistent-runner lifecycle.

Preserve fail-closed state safety while distinguishing:

1.  interrupted finalization where the original container layer still
    exists and can safely complete pending finalization; and
2.  interrupted finalization where the original container layer is
    unavailable or cannot be proven to correspond to the durable marker,
    which must remain fail closed.

Safe same-container recovery must not require a token, registration,
deregistration, replacement, or destructive recovery.

## 3. Recovery Design Requirements

Implement a deterministic association between durable listener-active
state and the container/session in which the listener was running.

A suitable design may use a nonce, container identity, or equivalent
unique identifier recorded both durably and in container-local evidence.
On startup:

-   if durable and container-local evidence demonstrably correspond,
    complete interrupted finalization using the existing validate →
    stage → sync → promote → relink → revalidate mechanism before
    starting the listener;
-   if evidence is missing, malformed, mismatched, or ambiguous, fail
    closed and require the A-1 administrative recovery procedure.

Do not simply delete `.listener-active`. Do not weaken validation or
introduce destructive automatic recovery.

For provable same-container recovery, acquire the lifecycle lock,
inspect known state paths, reject unsupported state, validate effective
state, safely persist any pending runtime state, revalidate, clear the
marker only after completion, then proceed with token-free listener
startup.

If no runtime state changed, prove there is nothing to promote and
complete the interrupted finalization safely.

After container recreation, if the durable marker survives but original
container-local evidence does not, **FAIL CLOSED**.

## 4. Safety Properties

Preserve all approved lifecycle properties: no deregistration on normal
shutdown; token-free persisted-identity restart; no automatic
registration; no `--replace`; no destructive stale-record recovery;
protected persistent identity/configuration state; disposable `_work`;
explicit bootstrap and decommission; `--disableupdate`; fail-closed
malformed/partial/ambiguous/unsupported state.

The recovery path must never call `config.sh remove` or equivalent and
must not require a registration token.

## 5. Mandatory F-2 Tests

Add network-isolated tests for:

### Test A --- SIGKILL, same container, no runtime state change

Start valid synthetic identity, start listener, make no identity/config
change, SIGKILL before finalization, verify marker remains, restart the
same container, prove continuity, validate state, complete interrupted
finalization, and reach token-free listener startup with no
config/remove/replace.

**Expected: PASS.**

### Test B --- SIGKILL, same container, pending runtime migration

Have the listener create/replace valid `.credentials_migrated` and
`.runner_migrated`, kill before finalization, restart the same
container, prove continuity, validate and persist pending state through
the F-1 mechanism, verify ownership/mode, clear marker only after
completion, and start without bootstrap.

**Expected: PASS.**

### Test C --- SIGKILL followed by recreation

Create interrupted state, retain the volume, recreate the container so
original local evidence is absent, then attempt startup.

**Expected: FAIL CLOSED.**
Listener/bootstrap/registration/removal/replace must not occur and
evidence must remain for A-1 recovery.

### Test D --- malformed/mismatched continuity evidence

Exercise missing, malformed, mismatched, or invalid continuity evidence.

**Expected: FAIL CLOSED.**

### Test E --- interrupted recovery/finalization

Where practical, interrupt recovery itself. Confirm no premature marker
clearance, no partial state accepted as valid, no
bootstrap/deletion/deregistration. Next startup must either safely
resume provable same-container finalization or fail closed.

## 6. B-1 --- Listener Exit-Status Race

Review 005 identified a race where TERM/INT can set
`wait_interrupted=true` after backgrounding the listener but before the
primary wait, causing an unnecessary second wait and possible exit 127.

Inspect the actual implementation and apply the smallest correct fix.
The reviewer suggested resetting `wait_interrupted=false` immediately
before the wait loop.

Add a deterministic regression test if practical. At minimum preserve
correct propagation of known listener status 17.

## 7. B-2 --- Registration-Gate Test

Do not attempt to resolve B-2 synthetically.

Carry forward a named DEFERRED test for actual GitHub Actions runner
2.328.0 TERM behavior, job drain/exit behavior, sufficiency of the
60-second stop grace period, and Docker escalation behavior.

No registration is authorized.

## 8. Regression Requirements

Run the complete WP-0.3 validation suite. Reconfirm AC-01 through AC-16
and explicitly account for:

-   F-1 remains resolved;
-   A-1 remains resolved;
-   A-2 remains resolved;
-   F-2 resolved locally/synthetically;
-   B-1 resolved;
-   B-2 DEFERRED;
-   A-3 through A-7 unchanged unless new evidence establishes a
    regression.

Do not convert registered-runner criteria to PASS from synthetic
evidence.

## 9. Documentation

Do not edit prior immutable operations artifacts. If documentation
changes are needed, create:

`Docs/WP-0.3-Runner-Lifecycle-Operations-3.md`

Document the distinction between provable same-container interrupted
finalization and recreated/unknown-container state requiring explicit
administrative recovery.

## 10. Scope and Edit Boundary

Modify only files necessary for F-2, B-1, tests, and required
documentation. Likely candidates are `entrypoint.sh`,
lifecycle/container tests, `tests/validate-containers.ps1`, and
`README.md`. Modify `validate-state.py` only if technically required for
continuity-evidence validation.

Do not modify governance documents, WP-0.2, WP-0.3, prior prompts, prior
handoffs, prior reviews, or prior operations artifacts. Do not
clean/reset unrelated working-tree changes.

If F-2 requires changing the approved WP-0.2 architecture or project
specification rather than an implementation correction, **STOP and
report the conflict**.

## 11. Authorization Boundaries

Not authorized: registration; registration-token acquisition/generation;
PAT use; real GitHub authentication; deregistration/decommission;
`--replace`; stale remote-record deletion; remote runner administration;
deployment/SSH credentials; `station-01`; website workflow changes;
production deployment; release.

Use synthetic state and isolated containers only.

## 12. Git Boundary

Remain on `codex/wp-0.3-lifecycle`.

No commit, push, merge, pull request, tag, release, rebase, or
deployment is authorized. Read-only Git inspection is permitted.

## 13. Required Validation

At minimum run:

``` powershell
Set-Location -LiteralPath 'C:\Development\action-runner'
docker compose config
docker compose build
.\tests\validate-containers.ps1
git diff --check
git status --short
git diff --exit-code -- alignment.md project-specification.md
```

Explicitly validate graceful shutdown, ordinary stop/start,
same-container SIGKILL recovery with and without pending migration,
recreation fail-closed behavior, malformed continuity evidence,
interrupted recovery safety, F-1 persistence, listener exit-status
propagation, no bootstrap/registration/removal/replace, disposable
`_work`, and absence of real GitHub credential/network operations.

## 14. Round 3 Handoff

Create a new immutable artifact:

`_Context/Executions/WP-0.3-round-3-handoff-20261013.md`

Do not modify prior handoffs.

Include Role Authority, date, branch, governing Review 005, exact F-2
design, continuity mechanism and rationale, same-container recovery,
recreation fail-closed behavior, interrupted-recovery behavior, B-1 fix,
B-2 DEFERRED gate test, files changed, documentation version if any,
commands/results, Tests A-E evidence, AC-01 through AC-16 accounting,
preservation of F-1/A-1/A-2, remaining advisories/deferrals, diff/status
evidence, governance integrity, and confirmation no
registration/token/PAT/decommission/deployment occurred.

Classify evidence as `LOCAL`, `SYNTHETIC`, `STATIC`, or `DEFERRED`. Do
not describe synthetic results as proof of actual Docker Desktop, WSL2,
Windows shutdown, or GitHub runner behavior.

## 15. Stop Condition

After authorized implementation, complete local validation, and Round 3
handoff:

**STOP.**

Do not self-approve, register the runner, obtain credentials, or perform
Git mutation operations.

Submit the delta for independent Review Tool evaluation. Expected
artifact:

`_Context/Reviews/REVIEW-action-runner-006.md`

Review 006 should focus on F-2 closure, B-1 closure, preservation of
F-1/A-1/A-2, Round 3 regressions, and correct DEFERRED treatment of B-2.

Even an approving Review 006 does **not** authorize runner registration.
Registration remains a separate Owner approval gate.
