---
name: burndown
description: Run dev-cycle across a batch of issues (labels, milestone, issue list, or a board status such as Ready); triage, dependency-ordered waves, one cycle per issue with wave concurrency, closing QA sweep, batch report. Use for a batch; dev-cycle for one issue.
---

# Burndown

`dev-cycle` in batches. This skill adds scope, triage, ordering, concurrency, and a closing QA sweep; everything inside an issue (plan, claim, implement, review, revise, merge) is `dev-cycle`, run per issue and recorded, never restated or controlled from here.

Project facts from `AGENTS.md`: **§ Project Board**, **§ Branch Map** (whether merging auto-deploys), **§ Build & Validation**, **§ Code Layout & Tech Stack** (to derive write sets); **§ Environments** and **§ Agent Login** only for the QA sweep (no running app: skip it with a note). Missing section: name it and stop.

Scope, in precedence: explicit issue list; label query; milestone; a board status the user names; else the board's ready status.

## Coordinator Model

The coordinator owns scope, triage, the dependency graph, waves, running the cycles, accepting results, the QA sweep, and the report. It never edits issue bodies or labels, moves board items, pushes, or merges; its only GitHub writes are triage comments (Phase 2). Developers push PR branches, and nothing else leaves the machine unless the user asks.

State lives in two places only: the board Status (shared, per issue) and a tracking table in this conversation (issue; decision; dependencies; write set; wave; PR; review round and exit reason; status). Never write a batch file into the project; a second burndown could not read it, and the board already coordinates.

Concurrency is bounded by exactly two things: **dependency edges** (an issue waits until everything it depends on is merged) and **write-set overlap** (issues touching the same files, migrations, contracts, routes, state model, or fixtures never run concurrently; when in doubt, serialize). Issues within a wave share no edges; their cycles run side by side and phases may interleave. An issue not in the expected status when its wave opens is skipped and noted. Each issue completes its cycle (merged or parked) before a dependent starts.

## Phase 1: Candidates

```sh
gh issue list --state open --limit 200 --json number,title,labels,assignees,url
gh project item-list <project-number> --owner <owner> --format json --limit 200 --jq '.items[] | select(.status=="<ready-status>") | {number:.content.number,title:.title,url:.content.url}'
```

The board result is only the candidate set; read each issue (`gh issue view --json number,title,body,labels,comments,url`) before triage.

## Phase 2: Triage And Waves

Per issue decide: do now / defer / split / blocked / duplicate. Confirm it still applies; identify dependencies; split oversized issues via `issue-refine` (parent kept, native sub-issues); keep data-integrity, auth, and foundational work early; never silently include items from other columns.

Every decision other than do-now is posted on the issue, where the next reader will see it, as one comment: `gh issue comment <n> --body "Burndown YYYY-MM-DD: deferred|blocked|duplicate of #m|split into #a #b. <reason in one line>"`. Do-now issues get no comment; the plan ledger will carry that.

Then order: record each kept issue's dependencies and write set (from its scope plus a quick search of the areas it touches); build the graph, adding an edge for any write-set overlap; partition into waves (wave 1 has no unmet edge; each later wave's edges resolve to earlier waves); record in the table. A cycle or unorderable edge is a planning smell: split or ask, never guess. Remaining freedom: order by risk and priority.

## Phase 3: Run The Cycles

Wave by wave; within a wave, `dev-cycle` for every issue concurrently. A wave opens only when the earlier-wave issues it depends on are merged.

Per issue, follow `dev-cycle` exactly, passing into its prompts the owned files/modules from the write set and the batch validation from § Build & Validation. Record what it returns (PR, approach, merge result, review round and exit reason, board status, validation, changed paths). Then:

- **Decision points** from the architect: record `needs-decision` with the questions, park dependents, continue; put all such questions to the user together at the end of the wave (sooner if the wave cannot progress). Re-run the cycle with the answers in the plan prompt.
- **Parked PR** (revision cap or contested finding): record round, reason, both positions; park dependents; never re-open the loop from here.
- **Merge criterion unmet**: record for the user and move on.
- **`claimed`** (the issue left ready between snapshot and claim, or another architect's ledger won the tie-break): record `claimed-elsewhere`, drop it and its dependents from this batch. Two or more in one wave means another burndown or developer is working the same scope: stop, report which issues, and ask before continuing.

Independent work keeps flowing across wave boundaries: an issue is eligible as soon as its prerequisites merge. A parked issue blocks only its dependents.

Before the batch is integrated: run the widest practical § Build & Validation once if per-PR validation did not cover it; confirm no temp files, secrets, debug output, local worktrees, or merged-PR local branches remain.

## Phase 4: QA Sweep

Discovery, not a gate: merged PRs are never reverted; confirmed bugs become backlog work. Skip with a note if nothing merged or there is no running app.

1. Confirm the merged work is live on the QA target (staging by default, never production unless asked). If merging auto-deploys (§ Branch Map), wait for it; otherwise test what is deployed and flag the gap.
2. Scope: per merged issue, concrete flows from its expected outcome and the PR's changed behavior; plus integration points where two merged changes meet.
3. Dispatch one `quality-assurance` agent (fresh; not an implementer or reviewer from this batch) with the flow list, merged issue/PR references, and target. It runs `qa`, which files bugs at the new-issue status referencing the merged PR/issue they trace to; note in the prompt that they come from this batch's sweep.
4. Record flows tested, bugs filed (URLs), non-reproducible observations, validation limits.

## Phase 5: Report

Completed; deferred, blocked, or claimed elsewhere; awaiting a design decision (with the questions). PRs merged, parked (round, reason, what remains), and waiting on a criterion, plus what each blocks. Validation run. QA sweep results, including whether merged changes were confirmed live and any regression tracing to a merged PR with a recommended fast-follow. Remaining risks and the recommended next batch. Harness feedback: recurring findings or guardrail gaps as concrete `AGENTS.md` or checklist amendments.
