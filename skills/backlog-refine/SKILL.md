---
name: backlog-refine
description: Refine issues in dependency-ordered waves with a human approval gate. Use to groom, refine, triage, or clear a backlog batch.
---

# Backlog Refine

Batch orchestration of `issue-refine`; use it directly for one issue.

Project facts from `AGENTS.md`: **§ Project Board** (which status is backlog, which is ready), **§ Repositories**, **§ Code Layout & Tech Stack**. Missing section: name it and stop.

Scope: backlog status by default; otherwise issue list, label query, or milestone. Explicit `board: none` is valid per `issue-plan`: skip board operations, report refinement without transition; stop without explicit scope. Missing board facts: stop.

## Rules

- Non-interactive workers return questions and already-clear items; the caller holds the user gate and re-dispatches with answers.
- Mandatory human gate: no fan-out beforehand, refinement with unanswered questions, or invented scope. "Skip", "defer", and "close" are valid answers.
- Only `issue-refine` moves an item to ready, updates a body, or splits (parent kept, native sub-issues). This skill writes nothing but `.tmp-*` body files.
- Do not close, relabel, or reassign beyond what the user approved at the gate.

## Flow

1. **Enumerate** all pages: `gh api --paginate 'repos/<owner>/<repo>/issues?state=open&per_page=100'`; exclude `pull_request` entries and apply scope filters. For boards, use `issue-plan` § Board Status Transitions' complete lookup, filtering to consuming-repo Issues then backlog status. Incomplete enumeration: stop. Retain canonical URLs/repo identity in tracking and dispatch; scope number-based commands to § Repositories; reject explicit outside targets. Flag obsolete/duplicate items, never drop them.
2. **Map** scope and parent/child dependencies from issue text and a quick code search. Wave 1 has no unresolved dependencies; later waves depend only on earlier ones; same-wave items are independent.
3. **Assess** the What using `issue-refine` dimensions: body, comments, labels, linked context; code only for feasibility. Surface all material ambiguity, not just blockers; defer design to `issue-plan`.
4. **Gate** once: numbered questions grouped by wave/item, ordered by wave, priority, age, plus go-ahead. Stop for answers; approval covers only cleared items.
5. **Track** item, wave, state (`needs-answers` / `clarified` / `refined->ready` / `skipped` / `deferred`), notes; in this conversation, never in a project file.
6. **Refine** waves with one `issue-refine` worker per item (sequentially here if unavailable). Pass clarifications as facts, go-ahead as approval, and unique `.tmp-refined-body-<number>.md` paths. Start only after prerequisite items are refined; split parents precede children in later waves.
7. **Confirm** each item reached ready (`issue-refine` verifies), or was refined with `board: none`; record failures honestly.
8. **Report**: refined and readied; skipped, deferred, closed; still blocked on answers; wave structure; recommended next batch.
