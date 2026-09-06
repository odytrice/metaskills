---
name: issue-refine
description: Clarify an issue's scope and acceptance criteria for implementation. Use to clarify, scope, groom, refine, or break down an existing issue.
---

# Refine Issue

Own the **What**; `issue-plan` owns the **How**. No branches, commits, or implementation edits.

Project facts from `AGENTS.md`: **§ Repositories** (issue template), **§ Project Board**, **§ Code Layout & Tech Stack** (feasibility checks only). Missing section: name it and stop.

Explicit `board: none` is valid per `issue-plan` § Board Status Transitions: skip board operations and report refinement without a status transition. Missing board facts still stop.

## Rules

- No file lists, task breakdowns, data-model/API designs, or implementation order. Convert design discussion to constraints in `## Notes` (e.g. "must not change the public API"); defer design to `issue-plan`.
- Code reading stops at feasibility: existing behavior, PR-sized scope, invariant conflicts.
- Ask only scope/acceptance questions; distinguish facts from assumptions. Stop for blocking answers.
- No refinement comments. Discuss in chat; body edits require approval. Non-interactive workers return proposal and questions.

## Workflow

1. Load issue and § Repositories template; preserve template sections.

   ```sh
   gh issue view <number-or-url> --json number,title,body,labels,assignees,comments,state,url
   ```

2. Feasibility check (three questions above).
3. Assess intent, behavior (flow, inputs/outputs, permissions, user-visible failures), boundaries, testable completion, and incoming/outgoing dependencies. Conclude: ready, needs answers, or split.
4. Discuss using the Output Shape.
5. Propose template headings or `## Summary`, `## Context`, `## Expected outcome` (acceptance criteria), `## Notes` (binding constraints). In template task sections, leave a one-line plan-ledger pointer.
6. After approval, stage in `.tmp-refined-body.md` (file-write tool), apply, re-read, report, delete the file.

   ```sh
   gh issue edit <number-or-url> --body-file .tmp-refined-body.md
   ```

7. Move to ready per `issue-plan` § Board Status Transitions; report verified status. Split parents stay put; refine/ready children individually.

## Splitting

Beyond one PR: propose child titles and one-line scopes in chat under the rewrite approval gate. Retain parent with goal, context, links, and acceptance criterion "all sub-issues resolved". Create/link children via `issue-raise` § Sub-Issue Linking; report parent and every child. Never dissolve into loose top-level issues.

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
