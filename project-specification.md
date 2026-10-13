# ThisByte Action Runner --- Project Specification

**Project:** action-runner\
**Organization:** ThisByte LLC\
**Document:** Project Specification\
**Version:** Revision 2\
**Status:** Reconciled Specification — Pending Owner and Chief Architect Review\
**Date:** 2026-10-12\
**Revision Authority:** Implementation Tool — Owner-authorized project-specification update\
**Project Root:** `C:\Development\action-runner`\
**Project Source Repository:** `scantoria/action-runner`\
**Initial Repository Served by the Runner:** `scantoria/thisbyte-website`

This revision incorporates the Owner-approved WP-0.2 architecture from
`_Context/Work-Packages/WP-0.2-Runner-Lifecycle-Registration-Design.md` and
the authorized, paused WP-0.3 scope from
`_Context/Work-Packages/WP-0.3-Runner-Lifecycle-Implementation-Remediation.md`.
It does not authorize implementation, registration, credential acquisition,
or deployment. WP-0.3 remains paused pending Owner and Chief Architect
review of this reconciled specification.

------------------------------------------------------------------------

## 0. Project Identity and Area of Operation

**Governance update authority:** Implementation Tool, executing the Owner-authorized governance update on 2026-10-12.

**Project ID:** `AR`

The Project ID is used for project-scoped governance artifacts that require
an identifier, including Incident Resolution and Prevention (IRP) filenames defined
by `alignment.md`.

IRP files use the following naming convention:

`IRP-AR-NNN.md`

where `NNN` is a zero-padded sequential incident number beginning with `001`.
IRP files are stored in `_Context/Sessions/` in accordance with
`alignment.md`.

**Project Name:** ThisByte Action Runner

**Project Root / Area of Operation:** `C:\Development\action-runner`

The Area of Operation consists of the project root and its subdirectories.
No searching, reading, or writing outside this boundary is authorized unless
the Owner explicitly grants an exception.

------------------------------------------------------------------------

## 1. Purpose

The Action Runner project establishes a controlled, reproducible, and
security-conscious self-hosted GitHub Actions runner for ThisByte
development and deployment workflows.

The initial runner will operate on the ThisByte HP Windows development
workstation using Docker Desktop and WSL2/Linux containers. It will
provide GitHub Actions execution capability without placing the runner
directly on production or infrastructure-serving hosts.

This project is infrastructure supporting CI/CD. It is separate from the
application source code and shall remain independently maintainable.

------------------------------------------------------------------------

## 2. Project Objectives

The project shall:

1.  Provide a containerized, persistent GitHub Actions self-hosted runner.
2.  Keep runner configuration reproducible as code.
3.  Execute the runner as an unprivileged Linux user.
4.  Establish a controlled trust boundary between GitHub Actions and the
    ThisByte local network.
5.  Avoid granting workflow jobs control of the Docker host.
6.  Avoid embedding credentials or secrets in images or source control.
7.  Support controlled CI execution for the `scantoria/thisbyte-website`
    repository.
8.  Later support restricted deployment from the runner to the
    `station-01` nginx server.
9.  Separate CI responsibilities from CD responsibilities and
    credentials.
10. Provide an operational model for registration, shutdown, recovery,
    rebuild, and eventual migration to a dedicated runner host.

------------------------------------------------------------------------

## 3. Current Project State

### 3.1 Current Governance and Work-Package State — 2026-10-12

-   WP-0.1 baseline implementation/review is complete. This does not
    establish completion of the lifecycle remediation or operational acceptance.
-   WP-0.2 Runner Lifecycle & Registration Design is Owner-approved
    as of 2026-10-12 and establishes the persistent-runner architecture.
-   WP-0.3 Runner Lifecycle Implementation / Remediation is authorized
    as the next implementation stage, but remains paused until this
    specification reconciliation is completed and reviewed by the Owner
    and Chief Architect.
-   Runner registration has not been authorized.
-   Acquisition or use of a registration token or PAT has not been authorized.
-   Deployment credentials have not been authorized.
-   `station-01` access, modification, and deployment remain outside
    current authorization. Production deployment is not authorized.

