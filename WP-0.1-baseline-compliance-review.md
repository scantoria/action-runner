# WP-0.1 Baseline Compliance Review

**Project:** ThisByte Action Runner  
**Role:** Implementation Tool performing review-only work package  
**Date:** 2026-09-26  
**Project root:** `C:\Development\action-runner`  
**Disposition:** Not ready for GitHub runner registration; ready for registration-design/remediation work package.

## 1. Executive Summary

This review examined the existing local Action Runner implementation against `project-specification.md` and `alignment.md` without registering the runner, generating credentials, modifying infrastructure, modifying the target `thisbyte-website` repository, committing, pushing, or implementing remediation.

The implementation is broadly aligned with the approved security boundary for a prototype: it uses the official GitHub Actions runner distribution pinned to `2.328.0`, runs as non-root user `runner`, does not install `sudo`, does not mount `/var/run/docker.sock`, does not expose inbound ports, and does not bake GitHub runner tokens or deployment credentials into the image.

The implementation should not proceed to GitHub runner registration yet. Blocking items remain around registration-token design approval, operational lifecycle behavior, and shutdown/deregistration testing. The highest-risk implementation issue is `entrypoint.sh` cleanup behavior: signal handling and `EXIT` cleanup can invoke deregistration twice, and partial registration failure or token expiration may leave stale GitHub runner registrations. These issues do not violate the current hold point because the runner is not registered, but they should be remediated before registration is authorized.

Finding counts:

- COMPLIANT: 15
- OBSERVATION: 8
- REQUIRES DECISION: 6
- NON-COMPLIANT: 3

## 2. Governing Requirements Reviewed

Reviewed in full:

- `project-specification.md`
- `alignment.md`

Mandatory requirements identified:

- The immediate objective is a secure, reproducible, repository-scoped GitHub Actions runner for `scantoria/thisbyte-website`.
- Runner registration, deployment credentials, `station-01` changes, workflow creation, and production deployment remain blocked until explicit approval.
- The runner must use the official GitHub Actions runner distribution and pin the version.
- The runner process must execute as a non-root Linux user.
- The container must not be privileged and must not mount `/var/run/docker.sock`.
- Inbound ports must not be exposed unless explicitly justified later.
- Credentials must not be committed, baked into images, or printed in logs.
- `.env` must be excluded from Git and must not be treated as permanent configuration for short-lived registration tokens.
- Persistent storage must be minimized; `/actions-runner/_work` is currently the justified persistent path.
- CI/CD separation must be preserved; deployment credentials are deferred.
- Registration-token lifecycle remains an open design decision.
- Review and implementation agents must stop and report conflicts rather than silently correcting governing documents or implementation.

Role/responsibility requirements identified:

- Owner retains Git commit, push, PR, merge, release, runner-registration authorization, deployment, and production migration responsibilities unless a scoped exception is explicitly granted.
- Implementation Tool may work only within `C:\Development\action-runner` and only within explicit task scope.
- This work package is review-only and does not authorize remediation.

## 3. Current Architecture Assessment

### Finding ARCH-1 - Current boundary matches intended prototype

Classification: COMPLIANT

Evidence:

- `project-specification.md` Sections 5 and 27 define the current boundary as GitHub Actions to HP Windows workstation to Docker Desktop/WSL2 to unprivileged runner container, with deployment to `station-01` deferred.
- Local files implement only the runner image, Compose service, entrypoint, and documentation.
- No deployment SSH keys, production credentials, or workflow files were found in the project root file set reviewed.

Assessment:

The current implementation remains within the initial runner-container boundary and does not implement deployment access.

### Finding ARCH-2 - Project structure supports governance model

Classification: COMPLIANT

Evidence:

Expected files are present at project root:

```text
project-specification.md
alignment.md
README.md
Dockerfile
compose.yaml
entrypoint.sh
.env.example
.gitignore
.dockerignore
.gitattributes
```

