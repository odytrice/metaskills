---
name: burndown
description: Triage, plan, execute, review, and merge a batch of GitHub issues from labels, milestones, issue lists, or a GitHub Projects status/column such as Ready, with a decision ledger, dependency ordering, developer worker delegation, architect PR review, board status transitions as the shared state machine, validation, and a closing QA sweep that exercises the merged work and files regressions back to the backlog.
---

# GitHub Issue Burndown

Use this skill for a batch of GitHub issues, not for a single small fix. For one issue, use `dev-cycle`.

This skill contains no project facts. Resolve every project-specific value from the repository's `AGENTS.md`:

- Board owner/org, project number, and the `Status` option names in lifecycle order: **§ Project Board**.
- The base/integration branch for worktrees and PRs: **§ Branch Map**.
- Build, test, lint commands and the DB tripwire file list: **§ Build & Validation**.
- Project-specific review guidance: **§ Review Notes** (owned by `code-review`; do not re-list it here).
- QA target environment and login for the closing QA sweep: **§ Environments** and **§ Agent Login** (owned by `quality-assurance`/`agent-login`). These are needed only for Phase 5; if the project has no running app to test, that phase is skipped with a note rather than stopped.

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
- Do not push or deploy unless explicitly requested. Merging is governed by the merge policy in Phase 4: squash-merge automatically only when the review is clean (no Critical or High findings) and the `code-review` skill's auto-merge criteria are met; when it is not clean, run the bounded revision loop in Phase 4 (at most two fix-and-re-review rounds) and never loop past that cap. A PR still blocked after the cap does not halt the batch: park it as manual intervention in the ledger and move on to the next non-blocking item, surfacing it in the Phase 6 report.
- Do not move a project item to `Done` until the linked PR is merged and the issue's requested behavior is actually complete; prefer letting `Closes #<issue-number>` automation do it.
- Do not rewrite an issue body except to check off completed task checkboxes or make an explicitly requested issue edit.
- Work in small batches. If issues are independent, still keep each change scoped and reviewable.

## Coordinator/Worker Model

The coordinator (main context) owns triage, dependency-graph construction, wave planning, the decision ledger, board status transitions, final review acceptance, merge integration, and user reporting. It stays out of implementation detail.

Fan out one **developer** worker agent per kept issue; each worker runs the `dev-cycle` skill. Fan out one **architect** review agent per PR; each runs the `code-review` skill. After the batch is integrated, spawn one **quality-assurance** agent for the closing QA sweep (Phase 5).

Hard rules:

- The implementer never reviews its own PR. `developer` and `architect` are distinct agents with distinct contexts.
- Parallelism is the default, not the exception. The coordinator builds a dependency graph (Phase 2), partitions the kept issues into ordered waves, and runs every issue in a wave concurrently. Two bounds cap concurrency, and nothing else does:
  1. **Dependency edges.** An issue waits until every issue it depends on is merged, so it always lands in a later wave than its prerequisites.
  2. **Write-set overlap.** Issues touching the same files, migrations, DTO/API contracts, routes, frontend state model, or shared test fixtures must never run concurrently; the coordinator serializes them into different waves even when no dependency edge forces it. When in doubt about overlap, serialize.
- The board `Status` field is the shared state machine. Moving an item out of `Ready` into the in-progress status is the claim; if an issue is not in the expected status when a worker would start, skip it and note why; do not implement it.
- Reviews happen in a separate review worktree with a fresh context that has no implementation history.
- Each issue still completes its full cycle (dev-cycle, review, review-fixes, integration) before anything that depends on it starts. Parallelism widens each wave; it does not leave a wave's PRs dangling open while dependent work begins.

Worker guidance:

- Prefer one worker per issue. Split a large issue across workers only when the tasks have disjoint ownership and can be reviewed independently; then the coordinator serializes issue-checklist edits or names one worker as checklist owner.
- Launch a wave's workers together in a single dispatch rather than dripping them out one at a time, so the wave actually runs in parallel. The coordinator holds the wave boundary: it does not open the next wave until this wave's gating PRs are merged.
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

If the harness cannot spawn subagents, the coordinator may run `dev-cycle` sequentially itself for each issue. Review is the exception: it must always run in a fresh context with no implementation history (a new session or a spawned agent), in its own review worktree. Never review from the context that produced the implementation.

## Review-Agent Model

After each worker opens a PR, review it before moving to the next issue:

