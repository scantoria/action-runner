# WP-0.3 Round 3 Implementation Handoff

Date: 2026-10-13  
Role Authority: Implementation Tool  
Project: ThisByte Action Runner (AR)  
Area: C:\Development\action-runner  
Branch: codex/wp-0.3-lifecycle  
Authority: Owner's Round 3 prompt; governing independent REVIEW-action-runner-005.md.

## Governing inputs and scope

Read alignment.md, project-specification.md, WP-0.2, WP-0.3, Round 2 prompt, both prior WP-0.3 handoffs, Reviews 004/005 and operations version 2 before implementation. Continue the same scoped WP-0.3 authorization/previous recorded governance exception; no new architecture or scope exception is introduced. Implement F-2 and B-1 only, preserving accepted F-1/A-1/A-2. B-2 is a registration-gate test. A-3 through A-7 remain unchanged; no new regression evidence was found.

## Exact F-2 design and rationale

STATIC: Each listener session generates secrets.token_hex(32), a local transaction nonce (not a GitHub token). Exact JSON fields are version=1, nonce and current container hostname. Record /actions-runner/.listener-session in the container layer first, then /runner-state/.listener-active durably, before starting the listener. Exclusive temporary creation, mode 0600, file fsync, atomic replacement and directory fsync protect publication. The lifetime FD9 flock remains held.

STATIC: Continuity validation uses lstat: both records must be regular runner-owned 0600 files sized 1–2048 bytes. Strict duplicate-rejecting JSON, exact keys, integer version 1, 64 lowercase hex nonce, equality of both records and current hostname are required. Explicit checks do not depend on Python asserts. The nonce binds a retained layer/session to the durable marker; it is not a security boundary against a container administrator fabricating both records.

On token-free run with an active marker, validate continuity before any listener or configuration. With proven retained layer, reuse the F-1 finalizer under lock: inspect supported paths/permissions, validate effective complete state, compare every pending copy with its validated source, stage/sync/promote regular files, atomically relink through .relink paths, revalidate persisted state, sync, then clear durable marker and local evidence. Unchanged valid volume links require zero promotions. Listener startup then publishes a new session. No registration, remove, replacement or destructive stale-record recovery is called.

Recreated containers lack original local evidence and fail closed. Missing/malformed/mismatched/insecure/legacy empty evidence, unsupported state, error markers, unknown metadata, partial/different staging, or interrupted record publication cannot force recovery. Preserve container/volume for A-1. A complete matching pending copy can safely resume after a second kill; mismatched pending remains intact with active/error markers. TERM/INT is ignored during finalization to protect completion; SIGKILL remains unavoidable and is tested. Atomic relinking removes the prior missing-path gap. Auxiliary exact redundant staging can be removed only after equality proof; invalid identity is never promoted or erased.

## B-1 supervision correction

STATIC + SYNTHETIC PASS: Removed the stale wait_interrupted flag. Bash wait -n -p completed_pid identifies actual child completion; interrupted wait retries. If the child already exited before wait-n (127 without completion PID), a single cached explicit wait retrieves its actual result and exits the loop. This avoids both the flagged early-signal race and a reset-window race.

Two fixture-only temporary source copies inject TERM (1) before the loop and (2) immediately before primary wait. Mock listener exits 17 in both cases and supervisor returns 17, not 127. Production code has no test injection hook. Ordinary exit 17 and TERM/INT regression cases pass. An isolated pinned-Bash experiment confirmed wait-n on an already-exited child returns 127/unset PID and explicit cached wait returns 17.

## B-2 DEFERRED gate

B2-RUNNER-2.328.0-TERM-DRAIN-60S-ESCALATION — DEFERRED: after separate registration authorization, verify actual runner 2.328.0 TERM/INT handling, active-job drain, exit status, 60-second grace sufficiency, Docker escalation and subsequent retained-container recovery. Synthetic listeners cannot resolve this gate. Real GitHub migration with stop/start and recreation remains separately DEFERRED.

