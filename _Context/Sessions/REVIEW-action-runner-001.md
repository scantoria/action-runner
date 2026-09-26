# Review — Initial Action Runner Implementation

**Authority exercised:** Review Tool role, per alignment.md Section 2.
**Date:** 2026-09-25
**Reviewer:** Claude (Sonnet 5), acting as Review Tool
**Scope of review:** the existing prototype implementation described in project-specification.md Section 3 ("Current Project State") and gated by Section 3.1's Mandatory Current Hold Point — Dockerfile, compose.yaml, entrypoint.sh, .env.example, .gitignore, .dockerignore, .gitattributes, README.md — reviewed against project-specification.md and alignment.md.

**Disposition: CHANGES REQUIRED**

One functional defect (entrypoint.sh double-cleanup on signal) must be fixed before the Section 3.1 hold point can be considered satisfied on shutdown-behavior grounds. Everything else below is an advisory or a process gap, not a security-requirement violation — no hard "SHALL NOT" constraint in Section 7/8/9 is currently violated by the code as written.

---

## 1. Conflict flagged (alignment.md Section 4)

alignment.md Section 0 and Section 1 ("Area of Operation") both cite **"project-specification.md, Section 0"** as the definition of Area of Operation. project-specification.md's sections begin at **Section 1 (Purpose)** — there is no Section 0. The closest candidate is Section 1's stated Project Root (`C:\Development\action-runner`). This is reported per Section 4 rather than silently resolved; whoever holds the Chief Architect or governance-editing role should correct the cross-reference in alignment.md.

## 2. Required change

**entrypoint.sh — duplicate cleanup on SIGINT/SIGTERM.**

```sh
trap handle_signal INT TERM
trap cleanup EXIT
```

`handle_signal()` calls `cleanup()` directly, then `exit 0`. In bash, an explicit `exit` inside a signal trap still fires the `EXIT` trap afterward, so `cleanup()` runs a **second time**: it re-checks `runner_pid` (harmless, already dead) but also re-issues `./config.sh remove --unattended --token "${RUNNER_TOKEN}"` a second time. The failure is swallowed by `|| true`, so this is not a security exposure, but it:

- produces duplicate "Removing runner registration..." log lines, undermining the clean shutdown/deregistration record Section 18 expects, and
- is exactly the kind of defect Section 23's unchecked "[ ] Shutdown behavior is tested" / "[ ] Deregistration behavior is tested" criteria exist to catch, per Section 3 of the Evidence & Verification Standard (traceable evidence, not confidence).

**Suggested fix:** make `cleanup()` idempotent (guard with a `cleanup_done` flag set at entry) or drop the direct call in `handle_signal()` and rely solely on the `EXIT` trap, since it already fires after a signal-triggered `exit`.

## 3. Advisories (non-blocking)

- **Registration-token mechanism has been implicitly decided by code, not yet by the Owner.** project-specification.md Section 25 lists "final mechanism for obtaining short-lived GitHub runner registration credentials" as an intentionally open/deferred decision. entrypoint.sh and .env.example already assume one specific mechanism (a human manually pastes a pre-generated token into `.env`, no expiry/refresh handling). That may well be the right initial choice, but Section 11.2 says this "remains a design decision to be approved before registration" — recommend the Owner explicitly ratify (or revise) this mechanism as a standalone decision before the Section 3.1 hold point is lifted, rather than letting the implementation's existing shape stand in for that approval.
- **Deregistration will often silently fail by design.** `config.sh remove` reuses the original `RUNNER_TOKEN`. GitHub registration tokens are short-lived (typically ~1 hour), so on any container lifetime longer than that, deregistration will fail and be swallowed by `|| true`. This is consistent with Section 7's "where technically possible" / Section 11.3's "where appropriate" wording, so it's not a defect — but it means stale runner registrations should be expected as routine, not exceptional, and Section 19's "Remove obsolete runner registrations if necessary" step should be treated as a standing operational task, not a rare cleanup. Worth stating explicitly in the operational docs so it isn't mistaken for a bug later.
- **No cap_drop / no-new-privileges / read-only rootfs hardening in compose.yaml.** Not required by any enumerated Section 7 "SHALL" — the current settings (no privileged, no docker.sock, no inbound ports, non-root) satisfy the stated requirements. Flagging only as an optional further-hardening suggestion, not a gap against the spec as written.

## 4. Process/governance gaps (flagged per Review Tool authority to flag governance violations, alignment.md Section 2)

- No work-package scope document exists in `_Context/Work-Packages/` (empty) authorizing this implementation's scope. alignment.md's Scoping flow attributes originating scope to the Chief Architect role; none is on file for the work already done.
- No handoff artifact exists in `_Context/Sessions/` for the implementation work completed so far, despite alignment.md Section 1 requiring one "at the completion of every work package" and regardless of whether a platform switch occurred.
- These are noted as gaps to close, not attributed to any specific platform — alignment.md Section 5 resolves authority by artifact content, not by inference about who produced prior work, and none of that is available here.

## 5. What the review confirmed as compliant

Checked directly against project-specification.md Section 7 (Container Requirements), Section 8 (Docker Host Security), Section 9 (Runtime Identity), Section 10 (GitHub Scope), Section 11 (Registration/Credential Handling), and Section 20 (never-commit list):

- Base image supported and pinned runner version (2.328.0) matches the spec's currently-pinned version.
- Container runs as non-root `runner`; no sudo granted; no sudoers modification.
- `docker.sock` is not mounted anywhere in compose.yaml or the Dockerfile.
- No `privileged: true`, no published ports, in compose.yaml.
- No credentials, tokens, or keys are embedded in the Dockerfile or image layers; `RUNNER_TOKEN` is supplied only via `.env` at runtime.
- `.env`, `.env.*`, `*.key`, `*.pem`, `credentials/`, `_work/` are excluded from both `.gitignore` and `.dockerignore`; `.env.example` contains only an empty `RUNNER_TOKEN=` placeholder, no live secret.
- Persistent storage is limited to the named volume mounted at `/actions-runner/_work`, matching Section 12's justified path; no runner configuration state is separately persisted.
- Runner scope (repo-scoped URL built from `GITHUB_OWNER`/`GITHUB_REPOSITORY`, default labels `self-hosted,linux,x64,thisbyte`, name `thisbyte-hp-runner`) matches Section 10 exactly.

---

*This artifact is delivered as a saved file per alignment.md Section 6 (Artifact Integrity). Once created it is final; any correction or follow-up review produces a new sequentially-numbered file (e.g. `REVIEW-action-runner-002.md`), not an edit to this one. Filename uses the project's working name in place of a registry-assigned Project ID, which was not available to this review — reconcile against the company's Project ID Registry if/when this file is renamed to match the IRP-style convention.*
