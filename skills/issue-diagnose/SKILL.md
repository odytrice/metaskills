---
name: issue-diagnose
description: Diagnose a bug's root cause in one RCA comment before planning. Use to diagnose a bug, find its root cause, or run an RCA on an issue.
---

# Diagnose Issue

Architect-only: find a bug's Why in one living RCA comment before any plan. Never design the fix (`issue-plan` owns the How) or edit the body (`issue-refine` owns the What).

Project facts from `AGENTS.md`: **§ Repositories**, **§ Branch Map** (reproduction base), **§ Code Layout & Tech Stack**, **§ Build & Validation**, **§ Review Notes** (critical flows). Missing section: name it and stop.

No board reads, claims, or transitions. Any open issue; closed: stop.

## Criteria (shared)

Shared by `issue-refine`, `issue-plan`, and `code-review`. A bug has Type `Bug`, a bug label, or a body describing existing behavior that differs from what is expected. It needs an RCA when any criterion applies:

| Criterion | Applies when |
|---|---|
| Impact | Serious actual or potential harm: security, permissions, privacy, money, data loss or corruption (including saved bad data and near misses), or a § Review Notes critical flow |
| History | It outlived a fix or is worked around: happened before; earlier fix failed or was reverted; issue reopened; manual reruns, refreshes, or data patches |
| Distance | The cause is not visible where the failure shows: intermittent; depends on data, timing, order, or environment; silent (wrong result, no error); the first "why" leads into another component or only a guess answers it |
| Ownership | What should have prevented it did not, or nothing owns it: bypassed safeguard (validation, constraint, expected writer, test); two components each assume the other handles it; the same mistake likely exists elsewhere |
| Fix shape | The obvious or a proposed fix adds machinery around the symptom: retry, fallback, special case, suppressed error, new record, flag, or format |
| Request | The user asks |

Skip only when none applies: one "why" lands on a defect you can point to where the failure shows, and fixing it there adds nothing new. Doubt: diagnose.

## The RCA Comment

One per issue, first line `<!-- root-cause -->`; edit in place, never post another. Once triggered, always post, even for a one-step chain, so the trigger can see diagnosis happened.

```md
<!-- root-cause -->
## Root Cause

_Diagnosis for this issue: the Why. Edited in place on re-diagnosis; the fix lives in the plan ledger._

**Conclusion:** actionable cause | needs refinement | needs evidence
**Criteria:** <criteria that applied> | request
**Re-diagnosed:** <trigger; what changed, or "cause unchanged">

## Observed Failure
Reproduced on `<sha>` with <command or steps>; report in the issue body. Or: not reproduced, <what was tried>.

## Why Chain
1. <failure>, because <cause>. Evidence: <path:line, test output, log>.
2. <cause>, because <deeper cause>. Assumption: <basis>.
Stops at: <actionable cause>, or the open question below.

## Existing Responsibility
<component or contract that should already handle this; how it was bypassed or failed>, or "None: ownership gap".

## Proof
<reproduction that fails on base and must pass after the fix: test to add (location, assertion) or manual steps>

## Variants
<other places with the same mistake>

## Refinement Needed
<specific body change>

## Open Questions
1. <question>
```

Omit `Re-diagnosed` on first diagnosis and empty `Variants`, `Refinement Needed`, `Open Questions`. Few evidence-backed lines; mark every step Evidence or Assumption; an open question beats an invented cause; no fix design.

- **actionable cause**: the chain reached a cause with evidence; open questions past it become plan risks.
- **needs refinement**: the body is wrong (intended behavior, a different failure, wider scope, saved bad data needing repair); name the change.
- **needs evidence**: no actionable cause is reachable (cannot reproduce, needs production data); name the evidence.

## Workflow

1. Load the issue and all comments via paginated REST, retaining numeric ids:

   ```sh
   gh issue view <number-or-url> --repo <repo-slug> --json number,title,body,labels,state,url
   gh api --paginate repos/<owner>/<repo>/issues/<number>/comments --jq '.[] | {id, html_url, body}'
   ```

2. Existing RCA: report it and stop, unless the user requests re-diagnosis or the current `dev-cycle` authorizes it (issue URL, RCA REST id, triggering blocker or review finding). Multiple RCAs: stop as ambiguous.
3. Reproduce in a detached worktree at the § Branch Map base tip:

   ```sh
   git fetch origin <base>
   git worktree add --detach .worktrees/diagnose-<number> origin/<base>
   ```

   Use existing tests, § Build & Validation commands, history (`git log`, `git blame`), logs, or the issue's evidence; never edit tracked files. A reproduction needing a new test goes under Proof as specified, not run.
4. Follow the chain to an actionable cause or an open question; name the existing responsibility; search for variants.
5. Stage `.tmp-rca-<number>.md` with a file-write tool. Create: re-fetch all REST comments, POST, then apply `issue-plan` § Claim's numeric-id tie-break to RCA comments (a later duplicate deletes only itself and reports the earlier one). Re-diagnosis: re-fetch and PATCH the unique RCA by numeric id. Verify the stored body and uniqueness; remove the temp file even on failure.

   ```sh
   gh api -X POST repos/<owner>/<repo>/issues/<number>/comments -F body=@.tmp-rca-<number>.md --jq '{id, html_url}'
   gh api -X PATCH /repos/<owner>/<repo>/issues/comments/<comment-id> -F body=@.tmp-rca-<number>.md
   ```

6. From the original repo, remove only a clean worktree whose resolved path is inside `.worktrees/`; otherwise stop/report:

   ```sh
   git worktree remove .worktrees/diagnose-<number>
   git worktree prune
   ```

7. Report RCA link and REST id, conclusion, criteria, and the refinement or evidence needed.
