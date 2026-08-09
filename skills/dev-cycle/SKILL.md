---
name: dev-cycle
description: Execute a GitHub issue or focused change from issue context through GitHub Projects status updates, an isolated git worktree, implementation, validation, PR creation, worktree cleanup, and a clear completion summary.
---

# Dev Cycle

Use this skill for one focused GitHub issue, bug, feature, or cleanup task that should be implemented rather than merely planned.

## Project Facts Come From AGENTS.md

This skill contains no project facts. Resolve them at runtime from the repository's `AGENTS.md` (per the harness contract):

- **§ Branch Map**: the base branch for worktrees and PRs. This is the single source of truth; never assume `main` or any other default.
- **§ Build & Validation**: the exact build/test/lint/format commands per layer, and the **DB tripwire files** list.
- **§ Project Board**: board owner/org, project number, and `Status` option names in lifecycle order.
- **§ Repositories**: the app repo slug and issue template path.
- **§ Code Layout & Tech Stack**: where the code lives and the architectural conventions to follow.

If a section this skill needs is missing from `AGENTS.md`, say so and stop. Do not guess.

## Inputs

- GitHub issue number or URL (with its plan-ledger comment, when one exists).
- A direct user request.
- A batch decision-ledger/plan file, when one is supplied.
- A failing build/test/lint output.

## Core Rules

- Follow `AGENTS.md`.
- Use GitHub for issue and PR workflow.
- Use `rg` first for searches.
- Do not overwrite user changes.
- Keep edits scoped.
- Reserve agent autonomy for well-specified work. The dangerous part of a change is the last 20%; ambiguous requirements, edge cases, integration points, and architectural trade-offs. If requirements are ambiguous, a business-logic assumption is required, or a structural trade-off surfaces mid-implementation, stop and surface it rather than inventing scope. Code that looks right and passes basic tests but encodes a wrong assumption is worse than an honest blocker.
- Use file edit/write tools for manual edits, never shell here-strings.
- Follow the project's host-side vs. service-internal config conventions in `AGENTS.md` (e.g. no `localhost` where a loopback IP or service name is required).
- Never use destructive git commands unless explicitly requested.
- Do not implement or commit directly on any integration branch listed in `AGENTS.md` § Branch Map, or on the user's active working branch.
- Create a dedicated git worktree and branch before implementation begins.
- The deliverable is a GitHub PR. If a PR cannot be created, report the blocker instead of treating local commits as complete.
- Clean up the local worktree after the PR is created; do not delete the remote PR branch as part of cleanup.

## Plan Ledger Coordination

Do not silently assume the `issue-plan` skill ran. Check the issue's comments for a plan-ledger comment (first body line is `<!-- plan-ledger -->`):

- **Ledger exists**: its checklist is the task list to execute. The issue was already claimed and moved to `In progress` by `issue-plan`; do not repeat that transition. Track progress in that one comment: check tasks off as they are implemented, tested, and included in the branch; surface execution blockers in its `## Blockers` section. Re-fetch the comment immediately before editing so concurrent updates are not lost; edit it in place, never add a second plan comment.
- **No ledger**: for a well-specified small task, proceed; this skill then owns the `In progress` transition itself (move the board item to `In progress` before implementation edits begin, using the status-as-lock discipline: only claim from `Ready`, re-read to confirm the transition took). For anything under-specified, stop and run `issue-plan` (or `issue-refine`) first rather than opening a worktree to produce plausible-looking code on an ambiguous task.

## Worktree And PR Workflow

Resolve the base branch from `AGENTS.md` § Branch Map (call it `<base>` below). Use a dedicated worktree for every implementation:

```powershell
git fetch origin <base>
git worktree add -b issue-<number>-<short-slug> .worktrees/issue-<number>-<short-slug> origin/<base>
```

If the user specifies a different base, use that instead. If the branch already exists, attach it to a worktree instead of creating a duplicate branch:

```powershell
git worktree add .worktrees/<branch-name> <branch-name>
```

Run all implementation, formatting, tests, commits, and PR commands from inside the worktree. Keep the original checkout untouched except for coordination.

When the implementation is complete:

```powershell
git status --short
git add <changed-files>
git commit -m "<short imperative message>"
git push -u origin <branch-name>
gh pr create --base <base> --head <branch-name> --title "<title>" --body-file <body-file>
```

The PR body is the durable implementation report. Include the change summary, validation results, risks, and any incomplete work there. Reference the ticket exactly once, as the final line of the PR body: `Closes #<issue-number>` when the PR fully resolves the issue (so GitHub associates the PR, closes the issue on merge, and project automation can move it to `Done`), or `Refs #<issue-number>` for partial work. Do not mention the issue number anywhere else in the PR body or title.

After opening (or editing) a `Closes` PR, verify GitHub actually registered the closing link:

```powershell
gh pr view <number> --json closingIssuesReferences --jq '.closingIssuesReferences'
```

If the array is empty, the merge will NOT close the issue (this has happened even with a correct final line, e.g. when the body was edited around creation time). Re-edit the PR body until the reference registers; do not rely on the text alone.

After the PR is created and the worktree has no uncommitted changes, remove the local worktree from the original repo:

```powershell
git worktree remove .worktrees/<branch-name>
git worktree prune
```