## Files changed

Hash comparison against the captured Round 3 baseline proves exactly these existing files changed: entrypoint.sh, README.md, tests/lifecycle.sh, tests/container-listener.sh, tests/validate-containers.ps1. New: tests/validate-recovery.ps1, Docs/WP-0.3-Runner-Lifecycle-Operations-3.md and this handoff. validate-state.py, Dockerfile, Compose, governance and all previous immutable artifacts remain unchanged. Pre-existing unrelated modifications/deletions/untracked artifacts are preserved.

Operations version 3 carries the full A-1 inspect/preserve/condition/authorization/revalidate/resume procedure, with proven retained-container versus unknown/recreated-layer decisions. No manual recovery, backup, remote inspection or marker-clearance procedure was executed.

## F-2 Tests A–E: one-to-one evidence

All are SYNTHETIC PASS using real isolated Docker actions and synthetic identities/listeners; network=none, no real credentials. Each fixture checks no configuration invocation.

| Test | Actual result and assertions |
| --- | --- |
| A | Docker SIGKILL exit 137, unchanged identity, durable marker retained; same-container restart reaches second listener token-free, completes with zero promotions; graceful close retains base hashes. |
| B | Both valid migration files exist only in retained layer before SIGKILL; restart finalizes generation 1 into volume at 0600/runner UID before listener, no second migration/bootstrap. |
| C | New container using retained volume refuses with exit 1 before listener; original marker/base hashes preserved; no configuration or administrative markers. |
| D | Eight defects: missing local evidence, malformed local JSON, nonce mismatch, wrong container in both, duplicate durable keys, local 0644, local symlink, legacy empty durable marker. Each refuses before a new listener/config and preserves evidence/base identity. |
| E complete | Fixture-only sync wrapper blocks after a complete synced pending credentials copy. Second SIGKILL leaves marker; next same-container start resumes equality-verified staging, reaches third listener, persists generation 1 and clears pending only after completion. |
| E partial | Corrupt only synthetic staged copy to {}; second kill and next restart refuse, preserve {} pending and active/error markers, no invalid promotion or new listener. |

## Accepted baseline preservation

F-1 SYNTHETIC PASS: runtime-created/atomically replaced credential/settings migrations persist across graceful termination, same-container stop/start, recreation and generation 1–4, runner ownership/0600, base hashes unchanged. Invalid runtime/persisted migration and unsupported JIT/service state remain refused. _work survives same-layer stop/start and disappears on recreation.
A-1 STATIC PASS: operations version 3 preserves actionable authorized recovery with exact backup/inspection/decision examples and adds continuity distinction.
A-2 SYNTHETIC PASS: seven negative decommission guards (confirmation, missing removal token, conflicting tokens, removal token on run, absent/partial/malformed state) refuse before config/remove stub. No real or positive decommission executed.

## AC-01 through AC-16

