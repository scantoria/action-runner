# WP-0.2 --- Runner Lifecycle & Registration Design

**Project:** ThisByte Action Runner\
**Role Authority:** Chief Architect\
**Project Root:** `C:\\Development\\action-runner`\
**Target Runner:** `thisbyte-hp-runner`\
**Target Repository:** `scantoria/thisbyte-website`\
**Work Package Type:** Architecture / Design\
**Status:** **APPROVED 2026-10-12**

------------------------------------------------------------------------

## 1. Objective

Define and document the complete lifecycle and registration architecture
for the persistent, repository-scoped ThisByte GitHub Actions runner
before lifecycle remediation or runner registration occurs.

WP-0.2 is a **design-first** work package.

It resolves the lifecycle concerns identified during WP-0.1,
specifically:

-   **LIFE-4:** Normal shutdown incorrectly coupled to runner
    deregistration, including the double-cleanup/deregistration defect.
-   **LIFE-5:** Partial-registration and stale-state conditions can
    create ambiguous or unsafe startup behavior.

WP-0.2 establishes the approved architecture that WP-0.3 shall
implement.

------------------------------------------------------------------------

## 2. Scope Boundary

WP-0.2 defines architecture and lifecycle behavior only.

It does **not** authorize:

-   Runner registration.
-   Acquisition or generation of a GitHub runner registration token.
-   Use or introduction of a Personal Access Token (PAT).
-   Runtime lifecycle remediation.
-   Deployment credentials.
-   SSH credentials.
-   Access to or modification of `station-01`.
-   Modification of the `thisbyte-website` repository or its workflows.
-   Production deployment.

The existing registration and deployment hold remains active.

------------------------------------------------------------------------

## 3. Architectural Principles

The approved lifecycle model is based on the following principles:

1.  The runner is a **persistent self-hosted runner**, not an ephemeral
    runner.
2.  Normal shutdown does not mean permanent runner removal.
3.  Registration is an explicit bootstrap operation.
4.  Ordinary restarts reuse persisted runner identity and configuration.
5.  Registration/configuration state is persistent and sensitive.
6.  The job workspace and runner identity are separate lifecycle
    concerns.
7.  Registration credentials are short-lived bootstrap secrets.
8.  Deployment credentials are a separate future CD concern.
9.  Invalid or ambiguous state fails closed.
10. Stale or duplicate GitHub runner records require explicit
    administrative recovery.
11. The runner must not silently replace an existing GitHub runner.
12. Runner software versioning remains controlled by the Docker image.

------------------------------------------------------------------------

## 4. Runner Lifecycle State Model

The runner lifecycle shall distinguish the following states:

1.  **Unregistered**
2.  **Bootstrap / Registration Requested**
3.  **Registration in Progress**
4.  **Registered / Configured**
5.  **Listener Running / Online**
6.  **Stopped / Offline**
7.  **Registration or Configuration Failure**
8.  **Partial Registration / Recovery Required**
9.  **Explicit Decommission / Deregistration**

These states must not be collapsed into a single startup/shutdown path.

### 4.1 First Start

``` text
FIRST START
    |
    v
Valid registration state present?
    |
    +-- YES --------------------> Start runner listener
    |                                  |
    |                                  v
    |                             Runner Online
    |
    +-- NO --> Explicit bootstrap requested?
                    |
                    +-- NO --> Fail closed
                    |
                    +-- YES --> Valid runtime registration token?
                                      |
                                      +-- NO --> Fail closed
                                      |
                                      +-- YES --> Register
                                                    |
                                                    +-- SUCCESS
                                                    |     Persist state
                                                    |     Start listener
                                                    |
                                                    +-- FAILURE
                                                          Stop
                                                          Preserve diagnostics
```

Registration must not occur merely because a container starts.

------------------------------------------------------------------------

## 5. First-Time Registration / Bootstrap

First-time registration is an explicit administrative bootstrap
operation.

The approved bootstrap model is:

``` text
Owner / Authorized Operator
        |
        v
Obtain short-lived repository runner token
        |
        v
Inject token for first registration only
        |
        v
Execute runner configuration
        |
        v
Persist runner identity/configuration state
        |
        v
Discard bootstrap token
        |
        v
Start listener
```

Requirements:

-   Registration must be explicitly requested.
-   A short-lived repository registration token is supplied only at
    runtime.
-   A long-lived PAT must not be placed inside the runner.
-   Registration credentials must not be baked into the image.
-   `RUNNER_TOKEN` must not be treated as permanent `.env`
    configuration.
-   Successful registration must establish persistent runner
    configuration before normal listener operation.
-   Ordinary restarts must not require another registration token.

WP-0.2 approves this model but does not authorize executing it.

------------------------------------------------------------------------

## 6. Persistent Runner Identity and Configuration

GitHub runner registration produces identity and configuration state
that must survive container replacement and ordinary host lifecycle
events.

The architecture shall distinguish:

``` text
Runner Image
    Disposable

Runner Registration / Configuration State
    Persistent
    Sensitive

_work
    Disposable by default

Registration Token
    Short-lived bootstrap secret

Deployment Credentials
    Future and separate
```

Registration/configuration state must:

-   Have an explicit persistence boundary.
-   Survive container recreation.
-   Be protected as sensitive credential-bearing state.
-   Remain independent from `_work`.
-   Be validated before the listener starts.

The exact implementation mechanism is delegated to WP-0.3, provided it
preserves these architectural properties.

------------------------------------------------------------------------

## 7. `_work` Lifecycle Decision

`_work` is **disposable by default**.

It shall not be treated as the persistence mechanism for runner identity
or registration configuration.

If future performance requirements justify persistence, GitHub caching,
artifacts, or another explicit mechanism should be evaluated
independently.

Any implementation constraint that requires changing this decision must
be surfaced for architecture review rather than silently adopted.

------------------------------------------------------------------------

## 8. Normal Shutdown --- LIFE-4 Resolution

Normal shutdown must **not deregister the runner**.

The following events are normal lifecycle events:

``` text
Windows shutdown
Docker Desktop stop
WSL2 shutdown
Container stop
SIGTERM
SIGINT
        |
        v
Stop runner listener cleanly
        |
        v
DO NOT DEREGISTER
        |
        v
Runner remains registered as Offline
```

Requirements:

-   Stop the listener cleanly where possible.
-   Do not execute runner removal during normal shutdown.
-   Do not delete persisted registration state.
-   Do not require a new registration token on the next startup.
-   Shutdown handling must be idempotent.
-   LIFE-4 double cleanup/deregistration behavior must be eliminated.

------------------------------------------------------------------------

## 9. Normal Restart

Normal restart uses persisted registration state.

``` text
Container starts
        |
        v
Validate persisted registration state
        |
        v
Start listener
        |
        v
Runner reconnects
```

The intended model applies to:

-   Container restart.
-   Docker Desktop restart.
-   WSL2 restart.
-   Windows restart.
-   Host recovery following ordinary power cycling.

A normal restart must not trigger registration or require a bootstrap
token.

------------------------------------------------------------------------

## 10. Startup Fail-Closed Model --- LIFE-5 Resolution

Startup must be state-aware and fail closed.

``` text
START
  |
  v
Valid persisted runner config?
  |
  +-- YES --> Start listener
  |
  +-- NO --> Explicit bootstrap requested?
                 |
                 +-- NO --> Fail closed
                 |
                 +-- YES --> Runtime token present?
                                |
                                +-- NO --> Fail closed
                                |
                                +-- YES --> Attempt registration
                                              |
                                              +-- SUCCESS
                                              |     Persist state
                                              |     Start listener
                                              |
                                              +-- FAILURE
                                                    Stop
                                                    Preserve diagnostics
                                                    Do not auto-loop
```

The runner must not infer that missing or damaged local state means it
is safe to create or replace a GitHub runner.

------------------------------------------------------------------------

## 11. Partial Registration and Recovery --- LIFE-5

