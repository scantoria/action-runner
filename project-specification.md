# ThisByte Action Runner --- Project Specification

**Project:** action-runner\
**Organization:** ThisByte LLC\
**Document:** Project Specification\
**Status:** Draft for Review\
**Date:** 2026-09-25\
**Project Root:** `C:\Development\action-runner`\
**Target GitHub Repository:** `scantoria/thisbyte-website`

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

1.  Provide a containerized GitHub Actions self-hosted runner.
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

At the time of this specification, an initial runner implementation has
been created and locally validated.

Completed:

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
-   Persistent storage is limited to the runner work directory.
-   No GitHub runner token is currently present.
-   Runner has not been registered with GitHub.
-   No deployment SSH credentials have been created.
-   No changes have been made to `station-01` as part of this project.

### 3.1 Mandatory Current Hold Point

The runner image may be built and locally validated, but the runner
**SHALL NOT be registered with GitHub and SHALL NOT receive deployment
credentials until the applicable design, security, and
credential-handling requirements are reviewed and approved.**

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
-   Persistent runner workspace.
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

``` text
GitHub Repository
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
(non-root Linux runner)
        |
        | future restricted SSH deployment
        v
station-01
Ubuntu / nginx
```

### 5.2 Trust Boundaries

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
-   support graceful shutdown.
-   Support clean runner deregistration where technically possible.

Current pinned runner version:

``` text
2.328.0
```

A runner-version upgrade shall be treated as a controlled dependency
update and validated before adoption.

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

Initial runner scope:

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

-   Registration credentials shall be short-lived wherever supported.
-   Registration credentials shall never be committed.
-   Registration credentials shall never be baked into a Docker image.
-   Secrets shall not be written to logs.
-   Secrets shall not be included in `.env.example`.
-   Long-lived credentials shall not be introduced solely to automate
    acquisition of short-lived credentials without explicit security
    review.

### 11.2 `.env`

The `.env` file shall be excluded from Git.

Non-secret runtime configuration may include:

``` text
GITHUB_OWNER=scantoria
GITHUB_REPOSITORY=thisbyte-website
RUNNER_NAME=thisbyte-hp-runner
RUNNER_LABELS=self-hosted,linux,x64,thisbyte
```

The final mechanism for acquiring and supplying the GitHub registration
token remains a design decision to be approved before registration.

A short-lived registration token SHOULD NOT be treated as permanent
project configuration.

### 11.3 Registration Lifecycle

The final runner lifecycle shall support:

1.  Validate required non-secret configuration.
2.  Obtain or receive an authorized short-lived registration credential.
3.  Configure the runner.
4.  Start the runner.
5.  Receive GitHub Actions jobs.
6.  Handle SIGTERM/SIGINT cleanly.
7.  Stop the runner process.
8.  Attempt GitHub deregistration where appropriate.
9.  Avoid exposing registration credentials during any lifecycle stage.

Container restart behavior and registration state shall be tested before
the runner is considered operational.

------------------------------------------------------------------------

## 12. Persistent Storage

Persistent storage shall be minimized.

The currently justified persistent path is:

``` text
/actions-runner/_work
```

This supports runner job workspace/cache continuity.

Runner configuration state shall not be persisted merely as a
convenience unless doing so is intentionally selected as part of the
lifecycle design.

Persistent storage shall be treated as potentially containing repository
source, build output, logs, or other workflow data and protected
accordingly.

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

Recovery should consist of:

1.  Rebuild the image from the project source.
2.  Recreate the container using Compose.
3.  Supply authorized runtime configuration.
4.  Register the replacement runner.
5.  Validate connectivity.
6.  Execute the runner test workflow.
7.  Remove obsolete runner registrations if necessary.

Manual modifications inside a running container shall not be considered
authoritative configuration.

------------------------------------------------------------------------

## 20. Repository and Source-Control Requirements

The `action-runner` project shall remain separate from application
repositories.

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
└── .gitattributes
```

The project may later be placed in a dedicated private GitHub repository
after review.

The following shall never be committed:

-   `.env`
-   GitHub registration tokens
-   Personal Access Tokens
-   SSH private keys
-   passwords
-   deployment secrets
-   generated credentials

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
-   [ ] Registration-token lifecycle is approved.
-   [ ] Runner successfully registers to the intended private
    repository.
-   [ ] GitHub reports the runner online.
-   [ ] A harmless test workflow executes successfully on the runner.
-   [ ] Shutdown behavior is tested.
-   [ ] Restart/re-registration behavior is tested.
-   [ ] Deregistration behavior is tested.
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

1.  Final mechanism for obtaining short-lived GitHub runner registration
    credentials.
2.  Whether runner configuration should be ephemeral or partially
    persistent.
3.  Long-term dedicated runner host/VM.
4.  Strategy for workflows that eventually require container-image
    builds.
5.  Exact artifact retention periods.
6.  Exact CI branch policy.
7.  Exact CD promotion policy.
8.  GitHub environment/protection configuration.
9.  Deployment release-directory and symlink implementation.
10. Runner monitoring/alerting requirements.

These decisions shall be resolved when required rather than prematurely
expanding privileges or infrastructure.

------------------------------------------------------------------------

## 26. Immediate Next Steps

Following approval of this specification:

1.  Place the approved `alignment.md` in the project root.
2.  Review the existing implementation against both governance
    documents.
3.  Inspect `compose.yaml` and `entrypoint.sh` specifically for
    lifecycle and secret-handling compliance.
4.  Resolve the registration-token acquisition design.
5.  Re-run local build/security validation.
6.  Authorize runner registration only after the preceding review
    passes.
7.  Register the runner to `scantoria/thisbyte-website`.
8.  Confirm GitHub reports the expected runner identity and labels.
9.  Execute a harmless CI validation workflow.
10. Stop and review results before introducing deployment credentials.

------------------------------------------------------------------------

## 27. Definition of the Current Boundary

The immediate objective is **not production deployment**.

The immediate objective is to establish a secure, reproducible,
repository-scoped GitHub Actions execution environment and prove that
GitHub can safely dispatch a harmless CI job to the ThisByte-owned
runner.

Only after that boundary is proven will the project proceed toward
deployment access to `station-01`.
