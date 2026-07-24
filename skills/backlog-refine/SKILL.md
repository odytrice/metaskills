---
name: backlog-refine
description: Refine a project's backlog into implementation-ready issues one item at a time by running issue-refine on each, pausing before each refinement to ask the user clarifying questions and waiting for answers whenever requirements are unclear. Use when asked to groom, refine, triage, or clear the backlog as a batch.
---

# Backlog Refine

Use this skill to walk a project's backlog and bring each item up to implementation-ready scope by running `issue-refine` on it, with a mandatory interactive clarity gate before each refinement. For a single issue, use `issue-refine` directly; this skill is the batch driver around it.

This is an interactive skill. It stops and waits for the user whenever an item's requirements are unclear, and it never guesses to keep the batch moving.

## Project Facts Come From AGENTS.md

Resolve every project-specific value at runtime from the repository's `AGENTS.md`:

- **§ Project Board** — board owner/org, project number, and the `Status` option names, including which status is the backlog and which is "ready for work".
- **§ Repositories** — the app repo slug and issue template path.
- **§ Code Layout & Tech Stack** — where code lives, to ground each readiness assessment.

If a required section is missing, say which one and stop. Do not guess.

## Ownership

Run by the `project-manager` agent (or the main interactive session). Like `issue-refine`, this skill does not write product code, create branches, or implement anything. Its only writes are temporary `.tmp-*` issue-body files (passed to `gh issue edit --body-file`), an optional progress ledger under `Docs/`, and the approved project status transition — all owned by `issue-refine`, which this skill defers to.

## Interactivity Is The Point

- The clarity gate must be answered by a human. Run this where you can reach the user and pause for a reply.
- If **any** material requirement for an item is unclear, ask the specific, numbered questions and **stop** — wait for the user's answer before running `issue-refine` on that item. Do not invent scope, do not assume a default, and do not jump ahead to another item's refinement to fill the wait.
- Raise the bar above a one-off refine: surface any material ambiguity as a question, not only the ones you would treat as strictly blocking on a single issue.
- If you are running where you cannot reach the user (a non-interactive worker), do not fabricate answers. Leave the item un-refined, collect its open questions, and return them for the human. Never advance an unclear item into `issue-refine`.

## Inputs And Scope

- **Default**: the board's backlog status column (the un-refined status named in `AGENTS.md` § Project Board).
- **Overrides**: an explicit issue list, a label query, or a milestone.
- If there is no project board, "backlog" is undefined — require an explicit scope (list, label, or milestone) and stop and ask when none is given.

## Order

- Process serially, one item at a time, so the human Q&A stays coherent. Never fan backlog items out in parallel — overlapping question threads are unusable.
- Order by priority, then age (oldest first), so the most important items are clarified first. Honor any order the user specifies.
- By default ask per item; if the user prefers fewer round-trips, you may gather questions for several upcoming items in one message — but still never refine any item whose questions are unanswered.

## Flow

1. **Enumerate the backlog.** Resolve scope, then list the items (`gh issue list`, or `gh project item-list` filtered to the backlog status). Read each enough to confirm it still applies; flag obsolete or duplicate items with a note rather than silently dropping them.

2. **Track progress.** For more than a couple of items, keep a short ledger — item, state (`needs-answers` / `clarified` / `refined->ready` / `skipped` / `deferred`), and notes — in chat, or in `Docs/plans/YYYY-MM-DD-backlog-refine.md` for a large backlog so the interactive pass can resume across turns or sessions.

3. **Per item, in order:**
   a. **Assess readiness.** Load the issue (body, comments, labels, linked context) and use § Code Layout & Tech Stack to ground it. Look for ambiguity in user flow, data model, API contract, UI behavior, permissions, failure modes, migrations, acceptance criteria, and scope boundaries — the same dimensions `issue-refine` analyzes.
   b. **Clarity gate.** If the item is fully clear, go to (c). Otherwise present the numbered questions and **stop** — wait for the user. Treat "skip", "defer", or "close" as valid answers: record and move on if the user says so. Do not run `issue-refine` until the item is clear.
   c. **Refine.** With the item clear, run the `issue-refine` skill for it, passing the user's clarifications as confirmed facts so it does not re-ask them. `issue-refine` owns the proposal, the approval-before-write, the issue-body update, **and the backlog->ready status transition** — do not bypass or duplicate any of them.
   d. **Confirm and record.** `issue-refine` already moves the item to the ready-for-work status after approval and re-reads to verify it. Confirm the item actually reached "ready" before recording it as done; if `issue-refine` skipped the move (not approved, not on the board, or the edit failed), record that honestly and leave the item as not-done. Advance to the next item.

4. **Report.** Items refined and moved to ready, items skipped / deferred / closed, items still blocked on your answers, and the recommended next batch. Never report an item as refined unless `issue-refine` updated it and it is now in the ready status.

## Safety

- One item at a time; never parallel.
- Never guess or assume to keep moving. An unanswered clarity gate leaves that item un-refined and surfaced — it does not license inventing scope.
- Do not move an item to ready except through `issue-refine`'s approved transition, and do not mark an item done until you have confirmed it is in the ready status.
- Do not create branches, commits, PRs, or implementation edits.
- Do not close, relabel, or reassign items beyond what the user approves at the gate.
- When an item needs to be split, do it through `issue-refine`'s sub-issue path: keep the original item as the parent summary and attach the pieces as native GitHub sub-issues so the parent shows a progress bar. Never dissolve a backlog item into disconnected top-level issues.
