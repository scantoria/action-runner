# WP-0.3 — Runner Lifecycle Implementation Handoff

**Role Authority:** Implementation Tool
**Date:** 2026-10-12
**Project:** ThisByte Action Runner (AR)
**Branch:** codex/wp-0.3-lifecycle
**Disposition:** Implementation and permitted local validation complete; independent review pending. No self-approval.
**Governing scope:** Approved WP-0.2 and authorized WP-0.3 under _Context/Work-Packages/.

## Owner authorization / scoped exception

The Owner stated: "This is your authorization to proceed with WP-03 implementation." This directly followed the proposed authorization to create codex/wp-0.3-lifecycle and the scoped exception to alignment.md Section 6's missing Scope/Phases/Sprints reconciliation timestamp, using approved WP-0.2 and WP-0.3 as scope. The Implementation Tool proceeded on that basis and created the dedicated branch. No broader exception, standing Git authorization, or governance amendment is claimed. The earlier specification-review pause was lifted by the Owner's implementation authorization.

## Completed files

- Modified entrypoint.sh: state-aware run/bootstrap/decommission operations, protected mount and file checks, exclusive identity lock, failure/interruption markers, no shutdown removal, no silent replacement, disableupdate, and direct listener execution.
- Created validate-state.py: strict single-object JSON parsing with duplicate/non-finite rejection, identity/persistence/update checks, OAuth state checks, RSA arithmetic consistency checks, and administrative-token snapshot rejection; no network access or secret-content diagnostics.
- Modified Dockerfile: protected runner-state directory, validator inclusion, Python standard library and util-linux for validation/locking/process groups, and libicu74 to repair the baseline runtime dependency. Version remains 2.328.0; user remains runner.
- Modified compose.yaml: runner-state volume, disposable _work, explicit non-secret environment interpolation (removed whole-file env injection), init=true, 60-second stop grace period, and restart=no.
- Modified .env.example: removed the token field; non-secret configuration only.
- Modified .gitignore and .dockerignore: exclude sensitive local state; additionally exclude artifact/test directories from build context.
- Modified README.md: persistence, ordinary lifecycle, recovery, exact future administrative commands, token/environment metadata handling, validation commands, and authorization gates.
- Created tests/lifecycle.sh, tests/container-listener.sh, and tests/validate-containers.ps1: synthetic, network-isolated validation; no real configuration/removal or authentication.
- Created Docs/WP-0.3-Runner-Lifecycle-Operations.md and this _Context/Executions/WP-0.3-handoff-20261012.md.

alignment.md and project-specification.md were not changed. Their SHA256 values remain:

```text
alignment.md: A782DBBD21833487573E40A2A8161AF2579E9834144F4AE0C72203D100F21E4D
project-specification.md: 3890C449A5A97F0A82482F99000FB239544A7B3280C73727FBA31F67A512E59B
```

Pre-existing unrelated deletions of WP-0.1-baseline-compliance-review.md and three session artifacts, their untracked execution/review counterparts, the untracked session records, and untracked WP-0.2/WP-0.3 copies were preserved. No clean/reset, artifact relocation, old-volume migration, or unrelated correction was performed.

## Acceptance-criterion accounting