- Spawn the `architect` agent (review-only; it must not edit product code) to run `code-review` against the PR from a separate review worktree; never the implementation worktree.
- Post the review output as a PR comment.
- If the review has any Critical or High finding, do not stop outright and do not loop without limit: run the bounded revision loop (Phase 4). Dispatch the `developer` agent to fix the specific findings, then re-review from a fresh `architect` context scoped to those findings. Allow at most two such rounds; if the PR is still not clean after the second re-review, or a finding is contested between the two agents, park that PR as manual intervention in the ledger and move on to the next non-blocking issue or PR; do not halt the batch to wait on it.
- If the review is clean and the `code-review` skill's auto-merge criteria are met (required checks passed, PR mergeable, no Critical/High findings), the coordinator squash-merges, deletes the remote branch, and deletes the local PR head branch. If any auto-merge criterion is unmet, do not force it: leave the PR for the user to merge, note it in the ledger, and move on to the next non-blocking item rather than halting the batch.
- The coordinator merges; the review agent reports findings and comment status but does not merge.

Review worktree, review checks, PR-comment shape, severity guide, re-review convergence, and merge mechanics live in `code-review`; do not re-embed them here. Command shape, with `<base>` from `AGENTS.md` § Branch Map:

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

After a confirmed merge, delete the local PR head branch too, so the batch leaves no dangling branches. `--delete-branch` removes only the remote branch, and `git worktree remove` leaves behind the local branch that `gh pr checkout` created in the review worktree. From the original repo:

```powershell
gh pr view <pr-number> --json state,headRefName
git branch -D <headRefName>
```

Delete it only once GitHub confirms the PR is merged; force deletion (`-D`) is expected for squash merges. If the branch is still checked out in a worktree or the PR is not confirmed merged, leave it and note it.

If branch protection, failed checks, conflicts, or permissions block the merge, park that item as manual intervention and move on to the next non-blocking item; do not halt the batch. The PR body must end with `Closes #<issue-number>` as its final line for fully resolved issues so the merge closes the issue and project automation moves it to `Done`; reference the ticket only there.

## Issue Checklist Updates

Workers keep the issue's task checklist current as PR tasks complete:

- Check off only task lines whose behavior is implemented, tested, and included in the PR branch.
- Do not check off vague umbrella tasks until the full task is complete.
- Re-fetch the current body immediately before editing so concurrent checkbox updates are not lost.
- Preserve all other text exactly; do not rewrite titles, notes, scope, or acceptance criteria.
- Report every checkbox changed in the worker result and the ledger.

If the project keeps tasks in a dedicated plan-ledger comment (per its `AGENTS.md` conventions), edit that single comment in place instead of the issue body; never add a second one. Otherwise edit the issue body checklist with a body file:

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
- Write set: the files/migrations/contracts/routes/state/fixtures the issue touches, used to detect overlap.
- Wave: the execution wave assigned in Phase 2.
- Validation required.
- Notes.

## Phase 2: Triage

For each issue:

- Confirm it still applies to current code.
- Identify dependencies and sequencing; order dependent issues before their dependents.
- Split oversized issues if they would produce an unsafe PR. When you split, keep the original issue as the parent and create each piece as a native GitHub sub-issue of it (the same parent-plus-sub-issues shape `issue-refine`/`issue-raise` use), so the parent shows a progress bar; never dissolve it into disconnected top-level issues. Link a child with `$childId = gh api repos/<owner>/<repo>/issues/<child-number> --jq '.id'` then `gh api --method POST repos/<owner>/<repo>/issues/<parent-number>/sub_issues -F sub_issue_id=$childId`.
- Move implementation-only details into tasks if the issue is vague.
- Keep data-integrity, auth, and highest-priority blockers ahead of lower-risk work.
- For board batches, preserve the requested status/column scope; do not silently include items from other columns.

### Dependency graph and waves

After triaging the kept issues, build the execution plan before any implementation starts. This is what makes the batch run in parallel safely.

1. For each kept issue, record two things in the ledger: its hard **dependencies** (issues whose merged output it needs) and its **write set** (files, migrations, DTO/API contracts, routes, frontend state model, shared test fixtures). Derive the write set from the issue scope plus a quick `rg` over the areas it touches (grounded in `AGENTS.md` § Code Layout & Tech Stack).
2. Build a dependency graph from those edges. Add an edge between any two issues whose write sets overlap even if neither strictly depends on the other, so overlap is scheduled exactly like a dependency.
3. Partition the graph into ordered **waves**. Wave 1 is every issue with no unmet dependency and no unresolved overlap; each later wave is the issues whose graph edges all resolve to earlier waves. By construction, issues within a wave share no edges, so they are safe to run concurrently.
4. Record each issue's wave in the ledger. A dependency cycle or an edge you cannot order is a planning smell: break it by splitting an issue (keep the original as the parent and create sub-issues, per the split rule above) or surface it to the user, rather than guessing an order.
5. Sequence the waves themselves by risk and priority where there is freedom: put data-integrity, auth, and blocking foundational issues in the earliest wave their edges allow.

