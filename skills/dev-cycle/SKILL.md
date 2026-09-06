---
name: dev-cycle
description: Orchestrate one issue from plan through implementation, review, and merge. Use when asked to implement, build, ship, or do an issue.
---

# Dev Cycle

Coordinator (user session or `burndown` per issue): dispatch and sequence roles; never write code, post plans, transition board status, or merge.

Project facts from `AGENTS.md`: **§ Project Board**, **§ Branch Map**, **§ Build & Validation**, **§ Repositories**. Missing section: name it and stop.

Use `issue-plan` § Board Status Transitions: explicit `board: none` skips board operations, not ledger ownership; missing board facts stop. Deliver fully resolving PRs only, never partial `Refs`.

## Inputs

GitHub issue number/URL anchors ledger, claim, and `Closes #n`. No issue: run `issue-raise` first. Batch coordinator may supply owned file/module scope and validation requirements.

## Phases

| Phase | Role | Skill | Skipped when |
|---|---|---|---|
| 1. Plan | `architect` | `issue-plan` | the user explicitly asked to resume an already-planned issue |
| 2. Implement | `developer` | `issue-implement` | explicit resume with an existing delivery PR goes to review |
| 3. Review + merge | `architect`, distinct from phase 2 | `code-review` (PR mode) | never |
| 4. Revise | `developer`, then a fresh `architect` | `issue-implement` § Revision Round, `code-review` § Re-review | the review was clean |

- Fresh context per phase: issue number/URL and needed facts only, no inherited conversation.
- Never skip planning as "trivial"; the architect establishes scope before implementation/review. The soft gate avoids unnecessary round trips.
- Validate each result against its request before dispatching the next; inconsistencies stop.

## Phase Prompts

```text
Plan: Run issue-plan on issue <number> (<url>). Return ledger link, approach, task count, blockers/decisions.
Implement: Run issue-implement initial mode on issue <number> (<url>). Claim/resume evidence; ledger REST id/link: <...>. [Owned scope: <files/modules>.] Validation: <§ Build & Validation>. Return PR URL, paths, ledger state, validation output, risks.
Review: Run code-review PR mode on PR <number>, round <n>. Merge iff criteria hold; perform after-merge steps. Return assessment, comment URL, merge/blocker, board transition, cleanup.
Revise: Run issue-implement revision mode on PR <number> (issue <n>, <url>). Current-cycle ownership; ledger REST id/link: <...>. Findings from <review comment URL>: <enumerated>. Validation: <...>. Return commits, fixed/contested findings with reasoning, validation output.
```

## Flow

1. Load issue (`gh issue view <n> --repo <repo-slug> --json number,title,body,state,url`), complete board lookup, and all REST ledger comments per `issue-plan`. Closed/done: finished, stop. Existing ledger or in-progress/in-review: `claimed`, stop unless explicitly user-authorized resume, even boardless; batch dispatch is not authorization. Backlog/unrefined: `issue-refine`. Authorized resume with delivery PR goes to review, not initial implementation: first verify unique ledger, open PR identity, exact intended closing reference, and in-review or `board: none`. In-review without matching PR blocks.
2. **Plan**, unless explicit resume. `claimed`: report/stop. Decisions instead of ledger: return to user/batch coordinator and stop, never answer for the architect. Confirm unique ledger and in-progress or `board: none`; retain claim/resume evidence and ledger REST id/link for handoffs.
3. **Implement.** Require fully resolving PR URL, exact closing-reference verification per `issue-implement`, validation output, and verified in-review or `board: none`. Blocked: return ledger once to architect in `issue-plan` same-cycle blocked-plan repair mode, with ownership evidence/blockers. Continue only after ledger blockers clear; decisions or repeated blocker stop, never generic auto-resume.
4. **Review**, round 1. Merged: finish. Critical/High: revise. Otherwise any unmet merge criterion, including important Medium findings: report the blocker and leave the PR open for the user.
5. **Revise**, at most twice (review rounds 2/3). Developer fixes enumerated findings only; fresh architect re-reviews against prior comment. Contest ends loop immediately for human decision. Cap/contest: park PR with round, exit reason, both positions.
6. **Report**: issue/PR URLs, ledger link/approach, merge commit or parked round/reason or unmet criterion, verified board status, validation, residual risks, incomplete work.

## Without Subagents

One fresh session per phase, loading only that phase's skill and prompt. Never review in the session that implemented.