Assessment:

The project root contains the governing documents and implementation files expected by `project-specification.md` Section 20.

### Finding ARCH-3 - Worktree is not yet committed and includes untracked governing documents

Classification: OBSERVATION

Evidence:

`git status --short --branch` returned:

```text
## main...origin/main
 M .env.example
 M .gitattributes
 M .gitignore
 M Dockerfile
 M README.md
 M entrypoint.sh
?? .dockerignore
?? alignment.md
?? compose.yaml
?? project-specification.md
```

Assessment:

This review did not perform Git operations, per the work package hold point and `alignment.md`. Owner action will be required later to decide how these files are committed and reviewed.

## 4. Dockerfile Findings

### Finding DOCKER-1 - Runner version is pinned

Classification: COMPLIANT

Evidence:

`Dockerfile` contains:

```text
ARG RUNNER_VERSION=2.328.0
```

The runner download URL uses `v${RUNNER_VERSION}` and `actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz`.

Assessment:

This satisfies `project-specification.md` Section 7's requirement to pin the runner version. Current pinned version matches Section 7: `2.328.0`.

### Finding DOCKER-2 - Official GitHub runner distribution is used

Classification: COMPLIANT

Evidence:

`Dockerfile` downloads from:

```text
https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
```

Assessment:

The implementation uses the official `actions/runner` release distribution.

### Finding DOCKER-3 - Runner executes as non-root

Classification: COMPLIANT

Evidence:

`Dockerfile` creates `runner` and ends with:

```text
USER runner
ENTRYPOINT ["/entrypoint.sh"]
```

Runtime validation returned:

```text
uid=1001(runner) gid=1001(runner) groups=1001(runner)
```

Assessment:

This satisfies `project-specification.md` Sections 7 and 9.

### Finding DOCKER-4 - Sudo is absent

Classification: COMPLIANT

Evidence:

Runtime validation returned:

```text
sudo-absent
```

Assessment:

This satisfies `project-specification.md` Sections 7 and 9. The current Dockerfile does not install `sudo` or add the runner user to sudoers.

### Finding DOCKER-5 - Package set is minimal for current bootstrap needs

Classification: COMPLIANT

Evidence:

`Dockerfile` installs only:

```text
ca-certificates
curl
git
gzip
tar
```

Assessment:

The current package set is justified by runner download, archive extraction, GitHub Actions checkout/git use, and TLS. No SSH/deployment tooling is installed.

### Finding DOCKER-6 - Runner tarball is not checksum-verified

Classification: OBSERVATION

Evidence:

`Dockerfile` downloads the runner tarball with `curl -fsSL` and extracts it, but does not verify a published checksum before extraction.

Assessment:

`project-specification.md` requires the official runner distribution and reproducibility, but does not explicitly require checksum verification. Adding checksum verification would strengthen supply-chain evidence before registration.

### Finding DOCKER-7 - Base image is tag-pinned but not digest-pinned in source

Classification: OBSERVATION

Evidence:

`Dockerfile` uses:

```text
FROM ubuntu:24.04
```

Build output resolved this to:

```text
ubuntu:24.04@sha256:008173c23f95b170204355c12626cb5a965d779a7e1283b09e9cffbb1bf33ca3
```

Assessment:

`ubuntu:24.04` is an acceptable supported base image, but source-level digest pinning would improve byte-for-byte reproducibility.

## 5. Compose Findings

### Finding COMPOSE-1 - Compose configuration validates

Classification: COMPLIANT

Evidence:

`docker compose config` exited successfully and rendered:

```text
image: thisbyte/actions-runner:2.328.0
restart: unless-stopped
```

Assessment:

This satisfies the current local validation requirement in `project-specification.md` Section 23.

### Finding COMPOSE-2 - Restart policy is set

Classification: COMPLIANT

Evidence:

Rendered Compose config:

```text
restart: unless-stopped
```

