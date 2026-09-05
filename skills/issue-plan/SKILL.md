---
name: issue-plan
description: Design the How for a refined issue (approach, touch points, validation, risks, tasks), claim it on the board, and post the single plan-ledger comment. Architect-only; phase 1 of dev-cycle. Use when asked to plan an issue or design its approach.
---

# Plan Issue

The issue body holds the What (`issue-refine`); this skill decides the How and records it as one living comment on the issue that `issue-implement` executes. It designs; it does not implement. Always run by an `architect`.

Project facts from `AGENTS.md`: **§ Project Board**, **§ Repositories**, **§ Code Layout & Tech Stack**, **§ Build & Validation**, **§ Review Notes**. Missing section: name it and stop.

## The Plan Ledger

One comment per issue, for its whole lifecycle, identified by `<!-- plan-ledger -->` as the first line. Never post a second; find and edit in place. Only this skill creates it. Issue bodies never carry a design or task checklist.

## Approval Gate (soft)

Most plans are claimed and posted without a round trip. Present the plan and wait **only** when one holds:

- Two or more approaches with materially different trade-offs and no clear winner from the codebase or `AGENTS.md`.
- The design must widen the issue's scope or break a `## Notes` constraint.
- A split, a migration or backfill of existing data, a public contract change, or a security/permission decision.
- The What is still ambiguous after reading the codebase.

When gating, ask the specific decision with a recommendation, then stop. Otherwise state the chosen approach and rejected alternatives in the report. As a non-interactive worker never wait: return the plan and decision points without claiming or posting.

## Board Status Transitions (shared mechanics)

`issue-raise`, `issue-refine`, `issue-implement`, and `code-review` reference this section. Resolve `<project-number>`, `<owner>`, and option names from § Project Board; look up IDs live, never hardcode.

```sh
gh project view <project-number> --owner <owner> --format json --jq '.id'
gh project field-list <project-number> --owner <owner> --format json --jq '.fields[] | select(.name=="Status") | {id, options}'
gh project item-list <project-number> --owner <owner> --format json --limit 200 --jq '.items[] | select(.content.number==<issue-number>) | {id, status, title}'
gh project item-edit --project-id <project-id> --id <item-id> --field-id <status-field-id> --single-select-option-id <option-id>
```

After every transition re-run the item-list lookup and report the verified status, not the intended one. Issue not on the board: do not add it silently; note and ask. Missing `gh project` scope: ask the user to run the refresh command in § Project Board. § Project Board `none`: skip transitions.

## Claim (status as lock)

Moving ready → in-progress is the claim; claim only from ready. Backlog: not refined, route through `issue-refine`. In progress / in review / done: someone else's or finished; stop and report `claimed` (a ledger without a PR may be a crashed run, but only the user can say so: re-plan or update an existing ledger only when explicitly asked to resume). Transition, then re-read; if the status changed under you, yield.

The board cannot tell two simultaneous claimants apart, so the ledger comment is the tie-break: after posting, re-fetch the comments; if another `<!-- plan-ledger -->` comment has a lower id than yours, delete yours (`gh api -X DELETE /repos/<owner>/<repo>/issues/comments/<your-comment-id>`) and report `claimed`, leaving the status alone.

## Workflow

1. Load the issue and comments; check for an existing ledger and the board status.

   ```sh
   gh issue view <number-or-url> --json number,title,body,labels,state,url,comments
   ```

2. Fix the target: `## Expected outcome` is the goal, `## Notes` constraints are binding. Unclear What: stop and route through `issue-refine`. If the plan reveals several issues, route through `issue-refine` (parent kept, native sub-issues), then plan each child.
3. Explore: the code the outcome touches, the existing pattern for that kind of change, contracts and data it depends on, tests covering the area, validation commands in § Build & Validation. Follow the codebase's conventions unless the issue is about changing them; never invent paths.
4. Design: enumerate viable approaches, choose the smallest that satisfies the acceptance criteria, note in one line each why the others lose. Spell out interface, contract, data, and configuration changes; compatibility and migration needs; the validation strategy; risks and their containment.
5. Decompose into the smallest individually implementable and verifiable tasks, dependency-ordered, each with a code area and a validation signal; note parallelizable ones.
6. Apply the Approval Gate; if it triggers, present and stop.
7. Claim (skip if there is no board, or the user asked to resume an existing ledger).
8. Write the ledger to `.tmp-plan-<number>.md` with a file-write tool (not shell redirection):

   ```md
   <!-- plan-ledger -->
   ## Plan

   _Single source of truth for this issue's design and tasks. Edited in place; no further plan comments._

   ## Approach
   Chosen design and why. Rejected: <alternative> (<reason>).

   ## Touch Points
   - `<path or module>`: what changes

   ## Validation
   Tests to add or extend; checks to run.

   ## Risks
   Risk and containment, one line each, or _None._

   ## Tasks
   - [ ] Task: unit, code area, validation signal

   ## Sequence
   Order and parallelizable tasks.

   ## Blockers
   _None._
   ```

   `Approach`, `Tasks`, `Blockers` required; for a small obvious change a one-sentence Approach suffices and the other sections may be omitted.

9. Post (only after a confirmed claim), then delete the temp file. `<owner>/<repo>` from § Repositories.

   ```sh
   gh issue comment <number> --body-file .tmp-plan-<number>.md
   ```

   Then the tie-break in § Claim. Resuming an existing ledger (explicit user request only): edit in place, never a second comment.

   ```sh
   gh issue view <number> --json comments --jq '.comments[] | select(.body | startswith("<!-- plan-ledger -->")) | .id'
   gh api -X PATCH /repos/<owner>/<repo>/issues/comments/<comment-id> -F body=@.tmp-plan-<number>.md
   ```

10. Report: issue and plan comment links, approach in one line with rejected alternatives, task count, sequence, risks, blockers. Not claimed: `claimed` or the reason, and that nothing was posted.
