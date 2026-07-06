---
name: burndown
description: Triage, plan, execute, review, and merge a batch of GitHub issues from labels, milestones, issue lists, or a GitHub Projects status/column such as Ready, with a decision ledger, dependency ordering, developer worker delegation, architect PR review, board status transitions as the shared state machine, and validation.
---

# GitHub Issue Burndown

Use this skill for a batch of GitHub issues, not for a single small fix. For one issue, use `dev-cycle`.

This skill contains no project facts. Resolve every project-specific value from the repository's `AGENTS.md`:

- Board owner/org, project number, and the `Status` option names in lifecycle order: **§ Project Board**.
- The base/integration branch for worktrees and PRs: **§ Branch Map**.
- Build, test, lint commands and the DB tripwire file list: **§ Build & Validation**.
- Project-specific review guidance: **§ Review Notes** (owned by `code-review`; do not re-list it here).

If any required section is missing from `AGENTS.md`, say so and stop. Do not guess.

## Inputs

Scope selection, in order of precedence:

- An explicit list of issue numbers.
- A label query, for example `priority:P0 area:api`.
- A milestone.
- A GitHub Projects view, status, or column described by the user.
- If no scope is provided, default to the project board's `Ready` column (board identified in `AGENTS.md` § Project Board).

## Safety

- Do not close, relabel, or reassign issues without clear intent.
- Do not mass-edit issues before the burndown plan is clear.
- Do not push or deploy unless explicitly requested. Merging is governed by the merge policy in Phase 4: squash-merge automatically only when the review is clean (no Critical or High findings) and the `code-review` skill's auto-merge criteria are met; otherwise stop and ask.
- Do not move a project item to `Done` until the linked PR is merged and the issue's requested behavior is actually complete; prefer letting `Closes #<issue-number>` automation do it.
- Do not rewrite an issue body except to check off completed task checkboxes or make an explicitly requested issue edit.
- Work in small batches. If issues are independent, still keep each change scoped and reviewable.

## Coordinator/Worker Model

The coordinator (main context) owns triage, dependency ordering, the decision ledger, sequencing, board status transitions, final review acceptance, merge integration, and user reporting. It stays out of implementation detail.

Fan out one **developer** worker agent per kept issue; each worker runs the `dev-cycle` skill. Fan out one **architect** review agent per PR; each runs the `code-review` skill.

Hard rules:

- The implementer never reviews its own PR. `developer` and `architect` are distinct agents with distinct contexts.
- Never run workers in parallel when their write sets overlap: same files, migrations, DTO/API contracts, routes, frontend state model, or shared test fixtures. Sequence them instead.
- The board `Status` field is the shared state machine. Moving an item out of `Ready` into the in-progress status is the claim; if an issue is not in the expected status when a worker would start, skip it and note why — do not implement it.
- Reviews happen in a separate review worktree with a fresh context that has no implementation history.

Worker guidance:

- Prefer one worker per issue. Split a large issue across workers only when the tasks have disjoint ownership and can be reviewed independently; then the coordinator serializes issue-checklist edits or names one worker as checklist owner.
- Give each worker a narrow prompt: issue number, issue URL/body or task excerpt, expected branch name, owned files or modules, required validation (from `AGENTS.md` § Build & Validation), and the `AGENTS.md` coding rules that matter for that slice.
- Start workers without inherited conversation context unless they genuinely need it; pass only the issue/task facts and relevant file paths.
- Tell workers they are not alone in the codebase, must not revert user or other-agent changes, must check off completed issue checklist tasks as PR work lands, and must report changed paths, checkbox updates, validation run, residual risks, and PR/branch status.
- Keep the coordinator working on non-overlapping coordination while workers run; wait only when a worker result is needed for the next integration step.
- Review each worker's diff before accepting it. Resolve conflicts in the coordinator context, not by asking unrelated workers to touch shared files.

Worker prompt shape (delegated to the `developer` agent):