| ID | Round 3 disposition | Evidence |
| --- | --- | --- |
| AC-01 | SYNTHETIC + STATIC PASS; registered DEFERRED | TERM/INT forwarding, actual Docker stop/SIGINT and zero exits; no removal, valid state persisted; listener status 17 propagated, including both deterministic B-1 timing cases. |
| AC-02 | SYNTHETIC PASS; registered DEFERRED | Token-free base and migrated identity startup; same-container restart and recreation; config stub absent. |
| AC-03 | LOCAL + SYNTHETIC PASS | Actual image missing-state exit 1 plus unchanged regression fixture; no registration. |
| AC-04 | LOCAL + SYNTHETIC PASS | Actual image explicit bootstrap without token exit 1 plus fixture. |
| AC-05 | STATIC + SYNTHETIC PASS; credentialed DEFERRED | Existing non-secret Compose/example unchanged; bootstrap synthetic input unset/absent from state; ordinary run rejects token. |
| AC-06 | STATIC + SYNTHETIC PASS; registered DEFERRED | Required protected named volume unchanged; runtime migration now persisted with validated state, atomic per-file staging, active marker, lifetime lock and proven retained-container recovery (F-2 Tests A–E). |
| AC-07 | STATIC + SYNTHETIC PASS | Workspace remains outside state volume; stop/start versus recreation behavior tested. |
| AC-08 | LOCAL/SYNTHETIC PASS; remote DEFERRED | Full original malformed/partial/permission/RSA/marker regressions; new migrated-state rejection; A-1 actionable procedure. |
| AC-09 | STATIC + SYNTHETIC PASS; GitHub records DEFERRED | No replace, automatic registration or stale-record operations; valid state rejects bootstrap. |
| AC-10 | STATIC + SYNTHETIC guard PASS; real execution DEFERRED | Seven refusal scenarios before config stub; explicit decommission remains distinct. |
| AC-11 | STATIC + SYNTHETIC PASS; actual configuration DEFERRED | Bootstrap recorded disableupdate; both settings types require disableUpdate=true; version 2.328.0 unchanged. |
| AC-12 | STATIC + SYNTHETIC PASS | restart=no unchanged; failed/interrupted bootstrap and listener preservation markers prevent automatic attempts. |
| AC-13 | LOCAL/STATIC/SYNTHETIC PASS | Same image user/security design; runtime harness inspect and Compose resolved config are separate evidence; no credentials/sudo in image; no privileged mode/socket/ports. |
| AC-14 | LOCAL PASS | Required Compose config/build exit 0; runtime libraries resolve; real version commands report 2.328.0. |
| AC-15 | STATIC PASS | Registered lifecycle tests remain explicitly DEFERRED; synthetic migration is not claimed as GitHub confirmation. |
| AC-16 | SAVED EVIDENCE PASS | This Round 3 immutable handoff contains one-to-one findings/criteria, full final command output and remaining limits. |


## Required commands and actual output

LOCAL: docker compose config, docker compose build --quiet and .\tests\validate-containers.ps1 completed successfully, full run exit 0. The build quiet option affects output only. Complete captured output:

