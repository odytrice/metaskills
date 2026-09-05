---
name: issue-refine
description: Refine an existing issue's What (scope, acceptance criteria, constraints) into an implementation-ready body and move it to ready; splits into native sub-issues when too large. Never designs the How. Use when asked to clarify, scope, groom, refine, or break down an issue.
---

# Refine Issue

Turn a vague issue into a spec: what is asked, why, the boundary, and how "done" is judged. This skill owns the **What**; the **How** (approach, touch points, tasks) is `issue-plan`. Analysis and discussion only: no branches, commits, or implementation edits.

Project facts from `AGENTS.md`: **§ Repositories** (issue template), **§ Project Board**, **§ Code Layout & Tech Stack** (feasibility checks only). Missing section: name it and stop.

## Rules

- Stay on the What: no file lists, task breakdowns, data-model or API designs, or implementation order. When the user drifts into design, capture the constraint it implies (e.g. "must not change the public API") for `## Notes` and leave the design to `issue-plan`.
- Read the codebase for feasibility only: does the behavior already exist, is this one PR-sized unit, does it contradict a current invariant. Stop there.
- Ask only questions that change scope or acceptance criteria; separate confirmed facts from assumptions. If they block, stop after asking.
- Never post refinement comments. Discuss in chat; edit the body only after approval. As a non-interactive worker, return the proposal and questions as your result.

## Workflow

1. Load the issue and the template (§ Repositories) so a rewrite preserves its sections.

   ```sh
   gh issue view <number-or-url> --json number,title,body,labels,assignees,comments,state,url
   ```

2. Feasibility check (three questions above).
3. Assess the What: intent clear; behavior unambiguous (user flow, inputs and outputs, permissions, failure modes as the user sees them); boundaries explicit; "done" testable; dependencies on or from other issues. Conclude: ready, needs answers, or split.
4. Discuss using the Output Shape.
5. Propose the body: template headings, otherwise `## Summary`, `## Context`, `## Expected outcome` (the acceptance criteria), `## Notes` (constraints the plan must respect). Never a task checklist, file list, or design; if the template has a tasks section, leave a one-line pointer to the plan ledger.
6. After approval, stage in `.tmp-refined-body.md` (file-write tool), apply, re-read, report, delete the file.

   ```sh
   gh issue edit <number-or-url> --body-file .tmp-refined-body.md
   ```

7. Move to ready per `issue-plan` § Board Status Transitions and report the verified status. A parent just split stays put; its children are refined and readied individually.

## Splitting

When too large for one PR: propose the children in chat (title plus one-line scope; same approval gate as a rewrite); keep the original as the parent, its body reduced to goal, context, and links, its acceptance criteria to "all sub-issues resolved"; create and link each child via `issue-raise` § Sub-Issue Linking; report the parent and every child. Never dissolve a parent into loose top-level issues.

## Output Shape

```md
**Current Understanding**
**Proposed Scope**
**Out Of Scope**
**Acceptance Criteria**
**Constraints** (for the plan to respect; not the design)
**Dependencies**
**Questions** (numbered)
```

Omit empty sections.
