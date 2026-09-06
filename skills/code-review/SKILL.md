---
name: code-review
description: Review PRs for merge or local changes for commit readiness. Use when asked to review a PR, branch, diff, or current changes.
---

# Code Review

Select mode first. Both require `AGENTS.md` **§ Build & Validation** (commands, DB tripwires, commit convention), **§ Code Layout & Tech Stack**, **§ Review Notes** (checks/detail file). PR additionally requires **§ Repositories**, **§ Branch Map** (bases, auto-deploy), **§ Project Board** (done automation). Missing required section: name it and stop.

Use this directory's `checklist.md` plus § Review Notes; `output-format.md` defines output/severity. Findings first; style only where it hides risk.

PR: explicit `board: none` skips board operations per `issue-plan` § Board Status Transitions; missing facts stop. Local: no board config/operations. Standalone partial PRs are allowed; transition only issues this PR actually closes, never mere references.

## Modes

- **PR mode** (PR number/URL/branch): independent agent/worktree, PR comment, conditional squash-merge.
- **Local mode** (no target, uncommitted changes, pre-commit gate): in-place review, user report; any Critical/High blocks commit.

## PR Mode

Reviewer must differ from implementer. If you authored/substantially edited the change, stop and spawn a reviewer with only PR number/URL, linked issue, validation expectations; never reuse implementation context/worktree. Reviewer alone merges; caller (user, `dev-cycle`, `burndown`) only records results.

### Review Worktree

Capture `<reviewed-sha>` = `headRefOid`, `<base-sha>` = `baseRefOid`, `<base>` = `baseRefName`; cross-check base against § Branch Map. Verify `origin` matches § Repositories' PR base repo; scope number-based `gh` commands there. Fetch PR head ref (also for forks); require captured SHA match before detached checkout:

```sh
git fetch origin <base>
git fetch origin refs/pull/<number>/head
git rev-parse FETCH_HEAD
git worktree add --detach .worktrees/review-pr-<number> <reviewed-sha>
```

Require worktree `git rev-parse HEAD` = `<reviewed-sha>` and both captured commits available. All reads/diffs/validation run here using `git diff <base-sha>...<reviewed-sha>`, never moving `gh pr diff`. Fetch/head mismatch: fresh metadata and review, never substitute newer SHA. After comment/any merge, from original repo:

```sh
git worktree remove .worktrees/review-pr-<number>
git worktree prune
```

Remove only a clean worktree whose resolved path is inside the repo's `.worktrees/`; otherwise stop/report.

### Process

1. `gh pr view <number> --json title,body,baseRefName,baseRefOid,headRefName,headRefOid,url,closingIssuesReferences`; capture SHAs before checkout. Read pinned-range paths/commits, linked issues, and paginated REST ledger comments per `issue-plan`; ledger = intended design.
2. Read changed files and surrounding context via § Code Layout & Tech Stack; apply relevant checklist/Review Notes.
3. Validate touched layers where practical per § Build & Validation. Touched DB tripwire: live-database suite must pass locally or in CI before approval.
4. Post per `output-format.md`, header `**Review complete** -- [View PR](<pr-url>)` (use `View job` if job URL exists), naming reviewed head/base SHAs. Re-fetch metadata; changed head requires fresh pinned checkout, validation, re-review before approval/merge. Never transfer approval to a new SHA.

### Re-review (revision passes)

Existing `**Review complete**` comment: converge.

- Classify each prior finding **Resolved**, **Partially resolved**, or **Not resolved**, citing commit/hunk.
- New findings only: fix-induced regressions or release-threatening Critical/High not surfacable earlier. No previously reviewable new Medium/Low.
- Open with **Prior findings** recap; list only open findings/new regressions; label header re-review.
- `dev-cycle` bounds revisions: two, then park.

### Squash Merge (the reviewer merges)

Merge only if `Approve`, no Critical/High or important pre-merge Medium, required checks passed, PR mergeable, no production-breaking validation, no review-only request, and no § Branch Map auto-deploy the user wants to time manually.

```sh
gh pr merge <number> --repo <repo-slug> --squash --match-head-commit <reviewed-sha>
```

Immediately before merge re-fetch head/base and reviewed-head required checks. Changed head/base or head-match rejection: refresh pinned review/validation, never just retry a newer SHA. Use PR commit subject if it meets § Build & Validation convention; otherwise write one that does. Unmet criterion: leave open and report it.

### After A Merge

1. **Board.** `board: none`: skip/report. Otherwise verify registered closing issues are closed. Automation off: move only closed issues to done per `issue-plan` § Board Status Transitions. Automation on: verify with the same complete lookup; report pending/failure honestly. Last open sub-issue: note parent closeable, never close it.
2. **Branches.** Detached checkout creates no local head branch. Preserve pre-existing user/implementation branches; never use `--delete-branch`. Remote cleanup belongs to repository automation or a separate explicit request.

Report: comment URL, assessment, merge commit or blocking criterion, board transition, worktree and branch cleanup.

## Local Mode

No worktree or separate agent.

1. `git diff --name-only` and `git diff --cached --name-only` (or caller's paths). No changes: report/stop.
2. Map files via § Code Layout & Tech Stack; read diffs/surroundings and apply relevant checklist/Review Notes.
3. Validate where practical; touched DB tripwire requires live-database suite before commit.
4. Report per `output-format.md`. Any Critical/High blocks commit: Summary says "Commit blocked: <n> Critical/High" and lists required fixes. Re-review with the same convergence discipline.