### 3.2 Historical Prototype Baseline — 2026-09-25

The initial implementation was created and locally validated in September.
The following are historical baseline facts, not claims of current
WP-0.3 validation:

-   Dockerfile created.
-   `compose.yaml` created.
-   `entrypoint.sh` created.
-   `.env.example`, `.gitignore`, `.dockerignore`, and `.gitattributes`
    created.
-   README created.
-   Docker image successfully built as
    `thisbyte/actions-runner:2.328.0`.
-   `docker compose config` completed successfully.
-   Container runtime inspection confirmed execution as non-root user
    `runner`.
-   No inbound ports are exposed.
-   Docker socket is not mounted.
-   Container is not privileged.
-   Prototype persistent storage was limited to the runner work directory;
    WP-0.3 must replace that model with the approved Section 12 requirements.
-   No GitHub runner token is currently present.
-   Runner has not been registered with GitHub.
-   No deployment SSH credentials have been created.
-   No changes have been made to `station-01` as part of this project.

### 3.3 Mandatory Current Hold Point

After specification review, WP-0.3 may implement and locally validate the
approved lifecycle without credentials. This specification revision itself
does not authorize that step. The runner
**SHALL NOT be registered with GitHub and SHALL NOT receive deployment
credentials until the applicable design, security, and credential-handling
requirements are reviewed and approved, and the Owner explicitly authorizes
each respective operation.** Review approval alone does not authorize
registration, token acquisition, or deployment credentials.

The existing implementation is therefore considered a prototype
implementation subject to review against this specification.

------------------------------------------------------------------------

## 4. Scope

### 4.1 In Scope

The initial project includes:

-   Docker-based GitHub Actions runner.
-   Docker Desktop/WSL2 host integration.
-   Runner image definition.
-   Docker Compose configuration.
-   Runner startup and shutdown lifecycle.
-   GitHub runner registration and deregistration design.
-   Runtime configuration.
-   Secret-handling design.
-   Persistent runner registration/configuration state and separate,
    disposable-by-default job workspace.
-   Runner labeling and targeting.
-   Repository-level runner integration.
-   CI execution.
-   Future restricted SSH deployment path to `station-01`.
-   Operational documentation.
-   Recovery/rebuild procedures.
-   Security validation.
-   Test workflow proving runner operation.

### 4.2 Out of Scope for Initial Registration

The following shall remain deferred until explicitly authorized:

-   Production deployment.
-   Deployment SSH credentials.
-   Changes to `station-01`.
-   nginx configuration changes.
-   Internal DNS changes.
-   PKI/certificate changes.
-   GitHub production environments.
-   Production secrets.
-   Automated production promotion.
-   Broad organization-level runner access.
-   Docker-in-Docker or host Docker control.
-   Unrestricted access to the ThisByte LAN.

------------------------------------------------------------------------

## 5. Architecture

### 5.1 Initial Architecture

The initial architecture uses a **persistent**, repository-scoped GitHub
Actions runner. Ephemeral runner operation is deferred unless separately
approved in the future. The project's source repository is
`scantoria/action-runner`; the initial repository served by the runner is
`scantoria/thisbyte-website`.

``` text
Initial Repository Served by the Runner
scantoria/thisbyte-website
        |
        | GitHub Actions
        v
HP Windows Workstation
        |
        v
Docker Desktop / WSL2
        |
        v
action-runner container
(persistent, non-root Linux runner)
        |
        | future restricted SSH deployment
        v
station-01
Ubuntu / nginx
```

### 5.2 Approved Persistent-Runner Lifecycle

``` text
Explicit first bootstrap (only after separate Owner authorization)
        |
        v
Registration/configuration state persisted
        |
        v
Listener starts
        |
        v
Normal shutdown stops listener without deregistration
        |
        v
GitHub runner remains registered and appears Offline
        |
        v
Restart uses persisted registration/configuration state
        |
        v
Listener reconnects without a new registration token
```

GitHub Online/Offline transitions and actual reconnection are required
registered-runner tests, not verified outcomes of this reconciliation.

### 5.3 Trust Boundaries

The architecture contains distinct trust boundaries:

