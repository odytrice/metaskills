---
name: code-review
description: Review a PR/branch (separate agent and worktree; posts a comment; squash-merges when criteria hold) or the local uncommitted diff (pre-commit gate; Critical/High blocks). Use when asked to review a PR, branch, diff, or current changes.
---

# Code Review

Project facts from `AGENTS.md`: **§ Branch Map** (base branches; whether merging auto-deploys), **§ Build & Validation** (commands, DB tripwire files, commit convention), **§ Code Layout & Tech Stack**, **§ Review Notes** (project checks and any detail file), **§ Project Board** (done automation). Missing section: name it and stop.

Checks are `checklist.md` (stack-neutral, this directory) plus § Review Notes; output structure and severity ladder are `output-format.md`. Lead with findings; style only where it hides risk.

## Modes

- **PR mode** (given a PR number, URL, or branch): separate agent and review worktree; post the review as a PR comment; squash-merge when the criteria below hold.
- **Local mode** (uncommitted working-tree changes, or a pre-commit gate): review in place, report to the user; any Critical or High finding blocks the commit.

## PR Mode

The reviewer is a different agent from the implementer. If the current agent authored or substantially edited the change, stop and spawn a separate review agent with only the PR number/URL, linked issue, and validation expectations; it does not reuse the implementation worktree or context. The reviewer merges; the caller (user, `dev-cycle`, or `burndown`) records the result and never merges on its behalf.

### Review Worktree

`<base>` is the PR's `baseRefName`, cross-checked against § Branch Map:

```sh
git fetch origin <base>
git worktree add .worktrees/review-pr-<number> origin/<base>
cd .worktrees/review-pr-<number>
gh pr checkout <number>
```

All reads, diffs, and validation run here. After the comment (and any merge), from the original repo:

```sh
git worktree remove .worktrees/review-pr-<number>
git worktree prune
```

Before removing, verify the resolved path is inside the repo's `.worktrees/` and the worktree is clean; otherwise stop and report.

### Process

1. Context: `gh pr view <number> --json title,body,files,commits,baseRefName,headRefName,headRefOid,url`, `gh pr diff <number>`, `gh issue view` for linked issues (the plan ledger is the intended design; judge the diff against it).
2. Read the changed files and enough surrounding context, navigating by § Code Layout & Tech Stack.
3. Apply the relevant `checklist.md` sections plus § Review Notes.
4. Validate where practical with § Build & Validation for the layers touched. A touched DB tripwire file means the live-database suite must have run and passed (CI or locally) before approval.
5. Post the comment per `output-format.md`, headed `**Review complete** -- [View PR](<pr-url>)` (a `View job` link instead when a job URL exists).

### Re-review (revision passes)

When the PR already carries a `**Review complete**` comment from this skill, converge:

- Judge each prior finding **Resolved**, **Partially resolved**, or **Not resolved**, pointing to the commit or hunk.
- New findings only for a regression the fix introduced, or a Critical/High that genuinely threatens release and was not surfacable earlier. No fresh Medium/Low that was equally reviewable before.
- Open with a short **Prior findings** recap; list only still-open findings and new regressions; mark the header as a re-review.
- `dev-cycle` owns the round bound (two revision rounds, then park).

### Squash Merge (the reviewer merges)

Merge when all hold: assessment `Approve`, no Critical/High, no important Medium that should land first; required checks passed and the PR is mergeable; validation revealed nothing production-breaking; the user did not ask for review only; § Branch Map does not say merging triggers a deploy the user wants to time manually.

```sh
gh pr merge <number> --squash --delete-branch
```

Subject: the PR's commit subject if it follows the § Build & Validation convention, otherwise one you write to it. Any criterion unmet: leave the PR open and report which.

### After A Merge

1. **Board.** If § Project Board says done automation is off, move the item to done per `issue-plan` § Board Status Transitions; otherwise leave it to `Closes #n`. If this was the parent's last open sub-issue, note the parent is closeable (do not close it).
2. **Local branch.** `gh pr checkout` left a local head branch. From the original repo, once `gh pr view <number> --json state,mergedAt,headRefOid` confirms the merge and the local tip matches `headRefOid`: `git branch -D <headRefName>`. Otherwise leave it and say why.

Report: comment URL, assessment, merge commit or blocking criterion, board transition, worktree and branch cleanup.

## Local Mode

No worktree or separate agent.

1. `git diff --name-only` and `git diff --cached --name-only` (or the caller's paths). Nothing changed: say so and stop.
2. Map files to § Code Layout & Tech Stack areas; apply the relevant `checklist.md` sections plus § Review Notes.
3. Read the diffs and enough surrounding content.
4. Validate where practical; a touched DB tripwire file means the live-database suite runs before commit.
5. Report to the user per `output-format.md`. Any Critical or High blocks the commit: say so in the Summary ("Commit blocked: <n> Critical/High") and list what must be fixed. Re-review after fixes with the same convergence discipline.
