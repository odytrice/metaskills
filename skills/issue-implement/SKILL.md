---
name: issue-implement
description: Implement a planned, claimed issue from its plan ledger to a PR in an isolated worktree; also revision rounds on an existing PR. Developer-only; phase 2 of dev-cycle. Requires a plan ledger.
---

# Implement Issue

Execute the plan ledger an architect posted via `issue-plan`; do not plan, review, or merge. Normally dispatched by `dev-cycle`.

Project facts from `AGENTS.md`: **§ Branch Map** (base branch; never assume `main`), **§ Build & Validation** (commands, DB tripwire files, commit convention), **§ Project Board**, **§ Repositories**, **§ Code Layout & Tech Stack** (conventions, migration convention, build-order registration). Missing section: name it and stop.

## Preconditions (stop and report if any fails)

- A plan-ledger comment exists (first line `<!-- plan-ledger -->`). None: report "unplanned"; never create one.
- Board status is in-progress (or § Project Board is `none`). Ready: not claimed. In review / done: owned or finished. Never transition the claim yourself.
- `## Blockers` is `_None._`.

## Rules

- Execute `## Approach` and `## Tasks`. If the approach cannot work or a task is wrong, edit the ledger saying what changed and why before continuing. If the change is a real design decision (competing approaches, migration or backfill, contract or permission change, scope widening), write it in `## Blockers`, stop, and report; that is the architect's.
- The last 20% (ambiguous requirements, edge cases, integration points) is where damage happens: surface, do not guess.
- File edit/write tools for edits, never shell here-strings; the harness search tool for searches.
- You are not alone in the codebase: never revert user or other-agent changes; keep edits inside the issue's (and any given owned) scope; no destructive git commands unless asked.
- Never commit on a § Branch Map integration branch or the user's working branch; always the dedicated worktree.
- The deliverable is a PR; local commits are not completion. Remove the local worktree afterward; leave the remote branch.

## Ledger Updates

Check off a task only once implemented, validated, and in the branch. Re-fetch immediately before editing; edit in place by id (mechanics in `issue-plan` § Workflow step 9); never add a second plan comment.

## Worktree And PR

`<base>` from § Branch Map. Branch `issue-<number>-<short-slug>`.

```sh
git fetch origin <base>
git worktree add -b <branch-name> .worktrees/<branch-name> origin/<base>
```

Branch already exists (revision round, resumed run): `git fetch origin <branch-name>` then `git worktree add .worktrees/<branch-name> <branch-name>`.

Everything (edits, formatting, tests, commits, PR commands) runs inside the worktree; the original checkout stays untouched. When done:

```sh
git status --short
git add <changed-files>
git commit -m "<subject per § Build & Validation commit convention>"
git push -u origin <branch-name>
gh pr create --base <base> --head <branch-name> --title "<title>" --body-file <body-file>
```

PR body: what changed and files touched at a high level; validation commands and results (tripwire suite when it applied); board transition; anything not completed or verified; and, as the final line and nowhere else, exactly one ticket reference: `Closes #<n>` (fully resolves) or `Refs #<n>` (partial).

Verify the closing link registered; an empty array means the merge will not close the issue. Re-edit until it does:

```sh
gh pr view <number> --json closingIssuesReferences --jq '.closingIssuesReferences'
```

Then move the item to in-review (`issue-plan` § Board Status Transitions) and, from the original repo, remove the worktree; before removing, verify the resolved path is inside `.worktrees/` and the worktree is clean, otherwise stop and report.

```sh
git worktree remove .worktrees/<branch-name>
git worktree prune
```

## Flow

1. Read the issue, comments, and ledger; check preconditions. `git status --short`; a dirty checkout is left alone.
2. Create or attach the worktree.
3. Locate code via § Code Layout & Tech Stack and `## Touch Points`.
4. Implement tasks in `## Sequence` order, following the project's layering, error-handling, and state conventions; auth at the boundary; contract mirrors in sync; migration convention and build-order registration. Add or update tests per `## Validation` and whenever behavior changes. Check tasks off as they land. Docs only when part of the behavioral contract or asked; comments sparse.
5. Validate with § Build & Validation for the layers touched, plus the full build when a change crosses layers. Any DB tripwire file touched: run the live-database suite (or confirm the CI job is green) before the PR.
6. Commit, push, open the PR, verify the closing link, move to in-review.
7. No other GitHub writes unless asked; never close issues (the `Closes` link does).
8. Remove the worktree; add a PR comment with cleanup or final validation if not in the body.

## Revision Round

Dispatched with a PR number, the review comment URL, and enumerated findings:

- Attach the existing branch; fix only those findings; no scope widening or surrounding refactors.
- Re-run the validation the findings touch plus what the PR body listed; commit and push to the same branch; update the ledger if a task's state changed.
- Disagree with a finding: leave it unfixed, state the reasoning in a PR comment, report it as contested. The dispatcher decides.

## Return

PR URL, changed paths, ledger fully checked or not, validation output, residual risks, worktree cleanup status. Revision round: commits pushed, findings fixed, findings contested with reasoning, validation output.