1.  **GitHub boundary** --- workflow definitions, repository
    permissions, Actions jobs, and runner registration.
2.  **Runner-host boundary** --- Windows, WSL2, and Docker Desktop.
3.  **Runner-container boundary** --- unprivileged execution environment
    for Actions jobs.
4.  **Deployment boundary** --- future restricted communication between
    the runner and `station-01`.
5.  **Production boundary** --- production promotion shall remain
    separately controlled and shall not be implied by access to a
    development runner.

The runner shall not be treated as inherently trusted merely because it
is hosted on a ThisByte-owned workstation. GitHub Actions workflow code
executes on the runner and therefore inherits whatever resources the
runner can access.

------------------------------------------------------------------------

## 6. Host Environment

Initial host:

-   Windows HP development workstation.
-   Docker Desktop.
-   WSL2 Linux container engine.
-   Linux containers.
-   Docker Desktop configured to start with Windows user sign-in.

The HP workstation is acceptable for the initial development CI
environment. It is not assumed to provide 24x7 unattended availability.

If continuous CI/CD availability becomes a requirement, the runner
SHOULD migrate to a dedicated Linux host or VM.

------------------------------------------------------------------------

## 7. Container Requirements

The runner container SHALL:

-   Use a supported Linux base image.
-   Use the official GitHub Actions runner distribution.
-   Pin the runner version.
-   Run the Actions runner process as a non-root Linux user.
-   Not grant the runner user unrestricted sudo capability.
-   Not run in privileged mode.
-   Not mount `/var/run/docker.sock`.
-   Not expose inbound ports unless a future requirement explicitly
    justifies them.
-   Not embed GitHub tokens, PATs, SSH private keys, passwords, or other
    credentials in the image.
-   Contain only packages justified by runner operation or approved
    workflow requirements.
-   Be reproducible from source-controlled configuration.
-   Support graceful listener shutdown without deregistration or
    deletion of persisted registration/configuration state.
-   Support controlled runner deregistration through a separate,
    explicitly requested administrative decommission operation.
-   Configure registration using `--disableupdate`; the running
    container shall not silently self-update its runner binary.

Current pinned runner version:

``` text
2.328.0
```

A runner-version upgrade shall be treated as a controlled dependency
update, implemented through deliberate image/build version changes, and
validated before adoption. The Docker image is the authoritative
runner-version boundary.

------------------------------------------------------------------------

## 8. Docker Host Security

The Docker host represents a high-value trust boundary.

The Actions runner SHALL NOT receive unrestricted access to the Docker
daemon.

Specifically:

``` text
/var/run/docker.sock
```

shall not be mounted into the runner container under the initial
architecture.

Mounting the host Docker socket would allow workflow code to exercise
effective control over the Docker host and potentially escape the
intended container security boundary.

If future CI requirements require container builds, an alternative
design SHALL be evaluated rather than silently adding Docker socket
access.

------------------------------------------------------------------------

## 9. Runtime Identity

The runner shall execute under an unprivileged Linux account.

Current runtime identity:

``` text
runner
```

The runner user shall not be placed in sudoers merely to simplify
workflow implementation.

Filesystem permissions shall follow least privilege.

------------------------------------------------------------------------

## 10. GitHub Scope

Action Runner source repository: `scantoria/action-runner`.

Initial repository served by the runner and intended runner scope:

``` text
Owner:      scantoria
Repository: thisbyte-website
Runner:     thisbyte-hp-runner
Labels:     self-hosted, linux, x64, thisbyte
```

The initial runner shall be repository-scoped unless a later
architectural decision explicitly expands its scope.

Expanding the runner to organization-level use requires review because
doing so increases the number of repositories and workflows capable of
executing code on the local runner.

------------------------------------------------------------------------

## 11. Runner Registration and Credential Handling

### 11.1 Principles

Runner registration shall follow these principles:

-   Registration shall use an authorized short-lived repository runner
    registration token supplied at runtime for explicit bootstrap only.
