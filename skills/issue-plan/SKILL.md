---
name: issue-plan
description: Plan and claim a refined issue in one living ledger. Use when asked to plan an issue or design its approach.
---

# Plan Issue

Architect-only: design the How for `issue-implement`, never implement. The issue body holds the What (`issue-refine`); the living ledger holds the How.

Project facts from `AGENTS.md`: **§ Project Board**, **§ Repositories**, **§ Code Layout & Tech Stack**, **§ Build & Validation**, **§ Review Notes**. Missing section: name it and stop.

Shared contract for all callers: explicit § Project Board `none` (including `board: none`) skips board reads, claims, and transitions; report `board: none`. Absent/incomplete board facts: stop, never infer `none`.

## The Plan Ledger

One lifecycle comment per issue, first line `<!-- plan-ledger -->`. Only this skill creates it; thereafter edit in place, never post another. No design or task checklist in issue bodies.

## Approval Gate (soft)

Claim and post without approval **unless**:

- Materially different approaches have no clear winner in the codebase or `AGENTS.md`.
- Scope widens or a `## Notes` constraint breaks.
- A split, existing-data migration/backfill, public contract change, or security/permission decision is needed.
- The What remains ambiguous after code exploration.

At the gate, ask the specific decision with a recommendation and stop; non-interactive workers return plan/decision points without waiting, claiming, or posting. Otherwise report the chosen approach and rejected alternatives.

## Board Status Transitions (shared mechanics)

Shared by `issue-raise`, `issue-refine`, `issue-implement`, and `code-review`. Resolve project number, owner, and option names from § Project Board; look up IDs live.

```sh
gh project view <project-number> --owner <owner> --format json --jq '.id'
gh project field-list <project-number> --owner <owner> --format json --jq '.fields[] | select(.name=="Status") | {id, options}'
gh project item-list <project-number> --owner <owner> --format json --limit 1 --jq '.totalCount'
gh project item-list <project-number> --owner <owner> --format json --limit <actual-total-count>
gh project item-edit --project-id <project-id> --id <item-id> --field-id <status-field-id> --single-select-option-id <option-id>
```

Before item-edit, require returned item count = returned `totalCount`; zero needs no second fetch. Changed total: retry; unprovable completeness: stop. A fixed limit is not completeness. Match Issue content by canonical URL from `gh issue view <issue> --repo <repo-slug> --json url`, never number alone. Require one match: zero means ask, never silently add; multiple means stop as ambiguous. Batch/report reads retain content type, URL, and repository identity; exclude PRs/drafts and filter to § Repositories' consuming repo before status selection or counting.

After each transition repeat the complete lookup; report verified status. Missing `gh project` scope: ask the user to run § Project Board's refresh command. `board: none`: skip these commands.

## Claim (status as lock)

Claim only ready -> in-progress; re-read after transition and yield if status changed under you. Backlog: route to `issue-refine`. In progress / in review / done or any existing ledger: stop as `claimed`, even ready/boardless. Never infer a crashed run; resume requires explicit user authorization, not batch dispatch.

Sole coordinator exception: one **same-cycle blocked-plan repair**. Require `dev-cycle`'s issue URL, ledger REST id/link, current-cycle claim/explicit-resume evidence, and implementation blockers. Verify the ledger and in-progress or `board: none`; edit only that ledger under the same Approval Gate. No re-claim, second ledger, or takeover of unrelated/parked runs. Second blocker or unresolved decision: stop the cycle.

Simultaneous claimants use the ledger tie-break: after posting, re-fetch all comment pages. Another ledger with a lower numeric REST id: delete only yours (`gh api -X DELETE /repos/<owner>/<repo>/issues/comments/<your-comment-id>`), report `claimed`, leave status alone.

## Workflow

1. Load issue, all comments, ledger, and board status. Use paginated REST ledger ids, not `gh issue view --json comments` GraphQL node ids:

   ```sh
   gh issue view <number-or-url> --repo <repo-slug> --json number,title,body,labels,state,url
   gh api --paginate repos/<owner>/<repo>/issues/<number>/comments --jq '.[] | select(.body | split("\n")[0] == "<!-- plan-ledger -->") | {id, html_url, body}'
   ```

2. Target `## Expected outcome`; obey `## Notes`. Unclear What: stop for `issue-refine`. Several issues: refine into native sub-issues, retain parent, then plan each child.
3. Explore affected code, existing patterns, dependent contracts/data, tests, and § Build & Validation commands. Follow conventions unless changing them is the issue; never invent paths.
4. Enumerate viable approaches; choose the smallest meeting acceptance criteria and give one-line rejections of alternatives. Specify interface/contract/data/config changes, compatibility/migration needs, validation, risks and containment.
5. Make minimal independently implementable/verifiable tasks with code area and validation signal; dependency-order them and mark parallelism.
6. Apply the Approval Gate; if it triggers, present and stop.
7. Claim unless explicit `board: none`, authorized resume, or verified same-cycle repair. Boardless creation: re-check no ledger exists; ledger/tie-break signal ownership.
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

   Require `Approach`, `Tasks`, `Blockers`. Small obvious changes may use one-sentence Approach and omit other sections.

9. Immediately re-fetch all REST comments. Create only after confirmed claim or `board: none` with no ledger; use § Repositories' `<owner>/<repo>`, retaining numeric `id` and `html_url`:

   ```sh
   gh api -X POST repos/<owner>/<repo>/issues/<number>/comments -F body=@.tmp-plan-<number>.md --jq '{id, html_url}'
   ```

   Apply § Claim's paginated numeric-id tie-break, including boardless. Multiple pre-existing ledgers: stop as ambiguous; never delete others'. Authorized resume/repair: re-fetch the unique ledger, preserve intervening updates, PATCH its numeric REST id:

   ```sh
   gh api -X PATCH /repos/<owner>/<repo>/issues/comments/<comment-id> -F body=@.tmp-plan-<number>.md
   ```

   Verify stored body and ledger uniqueness via paginated REST. Never use GraphQL ids for REST PATCH/DELETE. Create a fresh temp file per update; retain through POST/PATCH and verification, then remove even on failure. On failure, report it; never claim success.

10. Report issue/ledger links, one-line approach and rejected alternatives, task count, sequence, risks, blockers. Not claimed: reason or `claimed`, and nothing posted.
