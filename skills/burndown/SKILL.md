---
name: burndown
description: Orchestrate dev-cycle in dependency-ordered batches with closing QA. Use for an issue list, label query, milestone, or board-status batch.
---

# Burndown

`dev-cycle` owns each issue's plan, claim, implementation, review, revision, and merge. Run and record it per issue; never restate or control its internals here.

Project facts from `AGENTS.md`: **§ Project Board**, **§ Repositories**, **§ Branch Map** (whether merging auto-deploys), **§ Build & Validation**, **§ Code Layout & Tech Stack** (to derive write sets); **§ Environments** and **§ Agent Login** only for the QA sweep (no running app: skip it with a note). Missing section: name it and stop.

Scope, in precedence: explicit issue list; label query; milestone; a board status the user names; else the board's ready status.

Explicit `board: none` is valid per `issue-plan`: require list/label/milestone scope or ask; skip board operations. Existing ledgers remain claimed, never silently resumed. Missing board facts: stop. Retain canonical issue URLs/repo identity in tracking, prompts, and GitHub commands; reject explicit targets outside the consuming repo.

## Coordinator Model

The coordinator owns scope, triage, dependencies, waves, cycle dispatch/results, QA, and reporting. Its only GitHub writes are triage comments (Phase 2): no body/label edits, board moves, pushes, or merges. Developers push PR branches; nothing else leaves the machine unless requested.

State lives only in board Status and a conversation tracking table: issue; decision; dependencies; write set; wave; PR; review round/exit reason; status. Never write project batch files.

Concurrency has exactly two bounds: **dependency edges** (all prerequisites must merge) and **write-set overlap** (shared files, migrations, contracts, routes, state model, or fixtures serialize; doubt also serializes). Same-wave cycles share no edges and may interleave phases. Skip and note issues outside expected status at wave opening. Parked prerequisites block dependents.

## Phase 1: Candidates

```sh
gh api --paginate 'repos/<owner>/<repo>/issues?state=open&per_page=100' --jq '.[] | select(.pull_request == null)'
```

Apply list/label/milestone filters. Board scope uses `issue-plan` § Board Status Transitions' complete item read, filtered to consuming-repo Issues then requested status. Failed/incomplete enumeration: stop. Before triage, read each candidate by canonical URL (`gh issue view --json number,title,body,labels,comments,url`). Scope number-based `gh` commands with `--repo <repo-slug>`.

## Phase 2: Triage And Waves

Decide per issue: do now / defer / split / blocked / duplicate. Confirm relevance and dependencies; split oversized issues via `issue-refine` (retain parent, native sub-issues). Prioritize data-integrity, auth, foundational work; never silently include other columns.

Post one comment per non-do-now decision: `gh issue comment <n> --body "Burndown YYYY-MM-DD: deferred|blocked|duplicate of #m|split into #a #b. <reason in one line>"`. Do-now uses the plan ledger, no comment.

Record kept issues' dependencies and write sets from scope and quick code searches. Add overlap edges; record waves (first: no unmet edges; later: edges resolve to earlier waves). Cycles/unorderable edges: split or ask, never guess. Otherwise order by risk and priority.

## Phase 3: Run The Cycles

Wave by wave; within a wave, `dev-cycle` for every issue concurrently. A wave opens only when the earlier-wave issues it depends on are merged.

Follow `dev-cycle` exactly; pass owned files/modules and § Build & Validation batch checks. Record returned PR, approach, merge result, review round/exit reason, board status, validation, changed paths. Handle:

- **Decision points**: record architect questions as `needs-decision`, park dependents, continue. Ask together at wave end (sooner if stalled); re-run with answers in the plan prompt.
- **Parked PR** (revision cap or contested finding): record round, reason, both positions; park dependents; never re-open the loop from here.
- **Merge criterion unmet**: record for the user and move on.
- **`claimed`** (left ready since snapshot or another architect's ledger won): record `claimed-elsewhere`; drop issue and dependents. Two or more per wave: stop, report overlapping issues, ask before continuing.

Across wave boundaries, issues become eligible as prerequisites merge; parked issues block only dependents.

Before integration: run the widest practical § Build & Validation if per-PR checks did not cover it; check for secrets/debug output and remove only clean, skill-owned temp files/worktrees. Preserve existing branches and user work; report retained artifacts.

## Phase 4: QA Sweep

Discovery, not a gate: merged PRs are never reverted; confirmed bugs become backlog work. Skip with a note if nothing merged or there is no running app.

1. Confirm merged work is live on the target (default staging; production only if asked). Wait for auto-deploy (§ Branch Map); otherwise test deployed behavior and flag gaps.
2. Scope flows from merged issues' expected outcomes, PR behavior changes, and integration points between changes.
3. Dispatch one fresh `quality-assurance` agent, neither batch implementer nor reviewer, with flows, merged issue/PR references, target, and batch-sweep context. It runs `qa`, filing at new-issue status with originating PR/issue references.
4. Record flows tested, bugs filed (URLs), non-reproducible observations, validation limits.

## Phase 5: Report

Completed; deferred, blocked, or claimed elsewhere; awaiting a design decision (with the questions). PRs merged, parked (round, reason, what remains), and waiting on a criterion, plus what each blocks. Validation run. QA sweep results, including whether merged changes were confirmed live and any regression tracing to a merged PR with a recommended fast-follow. Remaining risks and the recommended next batch. Harness feedback: recurring findings or guardrail gaps as concrete `AGENTS.md` or checklist amendments.