-   Registration credentials shall never be committed.
-   Registration credentials shall never be baked into a Docker image.
-   Secrets shall not be written to logs.
-   Secrets shall not be included in `.env.example`.
-   The token shall be used only when initial registration is actually
    required; ordinary restart of a configured persistent runner shall
    not require a registration token.
-   The bootstrap token shall be discarded after configuration and
    shall not be stored as normal persistent runner configuration.
-   A long-lived PAT shall not be placed inside the runner merely to
    acquire registration tokens.

### 11.2 `.env`

The `.env` file shall be excluded from Git.

Non-secret runtime configuration may include:

``` text
GITHUB_OWNER=scantoria
GITHUB_REPOSITORY=thisbyte-website
RUNNER_NAME=thisbyte-hp-runner
RUNNER_LABELS=self-hosted,linux,x64,thisbyte
```

`RUNNER_TOKEN` shall not become permanent `.env` configuration.
The high-level bootstrap-only token lifecycle is approved. The exact
operator/API mechanism for obtaining the short-lived repository token
remains deferred; WP-0.2 does not select an API, CLI, PAT, GitHub App,
or other acquisition mechanism. The runner shall receive the authorized
token as runtime bootstrap input only, not acquire it through an embedded
long-lived credential.

### 11.3 State-Aware Startup and Bootstrap

Startup shall validate non-secret configuration and distinguish:

1.  **Valid persisted registration/configuration state:** start the
    listener using that state without a registration token.
2.  **No state and bootstrap not explicitly requested:** fail closed
    with a clear diagnostic; do not attempt registration automatically.
3.  **Explicit bootstrap but required short-lived token absent:** fail
    closed with a clear diagnostic.
4.  **Partial, malformed, inconsistent, stale, or ambiguous local state:**
    fail closed, preserve state and diagnostics, and require explicit
    operator intervention. Do not silently repair, delete, replace,
    overwrite, or re-register ambiguous state.

Only explicitly requested, separately authorized bootstrap with absent
state and a valid runtime token may configure the runner. Configuration
shall use `--disableupdate`, persist complete registration/configuration
state before listener startup, and discard the bootstrap token.
Registration failure shall stop execution, preserve actionable diagnostics
and any partial state, and never enter automatic registration loops.
No lifecycle stage shall expose registration credentials.

Automatic or silent use of `--replace` is prohibited. Stale or duplicate
GitHub runner records and GitHub/local-state disagreement require deliberate
administrative recovery, not deletion or replacement during ordinary startup.

The restart policy, including any retention of `restart: unless-stopped`,
shall not create destructive, credential-consuming, or uncontrolled
registration retry loops. Failed bootstrap and invalid-state conditions
shall remain diagnosable. WP-0.3 shall validate this behavior.

### 11.4 Normal Shutdown and Restart

`SIGTERM`, `SIGINT`, `docker stop`, Docker Desktop shutdown, WSL2 shutdown,
and Windows host shutdown shall stop the listener cleanly where possible,
without GitHub deregistration or deletion of persisted state. Shutdown
handling shall be idempotent. The expected GitHub state is registered but
Offline. Ordinary restart shall reuse valid persisted state and reconnect
without a new registration token.

### 11.5 Explicit Administrative Decommission

Permanent runner removal is distinct from ordinary lifecycle events and
requires intentional operator action and separate authorization. Controlled
decommission shall deregister the GitHub runner identity before removing
persisted local state. Partial decommission failure shall preserve enough
information for recovery and diagnosis. Normal shutdown cannot enter this
path. Decommission execution is not authorized by WP-0.3 or this revision.

Registered lifecycle tests remain **DEFERRED** until separate Owner
registration authorization. These include GitHub Online/Offline transitions,
reconnection after container, Docker Desktop, WSL2, or Windows restart,
abnormal host termination, stale-record handling against GitHub, controlled
decommission/re-registration, and a harmless GitHub Actions CI job.

------------------------------------------------------------------------

## 12. Persistent Storage

Persistent storage shall be minimized while intentionally preserving the
runner's registration/configuration state. That state is required for normal
restart and reconnection, is sensitive credential-bearing material, and
shall be protected accordingly. It shall survive container recreation and
have an explicit documented storage boundary independent of job workspace
data. WP-0.3 selects and validates the implementation mechanism within
these approved constraints; persistence itself is no longer an open decision.