Before removing a worktree, verify the resolved path is inside the repo's `.worktrees/` directory. If cleanup fails or the worktree is dirty, stop and report the path and reason.

## GitHub Projects Status

If the project uses a board (see `AGENTS.md` § Project Board), keep the issue item status synchronized:

- If `issue-plan` already moved the issue to `In progress` (a plan ledger exists), do not repeat that transition; otherwise this skill moves it to `In progress` before implementation begins.
- Move the issue to `In review` once the PR exists and is linked to the issue.

Look up the live field/option IDs; never hardcode them. Resolve `<project-number>` and `<owner>` from § Project Board:

```powershell
gh project view <project-number> --owner <owner> --format json --jq '.id'
gh project field-list <project-number> --owner <owner> --format json --jq '.fields[] | select(.name=="Status") | {id, options}'
gh project item-list <project-number> --owner <owner> --format json --limit 200 --jq '.items[] | select(.content.number==<issue-number>) | {id, status, title}'
gh project item-edit --project-id <project-id> --id <item-id> --field-id <status-field-id> --single-select-option-id <option-id>
```

If the issue is not in the project, do not create a duplicate item silently; note it in the PR body and ask before changing the project. If `gh project` reports missing scope, ask the user to run `gh auth refresh --hostname github.com -s project`.

## Flow

1. Understand the task.
   - Read the GitHub issue with `gh issue view <number> --json ...,comments` when applicable, including the plan-ledger comment if one exists; its checklist is the task list to execute.
   - Read linked docs, plans, and PRs.
   - Check `git status --short` before editing.
   - If the current checkout is dirty, do not use it for implementation; preserve it and create the worktree from the selected base.
   - Assess specification quality before writing code (see the last-20% Core Rule and Plan Ledger Coordination).

2. Confirm ownership before implementing (if a project board is in use).
   - `In progress` with a plan ledger: claimed and planned; proceed, do not re-transition.
   - `Ready` (or `In progress` with no ledger but assigned to you / handed to you directly): claim it yourself per Plan Ledger Coordination.
   - `In review` or `Done`, or a plan ledger showing another worker's ownership: owned or finished; stop and report; do not steal it.
   - With no project board, treat the presence of a plan ledger (or an explicit user request) as the go-ahead and track state in the ledger only.

3. Create the implementation worktree.
   - Choose a branch name before editing.
   - Create or attach the worktree under `.worktrees/<branch-name>` from the § Branch Map base.
   - Switch all subsequent file reads, edits, and validation commands to the worktree path.

4. Locate the code.
   - Use `AGENTS.md` § Code Layout & Tech Stack to find the relevant backend, frontend, migration, deployment, and docs areas.

5. Choose the smallest correct change.
   - Follow the layering, purity, and error-handling conventions in `AGENTS.md`.
   - Keep handlers thin and enforce auth/access control at the boundary.
   - Keep any cross-language DTO or contract mirrors in sync, per `AGENTS.md`.
   - Keep frontend state in the project's existing state/store patterns.

6. Implement.
   - Add or update tests when behavior changes.
   - For schema changes, add a migration following the project's migration convention; list the migrations directory first to pick the next number, never trust spec numbers.
   - Register any new compiled files in the project's build/compile order, per `AGENTS.md` (e.g. `.fsproj` compile order).
   - As each plan-ledger task lands, check it off in the plan comment (see Plan Ledger Coordination).
   - Update docs only when they are part of the behavioral contract or the user asked.
   - Keep comments sparse and useful.

7. Validate.
   - Run the commands from `AGENTS.md` § Build & Validation for the layers you changed, and the full-app build when a change crosses layers and tooling is available.
   - **DB tripwire**: if any file in the § Build & Validation DB tripwire list was touched, also run the live-database integration suite locally (using the commands given there), or confirm the CI integration job is green, before opening the PR.

8. Commit, push, and open the PR.
   - Commit only from the implementation worktree, then push and create the PR against the § Branch Map base.
   - Put the implementation report in the PR body, ending with the single ticket reference as the final line (see Worktree And PR Workflow), and verify the closing link registered.
   - Move the board item to `In review` after the PR exists (if a project board is in use).

9. Update GitHub when asked or when the workflow clearly calls for it.
   - Use `gh issue comment` for implementation notes.
   - Use `gh issue edit` to adjust labels/assignee only when requested.
   - Do not close issues unless the user explicitly asks or the repo workflow says to.

10. Clean up the local worktree.
    - Remove the implementation worktree after the PR exists and the worktree is clean, verifying path safety first.
    - Leave the remote PR branch intact.
    - Add a PR comment with cleanup status or final validation results if not already captured in the PR body.

## Branch And Commit Guidance

Branch name for issue work:

```text
issue-<number>-<short-slug>
```

For direct requests without an issue:

```text
change-<short-slug>
```

Commit messages must follow `AGENTS.md`:

- Single line.
- Lowercase imperative mood.
- No trailing period.
- Aim under 72 characters.
- Match the style of recent commits in the repository.

## Completion Summary

The PR body must contain:

- What changed and files touched at a high level.
- Validation commands and results (including the DB tripwire suite result when it applied).
- GitHub Project status transition result (or note it was not applicable).
- Anything not completed or not verified.
- The single ticket reference as the final line (see Worktree And PR Workflow).

The chat final should be brief and point to the PR URL, plus note whether the local worktree cleanup succeeded.