Stopped container inspection:

```text
Restart={"Name":"unless-stopped","MaximumRetryCount":0}
```

Assessment:

This matches the requested container behavior and supports recovery after Docker/Desktop restart, subject to registration lifecycle behavior.

### Finding COMPOSE-3 - Container is not privileged and has no added capabilities

Classification: COMPLIANT

Evidence:

Stopped container inspection:

```text
Privileged=false
CapAdd=null
```

Assessment:

This satisfies `project-specification.md` Section 7.

### Finding COMPOSE-4 - Docker socket is not mounted

Classification: COMPLIANT

Evidence:

Rendered Compose config and container inspection showed only:

```text
action-runner_runner-work:/actions-runner/_work:rw
```

No `/var/run/docker.sock` bind was present. Runtime one-shot validation returned:

```text
docker-sock-absent
```

Assessment:

This satisfies `project-specification.md` Section 8.

### Finding COMPOSE-5 - No inbound ports are exposed

Classification: COMPLIANT

Evidence:

Image inspection returned:

```text
ExposedPorts=null
```

Stopped container inspection returned:

```text
PortBindings={}
```

Assessment:

This satisfies `project-specification.md` Section 7.

### Finding COMPOSE-6 - Persistent runner work volume is justified but sensitive

Classification: COMPLIANT

Evidence:

Rendered Compose config:

```text
runner-work:/actions-runner/_work
```

`project-specification.md` Section 12 identifies `/actions-runner/_work` as the currently justified persistent path.

Assessment:

The persistence is justified for job workspace/cache continuity. It creates an operational concern: the volume may contain checked-out private repository contents, build output, logs, or workflow artifacts and should be treated as sensitive local data.

### Finding COMPOSE-7 - Runner configuration state is not persisted

Classification: OBSERVATION

Evidence:

The only persisted path is `/actions-runner/_work`; runner config files under `/actions-runner` outside `_work` are not persisted by Compose.

Assessment:

This aligns with Section 12's caution against persisting runner configuration merely for convenience. It also means every container recreation will attempt fresh registration and later deregistration, which increases the importance of a robust short-lived token flow and stale-registration handling.

## 6. Entrypoint/Lifecycle Findings

### Finding LIFE-1 - Required configuration is validated before registration

Classification: COMPLIANT

Evidence:

`entrypoint.sh` requires:

```text
GITHUB_OWNER
GITHUB_REPOSITORY
RUNNER_TOKEN
```

It exits before `config.sh` when any required variable is empty.

Assessment:

This supports `project-specification.md` Section 11.3 item 1.

### Finding LIFE-2 - Registration occurs at container startup

Classification: COMPLIANT

Evidence:

`entrypoint.sh` runs:

```text
./config.sh --unattended --url "${repo_url}" --token "${RUNNER_TOKEN}" --name "${runner_name}" --labels "${runner_labels}" --work "${runner_workdir}" --replace
```

Assessment:

The runtime, not the image build, performs registration. This preserves the no-baked-token requirement.

### Finding LIFE-3 - Secrets are not intentionally printed by local script

Classification: COMPLIANT

Evidence:

`entrypoint.sh` echoes missing variable names, runner stop, and registration removal messages, but does not echo `RUNNER_TOKEN`.

Assessment:

The local script avoids intentional token logging. Output from GitHub's `config.sh` remains an external behavior to verify during registration testing.

### Finding LIFE-4 - Signal and EXIT traps can trigger duplicate cleanup

Classification: NON-COMPLIANT

Applicable specification sections:

- `project-specification.md` Section 7: "support graceful shutdown" and "Support clean runner deregistration where technically possible."
- `project-specification.md` Section 11.3: lifecycle shall handle SIGTERM/SIGINT, stop the runner process, and attempt GitHub deregistration where appropriate.

Evidence:

`entrypoint.sh` defines:

```text
trap handle_signal INT TERM
trap cleanup EXIT
```