The job workspace at:

``` text
/actions-runner/_work
```

is **disposable by default**. `_work` shall remain logically and
operationally separate from persistent runner identity/configuration and
shall never substitute for registration-state persistence.

Future performance requirements may evaluate GitHub caching, artifacts,
or explicit workspace persistence separately. Any technical constraint
requiring a change to the disposable-by-default architecture shall be
surfaced for architecture review before implementation.

Any retained repository source, build output, logs, caches, or workflow
data shall also be protected according to its sensitivity. Recovery shall
never silently delete ambiguous registration/configuration state.

------------------------------------------------------------------------

## 13. CI Responsibilities

The runner is intended to support CI activities such as:

``` text
checkout
   |
   v
dependency installation
   |
   v
lint
   |
   v
type checking
   |
   v
unit tests
   |
   v
production build
   |
   v
Playwright tests
   |
   v
axe-core accessibility checks
   |
   v
test/build artifacts
```

Actual workflow implementation belongs to the applicable application
project and shall not be introduced into `action-runner` merely because
the runner executes it.

------------------------------------------------------------------------

## 14. CI/CD Separation

CI and CD shall remain conceptually and operationally distinct.

### CI

CI validates source code and produces evidence/artifacts.

### CD

CD promotes an approved artifact or release to a target environment.

A successful CI run does not itself authorize production deployment.

Deployment credentials shall be introduced only after the runner itself
has been validated.

Production deployment shall require a separate authorization/approval
mechanism.

------------------------------------------------------------------------

## 15. Future Deployment to station-01

Future deployment architecture is expected to follow:

``` text
GitHub Actions
      |
      v
Self-hosted runner
      |
      | restricted SSH
      v
thisbyte-deploy@station-01
      |
      v
authorized website deployment paths
```

The deployment identity shall:

-   Be separate from interactive administrator identities.
-   Use its own SSH keypair.
-   Not have unrestricted sudo access.
-   Have write access only to required deployment locations.
-   Not administer Pi-hole, nginx, PKI, DNS, or unrelated server
    services unless a future requirement explicitly authorizes such
    access.

The intended website hierarchy on `station-01` is:

``` text
/srv/www/thisbyte/
├── org/
├── rebuild-01/
└── rebuild-02/
```

This directory structure is architectural context only and is not
authorized for modification by the current Action Runner work package.

------------------------------------------------------------------------

## 16. Environment Separation

The internal website targets currently planned are:

``` text
org.thisbyte.stjo.home.arpa
rebuild-01.thisbyte.stjo.home.arpa
rebuild-02.thisbyte.stjo.home.arpa
```

Production is a separate promotion/deployment target.

`rebuild-02` shall not automatically be treated as production.

------------------------------------------------------------------------

## 17. Runner Availability

The initial HP-hosted runner is a development infrastructure component.

Expected limitations include:

-   Availability depends on the HP workstation being powered on.
-   Availability depends on Windows being operational.
-   Availability depends on Docker Desktop being running.
-   Host maintenance or user activity may interrupt the runner.
-   The workstation is not initially treated as a high-availability
    CI/CD server.

These limitations are acceptable for initial development and validation.

A dedicated runner host SHOULD be evaluated if unattended or continuous
operation becomes operationally important.

------------------------------------------------------------------------

## 18. Logging and Auditability

The project shall maintain sufficient evidence to determine:

-   Whether the runner successfully registered.
-   When the runner connected/disconnected.
-   Which GitHub workflow invoked a job.
-   Whether CI succeeded or failed.
-   Whether a deployment was attempted.
-   Which artifact/version was deployed.
-   Whether deployment validation succeeded.
-   Whether rollback was required.

Secrets shall not be intentionally logged.

GitHub Actions logs and retained workflow artifacts should provide the
primary CI execution record.

------------------------------------------------------------------------

## 19. Recovery and Rebuild

The runner shall be treated as reproducible infrastructure rather than a
manually curated server.

Recovery with valid persisted runner state should consist of:

