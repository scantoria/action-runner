# WP-0.1 — Baseline Compliance Review

## Project

ThisByte Action Runner

Local project root:

C:\Development\action-runner

## Objective

Perform a formal baseline review of the existing Action Runner implementation against the project's governing documents before any further implementation, GitHub registration, credential creation, or infrastructure changes occur.

This is a REVIEW-ONLY work package.

Do not modify implementation files during this work package.

---

## Governing Documents

Before reviewing any implementation, read these documents in full:

1. project-specification.md
2. alignment.md

Treat these documents as authoritative for project scope, architecture, security boundaries, responsibilities, and approval gates.

If implementation conflicts with a governing document, identify the conflict rather than silently correcting either document or implementation.

---

## Current Project State

An initial Docker-based GitHub Actions runner implementation already exists.

Expected project contents include:

- project-specification.md
- alignment.md
- README.md
- Dockerfile
- compose.yaml
- entrypoint.sh
- .env.example
- .gitignore
- .dockerignore
- .gitattributes

The Docker image has previously built successfully as:

thisbyte/actions-runner:2.328.0

Previous validation reported:

- docker compose config passed
- docker compose build passed
- runner executes as non-root user `runner`
- container is not privileged
- no inbound ports exposed
- Docker socket is not mounted
- no RUNNER_TOKEN currently present
- persistent storage limited to /actions-runner/_work

Do not assume those findings are correct. Verify them where practical.

---

## Mandatory Hold Point

The runner SHALL NOT be registered with GitHub during this work package.

Do NOT:

- obtain a GitHub runner registration token
- create a PAT
- create or populate .env with secrets
- run a permanently registered runner
- create SSH keys
- add deployment credentials
- modify station-01
- modify thisbyte-website
- create GitHub Actions workflows
- commit
- push
- modify project implementation files

If any review step would require one of those actions, stop that portion of the review and document the limitation.

---

## Review Tasks

### 1. Governance Review

Read:

- project-specification.md
- alignment.md

Identify:

- mandatory requirements
- security requirements
- architectural boundaries
- approval gates
- deferred decisions
- acceptance criteria
- role/responsibility expectations

Confirm that the current project structure supports the governance model.

---

### 2. Dockerfile Review

Review the Dockerfile for:

- pinned GitHub Actions runner version
- use of official GitHub runner distribution
- non-root execution
- unnecessary packages
- privilege escalation paths
- secret exposure
- build-time versus runtime responsibilities
- file ownership
- entrypoint permissions
- unnecessary SSH/deployment tooling
- image reproducibility

Identify any deviation from project-specification.md.

---

### 3. Compose Review

Review compose.yaml for:

- restart policy
- privileged mode
- Docker socket exposure
- host filesystem mounts
- persistent volumes
- inbound ports
- environment variables
- secret handling
- container identity
- unnecessary capabilities
- network exposure
- lifecycle implications

Pay particular attention to:

runner-work:/actions-runner/_work

Determine whether this persistence is justified and whether it creates any security or lifecycle concerns.

---

### 4. Entrypoint Lifecycle Review

Perform a detailed review of entrypoint.sh.

Trace the complete lifecycle:

container start
    ->
configuration validation
    ->
runner registration
    ->
runner execution
    ->
SIGTERM/SIGINT
    ->
runner shutdown
    ->
runner deregistration
    ->
container exit/restart

Evaluate:

- first startup
- normal shutdown
- Docker restart
- Windows reboot
- Docker Desktop restart
- unexpected container termination
- stale GitHub runner registration
- registration failure
- deregistration failure
- token expiration
- duplicate runner names
- persistent _work state
- partially configured runner state

Identify race conditions or lifecycle assumptions.

---

### 5. Registration Token Design Review

This is a design review only.

The project specification intentionally leaves the final short-lived GitHub runner registration-token mechanism unresolved.

Evaluate the current implementation's expectations for RUNNER_TOKEN.

Compare reasonable approaches for supplying a short-lived registration credential without:

- committing it
- baking it into the image
- treating it as permanent configuration
- printing it in logs
- introducing an unnecessarily powerful long-lived credential

Do NOT implement a solution.

Provide a recommended design and explain its security and operational tradeoffs.

Explicitly distinguish:

A. runner registration token
B. GitHub PAT or equivalent credential used to obtain a token
C. GitHub Actions runtime credentials
D. future station-01 deployment credentials

These must not be conflated.

---

### 6. Security Boundary Review

Verify that the implementation preserves these boundaries:

GitHub
    |
    v
HP Windows
    |
    v
Docker Desktop / WSL2
    |
    v
unprivileged runner container

The runner must NOT currently have:

- Docker host control
- privileged mode
- unrestricted sudo
- deployment SSH credentials
- station-01 administrative access
- unnecessary inbound services

Identify any mechanism that could unintentionally weaken these boundaries.

---

### 7. Configuration Review

Review:

- .env.example
- .gitignore
- .dockerignore
- .gitattributes
- README.md

Verify that:

- secrets are excluded
- documentation matches implementation
- Windows/Linux line-ending behavior is appropriate for entrypoint.sh
- Docker build context excludes unnecessary/sensitive files
- example configuration contains no credentials
- README does not instruct operators to violate project-specification.md

---

### 8. Validation

You may perform non-destructive local validation such as:

docker compose config
docker compose build
docker image inspect
docker compose config output inspection

You may run an unregistered container only if doing so does NOT trigger GitHub registration or require credentials.

Do not cross the registration hold point.

---

## Deliverable

Create:

WP-0.1-baseline-compliance-review.md

Place it in the project root.

The report shall contain:

1. Executive Summary
2. Governing Requirements Reviewed
3. Current Architecture Assessment
4. Dockerfile Findings
5. Compose Findings
6. Entrypoint/Lifecycle Findings
7. Registration Credential Analysis
8. Security Boundary Assessment
9. Configuration/Documentation Findings
10. Validation Performed
11. Deviations from project-specification.md
12. Risks
13. Recommended Remediation
14. Open Decisions Requiring Architect/Owner Approval
15. Readiness Assessment for GitHub Runner Registration

For each finding, classify it as:

- COMPLIANT
- OBSERVATION
- REQUIRES DECISION
- NON-COMPLIANT

For NON-COMPLIANT findings, cite the applicable section of project-specification.md.

Do not assign arbitrary numeric risk scores.

---

## Final Response

When complete, provide a concise handoff containing:

- files reviewed
- validation performed
- number of findings by classification
- any blocking findings
- decisions required from Architect/Owner
- whether the implementation is ready to proceed to the registration-design/remediation work package

Do not implement remediation.

Stop after delivering the review.