| ID | Disposition | Traceable evidence |
| --- | --- | --- |
| AC-01 | PASS local; DEFERRED real registered behavior | Fixture TERM/INT and Docker stop/SIGINT reach the synthetic listener, return 0, leave state hashes intact, and never call configuration/removal. Source run path execs listener without removal traps. |
| AC-02 | PASS local; DEFERRED real reconnect | Valid synthetic persisted identity starts listener without token/configuration; recreated containers reuse the same hashes. Real version command reads linked synthetic state. Authentication/reconnection is not proven. |
| AC-03 | PASS | Both actual image and fixture startup with no state exit 1 with explicit bootstrap diagnostic; configuration is not called. |
| AC-04 | PASS | Actual image and fixture bootstrap without token exit 1 before config.sh. |
| AC-05 | PASS local; DEFERRED credentialed bootstrap | No token field in .env.example, no env_file injection. Synthetic input is discarded before stub listener and absent from state. Ordinary run rejects it. Docker one-off environment metadata limitations are documented. |
| AC-06 | PASS local; DEFERRED real generated state | Required /runner-state mount, 0700 directory/0600 files, named-volume persistence and links. Synthetic identity hashes survive multiple container recreations. Actual configuration output format after registration remains untested. |
| AC-07 | PASS | Compose has no _work volume. Container tests prove previous workspace marker absent after recreation while identity hashes remain unchanged. |
| AC-08 | PASS local | Tests cover missing pieces, malformed/duplicate/multiple-object JSON, identity mismatch, update-enabled state, OAuth/RSA defects and inconsistent RSA arithmetic, insecure permissions, foreign symlinks, unknown files, bootstrap failure and interruption, and recovery markers. State is preserved. |
| AC-09 | PASS static/local; DEFERRED GitHub records | No automatic --replace exists; valid identity rejects bootstrap, partial state never configures. No stale-record operation was performed against GitHub. |
| AC-10 | PASS static; DEFERRED execution | Removal exists only in explicit decommission with matching confirmation, valid state, exclusive lock and separate removal token. Remote removal success precedes local state deletion. Decommission was not invoked, including in mocks. |
| AC-11 | PASS static/local; DEFERRED actual registration | Stub bootstrap records --disableupdate and no --replace; local validator rejects disableUpdate=false. Image pins 2.328.0. |
| AC-12 | PASS | restart=no removes automatic container retry. Failed/interrupted bootstrap leaves a durable marker which prevents subsequent attempts; run does not configure. |
| AC-13 | PASS local | Runtime inspect: runner, privileged=false, no ports/socket; image has no identity/credentials or sudo capability; explicit Compose fields contain no tokens. Only synthetic test inputs were used, tests are excluded from image context. |
| AC-14 | PASS | docker compose config succeeds; final docker compose build --quiet exits 0. Native libraries resolve and real listener reports 2.328.0. |
| AC-15 | PASS | Registered tests explicitly listed DEFERRED in this handoff, README.md and operations note. |
| AC-16 | PASS | This saved handoff accounts individually for AC-01 through AC-15, actual results, files, limitations, failures and future protocol. |

These are implementation/local evidence dispositions, not an independent review approval or a claim that registered tests passed.

## Commands and actual results

Preflight read-only Git status/branch inspection, project file reads, and offline inspection of the existing runner scripts/help were performed. The initial default-sandbox Git branch/Docker calls encountered permissions; authorized elevated retries succeeded. git switch -c codex/wp-0.3-lifecycle returned "Switched to a new branch 'codex/wp-0.3-lifecycle'".

Final docker compose config --format json exited 0. Resolved settings included only GITHUB_OWNER, GITHUB_REPOSITORY, RUNNER_NAME, RUNNER_LABELS, RUNNER_WORKDIR=_work; init=true, restart=no, stop_grace_period=1m0s and a sole runner-state volume at /runner-state. No env_file, ports, privileged option, or socket mount is specified.

Final docker compose build --quiet, exit 0:

```text
Image thisbyte/actions-runner:2.328.0 Building 
 Image thisbyte/actions-runner:2.328.0 Built
```

Final .\tests\validate-containers.ps1, exit 0 (the script runs the full fixture suite plus Docker stop/recreation/security checks):