1.  Rebuild the image from the project source.
2.  Recreate the container using Compose.
3.  Supply authorized runtime configuration.
4.  Validate and reuse protected persisted registration/configuration state.
5.  Validate connectivity.
6.  Execute the runner test workflow.
7.  Confirm no new registration token or runner replacement was required.

Missing state shall not automatically trigger registration. Invalid or
ambiguous state shall fail closed and require explicit administrative
recovery. Abnormal termination shall not automatically deregister,
replace, or delete state. If recovery requires decommission or subsequent
re-registration, those are separate, explicitly authorized operations
under Section 11, not ordinary rebuild steps.

Manual modifications inside a running container shall not be considered
authoritative configuration.

------------------------------------------------------------------------

## 20. Repository and Source-Control Requirements

The `action-runner` project has its own source repository,
`scantoria/action-runner`, and shall remain separate from application
repositories. `scantoria/thisbyte-website` is the initial repository served
by the runner, not this project's source repository.

Expected root structure:

``` text
action-runner/
├── project-specification.md
├── alignment.md
├── README.md
├── Dockerfile
├── compose.yaml
├── entrypoint.sh
├── .env.example
├── .gitignore
├── .dockerignore
├── .gitattributes
├── Docs/
└── _Context/
    ├── Executions/
    ├── Reviews/
    ├── Sessions/
    └── Work-Packages/
```

The governance/artifact directories above already exist. Execution evidence,
independent reviews, and session records follow the locations and immutable
artifact rules in `alignment.md`; canonical WP-0.2 and WP-0.3 currently
reside under `_Context/Work-Packages/`. This structure describes existing
locations and does not authorize creating, moving, or restoring artifacts.

The following shall never be committed:

-   `.env`
-   GitHub registration tokens
-   Personal Access Tokens
-   SSH private keys
-   passwords
-   deployment secrets
-   generated credentials
-   credential-bearing runner registration/configuration state

------------------------------------------------------------------------

## 21. Governance

`project-specification.md` defines **what the project is intended to
build and the boundaries within which it operates**.

`alignment.md` defines the project roles, collaboration model,
implementation responsibilities, review expectations, and handoff
process.

Implementation agents shall review both documents before beginning or
continuing substantive work.

Where implementation conflicts with an approved project requirement, the
implementation shall stop and the discrepancy shall be surfaced rather
than silently changing the requirement.

------------------------------------------------------------------------

## 22. Change Control

Architectural or security-impacting changes require explicit review
before implementation.

Examples include:

-   Mounting the Docker socket.
-   Running the container privileged.
-   Adding sudo capability.
-   Expanding runner scope from repository to organization.
-   Adding inbound ports.
-   Adding long-lived GitHub credentials.
-   Adding deployment credentials.
-   Granting access to additional LAN resources.
-   Changing deployment authorization.
-   Changing production promotion behavior.
-   Moving the runner to another host.

Implementation details that remain within the approved specification may
be refined without redefining project architecture.

------------------------------------------------------------------------

## 23. Initial Acceptance Criteria

The initial runner implementation shall not be considered complete
until:

-   [ ] `project-specification.md` is reviewed and approved.
-   [ ] `alignment.md` is present at project root.
-   [ ] Dockerfile satisfies the security requirements.
-   [ ] Compose configuration validates.
-   [ ] Image builds successfully.
-   [ ] Container executes as non-root.
-   [ ] Container is not privileged.
-   [ ] Docker socket is not mounted.
-   [ ] No unnecessary inbound ports are exposed.
-   [ ] No credentials exist in the image.
-   [x] Bootstrap-only registration-token lifecycle and persistent-runner
    architecture are Owner-approved through WP-0.2 (2026-10-12).
-   [ ] Exact registration-token acquisition mechanism is approved before use.
-   [ ] WP-0.3 lifecycle remediation passes local noncredentialed validation
    and independent review.
-   [ ] Owner explicitly authorizes runner registration separately.
-   [ ] Persistent identity/configuration survives container recreation;
    `_work` is disposable by default and separate from that state.
-   [ ] Missing, partial, or invalid state fails closed without automatic
    registration, `--replace`, state deletion, or destructive recovery.
