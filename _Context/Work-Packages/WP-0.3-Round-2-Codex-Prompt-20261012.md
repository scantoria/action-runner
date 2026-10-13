# WP-0.3 Round 2 --- Lifecycle State Persistence Remediation

**Assigned Role:** Implementation Tool\
**Project:** ThisByte Action Runner\
**Project ID:** `AR`\
**Project Root / Area of Operation:** `C:\Development\action-runner`\
**Work Package:** WP-0.3 --- Runner Lifecycle Implementation /
Remediation\
**Round:** 2 --- Review Finding Remediation\
**Date:** 2026-10-12

## Owner Authorization

The Owner authorizes **WP-0.3 Round 2 remediation** to resolve the
blocking finding from:

``` text
_Context/Reviews/REVIEW-action-runner-004.md
```

This is a **delta remediation**, not a reopening or redesign of WP-0.3.

The implementation from WP-0.3 Round 1 is accepted as the baseline
except where modification is necessary to resolve the explicitly
authorized items below.

**Mandatory:** resolve F-1.

**Also authorized and requested:** remediate advisories A-1 and A-2
while working in this lifecycle code.

Advisories A-3 through A-7 are **not remediation scope** for this round
unless a change required for F-1, A-1, or A-2 necessarily affects them.
Report any such dependency rather than expanding scope unilaterally.

Runner registration remains **NOT AUTHORIZED**.

------------------------------------------------------------------------

## Governing Inputs

Before editing, read:

``` text
alignment.md
project-specification.md
_Context/Work-Packages/WP-0.2-Runner-Lifecycle-Registration-Design.md
_Context/Work-Packages/WP-0.3-Runner-Lifecycle-Implementation-Remediation.md
_Context/Executions/WP-0.3-handoff-20261012.md
_Context/Reviews/REVIEW-action-runner-004.md
Docs/WP-0.3-Runner-Lifecycle-Operations.md
```

Also inspect the current Round 1 implementation and tests on:

``` text
codex/wp-0.3-lifecycle
```

Do not create another branch unless the existing branch is unavailable
or doing so is required by an explicit Owner instruction.

Treat `REVIEW-action-runner-004.md` as the authoritative Round 1 review
finding for this remediation.

------------------------------------------------------------------------

## 1. Mandatory Remediation --- F-1

### Problem

The independent review identified a persistence gap for runner-managed
state files created or changed **during listener execution**.

The current implementation establishes links to persistent
`/runner-state` files only when the corresponding state file already
exists in the persistent volume.

The pinned GitHub Actions runner `2.328.0` contains references to
runner-managed files including:

``` text
.runner
.credentials
.credentials_rsaparams
.credentials_migrated
.runner_migrated
.setup_info
.service
```

The review determined that `.credentials_migrated` is already
anticipated by the implementation, but a file first created during
listener execution can remain in the disposable container layer rather
than reaching `/runner-state`.

`.runner_migrated` is additionally absent from the current state model.

This threatens the approved WP-0.2 persistent-identity model.

### Required Outcome

Modify the lifecycle implementation so that **runner-managed
identity/configuration state created or changed during listener
execution is preserved in `/runner-state` before that state can be lost
through ordinary container lifecycle operations.**

The implementation must preserve all previously approved properties:

-   normal shutdown does not deregister;
-   restart does not automatically register;
-   no silent `--replace`;
-   no destructive automatic recovery;
-   missing/partial/ambiguous state fails closed;
-   persisted state remains protected;
-   `_work` remains disposable;
-   bootstrap remains explicit;
-   decommission remains explicit and separate;
-   `--disableupdate` remains enforced.

The Implementation Tool may choose the technically appropriate
persistence mechanism, but **do not weaken the fail-closed lifecycle
merely to make persistence easier**.

------------------------------------------------------------------------

## 2. Runtime State-File Model

Review the pinned `2.328.0` runner's locally available binaries/scripts
and the existing state model.

At minimum, explicitly address:

``` text
.credentials_migrated
.runner_migrated
```

Add `.runner_migrated` to the persistent state model wherever
technically appropriate, including:

-   recognized state-file collection;
-   allow-list;
-   validation;
-   persistence;
-   recovery handling;
-   test fixtures.

Treat `.runner_migrated` consistently with its actual runner semantics
rather than merely adding its filename to suppress an error.

Do not invent unsupported GitHub behavior.

If local inspection establishes additional runner-managed
identity/configuration files that must participate in the persistence
model, report the evidence and include them only where necessary.