`handle_signal` calls `cleanup` and then `exit 0`; the `EXIT` trap then calls `cleanup` again. Because `runner_configured` remains `true`, deregistration may be attempted twice.

Assessment:

The script attempts cleanup, but duplicate cleanup makes shutdown behavior non-idempotent and may produce ambiguous deregistration failures. This should be remediated before registration.

### Finding LIFE-5 - Partial registration failure may leave stale registration

Classification: NON-COMPLIANT

Applicable specification sections:

- `project-specification.md` Section 7: support clean runner deregistration where technically possible.
- `project-specification.md` Section 11.3: lifecycle shall attempt GitHub deregistration and avoid exposing registration credentials during lifecycle stages.

Evidence:

`runner_configured=true` is set only after `./config.sh` exits successfully. If `config.sh` creates a GitHub-side registration and then exits nonzero before local success, `cleanup` will not call `config.sh remove`.

Assessment:

This is a lifecycle edge case that cannot be fully proven without registration, but the current script structure does not account for partial configuration state. A remediation work package should make cleanup idempotent and define how stale GitHub registrations are detected and removed.

### Finding LIFE-6 - Token expiration may prevent deregistration on delayed shutdown

Classification: OBSERVATION

Evidence:

The same `RUNNER_TOKEN` supplied at startup is reused for:

```text
./config.sh remove --unattended --token "${RUNNER_TOKEN}"
```

Assessment:

GitHub runner registration tokens are short-lived. A long-running container may shut down after the startup token expires, causing deregistration to fail. This is not necessarily avoidable without an approved token acquisition/removal design, but it must be handled operationally.

### Finding LIFE-7 - `--replace` handles duplicate names but can mask stale state

Classification: OBSERVATION

Evidence:

`entrypoint.sh` passes:

```text
--replace
```

Assessment:

`--replace` helps startup recover from an existing runner name, but it may also hide stale-registration behavior during routine restarts. Registration testing should explicitly examine GitHub-side runner inventory before and after shutdown/restart.

### Finding LIFE-8 - Restart and host reboot behavior remains untested

Classification: REQUIRES DECISION

Evidence:

The review did not run a registered runner and therefore could not test Windows reboot, Docker Desktop restart, GitHub online/offline state, deregistration after token expiration, or job execution.

Assessment:

These tests require crossing the registration hold point and therefore need Owner/Architect approval and a dedicated registration/remediation work package.

## 7. Registration Credential Analysis

### Finding TOKEN-1 - Registration-token lifecycle is unresolved

Classification: NON-COMPLIANT

Applicable specification sections:

- `project-specification.md` Section 3.1: runner shall not be registered until credential-handling requirements are reviewed and approved.
- `project-specification.md` Section 11.2: final mechanism for acquiring and supplying the GitHub registration token remains a design decision to be approved before registration.
- `project-specification.md` Section 23: registration-token lifecycle must be approved before implementation is complete.

Evidence:

`.env.example` contains:

```text
RUNNER_TOKEN=
```

No approved token-acquisition design is present in the implementation or governing documents.

Assessment:

This is a blocking readiness issue for runner registration, not a reason to modify `.env.example` during this review.

### Finding TOKEN-2 - Recommended registration-token design

Classification: REQUIRES DECISION

Recommendation:

Use a manual, short-lived repository runner registration token generated by the Owner from GitHub for the first registration/remediation work package. Place it only in a local, gitignored `.env` immediately before `docker compose up -d`; remove or rotate it after use. Treat any failed deregistration as an Owner-visible operational event requiring GitHub UI/API cleanup.

Tradeoffs:

- Security: avoids introducing a long-lived PAT or GitHub App private key before the runner lifecycle is proven.
- Operations: requires manual Owner action whenever the runner must be freshly registered.
- Auditability: keeps the initial registration gate human-controlled.
- Limitation: deregistration after token expiration may fail unless a fresh token is obtained for cleanup or stale registrations are removed manually.