## Phase 3: Execute

Execute wave by wave, in wave order. Within a wave, run all issues concurrently; do not open a wave until every earlier-wave issue it depends on is merged (Phase 4). Each issue completes its full cycle (dev-cycle, review, review-fixes, integration) before dependent work starts, so a wave's PRs are not left open while the next wave's dependent issues begin.

For each wave:

1. Confirm the wave is unblocked: every dependency of every issue in it has merged. Re-confirm no two issues in the wave have overlapping write sets; if triage missed an overlap, pull the later issue into a subsequent wave before starting.
2. For every issue in the wave, move its project item to the in-progress status (the claim). Skip and record any issue no longer in the expected source status, and drop anything that depended on it (or re-plan it into a later wave).
3. Fan out the wave's `developer` workers in one dispatch: one worker per issue running `dev-cycle`, all in parallel, each with a narrow non-overlapping scope.
4. For each worker, ensure it keeps changes issue-scoped, adds tests for the actual behavior fixed, checks off completed checklist tasks as PR work lands, and runs the validation required by `AGENTS.md` § Build & Validation, including the live-database integration suite when any DB tripwire file was touched.
5. Review each worker's result and diff before accepting it.
6. Hand the wave's PRs to Phase 4 for review and integration. The next wave starts only after this wave's gating PRs are merged.
7. Record per issue: result, wave, changed paths, checkbox updates, validation, and status transition in the ledger.

To maximize throughput, keep independent work flowing across wave boundaries: as soon as an issue's prerequisites are all merged, it is eligible to start even if unrelated long-running workers in an earlier wave are still going. A parked or failed issue (Phase 4) blocks only its own dependents; promote every still-eligible issue rather than stalling the batch on one blocker.

Suggested branch naming:

```text
issue-<number>-<short-slug>
```

## Phase 4: Review And Integrate

Review and integrate each wave's PRs. A wave typically opens several PRs at once, so review them concurrently: spawn one `architect` review agent per PR, each in its own review worktree with a fresh context (never share a worktree between reviews). Integrate a wave before opening the next wave that depends on it; independent later-wave work may proceed in parallel once its own prerequisites are merged. A PR that cannot be auto-resolved never halts the batch; park it and move on to the next non-blocking item (see the Bounded Revision Loop); its dependents are parked with it, but unrelated waves keep flowing. For each PR:

1. Create a separate review worktree from the base branch in `AGENTS.md` § Branch Map.
2. Spawn an `architect` agent to run `code-review` against the PR (fresh context, no implementation history). This is review round 1.
3. Post the review as a PR comment.
4. If Critical or High findings exist, enter the Bounded Revision Loop below instead of stopping immediately or re-reviewing without limit.
5. If the review is clean and the `code-review` auto-merge criteria are met, squash-merge with remote branch deletion. If it is clean but a criterion is unmet (checks pending, branch protection, merge conflict), leave it for the user to merge, note that in the ledger, and move on; do not block the batch waiting on it.
6. Rely on `Closes #<issue-number>` automation to close the issue and move it to done.
7. Clean up the review worktree (and any revision-round worktrees), and delete the merged PR's local head branch so no dangling branch remains (see Review-Agent Model).
8. Update the ledger with PR URL, the review round reached and loop-exit reason, review comment status, merge status, and cleanup status.
9. Move to the next non-blocking PR or issue.

### Bounded Revision Loop

This is the guardrail against the `developer` and `architect` ping-ponging a PR indefinitely. The coordinator owns the loop and its round counter; neither agent re-triggers the cycle on its own.

- **Cap.** At most two revision rounds per PR: review round 1, then at most rounds 2 and 3. Track the current round in the ledger.
- **A round.** When a review returns Critical or High findings and the cap is not yet reached:
  1. Dispatch the `developer` agent to fix only the specific findings raised, in the existing PR branch. Give it the review comment (or the enumerated findings), tell it to stay scoped to them with no unrelated changes, and to re-run the validation from `AGENTS.md` § Build & Validation.
  2. Re-review from a fresh `architect` context, with the review worktree rebuilt against the PR's latest head, pointing it at the prior review comment on the PR and telling it this is a scoped re-review of revision round N.