------------------------------------------------------------------------

## 3. Listener Lifecycle Persistence

Correct the lifecycle so that state changes made by the listener are not
trapped exclusively in the disposable container layer.

The implementation must support both:

``` text
docker compose stop
docker compose start
```

and container recreation without losing valid persistent runner
identity/configuration state.

If the implementation changes from direct `exec` of the listener to
supervised child-process execution, preserve correct signal behavior.

Specifically:

-   SIGTERM and SIGINT must reach the listener;
-   graceful shutdown must remain possible;
-   normal shutdown must never invoke deregistration;
-   state preservation must occur safely;
-   listener exit status should be propagated appropriately;
-   state persistence must not silently accept malformed or ambiguous
    files;
-   concurrency/identity locking must remain effective;
-   job processes must not cause accidental lifecycle cleanup or
    deregistration.

Do not introduce a shutdown path that calls:

``` text
config.sh remove
```

or equivalent.

------------------------------------------------------------------------

## 4. Mandatory F-1 Fixture Tests

Extend the synthetic/network-isolated test suite to exercise the exact
finding.

Add a fixture where the stub listener creates or updates:

``` text
.credentials_migrated
.runner_migrated
```

during listener execution.

Demonstrate at minimum:

1.  The runtime-created files are recognized as legitimate
    runner-managed state.
2.  They are persisted into the protected runner-state storage.
3.  Their expected permissions/ownership are enforced.
4.  They survive listener termination.
5.  They survive `docker compose stop` / `docker compose start` or the
    equivalent isolated fixture stop/start.
6.  They survive container recreation.
7.  Restart uses the persisted identity without invoking
    bootstrap/configuration.
8.  No removal/deregistration occurs.
9.  No `--replace` occurs.
10. `_work` remains disposable.
11. Malformed or invalid migrated state still fails closed rather than
    being silently persisted as valid identity.

The test must remain synthetic and network-isolated.

**Do not register a real runner to close F-1.**

------------------------------------------------------------------------

## 5. A-1 --- Administrative Recovery Procedure

The Owner authorizes remediation of advisory A-1.

Update the existing operational documentation to provide an actionable
administrative recovery procedure for durable lifecycle marker/error
states.

Cover at least:

-   failed bootstrap;
-   interrupted bootstrap;
-   failed/interrupted decommission;
-   partial state;
-   rejected/malformed state;
-   stale local state;
-   situation where GitHub may contain a runner record but local state
    is not usable;
-   situation where the GitHub runner record may already be absent.

The procedure must clearly distinguish:

``` text
inspect
preserve evidence/state
determine local/remote condition
explicit Owner-authorized recovery action
revalidate
resume
```

Do not implement an automatic recovery mechanism merely to document
recovery.

Do not instruct operators to delete, replace, overwrite, or re-register
ambiguous state without first establishing the applicable condition and
authorization.

Where recovery requires interaction with GitHub that cannot currently be
exercised because registration is unauthorized, mark that step as
requiring the future registration/administrative gate.

Do not execute it.

------------------------------------------------------------------------

## 6. A-2 --- Decommission Guard Tests

The Owner authorizes remediation of advisory A-2.

Add negative tests for decommission/refusal guards using mocks only.

At minimum test refusal for:

-   incorrect `RUNNER_DECOMMISSION_CONFIRM`;
-   missing removal token;
-   `RUNNER_TOKEN` supplied alongside a removal token;
-   `RUNNER_REMOVE_TOKEN` supplied to ordinary `run`;
-   absent registration state;
-   invalid/partial registration state where applicable.

These tests must prove the implementation refuses the operation **before
real removal could occur**.

No test may contact GitHub or invoke real runner removal.

The existing mock/stub mechanism should be used where appropriate.

------------------------------------------------------------------------

## 7. Regression Requirements

F-1 remediation must not regress any Round 1 acceptance criterion.

Re-run the complete WP-0.3 local validation suite, not merely the new
tests.

Specifically reconfirm AC-01 through AC-16. Do not convert any
registered-runner DEFERRED criterion into PASS based solely on synthetic
tests.

------------------------------------------------------------------------

## 8. Files and Scope

Modify only files necessary to remediate F-1, A-1, and A-2.

Expected candidates include:

``` text
entrypoint.sh
validate-state.py
tests/lifecycle.sh
tests/container-listener.sh
tests/validate-containers.ps1
README.md
Docs/WP-0.3-Runner-Lifecycle-Operations.md
```

