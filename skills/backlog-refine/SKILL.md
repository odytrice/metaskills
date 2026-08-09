---
name: backlog-refine
description: Refine a project's backlog into implementation-ready issues by first mapping the dependency hierarchy between items, gathering all clarifying questions in a single up-front gate, then running issue-refine across the backlog in parallel dependency-ordered waves. Use when asked to groom, refine, triage, or clear the backlog as a batch.
---

# Backlog Refine

Use this skill to walk a project's backlog and bring every item up to implementation-ready scope by running `issue-refine` on each. It front-loads the interaction: map how the items depend on each other, ask every clarifying question the backlog raises in one up-front gate, wait for the answers, then refine the items in parallel waves ordered by that dependency hierarchy. For a single issue, use `issue-refine` directly; this skill is the batch driver around it.

The clarity gate is still mandatory and still human-answered; it is batched to the front instead of repeated per item. The skill never guesses to fill a gap: an item whose questions go unanswered is left un-refined and surfaced, not invented.

## Project Facts Come From AGENTS.md

Resolve every project-specific value at runtime from the repository's `AGENTS.md`:

- **§ Project Board**: board owner/org, project number, and the `Status` option names, including which status is the backlog and which is "ready for work".
- **§ Repositories**: the app repo slug and issue template path.
- **§ Code Layout & Tech Stack**: where code lives, to ground each readiness assessment.

If a required section is missing, say which one and stop. Do not guess.

## Ownership

Run by the `project-manager` agent or the main interactive session. Like `issue-refine`, this skill does not write product code, create branches, or implement anything. Its only writes are temporary `.tmp-*` issue-body files (passed to `gh issue edit --body-file`), an optional progress ledger under `Docs/`, and the approved project status transitions, all owned by `issue-refine`, which this skill defers to.

Parallel fan-out:

- After the gate clears, fan out one refine worker per item within a wave, each running `issue-refine` on its item. Pass each worker the item's clarifications as confirmed facts and the batch go-ahead as approval, so `issue-refine` performs its body update and backlog->ready transition without pausing to re-ask or re-approve.
- Give each worker a unique temp-file name (for example `.tmp-refined-body-<number>.md`) so parallel workers never clobber each other's staged body.
- If a wave includes a parent being split into sub-issues, refine the parent first (it creates the sub-issues via `issue-refine`/`issue-raise`); the new sub-issues then land in a later wave.
- On a harness that cannot spawn workers, run the wave's items sequentially in the same context after the gate. The parallelism is a throughput optimization, not a correctness requirement.

## The Up-Front Clarity Gate

- The gate is a single, human-answered checkpoint before any refinement runs. Run this where you can reach the user.
- Assess every in-scope item first, then present all clarifying questions together, grouped by item and numbered. Raise the bar above a one-off refine: surface any material ambiguity, not only the questions you would treat as strictly blocking on a single issue.
- **Stop and wait** for the user's answers. Do not start refining while questions are outstanding, do not assume a default, and do not invent scope to keep moving.
- Treat "skip", "defer", or "close" as valid answers: record them and drop those items from the refinement set.
- The same gate collects the go-ahead to apply the refinements. Once answered, the user's approval authorizes the whole cleared batch, so the fan-out runs without further per-item approval pauses (see Ownership). An item the user does not clear stays un-refined.
- If you cannot reach the user (a non-interactive worker), do not fabricate answers. Leave the affected items un-refined, collect their open questions, and return them for the human. Items that were already fully clear may still be refined.

## Inputs And Scope

- **Default**: the board's backlog status column (the un-refined status named in `AGENTS.md` § Project Board).
- **Overrides**: an explicit issue list, a label query, or a milestone.
- If there is no project board, "backlog" is undefined; require an explicit scope (list, label, or milestone) and stop and ask when none is given.

## Dependency Hierarchy And Waves

- Before the gate, map how the in-scope items relate: which items block others (one item's scope depends on how another is resolved), and which are parent/child (a large item that will be split, or an existing sub-issue relationship). Ground this in the issue text and a quick `rg` over the areas each item touches.
- Build a dependency hierarchy from those relations and partition the items into ordered **waves**: wave 1 is every item with no unresolved dependency; each later wave is the items whose blockers all sit in earlier waves. Refine foundational items first so dependent items can reference their settled scope.
- Refinement writes are per-item and non-overlapping (each item's own issue body and status), so items within a wave are safe to refine in parallel. The dependency order is the reason to wave them, not write conflicts.
- Order questions and reporting by wave, then by priority and age (oldest first) within a wave. Honor any order the user specifies.

## Flow

1. **Enumerate the backlog.** Resolve scope, then list the items (`gh issue list`, or `gh project item-list` filtered to the backlog status). Read each enough to confirm it still applies; flag obsolete or duplicate items with a note rather than silently dropping them.

2. **Map the hierarchy and waves.** Build the dependency hierarchy across the in-scope items and partition them into ordered waves (see Dependency Hierarchy And Waves).

3. **Assess readiness for every item.** Load each item (body, comments, labels, linked context) and use § Code Layout & Tech Stack to ground it. Look for ambiguity in user flow, data model, API contract, UI behavior, permissions, failure modes, migrations, acceptance criteria, and scope boundaries (the same dimensions `issue-refine` analyzes).

4. **Run the up-front gate once.** Present all clarifying questions across the backlog together, grouped by item and wave and numbered, and ask for the go-ahead to refine the cleared items. **Stop and wait.** Record "skip"/"defer"/"close" answers and drop those items. Items already fully clear need no questions but are still covered by the go-ahead.

5. **Track progress.** Keep a short ledger of item, wave, state (`needs-answers` / `clarified` / `refined->ready` / `skipped` / `deferred`), and notes in chat, or in `Docs/plans/YYYY-MM-DD-backlog-refine.md` for a large backlog so the pass can resume across turns or sessions.

6. **Refine, wave by wave.** For each wave in order, fan out one `issue-refine` worker per cleared item in that wave (or run them sequentially on a harness without workers). Pass each worker its clarifications as confirmed facts, the batch go-ahead as approval, and a unique temp-file name. `issue-refine` owns the proposal, the issue-body update, **and the backlog->ready status transition**; do not bypass or duplicate them. Do not start a wave until the previous wave's items it depends on are refined.

7. **Confirm and record.** For each item, confirm `issue-refine` actually moved it to the ready status (it re-reads to verify). If the move was skipped (not on the board, or the edit failed), record that honestly and leave the item as not-done.

8. **Report.** Items refined and moved to ready, items skipped / deferred / closed, items still blocked on answers, the wave structure used, and the recommended next batch. Never report an item as refined unless `issue-refine` updated it and it is now in the ready status.

## Safety

- Parallelize only after the single up-front gate has cleared the items; never refine an item whose questions are unanswered, and never fan out before the gate.
- Refine in parallel only within a wave; respect the dependency order across waves so dependent items see their prerequisites' settled scope.
- Never guess or assume to keep moving. Unanswered questions leave those items un-refined and surfaced; they do not license inventing scope.
- Do not move an item to ready except through `issue-refine`'s transition, and do not mark an item done until you have confirmed it is in the ready status.
- Do not create branches, commits, PRs, or implementation edits.
- Do not close, relabel, or reassign items beyond what the user approves at the gate.
- When an item needs to be split, do it through `issue-refine`'s sub-issue path: keep the original item as the parent summary and attach the pieces as native GitHub sub-issues so the parent shows a progress bar. Never dissolve a backlog item into disconnected top-level issues.
