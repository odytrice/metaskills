---
name: backlog-refine
description: Refine a whole backlog; map dependencies, ask every clarifying question in one up-front gate, then run issue-refine in parallel dependency-ordered waves. Use when asked to groom, refine, triage, or clear the backlog as a batch.
---

# Backlog Refine

`issue-refine` in batches. Map how items depend on each other, ask every clarifying question in one gate, wait, then refine in waves. For one issue use `issue-refine` directly.

Project facts from `AGENTS.md`: **§ Project Board** (which status is backlog, which is ready), **§ Repositories**, **§ Code Layout & Tech Stack**. Missing section: name it and stop.

Scope: the backlog status by default; else an explicit issue list, label query, or milestone. No board and no explicit scope: stop.

## Rules

- Run from a context that can reach the user. A non-interactive worker cannot hold the gate: assess, build the questions, and return them with the already-clear items; the caller re-dispatches with answers.
- The gate is mandatory and human-answered. Never fan out before it, never refine an item with unanswered questions, never invent scope. "Skip", "defer", and "close" are valid answers.
- Only `issue-refine` moves an item to ready, updates a body, or splits (parent kept, native sub-issues). This skill writes nothing but `.tmp-*` body files.
- Do not close, relabel, or reassign beyond what the user approved at the gate.

## Flow

1. **Enumerate** (`gh issue list`, or `gh project item-list` filtered to the backlog status). Flag obsolete or duplicate items rather than dropping them.
2. **Map** dependencies (one item's scope depends on how another resolves; parent/child) from the issue text and a quick search of the areas each touches. Partition into waves: wave 1 has no unresolved dependency; later waves depend only on earlier ones. Items within a wave are independent and safe in parallel.
3. **Assess** each item's What (body, comments, labels, linked context; codebase for feasibility only) on the dimensions `issue-refine` uses. Surface any material ambiguity, not only blockers. Design questions belong to `issue-plan` later, not here.
4. **Gate** once: all questions grouped by wave and item, numbered, ordered by wave then priority and age, plus the go-ahead. Stop and wait. Once answered, approval covers the cleared batch; uncleared items stay un-refined.
5. **Track** item, wave, state (`needs-answers` / `clarified` / `refined->ready` / `skipped` / `deferred`), notes; in this conversation, never in a project file.
6. **Refine** wave by wave: one `issue-refine` worker per item (sequentially in this context without workers), each given its clarifications as confirmed facts, the go-ahead as approval, and a unique `.tmp-refined-body-<number>.md`. A parent being split is refined first; its children land in a later wave. Do not start a wave until the earlier-wave items it depends on are refined.
7. **Confirm** each item reached ready (`issue-refine` verifies); record failures honestly.
8. **Report**: refined and readied; skipped, deferred, closed; still blocked on answers; wave structure; recommended next batch.