Other WP-0.3 implementation files may be changed only if technically
necessary to close these findings.

Report why any additional file was changed.

**Do not modify:**

``` text
alignment.md
project-specification.md
_Context/Work-Packages/WP-0.2-Runner-Lifecycle-Registration-Design.md
_Context/Work-Packages/WP-0.3-Runner-Lifecycle-Implementation-Remediation.md
_Context/Reviews/REVIEW-action-runner-004.md
```

Existing governance and review artifacts are immutable.

Do not alter unrelated pre-existing working-tree changes.

Do not clean or reset the repository.

------------------------------------------------------------------------

## 9. Authorization Boundaries

This remediation **does not authorize**:

-   obtaining a GitHub registration token;
-   obtaining or using a PAT;
-   GitHub runner registration;
-   GitHub runner deregistration;
-   real decommission;
-   `--replace`;
-   stale GitHub runner deletion;
-   real GitHub credential migration testing;
-   modification of `thisbyte-website`;
-   GitHub Actions workflow changes;
-   deployment credentials;
-   SSH credentials;
-   `station-01` access or modification;
-   production deployment;
-   release.

Use synthetic credentials/state only where required for tests.

Do not use actual GitHub secrets or credentials.

------------------------------------------------------------------------

## 10. Git Boundary

Continue on:

``` text
codex/wp-0.3-lifecycle
```

Do not commit, push, merge, create a pull request, tag, release, or
deploy.

Do not rebase or otherwise alter branch ancestry.

The Owner retains control of those Git operations.

------------------------------------------------------------------------

## 11. Required Validation

At minimum rerun:

``` powershell
Set-Location -LiteralPath 'C:\Development\action-runner'

docker compose config
docker compose build
.\tests\validate-containers.ps1
git diff --check
git status --short
```

Also execute the new F-1 and A-2 tests as part of the normal test suite.

Verify:

-   runtime-created migrated state survives the required lifecycle
    transitions;
-   normal shutdown never removes registration state;
-   same-container restart succeeds with valid migrated state;
-   recreation succeeds with valid migrated state;
-   no bootstrap occurs during ordinary restart;
-   no deregistration occurs;
-   no `--replace` occurs;
-   malformed migrated state fails closed;
-   `_work` remains disposable;
-   decommission guards refuse invalid invocations;
-   recovery documentation is actionable;
-   no network access or real GitHub operation occurred.

Compare:

``` powershell
git diff --exit-code -- alignment.md project-specification.md
```

It must produce no WP-0.3 Round 2 change to either file.

------------------------------------------------------------------------

## 12. Round 2 Handoff

Create a **new immutable execution artifact** under:

``` text
_Context/Executions/
```

Use:

``` text
WP-0.3-round-2-handoff-20261012.md
```

Do not modify the Round 1 handoff.

The Round 2 handoff must contain:

-   Role Authority;
-   date;
-   branch;
-   governing finding `F-1`;
-   authorized advisories `A-1` and `A-2`;
-   exact files changed in Round 2;
-   exact F-1 remediation design;
-   treatment of `.credentials_migrated`;
-   treatment of `.runner_migrated`;
-   signal/shutdown behavior after remediation;
-   A-1 recovery-documentation changes;
-   A-2 guard tests added;
-   commands executed;
-   actual results;
-   one-to-one accounting of affected acceptance criteria;
-   regression results for the complete WP-0.3 suite;
-   any failures encountered and how they were resolved;
-   remaining DEFERRED registered-runner tests;
-   `git diff --check` result;
-   relevant `git diff --stat`;
-   relevant `git status --short`;
-   confirmation governance files were unchanged;
-   confirmation no real registration/token/PAT/decommission/deployment
    action occurred.

Clearly distinguish:

``` text
locally demonstrated
synthetically demonstrated
statically verified
DEFERRED until authorized registered-runner testing
```

Do not claim F-1 is confirmed against GitHub merely because the
synthetic test passes.

------------------------------------------------------------------------

## 13. Stop Condition

After implementation, complete local validation, and creation of the
Round 2 handoff:

**STOP.**

Do not self-approve.

Do not proceed to runner registration.

Do not perform Git commit/push/merge operations.

Submit the Round 2 implementation for independent delta review.

The expected next review artifact is:

``` text
_Context/Reviews/REVIEW-action-runner-005.md
```

That review should evaluate the Round 2 delta, closure of F-1, treatment
of A-1/A-2, and regression evidence rather than reopening accepted Round
1 findings without new evidence.
