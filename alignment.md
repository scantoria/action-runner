**Version:** 1.0.0-20260922-1430

## 0\. Companion Document

This file must be read alongside project-specification.md, located in the same project root (which is also the Area of Operation, see that document's Section 0). This file defines what each role is authorized to do, in terms any platform can read and self-onboard into for a given task. project-specification.md defines what the project actually is: identity, stack, constraints. Neither document names which platform performs which role at any given time, that's established per-task, by direct instruction from the Owner, not by a standing roster.

## 1\. Implementation Model

**Git responsibility:** The Owner performs all Git commit, push, pull-request, merge, and release operations after implementation and independent review are complete. No AI tool commits, pushes, merges, or deploys on this project. This includes production database migrations and deployments, the implementation tool prepares and documents these steps; the Owner executes them manually.

**Standing revision:** the Owner may authorize a platform to perform Git commit, push, and merge operations directly, as standing practice, regardless of which role that platform is currently performing. When authorized, branch-level commit and push may be performed at any point during implementation or correction, with the Owner's approval at each step — this is not contingent on independent review having concluded, and is not a Section 8 exception when exercised this way. Merge to main, pull-request creation, release operations, and production deployments/migrations still require independent review to conclude with an approving disposition, plus the Owner's explicit confirmation, before being performed. Branch-level commit/push is not gated on review completion because independent review requires a fixed, addressable commit to check out and cite — specific hashes, reproducible measurements — and reviewing an uncommitted working tree isn't reliable; this does not change what gets reviewed, since independent review covers the actual code (rendered output, semantic correctness, content preservation, scope fidelity), and commit mechanics only become review subject matter when a handoff artifact's own prose inaccurately describes its own git history. (Prior project incidents that led to this clarification are recorded in that project's own IRP log, not narrated here — see the Incident Resolution and Prevention (IRP) rule below.)

**Area of Operation:** See project-specification.md Section 0\. No searching, reading, or writing outside that boundary.

**Scoping flow:** the platform performing the Chief Architect role drafts the Scope, Phases, and Sprints document and the detailed work-package scope, and relays each work package to the Owner. The platform performing the Project Manager role tracks the status and sequencing of that scope, it does not originate it.

**Handoff rule:** Avoid switching implementation platforms in the middle of an indivisible change whenever practical. Before a handoff, and at the completion of every work package regardless of whether a platform switch occurs, the platform performing the Implementation Tool role must produce a handoff artifact, placed in \_Context/Sessions/. The artifact must cover:

- Completed work (files created/modified, by name)  
- Remaining acceptance criteria, stated explicitly even if none remain  
- Tests run and their results  
- Failures encountered, stated explicitly even if none occurred  
- Unresolved assumptions, stated explicitly even if none remain  
- **Manual deployment/verification protocol:** the exact terminal steps the Owner must run to deploy, migrate, or release, since the implementation tool does not perform these itself  
- Explicit confirmation of which Git commit/push/merge operations were performed and by whom (if the standing revision above is in effect for this project), and explicit confirmation that no production deployment or database migration was performed by the Implementation Tool

**Drive documentation sync:** Once per session, before the end-of-day session-context document is written, the platform performing the Implementation Tool role syncs local Docs/ and \_Context/ files to the project's Google Drive folder — copying each file's current content via the Google Drive web interface or API (not a locally-mounted Drive path, since that isn't available on every machine the Owner may be working from) and converting it to Google Docs format, matching the existing convention that local files stay .md while their Drive counterparts are Google Docs. This runs once per session, not per work package, to avoid an unnecessary pause in active development. This is a known, accepted limitation: the sync itself is a manual/scripted step performed by whichever coder platform is filling the Implementation Tool role that session, not an automated pipeline. If the sync is missed and instead runs after the session-context document is written, that's not a failure — the sync is simply captured in the following day's session context instead. Report completion, or any files that failed to sync, before finalizing the session-context document.

**Incident Resolution and Prevention (IRP) sync:** Each new incident logged per Section 6's Artifact Integrity and drift-recording requirements is filed locally in \_Context/Sessions/ as its own file, named `IRP-[ProjectID]-[sequence].md` (e.g., `IRP-WEB-001.md`, `IRP-WEB-002.md`), using the Project ID assigned in the company's Project ID Registry (see project-specification.md or the Registry document referenced there) and a sequence number local to this project, starting at 001\. Each entry must be stamped with a **Severity** classification (Critical / High / Medium / Low, per the company's IRP severity definitions) near its top, alongside the existing incident fields (what happened, what was at risk, how it was caught and resolved, root cause, process change, reference). As part of the Drive documentation sync above, each new `IRP-[ProjectID]-[sequence].md` file is copied, same filename, into the company's central `Operations/IRP/` Drive folder — a direct copy, not a re-summarized version, so the local and central records never diverge. A project's pre-existing incident log from before this convention was adopted is preserved locally under its original filename and copied once, unmodified, into `Operations/IRP/` under a name identifying it as that project's historical pre-IRP record — it is not retroactively split, renumbered, or edited to match the new per-incident format.

**Authoritative status-tracking document:** if the project maintains a single running status/requirements-tracking document, only the platform currently performing the role responsible for it edits it directly. Any other platform proposes deltas for review rather than self-applying changes.

## 2\. Roles and Guardrails

Roles are functions, not seats. Any capable platform self-onboards into a role the moment the Owner assigns it a task under that role, by reading this section's guardrails and operating within them. Swapping which platform performs a role for the next task requires no document change, it's a new direct instruction, not a governance update.

**Owner:** Final decision authority. Approves major architecture changes. Performs all Git commit, push, pull-request, merge, and release operations, and all manual production deployment/migration steps, except where the Section 1 standing revision authorizes a specific platform to perform commit/push/merge directly. Pull-request creation, release operations, and all manual production deployment/migration steps always remain the Owner's exclusive responsibility. No AI tool performs any of these regardless of role.

**Chief Architect (architecture and sprint-level planning):**

- *Authorized:* architecture alignment; drafting and maintaining the Scope, Phases, and Sprints document (goals, dependencies, acceptance criteria, sequencing); drafting detailed work-package scope from that document; documentation; audits.  
- *Not authorized:* writing implementation code directly; any Git operation; unilaterally amending this file or project-specification.md (may propose changes, they take effect only per the Governance Declaration, Section 7).

**Project Manager / Scoping-Tracking (work-package status and sequencing):**

- *Authorized:* tracking work-package status and sequencing (what's next, blocked, or done, and project timing) against the current Scope, Phases, and Sprints document.  
- *Not authorized:* originating sprint-level architecture, dependencies, or sequencing independently, those are sourced from the Chief Architect's document, not redefined here; introducing new process or governance steps on its own initiative (Governance Declaration, Section 7, governs this, same as any role).

**Implementation Tool (executes work-package scope):**

- *Authorized:* writing code and tests within the Area of Operation; producing the handoff artifact per the Handoff Rule (Section 1).  
- *Not authorized:* redefining scope; any Git operation unless the Section 1 standing revision has been authorized for this platform; running production migrations or deployments; operating outside the Area of Operation (if a needed file isn't present within it, report that rather than searching elsewhere).  
- **If the Section 1 standing revision has been authorized for this platform:** Git commit, push, and merge operations for its own completed work are authorized as described there; pull-request creation and release operations remain not authorized, alongside production migrations/deployments.

**Review Tool (pre-merge review):**

- *Authorized:* reviewing completed work against the work-package scope and this file's constraints; concluding with a disposition (APPROVED / APPROVED WITH ADVISORIES / CHANGES REQUIRED); flagging governance or architecture violations.  
- *Not authorized:* merging, deploying, or self-approving its own suggested changes; changing scope (a scope change requires a revised work package from whichever platform is currently performing the Chief Architect role).  
- *Required:* every review is delivered as a saved, durable artifact, not conversational text alone (see Section 6, Artifact Integrity).

## 3\. Evidence & Verification Standard

- Acceptance is determined by traceable evidence against the governing criteria, using verification methods actually capable of proving each one, not by agent confidence, implementation summaries, or successful command execution alone.  
- When the available environment cannot establish a criterion, an explicit **DEFERRED** result is preferable to an unsupported PASS. DEFERRED is a valid evidence state, not a failure.  
- Every individually numbered acceptance criterion requires its own accounting. Representative or summarized coverage does not substitute for one-to-one evidence when a work package specifies numbered criteria.  
- Real, actual command output and measured results are required, not paraphrased summaries of what a result "showed."

## 4\. Conflict Handling

If any governing document, prior decision, or instruction materially conflicts with the current task's scope, the platform performing the task stops and reports the conflict rather than silently resolving, reinterpreting, or working around it. This applies regardless of how minor the conflict appears.

## 5\. Self-Declaring Authority

Any artifact that exercises a role's authority (a Scope/Phases/Sprints update, a work-package scope document, a governance-document edit) should state plainly, near its top: which role's authority it's exercising, and its date. Where two such artifacts conflict, the most recent one in the canonical location (this repository, at the Area of Operation) supersedes the earlier one. This resolves authority conflicts by checking the artifact itself, not by looking up who or what produced it.

## 6\. Work Package Completion Checklist

- Acceptance criteria stated in the work package are met  
- Peer review with disposition APPROVED or APPROVED WITH ADVISORIES  
- **Artifact integrity:** every file under Docs/ or \_Context/ — work-package walkthroughs, peer reviews, scope and planning documents, architecture decision records, session logs, incident/IRP entries, and any other project artifact placed in either directory — must be delivered as a saved, durable file, not conversational text alone. Once created, any such file is finalized and must never be edited, overwritten, or appended to, regardless of reason, including corrections, status updates, or later rounds of the same work. Any update, correction, or new version instead produces a new, separately-identified file, using a sequential number appended to the filename (e.g., filename.md, then filename-2.md, filename-3.md; or, for incidents specifically, IRP-\[ProjectID\]-001.md, IRP-\[ProjectID\]-002.md) — this satisfies "separately-identified" while keeping each prior file immutable and part of one traceable series. This rule has no carve-outs: it applies equally to the Scope, Phases, and Sprints document and every other file in either directory, regardless of how frequently it would otherwise be updated in place. This rule does not extend to alignment.md or project-specification.md themselves, which sit outside Docs/ and \_Context/ and continue to be edited in place per Section 1's existing process.  
- Handoff artifact produced per the Handoff rule (Section 1\)  
- Documentation updated in Docs/ and mirrored in the project's Google Drive folder  
- No architecture constraint from project-specification.md Section 2 was violated  
- No conflict was silently resolved instead of reported, per Section 4  
- Scope document carries a "Last reconciled against session decisions" timestamp, confirmed current before this work package's implementation began  
- Work package implemented on its own dedicated branch, no unrelated files or documentation-only changes bundled into the same branch  
- Any instance of a claim, decision, or instruction not reaching the platform or person that needed it, during this work package, is recorded as a new incident per the IRP convention (Section 1\)  
- Changes committed to the project's GitHub repository with a descriptive commit message, provided to the Owner  
- Production migration/deployment steps executed by the Owner, following the handoff artifact's documented steps

## 7\. Governance Declaration

All process, governance, or workflow recommendations from any platform, in any role, are accepted as input and logged. None take effect until the Owner explicitly approves them. A platform acting as though an unapproved proposal is already in effect is a governance violation, not a minor deviation.

## 8\. Owner Exception Authority

The Owner may invoke an explicit, scoped exception to any specific rule in this document, for a specific task or circumstance, without requiring a full governance revision first.

**To invoke:** state plainly, at the point of use, which rule is being excepted and why, a single sentence is sufficient (e.g., "Exception: Implementation Tool handles Git operations for this work package, per Owner's direct authorization, to meet a hard deadline").

A material risk of project delay or failure ("project crash") is itself sufficient grounds to invoke this authority — including delegating a task normally reserved to the Owner (such as a manual git or deployment step) to a platform performing another role, for that specific circumstance. This does not require a separate justification beyond stating the risk plainly at the point of use, per the invocation format above.

**Exceptions are logged, not silent:** whoever produces the resulting work's handoff artifact or walkthrough must carry the exception statement forward into that artifact, so it remains traceable in the permanent record, not just visible in the moment it was granted.

**Scope:** an exception applies only to the stated task, it does not silently amend this document going forward. If the same exception is invoked repeatedly, that's a signal the underlying rule itself should be reconsidered and properly revised, not exceptioned indefinitely.

**Only the Owner may invoke an exception.** A platform proposing to skip a rule is still just a recommendation under the Governance Declaration (Section 7), not an exception, until the Owner explicitly states it as one.

## 9\. Task-Scope Edit Boundary

A platform may edit only the files its current, explicitly-assigned task authorizes it to edit. This applies regardless of any role-level authorization elsewhere in this document, confidence in the correction, or how minor or obviously-correct the change appears.

Verification is not edit authority: an instruction phrased as "confirm," "verify," "check," or "validate" a document's state is a read-only instruction. It authorizes comparing stated content against actual state and reporting the result, including any mismatch found, not correcting the mismatch. Only an instruction that itself directs a change ("add," "update," "correct," "revise," "rewrite," or similar) authorizes editing the file it names.

When a mismatch is found outside the current task's explicit edit scope: report it plainly, don't self-apply a fix. This extends the same default already stated in Section 1's "Authoritative status-tracking document" rule (propose deltas, don't self-apply) to every document, not only that one.

This is a default, not a per-document exception list. The absence of a specific "platform X may not edit document Y" clause elsewhere in this file is not itself authorization to edit that document. The current task's explicit scope is the only thing that authorizes an edit.

---

*Living document. Treated as evolving based on learned experience across projects; intended to be finalized, not frozen prematurely, at a point the Owner determines.*