```text
2.328.0
PASS: Non-root execution, shell syntax, real pinned listener loads with ICU
PASS: AC-03: absent state fails closed without configuration/listener
PASS: AC-04: explicit bootstrap without token fails closed
PASS: AC-08: partial state preserved and cannot trigger bootstrap
PASS: AC-08: malformed runner JSON fails closed
PASS: AC-08: duplicate JSON properties and multiple objects fail closed
PASS: AC-08/11: automatic-update state rejected
PASS: AC-08: repository mismatch fails closed
PASS: AC-08: incomplete OAuth/RSA state fails closed
PASS: AC-08: syntactically valid but inconsistent RSA state fails closed
PASS: AC-08/13: insecure permissions and unexpected state rejected
PASS: AC-08: state symlinks rejected without deletion
PASS: AC-02/06: valid synthetic persisted identity starts listener without token or config
PASS: AC-05/09: existing identity never bootstraps or replaces itself
PASS: AC-05/06/11: stubbed bootstrap writes through state links, disables update, and discards synthetic input
PASS: AC-08/12: failed bootstrap diagnostics retained; durable marker prevents retry
PASS: AC-08/12: interrupted bootstrap preserves partial state and requires recovery
PASS: AC-01/06: TERM and INT reach listener without config/removal or state changes; concurrent identity use blocked
2.328.0
PASS: Pinned real listener version command reads linked synthetic state without network access
PASS: Local fixture suite complete; real registration, real decommission, and GitHub behavior NOT EXECUTED.
PASS: Runtime inspect: User=runner, privileged=false, ports=none, Docker socket=absent, network=none.
PASS: Previous container workspace is absent after recreation.
Starting listener using persisted identity; normal shutdown never deregisters.
PASS: Synthetic listener started using retained state without a token.
PASS: Synthetic listener received TERM; no configuration or removal.
PASS: Docker TERM exit=0; fixture identity hashes unchanged across recreation; workspace disposable.
PASS: Runtime inspect: User=runner, privileged=false, ports=none, Docker socket=absent, network=none.
PASS: Previous container workspace is absent after recreation.
Starting listener using persisted identity; normal shutdown never deregisters.
PASS: Synthetic listener started using retained state without a token.
PASS: Synthetic listener received INT; no configuration or removal.
PASS: Docker INT exit=0; fixture identity hashes unchanged across recreation; workspace disposable.
Cleanup: only this run's isolated fixture containers and volume removed.
```

Actual image startup commands (no mocks), each with --rm --network none and an isolated anonymous volume at /runner-state: default run with GITHUB_OWNER=scantoria and GITHUB_REPOSITORY=thisbyte-website; the same command plus bootstrap; and an entrypoint bash command that writes '{}' as partial .runner before invoking /entrypoint.sh. Each produced the expected exit 1:

```text
missing-state: exit=1
Runner lifecycle stopped: No registration state. Explicit bootstrap is required after separate Owner authorization.
Preserve /runner-state. Review local state and GitHub records before administrative recovery.
bootstrap-without-token: exit=1
Runner lifecycle stopped: Explicit bootstrap requires a runtime short-lived registration token.
Preserve /runner-state. Review local state and GitHub records before administrative recovery.
real-image-partial-state: exit=1
Runner lifecycle stopped: Partial configuration: .credentials is missing.
Preserve /runner-state. Review local state and GitHub records before administrative recovery.
```

Final docker image inspect JSON plus offline non-root checks of identity-file absence, sudo absence and ldd resolution, exit 0:

```text
ImageId=sha256:10d5ea1246c7213b5ad62501c7f547ecc1d47c27b80d24a181bf46020262b268
User=runner
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin, DEBIAN_FRONTEND=noninteractive
ExposedPorts=absent
PASS: Image contains no configured identity or sudo capability; native runtime libraries resolve.
```

git diff --check and git diff --exit-code -- alignment.md project-specification.md exited 0 with no output. Source credential-pattern scanning found only explicit synthetic-not-a-token assignments in tests/lifecycle.sh, not real PAT/token/private-key material. Fixture RSA data is publicly derivable test input generated only inside disposable network-isolated containers; no real registration token, PAT, or deployment credential was obtained/generated/used.

git diff --stat for the seven modified tracked implementation files:

```text
 .dockerignore |   6 ++
 .env.example  |   2 +-
 .gitignore    |   3 +
 Dockerfile    |   8 ++-
 README.md     | 146 +++++++++++++++++++++++++++++++++++++++++++----
 compose.yaml  |  13 ++---
 entrypoint.sh | 180 +++++++++++++++++++++++++++++++++++++++++++++-------------
 7 files changed, 297 insertions(+), 61 deletions(-)
```

The stat excludes newly created/untracked validator, tests, operations note, and this handoff. It excludes unrelated pre-existing deletions.