Automation alternatives requiring later review:

- Fine-grained PAT used outside the container to request registration/remove tokens. This reduces manual token copying but introduces a long-lived secret that must be stored and protected.
- GitHub App flow outside the runner container. This can be better scoped and auditable but is more complex and still introduces long-lived private key material.
- Owner-run helper script that prompts for or fetches short-lived tokens and invokes Compose. This can improve repeatability, but the credential source still requires approval.

### Finding TOKEN-3 - Credential classes must remain separated

Classification: COMPLIANT

Assessment:

The current implementation does not conflate credential classes. They should remain distinct:

- Runner registration token: short-lived credential used to add/remove the self-hosted runner.
- GitHub PAT or equivalent: optional future credential that could obtain registration tokens, but is not present and requires review.
- GitHub Actions runtime credentials: credentials GitHub provides to jobs, such as `GITHUB_TOKEN`; not configured in this repo.
- Future `station-01` deployment credentials: SSH identity and host verification material for deployment; out of scope and not present.

## 8. Security Boundary Assessment

### Finding SEC-1 - Docker host boundary is preserved

Classification: COMPLIANT

Evidence:

No Docker socket mount was present in Compose or stopped container inspection. Runtime validation returned:

```text
docker-sock-absent
```

Assessment:

Workflow jobs would not receive direct Docker daemon control under the current implementation.

### Finding SEC-2 - Runner-container boundary is limited but not a hard security sandbox

Classification: OBSERVATION

Assessment:

The implementation avoids privileged mode, sudo, Docker socket, and inbound ports. However, GitHub Actions job code will still execute inside the runner container and can read/write `_work`, access outbound network according to Docker Desktop defaults, and consume any future secrets provided to jobs. This is consistent with `project-specification.md` Section 5.2's warning that the runner should not be treated as inherently trusted.

### Finding SEC-3 - No deployment boundary is crossed

Classification: COMPLIANT

Evidence:

No SSH keys, deployment credentials, or `station-01` configuration are present in the reviewed files.

Assessment:

The implementation preserves CI/CD separation and does not grant deployment access.

### Finding SEC-4 - Default outbound network remains available

Classification: OBSERVATION

Evidence:

Rendered Compose config includes:

```text
networks:
  default:
    name: action-runner_default
```

Assessment:

This creates the normal Docker Compose network. It does not expose inbound ports, but outbound network behavior remains governed by Docker Desktop defaults. Future LAN restrictions may require explicit network controls if workflows should be constrained.

## 9. Configuration/Documentation Findings

### Finding CFG-1 - `.env.example` contains no secrets

Classification: COMPLIANT

Evidence:

`.env.example` contains expected non-secret defaults and an empty token placeholder:

```text
GITHUB_OWNER=scantoria
GITHUB_REPOSITORY=thisbyte-website
RUNNER_NAME=thisbyte-hp-runner
RUNNER_LABELS=self-hosted,linux,x64,thisbyte
RUNNER_WORKDIR=_work
RUNNER_TOKEN=
```

Assessment:

This satisfies `project-specification.md` Section 11.1.

### Finding CFG-2 - `.env` and common secret files are gitignored and dockerignored

Classification: COMPLIANT

Evidence:

`.gitignore` excludes:

```text
.env
.env.*
!.env.example
*.key
*.pem
credentials/
_work/
```

`.dockerignore` excludes:

```text
.git
.env
.env.*
!.env.example
credentials/
_work/
*.key
*.pem
```

Assessment:

This protects common local credential files from Git and Docker build context.

### Finding CFG-3 - Line-ending configuration protects shell entrypoint

Classification: COMPLIANT

Evidence:

`.gitattributes` contains:

```text
*.sh text eol=lf
Dockerfile text eol=lf
compose.yaml text eol=lf
```

