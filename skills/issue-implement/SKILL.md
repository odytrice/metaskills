---
name: issue-implement
description: Implement a claimed plan ledger in an isolated worktree. Use for initial PR delivery or authorized review revisions.
---

# Implement Issue

Developer-only, normally dispatched by `dev-cycle`: execute the architect's `issue-plan` ledger; never plan, review, or merge.

Project facts from `AGENTS.md`: **§ Branch Map** (base branch; never assume `main`), **§ Build & Validation** (commands, DB tripwire files, commit convention), **§ Project Board**, **§ Repositories**, **§ Code Layout & Tech Stack** (conventions, migration convention, build-order registration). Missing section: name it and stop.

## Preconditions (stop and report if any fails)

- Ledger first line is `<!-- plan-ledger -->`. Missing: report `unplanned`; never create one.
- Explicit mode: **initial** implements the plan and opens a PR; **revision** fixes enumerated findings on the existing PR. PR number alone does not authorize revision.
- Initial requires in-progress. Revision requires in-review, open/unmerged PR, and repo/issue/branch matching the ledger and review comment. Explicit `board: none` skips board operations per `issue-plan`; missing board facts stop. Ready is unclaimed; done/closed is finished. Never claim yourself.
- Require current coordinator claim/resume evidence and ledger REST id/link, or explicit user resume authorization. Ledger alone never authorizes attachment, even boardless: stop as `claimed`.
- `## Blockers` is `_None._`.

## Rules

- Execute `## Approach`/`## Tasks`. Wrong task or unworkable approach: update the ledger with what/why before continuing. Design decisions (competing approaches, migration/backfill, contract/permission change, scope widening) belong to the architect: record in `## Blockers`, stop, report.
- Surface ambiguous requirements, edge cases, and integration points; never guess.
- Use file edit/write tools, not shell here-strings; use harness search tools.
- Stay within issue/owned scope; never revert others' changes or use destructive git commands unless asked.
- Commit only in the dedicated worktree, never on integration or user branches.
- Deliver a PR, not just local commits; remove the worktree afterward, retain the remote branch.

## Ledger Updates

Check tasks off only when implemented, validated, and in-branch. Re-fetch immediately before editing in place by id per `issue-plan` § Workflow step 9; never add another ledger.

## Worktree And PR

`<base>` from § Branch Map. Branch `issue-<number>-<short-slug>`.

```sh
git fetch origin <base>
git worktree add -b <branch-name> .worktrees/<branch-name> origin/<base>
```

Existing branch (authorized revision/resume only): `git fetch origin <branch-name>`, then `git worktree add .worktrees/<branch-name> <branch-name>`. Missing local branch: create tracking the fetched remote. Before revision edits require local tip = current PR `headRefOid`; only fast-forward a clean behind branch. Divergence/unexpected local commits: stop, never reset.

Run edits, formatting, tests, commits, and PR commands inside the worktree; leave original checkout untouched. Initial delivery:

```sh
git status --short
git add <changed-files>
git commit -m "<subject per § Build & Validation commit convention>"
git push -u origin <branch-name>
gh pr create --base <base> --head <branch-name> --title "<title>" --body-file <body-file>
```

PR body: high-level changes/paths; validation commands/results including applicable tripwire suite; board transition or `board: none`; unverified items. Final line, nowhere else: exactly one `Closes #<n>` for the intended consuming-repo issue. This skill/`dev-cycle` deliver fully resolving PRs only: incomplete scope means blockers and plan repair/approved split, never partial `Refs` delivery. Unrelated `code-review` PRs are exempt.

Require exactly one registered closing issue with canonical URL equal to the loaded issue URL, including repo identity; nonempty/matching number is insufficient. Wrong/extra/missing references block handoff: correct and re-fetch. If the configured base prevents registration, report the blocker, never loop indefinitely:

```sh
gh pr view <number> --json closingIssuesReferences --jq '.closingIssuesReferences'
```

Move to in-review per `issue-plan` § Board Status Transitions. From the original repo, remove only a clean worktree whose resolved path is inside its `.worktrees/`; otherwise stop/report:

```sh
git worktree remove .worktrees/<branch-name>
git worktree prune
```

## Flow

1. Read issue and all REST comments/ledger per `issue-plan`; check mode preconditions. `git status --short`; leave dirty checkout alone. Revision: follow § Revision Round, not initial flow below.
2. Create or attach the worktree.
3. Locate code via § Code Layout & Tech Stack and `## Touch Points`.
4. Implement in `## Sequence` order: project layering/error/state conventions, boundary auth, synchronized contract mirrors, migration convention, build-order registration. Test per `## Validation` and for behavior changes; check off per Ledger Updates. Docs only for behavioral contracts or requests; sparse comments.
5. Run § Build & Validation for touched layers; cross-layer changes require full build. Touched DB tripwire: live-database suite must pass locally or in CI before PR.
6. Complete § Worktree And PR, including closing-link verification, in-review, and cleanup. Comment cleanup/final validation if absent from body. No other GitHub writes unless asked; never close issues yourself (`Closes` does).

## Revision Round

Require explicit revision dispatch: PR number, issue URL, ownership evidence, ledger REST id/link, review comment URL, enumerated findings. Apply revision preconditions, not initial in-progress:

- Attach existing branch; fix only supplied findings, no scope widening or surrounding refactors.
- Re-run affected validation plus PR-body checks; commit/push same branch; update changed ledger task states.
- Re-verify exact intended closing reference; retain in-review or report `board: none`. No new PR/re-claim; apply initial cleanup safety checks.
- Disagreement: leave finding unfixed, explain in a PR comment, report contested; dispatcher decides.

## Return

PR URL, changed paths, ledger fully checked or not, validation output, residual risks, worktree cleanup status. Revision round: commits pushed, findings fixed, findings contested with reasoning, validation output.