## Failures encountered and resolved

- Baseline real runner failed to load due to absent ICU. Explicit libicu74 installation fixed this; version/native-library checks pass.
- Initial persistence approach used dangling state links, which the pinned runner treated as existing files. Offline version checks exposed this. Revised bootstrap stages ordinary files, moves them on handled completion/failure, and links only existing state. Real version with linked synthetic state now succeeds.
- python3-minimal did not contain the required JSON standard library. Replaced it with python3; final validator/fixtures pass.
- Test harness initially treated an empty Docker PortBindings object as truthy, used a Go template that failed for absent ExposedPorts, and a broad PAT regex matched PATH. Corrected checks use optional JSON fields and exact credential-variable names. Final runtime/image checks pass.
- Patch application context/format mismatches were resolved during editing; final source and diff checks pass.
- The upstream dependency installer emits failed probes for obsolete libssl/libicu package candidates on Ubuntu 24.04 but finishes successfully. Required actual native libraries and ICU are present; final build and listener version checks pass.

No unresolved local validation failure remains. No automatic-approval rejection occurred.

## Remaining criteria / assumptions / review conditions

Independent review remains pending. Real GitHub registration/configuration, Online/Offline transitions, listener authentication, token-free reconnect, Docker Desktop/WSL2/Windows restart, abnormal host termination, stale/duplicate record handling against GitHub, controlled decommission/re-registration, and harmless GitHub Actions CI execution are DEFERRED. They require separate Owner registration/credential authorization. No registered-runner acceptance is asserted.

The actual generated credential schema and first registered listener behavior must be confirmed at the authorized registration gate. Local schema/RSA arithmetic validation is not proof of GitHub identity/credential acceptance. Normal direct-listener signal handling was exercised using mocks; real job-draining behavior remains deferred.

Forced termination during bootstrap may leave partial files in the interrupted container layer before the completion/failure move. The durable marker and protected upstream output survive in the volume; preserve the interrupted container for recovery. No automatic registration retry or destructive repair occurs. The ordinary completed-state persistence model is unchanged.

Sensitive upstream configuration output is kept in protected administrative diagnostic files instead of container logs. Treat those files and _diag as sensitive, retain failed containers securely, and do not publish their contents. Docker admins can inspect runtime input in one-off creation environment until the container is removed; successful one-off containers should be removed and operator environment cleared as documented.

Operator/API token acquisition remains unresolved as intended; none is invented here. Automatic availability after host restart is intentionally not provided by restart=no. Any later restart policy change requires review. No other material architecture conflict was discovered.

Docs/ and _Context/ mirroring is still due at the once-per-session Google Drive sync before end-of-day context. No end-of-day context or Drive sync was performed. Owner commit/push/merge/release steps remain pending after review. These are not claimed complete.

## Exact manual verification / deployment protocol

No production deployment, migration, release or credentialed registration is part of this work package. The Owner/reviewer can rerun permitted checks:

```powershell
Set-Location -LiteralPath 'C:\Development\action-runner'
docker compose config
docker compose build
.\tests\validate-containers.ps1
git diff --check
git diff -- Dockerfile compose.yaml entrypoint.sh README.md .env.example .gitignore .dockerignore
git status --short
```

Review the new validate-state.py, tests/*, operations note and this handoff separately because ordinary git diff does not display untracked files. Preserve unrelated pre-existing changes when preparing any Owner-controlled commit. Exact future, separately authorized administrative bootstrap/decommission and ordinary start/stop commands are documented in README.md; do not execute them at this gate.

## Git / credential / production confirmation

Implementation Tool created only the authorized dedicated branch. No commit, push, pull request, merge, release, production deployment, database migration, GitHub runner registration/deregistration/replacement, real token/PAT acquisition or use, deployment credential creation, workflow modification, thisbyte-website modification, or station-01 access/modification occurred.

Only disposable synthetic test containers/volumes created by the validation runs were removed. Existing Docker volumes and project artifacts were untouched.

STOP: WP-0.3 implementation and allowed local validation are handed off for independent review; do not advance to registration or deployment.