```text
name: action-runner
services:
  runner:
    build:
      context: C:\Development\action-runner
      dockerfile: Dockerfile
      args:
        RUNNER_VERSION: 2.328.0
    environment:
      GITHUB_OWNER: scantoria
      GITHUB_REPOSITORY: thisbyte-website
      RUNNER_LABELS: self-hosted,linux,x64,thisbyte
      RUNNER_NAME: thisbyte-hp-runner
      RUNNER_WORKDIR: _work
    image: thisbyte/actions-runner:2.328.0
    init: true
    networks:
      default: null
    restart: 'no'
    stop_grace_period: 1m0s
    volumes:
      - type: volume
        source: runner-state
        target: /runner-state
        volume: {}
networks:
  default:
    name: action-runner_default
volumes:
  runner-state:
    name: action-runner_runner-state
 Image thisbyte/actions-runner:2.328.0 Building 
 Image thisbyte/actions-runner:2.328.0 Built 
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
PASS: A-2/AC-10: incorrect confirmation, absent removal token, conflicting tokens and removal token on run refuse before config
PASS: A-2/AC-10: absent, partial and malformed identity refuse before config; no removal mock was invoked
PASS: F-1/AC-02/06: runtime-created and atomically replaced migration files survive termination and same-layer restart at mode 0600/runner ownership
PASS: F-1/AC-01: listener exit status 17 propagated after valid state preservation, with no removal
PASS: B-1: deterministic TERM before loop and immediately before primary wait propagates listener status 17, not 127
PASS: F-1/AC-08: malformed runtime migration is not promoted; durable marker blocks restart and preserves rejected container evidence
PASS: F-1/AC-08: malformed persisted migration files fail closed before listener startup
PASS: F-1 state model: unsupported JIT/service state refuses startup and is preserved for review
2.328.0
PASS: Pinned real listener version command reads linked synthetic state without network access
PASS: Local fixture suite complete; real registration, real decommission, and GitHub behavior NOT EXECUTED.
PASS: Runtime inspect: User=runner, privileged=false, ports=none, Docker socket=absent, network=none.

PASS: Previous container workspace is absent after recreation.
Starting listener using persisted identity; normal shutdown never deregisters.
PASS: Synthetic listener created/updated both migrated files at runtime.
PASS: Synthetic listener started using retained state without a token.
PASS: Synthetic listener received TERM; no configuration or removal.
Validated interrupted/runtime state; promoted_regular_files=2.
Listener stopped; validated runtime identity state preserved. No deregistration performed.
PASS: F-1 migrated state is persisted at mode 0600, runner-owned, expected generation, with no incomplete finalization marker.
PASS: Docker TERM/fresh-container exit=0; migrated generation=1; base identity hashes unchanged; no bootstrap/removal.
PASS: Previous container workspace is absent after recreation.
Starting listener using persisted identity; normal shutdown never deregisters.
PASS: Synthetic listener created/updated both migrated files at runtime.
PASS: Synthetic listener started using retained state without a token.
PASS: Synthetic listener received TERM; no configuration or removal.
Validated interrupted/runtime state; promoted_regular_files=2.
Listener stopped; validated runtime identity state preserved. No deregistration performed.
PASS: Same-container stop/start retained its workspace.
Starting listener using persisted identity; normal shutdown never deregisters.
PASS: Synthetic listener created/updated both migrated files at runtime.
PASS: Synthetic listener started using retained state without a token.
PASS: Synthetic listener received TERM; no configuration or removal.
Validated interrupted/runtime state; promoted_regular_files=2.
Listener stopped; validated runtime identity state preserved. No deregistration performed.
PASS: F-1 migrated state is persisted at mode 0600, runner-owned, expected generation, with no incomplete finalization marker.
PASS: Docker TERM/same-container-restart exit=0; migrated generation=2; base identity hashes unchanged; no bootstrap/removal.
PASS: Runtime inspect: User=runner, privileged=false, ports=none, Docker socket=absent, network=none.
PASS: Previous container workspace is absent after recreation.
Starting listener using persisted identity; normal shutdown never deregisters.
PASS: Synthetic listener created/updated both migrated files at runtime.
PASS: Synthetic listener started using retained state without a token.
PASS: Synthetic listener received INT; no configuration or removal.
Validated interrupted/runtime state; promoted_regular_files=2.
Listener stopped; validated runtime identity state preserved. No deregistration performed.
PASS: F-1 migrated state is persisted at mode 0600, runner-owned, expected generation, with no incomplete finalization marker.
PASS: Docker INT/fresh-container exit=0; migrated generation=3; base identity hashes unchanged; no bootstrap/removal.
PASS: Previous container workspace is absent after recreation.
Starting listener using persisted identity; normal shutdown never deregisters.
PASS: Synthetic listener created/updated both migrated files at runtime.
PASS: Synthetic listener started using retained state without a token.
PASS: Synthetic listener received INT; no configuration or removal.
Validated interrupted/runtime state; promoted_regular_files=2.
Listener stopped; validated runtime identity state preserved. No deregistration performed.
PASS: Same-container stop/start retained its workspace.
Starting listener using persisted identity; normal shutdown never deregisters.
PASS: Synthetic listener created/updated both migrated files at runtime.
PASS: Synthetic listener started using retained state without a token.
PASS: Synthetic listener received INT; no configuration or removal.
Validated interrupted/runtime state; promoted_regular_files=2.
Listener stopped; validated runtime identity state preserved. No deregistration performed.
PASS: F-1 migrated state is persisted at mode 0600, runner-owned, expected generation, with no incomplete finalization marker.
PASS: Docker INT/same-container-restart exit=0; migrated generation=4; base identity hashes unchanged; no bootstrap/removal.
Cleanup: only this run's isolated fixture containers and volume removed.
PASS: F-2 Test A: actual SIGKILL=137, same-container unchanged identity recovered with zero promotions, token-free start, no config/remove/replace.
PASS: F-2 Test B: SIGKILL migration recovered from original layer and persisted at generation 1, mode 0600, runner ownership, without bootstrap/removal.
PASS: F-2 Test C: recreation with retained volume/missing original local evidence refuses; no listener/config/remove/replace; marker and base identity intact.
PASS: F-2 Test D/missing: continuity refused before new listener/config/remove; durable evidence and base identity preserved.
PASS: F-2 Test D/malformed: continuity refused before new listener/config/remove; durable evidence and base identity preserved.
PASS: F-2 Test D/mismatch: continuity refused before new listener/config/remove; durable evidence and base identity preserved.
PASS: F-2 Test D/container: continuity refused before new listener/config/remove; durable evidence and base identity preserved.
PASS: F-2 Test D/duplicate: continuity refused before new listener/config/remove; durable evidence and base identity preserved.
PASS: F-2 Test D/mode: continuity refused before new listener/config/remove; durable evidence and base identity preserved.
PASS: F-2 Test D/symlink: continuity refused before new listener/config/remove; durable evidence and base identity preserved.
PASS: F-2 Test D/legacy: continuity refused before new listener/config/remove; durable evidence and base identity preserved.
PASS: F-2 Test E/complete: SIGKILL during recovery kept marker; next same-container startup resumed complete matching staging and persisted valid migration before listener.
PASS: F-2 Test E/partial: interrupted recovery with mismatched staged data fails closed; no premature marker clearance or invalid promotion/deletion.
Cleanup: only F-2 fixtures created by this run removed; no real identity or remote operation.

```