```text
Use the dev-cycle workflow for issue <number>: <title>.
You own <files/modules>. Do not edit outside that scope without reporting why.
Implement the requested behavior in a dedicated worktree, check off completed issue checklist tasks as the PR work is completed, add focused tests, run <validation>, open a PR with the implementation report and a single ticket reference as the final line of the PR body (`Closes #<issue-number>` when the PR fully resolves the issue, `Refs #<issue-number>` for partial work; no issue references elsewhere in the body or title), clean up the local worktree, and summarize the PR URL, changed paths, issue checkbox updates, validation output, and risks.
You are not alone in the codebase; do not revert user or other-agent changes.
```

### Harnesses without subagents

If the harness cannot spawn subagents, the coordinator may run `dev-cycle` sequentially itself for each issue — **except review**. Review must always run in a fresh context with no implementation history (a new session or a spawned agent), in its own review worktree. Never review from the context that produced the implementation.

## Review-Agent Model

After each worker opens a PR, review it before moving to the next issue:

- Spawn the `architect` agent (review-only; it must not edit product code) to run `code-review` against the PR from a separate review worktree — never the implementation worktree.
- Post the review output as a PR comment.
- If the review has any Critical or High finding, stop automation for that PR and mark the issue as requiring manual intervention in the ledger.
- If the review is clean and the `code-review` skill's auto-merge criteria are met (required checks passed, PR mergeable, no Critical/High findings), the coordinator squash-merges and deletes the remote branch. If any auto-merge criterion is unmet, stop and ask the user; do not force it.
- The coordinator merges; the review agent reports findings and comment status but does not merge.

Review worktree, review checks, PR-comment shape, severity guide, and merge mechanics live in `code-review`; do not re-embed them here. Command shape, with `<base>` from `AGENTS.md` § Branch Map:

```powershell
git fetch origin <base>
git worktree add .worktrees/review-pr-<pr-number> origin/<base>
Set-Location .worktrees/review-pr-<pr-number>
gh pr checkout <pr-number>
```

When the review is posted, from the original repo:

```powershell
git worktree remove .worktrees/review-pr-<pr-number>
git worktree prune
```

Before removing, verify the resolved path is inside the repo's `.worktrees/` directory. If cleanup fails or the worktree is dirty, stop and report the path and reason.

Merge command shape when criteria are met:

```powershell
gh pr merge <pr-number> --squash --delete-branch
```

If branch protection, failed checks, conflicts, or permissions block the merge, stop that item and mark it for manual intervention. The PR body must end with `Closes #<issue-number>` as its final line for fully resolved issues so the merge closes the issue and project automation moves it to `Done`; reference the ticket only there.

## Issue Checklist Updates

Workers keep the issue's task checklist current as PR tasks complete:

- Check off only task lines whose behavior is implemented, tested, and included in the PR branch.
- Do not check off vague umbrella tasks until the full task is complete.
- Re-fetch the current body immediately before editing so concurrent checkbox updates are not lost.
- Preserve all other text exactly; do not rewrite titles, notes, scope, or acceptance criteria.
- Report every checkbox changed in the worker result and the ledger.

If the project keeps tasks in a dedicated plan-ledger comment (per its `AGENTS.md` conventions), edit that single comment in place instead of the issue body — never add a second one. Otherwise edit the issue body checklist with a body file:

```powershell
gh issue view <number> --json body --jq '.body' | Set-Content -NoNewline .tmp-issue-<number>-body.md
# Edit only completed checklist markers from "- [ ]" to "- [x]".
gh issue edit <number> --body-file .tmp-issue-<number>-body.md
Remove-Item .tmp-issue-<number>-body.md
```

## Board Status Workflow

The board and its `Status` option names come from `AGENTS.md` § Project Board. Keep item status synchronized with work state as the shared state machine:

- Move the issue to the in-progress status when implementation begins (this is the claim).
- Move the issue to the in-review status after a PR is raised and linked.
- Let GitHub automation move the issue to the done status after the `Closes #<issue-number>` PR merges.

Look up field and option IDs live; never hardcode them:

```powershell
gh project view <project-number> --owner <owner> --format json --jq '.id'
gh project field-list <project-number> --owner <owner> --format json --jq '.fields[] | select(.name=="Status") | {id, options}'
gh project item-list <project-number> --owner <owner> --format json --limit 200 --jq '.items[] | select(.content.number==<issue-number>) | {id, status, title}'
```

Then update:

```powershell
gh project item-edit --project-id <project-id> --id <item-id> --field-id <status-field-id> --single-select-option-id <option-id>
```