-   [ ] Registration uses `--disableupdate` and restart policy cannot
    cause uncontrolled registration loops.
-   [ ] Runner successfully registers to the intended private
    repository.
-   [ ] GitHub reports the runner online.
-   [ ] A harmless test workflow executes successfully on the runner.
-   [ ] Normal shutdown is tested without deregistration or state deletion.
-   [ ] Restart/reconnection using persisted identity is tested without
    a new registration token.
-   [ ] Abnormal termination and stale-record recovery are tested under
    explicit administrative control.
-   [ ] Separately authorized decommission and controlled re-registration
    behavior are tested independently of normal shutdown.
-   [ ] Operational instructions are documented.

------------------------------------------------------------------------

## 24. Deployment Acceptance Criteria

Deployment capability is a subsequent stage and shall require, at
minimum:

-   [ ] Dedicated `station-01` deployment identity.
-   [ ] Separate deployment SSH key.
-   [ ] No unrestricted sudo.
-   [ ] Deployment filesystem permissions follow least privilege.
-   [ ] Host-key verification is configured.
-   [ ] Deployment workflow uses approved artifacts.
-   [ ] Deployment smoke test exists.
-   [ ] Versioned release strategy exists.
-   [ ] Rollback procedure exists and is tested.
-   [ ] Production requires explicit approval.
-   [ ] Existing Pi-hole/nginx services remain unaffected.

------------------------------------------------------------------------

## 25. Deferred Decisions

The following decisions intentionally remain open:

1.  Exact operator/API mechanism for obtaining short-lived repository
    runner registration tokens; no API, CLI, PAT, GitHub App, or other
    acquisition mechanism is selected by WP-0.2.
2.  Long-term dedicated runner host/VM.
3.  Strategy for workflows that eventually require container-image
    builds.
4.  Exact artifact retention periods.
5.  Exact CI branch policy.
6.  Exact CD promotion policy.
7.  GitHub environment/protection configuration.
8.  Deployment release-directory and symlink implementation.
9.  Runner monitoring/alerting requirements.

WP-0.2 has resolved persistent-runner operation, intentional persistent
registration/configuration state, disposable-by-default `_work`, and the
bootstrap-only registration-token lifecycle. Ephemeral runner operation
remains deferred pending separate future approval; it is not the selected
initial design. The exact persistence implementation is delegated to
WP-0.3 within Section 12's boundaries.

These decisions shall be resolved when required rather than prematurely
expanding privileges or infrastructure.

------------------------------------------------------------------------

## 26. Immediate Next Steps

The approved progression is:

1.  Reconcile `project-specification.md` with approved WP-0.2 and current state.
2.  Obtain Owner and Chief Architect review of the reconciled specification.
3.  Resume WP-0.3 implementation/remediation only after that review and
    resolution of applicable governance prerequisites.
4.  Complete local noncredentialed lifecycle, build, and security validation.
5.  Complete independent review with traceable acceptance evidence.
6.  Obtain the Owner's separate decision on runner-registration authorization
    and resolve the exact token-acquisition mechanism before use.
7.  Only if explicitly authorized, perform controlled registration to
    `scantoria/thisbyte-website` and confirm expected identity, labels,
    and GitHub Online status.
8.  Execute harmless CI and the authorized registered lifecycle validation.
9.  Stop and review results before considering any deployment credentials.

This specification update does not authorize any later step. WP-0.3 remains
paused pending Owner and Chief Architect review. Token acquisition, runner
registration, deployment credentials, `station-01` access/modification,
and production deployment remain unauthorized.

------------------------------------------------------------------------

## 27. Definition of the Current Boundary

The immediate authorized task is this specification reconciliation and
its validation, followed by Owner and Chief Architect review. It does not
include WP-0.3 implementation or production deployment.

The subsequent project objective is to establish a secure, reproducible,
persistent, repository-scoped GitHub Actions execution environment and,
only after separate Owner registration authorization, prove that GitHub
can safely dispatch a harmless CI job to the ThisByte-owned runner.

Only after that boundary is proven will the project proceed toward
deployment access to `station-01`.