A registration attempt can fail after GitHub and local state have
diverged.

Examples include:

-   GitHub accepts registration but local state is incomplete.
-   Local configuration exists but the GitHub runner record has been
    removed.
-   Container or host termination occurs during configuration.
-   Registration state becomes damaged or incomplete.
-   A runner with the intended name already exists in GitHub.

These conditions must result in an explicit recovery state.

The runner must:

-   Stop.
-   Preserve diagnostics.
-   Avoid automatic registration loops.
-   Avoid automatic state deletion.
-   Avoid automatic deregistration.
-   Avoid silent replacement.

Recovery is an administrative action.

------------------------------------------------------------------------

## 12. Stale and Duplicate Runner Records

Stale and duplicate runner records shall not be silently corrected.

Automatic use of:

``` text
--replace
```

is prohibited.

The following conditions require explicit administrative review:

-   GitHub runner exists but local state is absent.
-   Local state exists but GitHub runner has been removed.
-   Duplicate runner name exists.
-   Persisted configuration is incomplete or damaged.
-   Registration attempt leaves ambiguous state.

The recovery procedure may be implemented in WP-0.3, but execution
against GitHub remains separately authorized.

------------------------------------------------------------------------

## 13. Registration Token Lifecycle

Registration credentials are bootstrap-only.

Approved separation:

``` text
Registration Token
    Bootstrap only

PAT / Operator GitHub Credential
    NOT inside runner

GitHub Actions Job Token
    Supplied by GitHub during jobs

Deployment SSH Key
    Future CD stage only
```

Requirements:

-   The Owner or authorized operator obtains the short-lived repository
    registration token.
-   The token is injected only for explicit first registration.
-   The token is discarded after bootstrap.
-   The token is not required for ordinary restarts.
-   The token is not stored as normal persistent runner configuration.
-   No long-lived PAT is placed in the runner merely to generate
    registration tokens.

------------------------------------------------------------------------

## 14. Explicit Decommission / Removal

Permanent removal is a separate administrative operation.

``` text
Owner requests removal
        |
        v
Explicit decommission procedure
        |
        v
Deregister GitHub runner identity
        |
        v
Remove persisted local runner state
```

Requirements:

-   Decommission must never be triggered by ordinary shutdown.
-   Decommission requires intentional operator action.
-   Deregistration and local-state destruction must use controlled
    ordering.
-   Partial decommission failure must preserve enough information for
    recovery and diagnosis.
-   Decommission execution remains outside WP-0.2 authorization.

------------------------------------------------------------------------

## 15. Abnormal Termination Recovery

The design must account for:

-   Process crash.
-   Forced container termination.
-   Docker failure.
-   Docker Desktop termination.
-   WSL2 termination.
-   Windows restart.
-   Unexpected host power loss.

Where valid persisted runner configuration remains, restart should reuse
that configuration and reconnect.

Where state is invalid or ambiguous, startup must fail closed and
require administrative recovery.

Abnormal termination must not automatically deregister or replace the
runner.

------------------------------------------------------------------------

## 16. Restart Policy

The existing `restart: unless-stopped` policy may be retained only if
startup behavior is safe.

Requirements:

-   Missing registration state must not trigger repeated registration
    attempts.
-   Missing bootstrap credentials must fail closed.
-   Failed registration must not become an automatic
    credential-consuming retry loop.
-   Invalid persisted state must remain diagnosable.
-   Restart behavior must not perform destructive recovery.

WP-0.3 shall validate the implementation implications of this policy.

------------------------------------------------------------------------

## 17. Runner Version and Update Model

The Docker image pins the GitHub Actions runner version.

The approved registration/configuration model shall therefore use:

``` text
--disableupdate
```

Reason:

The running container must not self-update and drift away from the
runner version declared by the Docker image.

Runner upgrades shall be deliberate, reproducible image changes.

------------------------------------------------------------------------

## 18. Persistent vs. Ephemeral Decision

Ephemeral runners were considered but are deferred.

Approved decision:

``` text
Persistent runner: YES
Ephemeral runner:  DEFERRED
```

A persistent runner is appropriate for the current single HP-hosted
ThisByte runner.

Ephemeral or autoscaling runner architecture may be reconsidered if
ThisByte later operates a runner fleet or develops requirements that
justify the additional complexity.

------------------------------------------------------------------------

## 19. Registered Lifecycle Test Plan

After implementation, independent review, and separate Owner
authorization for registration, the registered lifecycle shall be
validated through controlled testing.

Planned tests include:

1.  First controlled registration.
2.  GitHub reports the expected runner identity and labels.
3.  Runner reaches Online state.
4.  Harmless CI job executes successfully.
5.  Normal container stop leaves the runner registered and Offline.
6.  Container restart reconnects without a new registration token.
7.  Docker Desktop restart reconnects.
8.  WSL2 restart reconnects.
9.  Windows restart reconnects.
10. Abnormal termination recovers using valid persisted identity.
11. Ordinary restart succeeds without a registration token.
12. Explicit bootstrap without a token fails closed.
13. Failed bootstrap preserves diagnostics and does not auto-loop.
14. Partial or invalid registration state fails closed.
15. Stale or duplicate runner state requires explicit recovery.
16. Explicit decommission removes the runner through a controlled
    administrative path.
17. Controlled re-registration succeeds after authorized decommission.

Tests requiring a registered runner remain deferred until the Owner
separately authorizes registration.

------------------------------------------------------------------------

## 20. Security Constraints

WP-0.2 preserves all existing security boundaries.

The design must not introduce:

-   Docker socket access.
-   Privileged container execution.
-   Unrestricted `sudo`.
-   Unnecessary inbound ports.
-   Baked credentials.
-   Long-lived PATs.
-   Deployment credentials.
-   station-01 credentials.
-   Automatic production deployment capability.

The runner remains repository-scoped.

------------------------------------------------------------------------

## 21. WP-0.3 Implementation Impacts

The approved WP-0.2 design requires WP-0.3 to address, at minimum:

-   State-aware `entrypoint.sh` behavior.
-   Removal of deregistration from normal shutdown.
-   Explicit persistent registration/configuration storage.
-   Separation of `_work` from registration state.
-   Explicit bootstrap mode.
-   Runtime-only registration-token handling.
-   Fail-closed invalid/partial-state behavior.
-   Prohibition of automatic `--replace`.
-   Explicit decommission path.
-   `--disableupdate`.
-   Safe interaction with `restart: unless-stopped`.
-   Local non-credentialed lifecycle validation.
-   Traceable acceptance-criterion evidence.

WP-0.3 shall not reinterpret these architecture decisions without
surfacing a material conflict for review.

------------------------------------------------------------------------

## 22. Approval and Sequencing

Approved sequence:

``` text
WP-0.2
Runner Lifecycle & Registration Design
        |
        v
Owner Approval
        |
        v
WP-0.3
Runner Lifecycle Implementation / Remediation
        |
        v
Independent Review
        |
        v
Owner Registration Authorization
        |
        v
First Controlled Runner Registration
        |
        v
Harmless CI Validation
        |
        v
Stop / Review
        |
        v
Future Deployment-Credential Design
```

------------------------------------------------------------------------

## 23. Approval Record

**WP-0.2 Status:** APPROVED\
**Owner Approval Date:** 2026-10-12\
**Authorized Next Step:** WP-0.3 --- Runner Lifecycle Implementation /
Remediation\
**WP-0.3 Authorization:** APPROVED TO PROCEED\
**Runner Registration:** NOT AUTHORIZED\
**Registration Credential Acquisition:** NOT AUTHORIZED\
**PAT Introduction:** NOT AUTHORIZED\
**Deployment Credentials:** NOT AUTHORIZED\
**station-01 Access/Modification:** NOT AUTHORIZED\
**Production Deployment:** NOT AUTHORIZED

The Owner's approval of WP-0.2 establishes this document as the
lifecycle and registration design baseline for WP-0.3 implementation.