Record each transition in the ledger with timestamp and PR link when applicable. If an issue is not on the board, do not create a duplicate item silently; note it in the ledger and ask first.

## Phase 1: Build The Ledger

Query issues:

```powershell
gh issue list --state open --limit 200 --json number,title,labels,assignees,url
gh issue view <number> --json number,title,body,labels,comments,url
```

For board input (or when no scope was provided), query the project and filter by the requested status/column, defaulting to `Ready`:

```powershell
gh project item-list <project-number> --owner <owner> --format json --limit 200
gh --% project item-list <project-number> --owner <owner> --format json --limit 200 --jq ".items[] | select(.status==\"Ready\") | {number:.content.number,title:.title,labels:.labels,url:.content.url}"
```

If `gh project item-list` reports a missing scope, ask the user to refresh GitHub CLI auth or run:

```powershell
gh auth refresh --hostname github.com -s project
```

Use the board result only as the candidate set; read each issue with `gh issue view` before triage.

Create a decision ledger in `Docs/plans/` when the batch has more than two issues (create the directory if it does not exist). For one or two issues, the board and issue checklists already track state; skip the file.

```text
Docs/plans/YYYY-MM-DD-burndown-<scope>.md
```

Ledger columns:

- Issue.
- Priority.
- Area.
- Decision: do now, defer, split, blocked, duplicate.
- Dependencies.
- Validation required.
- Notes.

## Phase 2: Triage

For each issue:

- Confirm it still applies to current code.
- Identify dependencies and sequencing; order dependent issues before their dependents.
- Split oversized issues if they would produce an unsafe PR.
- Move implementation-only details into tasks if the issue is vague.
- Keep data-integrity, auth, and highest-priority blockers ahead of lower-risk work.
- For board batches, preserve the requested status/column scope; do not silently include items from other columns.

## Phase 3: Execute

For each kept issue, in dependency order:

1. Define the worker scope and dependencies; confirm no write-set overlap with any concurrently running worker.
2. Move the project item to the in-progress status (the claim). If it is no longer in the expected source status, skip it and record why.
3. Spin up a `developer` worker to run `dev-cycle` for the scoped issue/task.
4. Keep changes issue-scoped.
5. Make sure the worker adds tests for the actual behavior being fixed.
6. Make sure the worker checks off completed checklist tasks as PR work lands.
7. Make sure the worker runs the validation required by `AGENTS.md` § Build & Validation — including the live-database integration suite when any DB tripwire file was touched.
8. Review the worker result and diff before accepting it.
9. Record result, changed paths, checkbox updates, validation, and status transition in the ledger.

Suggested branch naming:

```text
issue-<number>-<short-slug>
```

## Phase 4: Review And Integrate

For each PR produced by Phase 3:

1. Create a separate review worktree from the base branch in `AGENTS.md` § Branch Map.
2. Spawn an `architect` agent to run `code-review` against the PR (fresh context, no implementation history).
3. Post the review as a PR comment.
4. If Critical or High findings exist, stop automation for that issue and mark manual intervention in the ledger.
5. If the review is clean and the `code-review` auto-merge criteria are met, squash-merge with remote branch deletion; otherwise stop and ask the user.
6. Rely on `Closes #<issue-number>` automation to close the issue and move it to done.
7. Clean up the review worktree.
8. Update the ledger with PR URL, review comment status, merge status, and cleanup status.
9. Move to the next PR or issue.

Before considering the batch done:

- Run the widest practical validation from `AGENTS.md` § Build & Validation once after the batch if not already covered by per-PR validation.
- Make sure no temporary files, secrets, debug output, or local worktrees remain.
- Update the ledger with final status and links.

## Phase 5: Report

Summarize:

- Completed issues.
- Deferred or blocked issues.
- PRs opened and merged.
- Validation run.
- Remaining risks.
- Recommended next batch.
- Harness feedback: if a review finding recurred across PRs or exposed a missing guardrail, propose a concrete `AGENTS.md` rule or skill-checklist amendment so the next batch does not re-discover it. Treat configuration gaps, not just code bugs, as batch output.

Per-PR risk checks (security, access control, domain-specific correctness) are owned by `code-review`, which works through `AGENTS.md` § Review Notes; do not re-list them here.
