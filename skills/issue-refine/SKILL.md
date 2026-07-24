---
name: issue-refine
description: Refine GitHub issues before implementation. Use when the user asks to clarify, scope, analyze, groom, refine, triage, prepare, or break down an existing issue; inspect the issue, comments, labels, linked context, and relevant codebase areas, raise blocking questions, and produce clear scope, acceptance criteria, and task checklists without starting implementation.
---

# Refine Issue

Use this skill to turn a vague or under-specified GitHub issue into implementation-ready scope. This is a discussion and analysis workflow, not an implementation workflow. All project facts come from the repository's `AGENTS.md` (harness contract): code areas from § Code Layout & Tech Stack, the issue template path from § Repositories, and the board owner, project number, and Status option names from § Project Board. If a required AGENTS.md section is missing, say which section is missing and stop — do not guess project facts.

## Core Rules

- Follow `AGENTS.md`.
- Do not create branches, commits, PRs, migrations, or implementation edits.
- Use GitHub as the source of issue state.
- Use `rg` first for local code and documentation searches.
- Ask only questions that materially affect scope, acceptance criteria, or implementation order.
- Separate confirmed facts from assumptions and open questions.
- Do not update the GitHub issue body, labels, assignees, or project status unless the user explicitly approves the proposed refinement.
- Never post refinement comments. Discuss refinements in chat, then update the issue body only after approval.
- When the analysis concludes an issue should be split, keep the original issue as the parent summary and create each piece as a native GitHub sub-issue of it (see "Splitting Into Sub-Issues"). Never dissolve the original into disconnected top-level issues or replace it wholesale; the parent must remain so GitHub shows a progress bar as children close.
- If the project uses a GitHub Project board (per `AGENTS.md` § Project Board), move the issue's item to the ready-for-work Status option after the user approves the refinement (Workflow step 7). If there is no board, skip the transition.

## Workflow

1. Load the issue.
   - If no issue number or URL is provided, ask for it.
   - Inspect the issue, comments, labels, assignees, state, and URL:

   ```powershell
   gh issue view <number-or-url> --json number,title,body,labels,assignees,comments,state,url
   ```

   - Read the issue template (path from `AGENTS.md` § Repositories) when one exists so any proposed rewrite preserves its sections.

2. Build local context.
   - Search for named routes, DTOs, services, components, database tables, docs, and error messages from the issue.
   - Read only the relevant files needed to understand the current behavior and likely implementation boundary.
   - Use `AGENTS.md` § Code Layout & Tech Stack to locate the relevant backend, frontend, migration, deployment, and docs areas.

3. Analyze readiness.
   - Identify what is already clear.
   - Identify ambiguity in user flow, data model, API contract, UI behavior, permissions, failure modes, migration needs, and validation.
   - Decide whether the issue is implementation-ready, needs user answers, or should be split into multiple issues (as sub-issues of the original; see "Splitting Into Sub-Issues").

4. Discuss with the user.
   - Present a concise refinement summary: current understanding, proposed scope, explicit out-of-scope items, likely files or modules affected, proposed task checklist, acceptance criteria, risks and dependencies, and blocking questions.
   - If questions are blocking, stop after asking them. Do not invent scope to fill the gaps.

5. Produce a refinement proposal.
   - When enough clarity exists, draft issue-ready text using the issue template when present, otherwise:
     - `## Summary`
     - `## Context`
     - `## Expected outcome`
     - `## Tasks`
     - `## Notes`
   - The body is the durable spec: `## Expected outcome` defines what "done" means. If the project's `AGENTS.md` states that execution checklists live elsewhere (e.g. a plan-ledger comment convention), omit `## Tasks` from the body; otherwise keep the checklist concrete enough for the implementation workflow to execute.
   - Include code references where useful, but avoid over-prescribing implementation details unless they are necessary constraints.

6. Update the issue body only after approval.
   - If the user approves replacing the issue body, stage the refined body in a temporary `.tmp-*` markdown file (e.g. `.tmp-refined-body.md`) and run:

   ```powershell
   gh issue edit <number-or-url> --body-file .tmp-refined-body.md
   ```

   - Re-read the issue after updating, report the final URL and what changed, and delete the temporary file.

7. Move the project item to the ready-for-work status once refinement is complete (only if a board is in use).
   - Resolve the board owner, project number, and the exact Status option name for "ready" from `AGENTS.md` § Project Board.
   - Look up the project id, the `Status` field and option ids, and the item id live — never hardcode IDs — then edit and verify the transition:

   ```powershell
   gh project view <project-number> --owner <owner> --format json --jq '.id'
   gh project field-list <project-number> --owner <owner> --format json --jq '.fields[] | select(.name=="Status") | {id, options}'
   gh project item-list <project-number> --owner <owner> --format json --limit 200 --jq '.items[] | select(.content.number==<issue-number>) | {id, status, title}'
   gh project item-edit --project-id <project-id> --id <item-id> --field-id <status-field-id> --single-select-option-id <ready-option-id>
   ```

   - After the edit, re-run the item-list lookup and confirm the new status. Report the verified transition, not the intended one; if the edit was skipped or failed, say so explicitly.
   - If the issue is not on the board, do not add a duplicate item silently; note it and ask before changing the project.
   - If `gh project` reports a missing scope, ask the user to run `gh auth refresh --hostname github.com -s project`.

## Splitting Into Sub-Issues

When refinement concludes the issue is too large and should become several issues, do not fan it out into disconnected top-level issues and do not overwrite the original with its parts. Instead:

- Keep the **original issue as the parent**: simplify its body to a high-level summary (goal, context, and links to the children) and let its acceptance criteria reduce to "all sub-issues resolved". Its task list becomes the set of child issues rather than low-level steps.
- Create each piece as its own issue and link it as a native GitHub **sub-issue** of the parent, so GitHub renders a progress bar on the parent that advances as children close.
- Split only after the user approves the proposed breakdown, the same approval gate as a body rewrite. Propose the child issues (a title plus one-line scope each) in chat first.

Delegate child creation and the parent link to `issue-raise` (it owns issue creation and sub-issue linkage), passing each child's scope and the parent issue number. The linkage uses the child's REST database `id`, not its number; resolve `<owner>/<repo>` from `AGENTS.md` § Repositories:

```powershell
$childId = gh api repos/OWNER/REPO/issues/CHILD_NUMBER --jq '.id'
gh api --method POST repos/OWNER/REPO/issues/PARENT_NUMBER/sub_issues -F sub_issue_id=$childId
gh api repos/OWNER/REPO/issues/PARENT_NUMBER/sub_issues --jq '.[].number'
```

Report the parent link and every child issue created. If the sub-issues API is unavailable, surface the parent and child numbers so the links can be added in the GitHub UI rather than leaving the children orphaned silently.

## Output Shape

Use this structure for the discussion response unless the issue is tiny:

```md
**Current Understanding**

**Proposed Scope**

**Out Of Scope**

**Likely Touch Points**

**Tasks**

**Acceptance Criteria**

**Risks Or Dependencies**

**Questions**
```

Omit empty sections. Keep questions direct and numbered.
