---
name: dev-cycle
description: Run one issue end to end; architect plans (issue-plan), developer implements (issue-implement), a separate architect reviews and merges (code-review), bounded revision loop. Orchestrates only. Use when asked to implement, build, ship, or do an issue.
---

# Dev Cycle

The unit of delivery for one issue. The coordinator (the user's session, or `burndown` per issue) dispatches each phase to its role and sequences results; it writes no code, posts no plan, transitions no board status, and never merges.

Project facts from `AGENTS.md`: **§ Project Board**, **§ Branch Map**, **§ Build & Validation**, **§ Repositories**. Missing section: name it and stop.

## Inputs

A GitHub issue number or URL; the ledger, claim, and `Closes #n` trail all hang off it. A direct request with no issue: raise one first via `issue-raise`, then run the cycle. Optionally, from a batch coordinator: an owned file/module scope and batch validation requirements.

## Phases

| Phase | Role | Skill | Skipped when |
|---|---|---|---|
| 1. Plan | `architect` | `issue-plan` | a ledger exists and the issue is in-progress |
| 2. Implement | `developer` | `issue-implement` | never |
| 3. Review + merge | `architect`, distinct from phase 2 | `code-review` (PR mode) | never |
| 4. Revise | `developer`, then a fresh `architect` | `issue-implement` § Revision Round, `code-review` § Re-review | the review was clean |

- Each phase runs in a fresh context with a narrow prompt: issue number and URL plus the facts that phase needs; nothing inherited from the conversation.
- Planning is never skipped for being "trivial". Whether a change is simple is only known after the architect has looked; the plan is the cheapest place to find that a small change has wide consequences, and it keeps review from becoming a design discussion across rounds. The soft gate keeps the cost to one dispatch.
- Accept a phase's result before starting the next: check it against what was asked; stop rather than forward something that does not add up.

## Phase Prompts

```text
Plan:    Run issue-plan on issue <number> (<url>). Return the plan comment link, approach, task count, blockers or decision points.
Implement: Run issue-implement on issue <number> (<url>). [Owned scope: <files/modules>.] Validation: <from § Build & Validation>. Return the PR URL, changed paths, ledger state, validation output, risks.
Review:  Run code-review in PR mode on PR <number>, round <n>. Merge if and only if the criteria hold, then the after-merge steps. Return assessment, comment URL, merge result or blocking criterion, board transition, cleanup.
Revise:  Run issue-implement § Revision Round on PR <number> (issue <n>). Findings from <review comment URL>: <enumerated>. Validation: <...>. Return commits, findings fixed, findings contested with reasoning, validation output.
```

## Flow

1. Load the issue (`gh issue view <n> --json number,title,body,state,url,comments`), board status, and whether a ledger exists (first comment line `<!-- plan-ledger -->`). Backlog/unrefined: route through `issue-refine`. In review / done: stop and report.
2. **Plan** if no ledger. Decision points returned instead of a ledger: surface them to the user (or return them to the batch coordinator) and stop; never answer design questions on the architect's behalf. Confirm the ledger exists and the status is in-progress.
3. **Implement.** Accept only a PR URL, a registered closing reference, validation output, and the in-review transition. A blocked result (`## Blockers` filled) sends the plan back to the architect once; if it recurs, stop and report.
4. **Review**, round 1. Merged: record and finish. Clean but a merge criterion unmet: report why and leave it. Critical/High: revise.
5. **Revise**, at most two rounds (review rounds 2 and 3). Developer fixes only the enumerated findings; a fresh architect re-reviews pointed at the prior comment. A contested finding ends the loop immediately (human call). Cap or contest: park the PR with round, exit reason, and both positions.
6. **Report**: issue and PR URLs; plan link and approach; merge commit, or parked (round, reason), or the unmet criterion; verified board status; validation; residual risks; anything incomplete.

## Without Subagents

One fresh session per phase, loading only that phase's skill and prompt. Never review in the session that implemented.