Runtime validation showed:

```text
-rwxr-xr-x 1 runner runner 1309 Sep 26 01:47 /entrypoint.sh
```

Assessment:

This is appropriate for Windows editing and Linux container execution.

### Finding CFG-4 - README aligns with hold point but is not complete operational documentation

Classification: OBSERVATION

Evidence:

README instructs:

```text
docker compose config
docker compose build
docker image inspect thisbyte/actions-runner:2.328.0
```

It also says registration should happen "After approval" by creating `.env` and running `docker compose up -d`.

Assessment:

README does not instruct operators to violate the hold point. It does not yet document full shutdown, restart, stale-runner cleanup, recovery, or token-expiration procedures required before operational acceptance.

### Finding CFG-5 - Operational instructions are incomplete for final acceptance

Classification: REQUIRES DECISION

Evidence:

`project-specification.md` Section 23 includes "Operational instructions are documented" as an initial acceptance criterion. README currently covers build, validation, and high-level future registration, but not full lifecycle operations.

Assessment:

Operational documentation should be expanded after the token/lifecycle design is approved and tested.

## 10. Validation Performed

All validation stayed below the registration hold point. No GitHub token was obtained. No `.env` was created. No registered runner was started.

### Command: `docker compose config`

Result: PASS

Key output:

```text
image: thisbyte/actions-runner:2.328.0
restart: unless-stopped
GITHUB_OWNER: scantoria
GITHUB_REPOSITORY: thisbyte-website
RUNNER_LABELS: self-hosted,linux,x64,thisbyte
RUNNER_NAME: thisbyte-hp-runner
RUNNER_WORKDIR: _work
volumes:
  - type: volume
    source: runner-work
    target: /actions-runner/_work
```

### Command: `docker compose build`

Result: PASS

Key output:

```text
Image thisbyte/actions-runner:2.328.0 Built
```

### Command: `docker image inspect thisbyte/actions-runner:2.328.0`

Result: PASS

Key output:

```text
User=runner
Entrypoint=["/entrypoint.sh"]
ExposedPorts=null
Volumes=null
Env=["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin","DEBIAN_FRONTEND=noninteractive"]
```

### Command: one-shot unregistered `docker run` with entrypoint overridden

Result: PASS

Key output:

```text
uid=1001(runner) gid=1001(runner) groups=1001(runner)
sudo-absent
docker-sock-absent
drwxr-xr-x 1 runner runner 4096 Sep 26 01:49 /actions-runner
-rwxr-xr-x 1 runner runner 1309 Sep 26 01:47 /entrypoint.sh
```

### Command: `docker compose create --no-build runner`

Result: PASS

Key output:

```text
Container action-runner-runner-1 Created
```

This did not start the runner and did not perform registration.

### Command: stopped container `docker inspect`

Result: PASS

Key output:

```text
User=runner
Entrypoint=["/entrypoint.sh"]
Restart={"Name":"unless-stopped","MaximumRetryCount":0}
Privileged=false
CapAdd=null
PortBindings={}
Binds=["action-runner_runner-work:/actions-runner/_work:rw"]
Env=["GITHUB_REPOSITORY=thisbyte-website","RUNNER_NAME=thisbyte-hp-runner","RUNNER_LABELS=self-hosted,linux,x64,thisbyte","RUNNER_WORKDIR=_work","GITHUB_OWNER=scantoria",...]
```

### Command: `docker compose down -v`

Result: PASS

Key output:

```text
Container action-runner-runner-1 Removed
Volume action-runner_runner-work Removed
Network action-runner_default Removed
```

The stopped validation container, empty validation volume, and validation network were removed.

## 11. Deviations from project-specification.md

### Deviation DEV-1 - Registration-token lifecycle is not approved

Classification: NON-COMPLIANT

Applicable specification sections:

- Section 3.1
- Section 11.2
- Section 23

Status:

This is an intentional current hold point and blocks runner registration.