- **Scoped re-review (convergence).** A re-review is not a fresh full review; it follows the `code-review` skill's Re-review discipline: verify each prior finding as Resolved / Partially resolved / Not resolved, and raise new findings only for regressions the fix introduced or genuinely missed Critical/High issues, never fresh Medium/Low nitpicks. The convergence rule is `code-review`'s and applies to every re-review; the two-round cap here is burndown's own bound on top of it.
- **Contested finding.** If the `developer` reports that it disagrees with a finding (believes it is wrong or out of scope) instead of fixing it, or the `architect` re-raises a finding the developer already reported as fixed, do not spend another round on it; it is a judgment dispute for the human.
- **Park, don't halt.** When the loop exits without a clean PR because the cap was reached with Critical/High findings still open or a finding was contested, park that PR as manual intervention in the ledger (record the round reached, the exit reason, and, for a dispute, both positions), then move on to the next non-blocking item. Do not stop the batch or wait on the user mid-run. A parked PR blocks anything that depends on it: park those dependents too and continue with independent work. The clean exit is the only one that proceeds to merge (step 5); everything parked is surfaced in the Phase 6 report.

Before considering the batch done:

- Run the widest practical validation from `AGENTS.md` § Build & Validation once after the batch if not already covered by per-PR validation.
- Make sure no temporary files, secrets, debug output, local worktrees, or merged-PR local branches remain.
- Update the ledger with final status and links.

## Phase 5: QA Sweep

After the batch is integrated, exercise the behavior the batch actually changed and file any bugs that surface. This is a discovery pass, not a gate: the PRs are already merged, so QA never reverts them; confirmed bugs become new work. If no PRs merged this batch, there is nothing newly deployed to exercise; skip this phase and say so.

Resolve the QA target and auth from `AGENTS.md` § Environments and § Agent Login. If the project has no running app to test (neither applies), skip this phase and note it in the report; do not invent a target.

1. Confirm the merged work is live on the QA target.
   - QA hits a running app, so it must test the environment where the merged changes are deployed; staging by default, never production unless the user explicitly asks.
   - If merging the base branch triggers a deploy (per `AGENTS.md` § Branch Map / § CI Pipeline), wait for that deploy to finish before testing. If merges do not auto-deploy, the target may not yet include the just-merged changes: test what is actually deployed and flag the gap as a validation limit rather than assuming.

2. Build the QA scope from the batch.
   - Take the issues whose changes actually landed (merged this batch) from the ledger; parked or blocked issues are out of scope because their changes are not deployed.
   - For each merged issue, derive concrete flows to exercise from its acceptance criteria / expected outcome and the behavior its PR changed.
   - Add the integration points between batch issues, where two merged changes touch the same flow, data, or screen, since cross-change interactions are a common source of regressions no single PR review would catch.

3. Run QA in a fresh agent.
   - Spawn the `quality-assurance` agent (fresh context; not the implementer or reviewer of any issue in the batch). Give it the scoped flow list, the merged issue/PR references, and the target environment.
   - It loads `agent-login`, drives the app through the Playwright MCP, reproduces before filing, and files only deterministically reproducible bugs. That workflow is owned by the `quality-assurance` agent; do not re-specify it here.

4. File and link bugs.
   - New bugs are filed as GitHub issues at the board's backlog status (per the `quality-assurance` workflow), using the repo issue template and Issue Type `Bug`.
   - When a bug traces to a specific merged PR/issue, reference it so the trail is clear, and note it was found by this batch's QA sweep. Do not re-open or revert the merged PR; the fix is new work.
   - These backlog bugs are what `backlog-refine` grooms next, closing the loop.

5. Record QA results in the ledger: flows tested, bugs filed (with URLs), reproducible-but-unfiled observations, and any validation limits.

## Phase 6: Report

Summarize:

- Completed issues.
- Deferred or blocked issues.
- PRs opened and merged.
- PRs parked for manual intervention (revision cap reached, a contested finding, or a merge criterion unmet), what remains open on each, and any issues blocked because they depend on a parked PR.
- Validation run.
- QA sweep: flows exercised, bugs filed (with URLs) on the backlog, non-reproducible observations, and QA validation limits (including whether the merged changes were confirmed live on the QA target). Call out prominently any confirmed regression that traces to a merged PR, with a recommended fast-follow.
- Remaining risks.
- Recommended next batch.
- Harness feedback: if a review finding recurred across PRs or exposed a missing guardrail, propose a concrete `AGENTS.md` rule or skill-checklist amendment so the next batch does not re-discover it. Treat configuration gaps, not just code bugs, as batch output.

Per-PR risk checks (security, access control, domain-specific correctness) are owned by `code-review`, which works through `AGENTS.md` § Review Notes; do not re-list them here.