After the complete functional run, only an entrypoint comment was clarified. Final image was rebuilt; bash -n, image user/security/state absence and actual no-token failure guards passed. No functional change required repeating the suite. Final image inspection:

```text
 Image thisbyte/actions-runner:2.328.0 Building 
 Image thisbyte/actions-runner:2.328.0 Built 
Docker image inspect .Id=sha256:f4c09ccf28335428b443cd07de368671ee7b4aeaa21424b97710adf2610dbd0b
aa6dcd939af7f80887e5c8212f0d65606260059849e6d320c1a538ee5935f1a9  /entrypoint.sh
9700d2261e1bec5bfee02a20ef73a45cb20e571c11847158688d1772b2b1839e  /validate-state.py
PASS: Final image has non-root configuration, no identity/session evidence or sudo, and valid shell syntax.
Actual image run: exit=1
Runner lifecycle stopped: No registration state. Explicit bootstrap is required after separate Owner authorization.
Preserve /runner-state. Review local state and GitHub records before administrative recovery.
Actual image bootstrap: exit=1
Runner lifecycle stopped: Explicit bootstrap requires a runtime short-lived registration token.
Preserve /runner-state. Review local state and GitHub records before administrative recovery.

```

Image ID is local Docker inspect .Id, not registry manifest identity. Normalized-LF host entrypoint and validator SHA256 match image hashes above.

LOCAL: git diff --check and git diff --exit-code -- alignment.md project-specification.md each exit 0 without output; branch remained unchanged. Read-only Git status/stat evidence before saving the two new artifacts:

```text
codex/wp-0.3-lifecycle
 M .dockerignore
 M .env.example
 M .gitignore
 M Dockerfile
 M README.md
 D WP-0.1-baseline-compliance-review.md
 D _Context/Sessions/REVIEW-action-runner-001.md
 D _Context/Sessions/REVIEW-action-runner-002.md
 D _Context/Sessions/WP-0.1-handoff-20260926.md
 M compose.yaml
 M entrypoint.sh
?? Docs/
?? _Context/Executions/WP-0.1-handoff-20260926.md
?? _Context/Executions/WP-0.3-handoff-20261012.md
?? _Context/Executions/WP-0.3-round-2-handoff-20261012.md
?? _Context/Reviews/REVIEW-action-runner-001.md
?? _Context/Reviews/REVIEW-action-runner-002.md
?? _Context/Reviews/REVIEW-action-runner-004.md
?? _Context/Reviews/REVIEW-action-runner-005.md
?? _Context/Reviews/WP-0.1-baseline-compliance-review.md
?? _Context/Sessions/EOD-session-context-20260926.md
?? _Context/Sessions/GPT-5.6_Session_Context_20260925_2246.md
?? _Context/Sessions/SESSION-2026-09-25-review.md
?? _Context/Work-Packages/WP-0.2-Runner-Lifecycle-Registration-Design.md
?? _Context/Work-Packages/WP-0.3-Round-2-Codex-Prompt-20261012.md
?? _Context/Work-Packages/WP-0.3-Round-3-Codex-Prompt-20261013.md
?? _Context/Work-Packages/WP-0.3-Runner-Lifecycle-Implementation-Remediation.md
?? tests/
?? validate-state.py
 README.md     | 321 +++++++++++++++++++++++++++++++++++++++++++++++--
 entrypoint.sh | 375 +++++++++++++++++++++++++++++++++++++++++++++++++++-------
 2 files changed, 645 insertions(+), 51 deletions(-)

```

The tracked diff stat is relative to HEAD and includes accepted uncommitted Round 1/2 changes. Untracked tests are omitted by normal Git stat. Round-3-only scope is established by whole-project before/after SHA256 comparison, not by that stat. Paths were normalized before comparing Windows separators. No baseline file was deleted. Governance SHA256: alignment.md A782DBBD21833487573E40A2A8161AF2579E9834144F4AE0C72203D100F21E4D; project-specification.md 3890C449A5A97F0A82482F99000FB239544A7B3280C73727FBA31F67A512E59B.

## Failures and limitations

A combined governing-document capture exceeded output capacity; independent reads completed. First new PowerShell recovery-script invocation had a parser error for $kind:; changed to braced variable before any Docker action, then standalone and complete suites passed. A JavaScript btoa helper for optional baseline diff statistics was unavailable; it failed before any file/tool operation, so used verified hash scope and read-only Git stat instead. No unresolved build/test failure or automatic approval rejection remains. Expected negative exits are safety refusals.

Evidence is LOCAL (build/image/read-only Git), SYNTHETIC (fixtures/control flow/Docker kills) or STATIC (code/operations). Actual authenticated Online/Offline, real credential migration/consumption, job drain, Windows/WSL2/Docker Desktop/host power-loss behavior, stale/duplicate remote records, real decommission and harmless CI remain DEFERRED. No synthetic result is promoted to registered-runner acceptance.

Drive mirroring remains pending for once-per-session sync before end-of-day context under alignment.md; no end-of-day artifact produced. Independent Review 006 and Owner Git decisions remain pending.

## Repeatable manual verification

```powershell
Set-Location -LiteralPath 'C:\Development\action-runner'
docker compose config
docker compose build
.\tests\validate-containers.ps1
git diff --check
git status --short
git diff --exit-code -- alignment.md project-specification.md
```

Inspect untracked tests and validator separately. Preserve unrelated working-tree changes in any future Owner-controlled publication decision.

## Boundaries and stop

No Git mutation: no branch creation/switch, commit, push, merge, rebase, PR, tag or release. No real token acquisition/generation, PAT, GitHub authentication, registration/deregistration/decommission, --replace, remote runner administration/deletion, deployment/SSH credential use, station-01 action, website workflow change or production deployment occurred. Runtime containers were network-isolated; only exact test-created containers/volumes were cleaned up. Docker build used normal declared pinned image/cache resolution, no runner API operations.

STOP after implementation, local validation and this immutable handoff. Submit for independent _Context/Reviews/REVIEW-action-runner-006.md; no self-approval or registration. Even Review 006 approval does not authorize registration.