### Deviation DEV-2 - Entrypoint cleanup is not cleanly idempotent

Classification: NON-COMPLIANT

Applicable specification sections:

- Section 7
- Section 11.3

Status:

Signal and `EXIT` traps can invoke cleanup twice, including duplicate deregistration attempts.

### Deviation DEV-3 - Partial registration and stale-runner handling are not resolved

Classification: NON-COMPLIANT

Applicable specification sections:

- Section 7
- Section 11.3
- Section 19

Status:

Current script structure does not handle all partial-registration, expired-token deregistration, stale-registration, or recovery cases.

## 12. Risks

### Risk RISK-1 - Stale GitHub runner registrations

Classification: OBSERVATION

If registration succeeds but deregistration fails due to token expiration, signal race, Docker Desktop termination, Windows reboot, or partial config failure, GitHub may retain stale offline runner records.

### Risk RISK-2 - Sensitive data in `_work`

Classification: OBSERVATION

The persistent `_work` volume can contain private repository contents, build outputs, logs, or artifacts. It is justified but should be protected and periodically cleaned according to an approved procedure.

### Risk RISK-3 - Long-lived credential temptation

Classification: REQUIRES DECISION

Automating token retrieval with a PAT or equivalent would improve operations but introduces a higher-value long-lived credential. That design requires explicit approval before implementation.

### Risk RISK-4 - Future workflows may need Docker builds

Classification: REQUIRES DECISION

The current runner intentionally lacks Docker host control. If future CI requires container-image builds, the project must choose an alternative design rather than mounting `/var/run/docker.sock`.

## 13. Recommended Remediation

No remediation was implemented during this review.

Recommended next remediation work package:

1. Make `entrypoint.sh` cleanup idempotent so signal handling and `EXIT` cannot deregister twice.
2. Define behavior for partial `config.sh` success/failure.
3. Define stale-runner cleanup procedure for GitHub UI/API.
4. Decide whether deregistration uses the startup token, a fresh removal token, or a separate Owner-run cleanup step.
5. Add operator documentation for startup, shutdown, restart, Windows reboot/Docker Desktop restart, failed registration, failed deregistration, and `_work` volume handling.
6. Consider checksum verification for the runner tarball.
7. Consider source-level digest pinning for the base image.
8. After remediation, run a registration-specific test plan under explicit Owner approval.

## 14. Open Decisions Requiring Architect/Owner Approval

1. Final short-lived runner registration-token mechanism.
2. Whether an Owner-manual token flow is acceptable for first registration.
3. Whether any long-lived credential, GitHub App, or PAT will ever be introduced to obtain short-lived runner tokens.
4. Whether runner configuration should remain ephemeral or be partially persisted.
5. How stale GitHub runner registrations are identified and removed.
6. Whether base image digest pinning and runner tarball checksum verification are required before registration.
7. How future container-image build workflows will be supported without Docker socket access.
8. What operational procedure governs cleaning or retaining the persistent `_work` volume.

## 15. Readiness Assessment for GitHub Runner Registration

Current readiness: NOT READY for GitHub runner registration.

Ready to proceed to: registration-design/remediation work package.

Blocking findings before registration:

- `TOKEN-1`: Registration-token lifecycle is unresolved and unapproved.
- `LIFE-4`: Cleanup can run twice during signal-triggered shutdown.
- `LIFE-5`: Partial registration failure may leave stale GitHub runner registration.
- `LIFE-8`: Registered lifecycle behavior remains untested by design.

Non-blocking positive readiness evidence:

- Compose config validates.
- Image builds.
- Image runs as non-root `runner`.
- `sudo` is absent.
- Container is not privileged.
- Docker socket is not mounted.
- No inbound ports are exposed.
- No credentials were found in image environment metadata.
- No deployment credentials are present.

The next authorized work should address registration-token design and lifecycle remediation before any runner registration attempt.
