---
name: issue-plan
description: Turn a refined GitHub issue into an execution plan. Use when the user asks to plan an issue, break it into tasks, or prepare it for implementation. Claims the issue on the project board (Ready -> In progress), posts a single living plan-ledger comment on the issue, and keeps that one comment as the source of truth for execution state.
---

# Plan Issue

Use this skill to convert a refined GitHub issue into an execution plan that lives on the issue as a single, continuously updated comment. This is the bridge between refinement (`issue-refine`) and implementation (`dev-cycle`).

This skill plans an issue; it does not implement it. Implementation is `dev-cycle`.

## Project Facts Come From AGENTS.md

This skill contains no project facts. Resolve them at runtime from the repository's `AGENTS.md` (per the harness contract):

- **§ Project Board**: board owner/org, project number, and the `Status` option names in lifecycle order. Look up field/option IDs live via `gh project field-list`; never assume them.
- **§ Repositories**: the app repo slug (`<owner>/<repo>`) used in `gh api` calls.
- **§ Code Layout & Tech Stack**: where backend/frontend/tests/migrations live, for grounding tasks in real paths.

If a section this skill needs is missing from `AGENTS.md`, say so and stop. Do not guess.

## The Plan Comment: One Living Ledger

The plan is a single comment on the issue that holds the task checklist and reflects current execution state. There is exactly one such comment per issue, for its whole lifecycle.

- Never post a second plan comment. Find the existing one and edit it in place.
- Identify it by the marker `<!-- plan-ledger -->` on the first line of the comment body.
- The checklist in this comment is the single source of truth for execution tasks. Do not duplicate it into the issue body; do not maintain a parallel issue-body checklist.
- Blocking questions surface inside this same comment (in a `## Blockers` section), not as new comments.

## Core Rules

- Follow `AGENTS.md`.
- Plan an existing issue. If no issue number/URL is given, ask for it.
- Use `rg` and `AGENTS.md` § Code Layout & Tech Stack to ground tasks in the real codebase; do not invent file paths.
- Do not create branches, commits, PRs, or implementation edits. Your only writes are the plan comment (via a temporary `.tmp-plan-<number>.md` body file) and the project status transition.
- Tasks must be concrete enough for `dev-cycle` to implement and check off individually.
- If the issue is too ambiguous to plan, stop and surface the blocking questions (in chat, or in the comment's `## Blockers` section) rather than inventing scope. Prefer routing genuinely under-specified issues back through `issue-refine` first.
- Plan tasks live in the single ledger comment, not as separate issues. If decomposition reveals the issue is really several issues (too large to be one), do not spin the plan out into loose top-level issues: route it back through `issue-refine`, which keeps this issue as the parent and creates the pieces as native GitHub sub-issues so the parent shows a progress bar. Then plan each child issue individually.

## Claim The Issue (status as lock)

The issue's board status is the claim lock. `issue-plan` only claims issues in `Ready` (use the actual option names from `AGENTS.md` § Project Board), and the move to `In progress` is the claim. This prevents two workers from picking up the same issue.

- The claim is the first mutating action: move the issue `Ready -> In progress` immediately, before decomposing or posting any ledger.
- Claim only from `Ready`. If the issue is in `Backlog`, it is not refined — stop and route it through `issue-refine` first. If it is already `In progress`, `In review`, or `Done` (and not your own prior plan run — an existing plan ledger is the tell), it is owned or finished — stop, report it as already claimed/owned, and do not touch its status or ledger.
- The claim is optimistic: read status, confirm `Ready`, transition to `In progress`, then re-read and confirm the transition took and was not overwritten. If the re-read shows it changed under you, yield and report; do not proceed to plan.
- Only after a confirmed claim do you post the plan ledger. If the project has no board (no § Project Board section content applies), skip the claim and treat the issue as claimable, but still maintain the single ledger.

## Workflow

1. Load the issue and its comments.

   ```powershell
   gh issue view <number-or-url> --json number,title,body,labels,state,url,comments
   ```

   - Check the comments for an existing plan ledger (first body line is `<!-- plan-ledger -->`). If one exists, you are updating it, not creating a new one.

2. Claim the issue (status as lock; only if a project board is in use).
   - If step 1 found an existing plan ledger, this issue is already claimed by a prior plan run; you are updating that ledger, not making a fresh claim. Skip the claim transition and proceed (do not treat your own prior `In progress` as someone else's claim).
   - Otherwise, read the item's current `Status`. If it is not `Ready`, stop: route `Backlog` items through `issue-refine`; report `In progress`/`In review`/`Done` items (with no plan ledger) as already claimed/owned and do not touch them.
   - Move the item `Ready -> In progress`. Resolve `<project-number>` and `<owner>` from `AGENTS.md` § Project Board and look up IDs live:

     ```powershell
     gh project view <project-number> --owner <owner> --format json --jq '.id'
     gh project field-list <project-number> --owner <owner> --format json --jq '.fields[] | select(.name=="Status") | {id, options}'
     gh project item-list <project-number> --owner <owner> --format json --limit 200 --jq '.items[] | select(.content.number==<issue-number>) | {id, status, title}'
     gh project item-edit --project-id <project-id> --id <item-id> --field-id <status-field-id> --single-select-option-id <option-id>
     ```

   - Re-read the item and confirm it is now `In progress`. If it changed under you (someone else claimed it concurrently), yield and report; do not plan it.

3. Build local context.
   - Use `AGENTS.md` § Code Layout & Tech Stack to find the areas the issue touches.
   - Read only what is needed to decompose the work into real, ordered tasks.

4. Decompose into tasks.
   - Break the issue into the smallest individually-implementable, individually-verifiable units.
   - Order them by dependency. Note which tasks can proceed in parallel and which gate others.
   - Each task should map to a concrete code area and a validation signal (from `AGENTS.md` § Build & Validation).

5. Compose the plan comment body in a temporary file `.tmp-plan-<number>.md`. Write it as UTF-8 WITHOUT a BOM; use a file-write tool, not PowerShell 5.1 `Out-File`/`Set-Content` (whose `utf8` encoding adds a BOM that breaks the first-line `<!-- plan-ledger -->` marker match). Use this shape:

   ```md
   <!-- plan-ledger -->
   ## Execution Plan

   _Single source of truth for this issue's tasks. Updated as work lands; do not add more comments._

   - [ ] Task 1: concrete unit, code area, validation
   - [ ] Task 2: ...
   - [ ] Task 3: ...

   ## Sequence

   Dependency order and any parallelizable tasks.

   ## Blockers

   _None._  (Replace with blocking questions if execution cannot proceed.)
   ```

6. Post the single plan comment (only after a confirmed claim).
   - If no plan ledger exists, create it:

     ```powershell
     gh issue comment <number> --body-file .tmp-plan-<number>.md
     ```

   - If a plan ledger already exists, edit that same comment in place by its id (never create a second one). Resolve `<owner>/<repo>` from `AGENTS.md` § Repositories:

     ```powershell
     gh issue view <number> --json comments --jq '.comments[] | select(.body | startswith("<!-- plan-ledger -->")) | .id'
     gh api -X PATCH /repos/<owner>/<repo>/issues/comments/<comment-id> -F body=@.tmp-plan-<number>.md
     ```

   - Remove the temporary file afterward.

7. Report.
   - Link the issue and the plan comment. State the task count, the sequence, and any blockers raised. If the issue could not be claimed, report why (not Ready / already owned) and that no ledger was posted.

## Updating The Ledger During Execution

`dev-cycle` (and any batch-execution worker) updates this same comment as tasks land; it does not edit the issue body checklist and does not add new comments. The contract is: keep the marker as the first line, check off tasks only when they are implemented and validated, surface blockers in `## Blockers`, and re-fetch the comment immediately before editing so concurrent updates are not lost.
