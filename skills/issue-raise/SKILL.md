---
name: issue-raise
description: Create GitHub issues for the current project repository. Use when the user asks to raise, file, open, create, or log a GitHub issue, ticket, bug, task, enhancement, cleanup, follow-up, or investigation; ask only necessary clarifying questions, use the repo issue template, select the GitHub Issue Type, add appropriate existing labels, and assign the issue to the requester/current GitHub user. When the issue is one piece of a larger issue's breakdown, keep the parent issue and create this issue as a native GitHub sub-issue of it so the parent shows a progress bar.
---

# Raise Issue

Use this workflow to create a GitHub issue from a user request. All project facts come from the repository's `AGENTS.md` (see the harness contract): the repo slug and issue template path from § Repositories, and the board owner/project number from § Project Board. If a required AGENTS.md section is missing, say which section is missing and stop — do not guess project facts.

## Workflow

1. Inspect the repository context.
   - Resolve the issue template path from `AGENTS.md` § Repositories and read it before drafting. If no template is defined or the file does not exist, use the fallback headings below.
   - Determine the GitHub repo from `AGENTS.md` § Repositories, confirming with `gh repo view --json owner,name` or `git remote -v` when in doubt.
   - Determine the assignee from the user's explicit request. If the user says "me" or gives no assignee, use the authenticated login from `gh api user --jq .login`.

2. Ask clarifying questions only when required to create a useful issue.
   - Ask for the missing behavior/problem if the request is too vague to summarize.
   - Ask for expected outcome or acceptance criteria if completion would otherwise be ambiguous.
   - Ask for Type or labels only when they cannot be inferred from the request and the live lists below.
   - Determine whether this issue belongs under a parent issue. If the request is a piece of a larger issue's breakdown, or the user names a parent, capture the parent issue number so the new issue can be linked as a sub-issue in step 6.
   - Do not ask for optional details that can be reasonably inferred. Put non-blocking unknowns in `Notes`.

3. Load available GitHub Issue Types and labels.

   ```powershell
   gh api graphql -f query='query($owner: String!, $repo: String!) { repository(owner: $owner, name: $repo) { issueTypes(first: 20) { nodes { id name description isEnabled } } } }' -F owner=OWNER -F repo=REPO
   gh label list --repo OWNER/REPO --limit 200
   ```

   When the repository has Issue Types enabled, select exactly one enabled Type before creating the issue (commonly `Task`, `Bug`, or `Feature` — the live response is the source of truth). If Types are not enabled, skip the Type step and note that in the final report. Do not substitute labels for Type. Use existing labels only; prefer the smallest useful set (area/priority labels only when clearly supported by the request). Do not create new labels unless the user explicitly asks.

4. Draft the issue body using the issue template headings when a template exists, otherwise:
   - `## Summary`: concise problem or requested change.
   - `## Context`: relevant background, impacted flow, current behavior, links, logs, or code references.
   - `## Expected outcome`: concrete success criteria.
   - `## Tasks`: actionable checklist items.
   - `## Notes`: assumptions, unknowns, screenshots/log placeholders, or implementation hints.

   If the project's `AGENTS.md` states that execution checklists live elsewhere (e.g. a plan-ledger comment convention), omit `## Tasks` from the body — the issue body is the durable spec, and `## Expected outcome` defines "done".

5. Create the issue, then set the Issue Type when applicable.
   - Stage multi-line bodies in a temporary `.tmp-*` markdown file (e.g. `.tmp-issue-body.md`) and pass it via `--body-file`; delete the file afterwards.
   - Pass `--title`, `--body-file`, `--label`, and `--assignee`.
   - Assign to the current authenticated user when the requester says "assign me" or names no other assignee.
   - `gh issue create` has no native Type flag, so set the Type immediately afterwards via the GraphQL `updateIssue` mutation using the selected `issueTypeId`.
   - If creation or Type assignment fails because of auth, permissions, unavailable Issue Types, or network access, report the exact blocker and do not fabricate completion.

   ```powershell
   gh issue create --repo OWNER/REPO --title "..." --body-file .tmp-issue-body.md --label "label-a,label-b" --assignee LOGIN
   gh issue view ISSUE_URL --json id --jq .id
   gh api graphql -f query='mutation($id: ID!, $issueTypeId: ID!) { updateIssue(input: {id: $id, issueTypeId: $issueTypeId}) { issue { number url issueType { name } } } }' -F id=ISSUE_ID -F issueTypeId=ISSUE_TYPE_ID
   ```

6. Link the issue under its parent when it is one piece of a larger issue's breakdown (parent captured in step 2).
   - Keep the parent issue as the high-level summary and attach this issue as a native GitHub sub-issue of it, so GitHub shows a progress bar on the parent that advances as its children close. Do not replace the parent with its parts, and do not track the breakdown only as a text checklist.
   - The sub-issues API links by the child's REST database `id` (an integer), not its issue number. Resolve `<owner>/<repo>` from `AGENTS.md` § Repositories:

   ```powershell
   $childId = gh api repos/OWNER/REPO/issues/CHILD_NUMBER --jq '.id'
   gh api --method POST repos/OWNER/REPO/issues/PARENT_NUMBER/sub_issues -F sub_issue_id=$childId
   ```

   - Verify the link took, then report the parent and child numbers:

   ```powershell
   gh api repos/OWNER/REPO/issues/PARENT_NUMBER/sub_issues --jq '.[].number'
   ```

   - If the sub-issues API is unavailable (older `gh`, or the endpoint returns 404/410), report that the sub-issue link could not be completed and surface the parent and child numbers so the relationship can be added in the GitHub UI. Do not silently leave the child as an orphaned top-level issue without saying so.

7. Add the issue to the project board when the user asks or the project workflow clearly requires it.
   - Resolve the board owner and project number from `AGENTS.md` § Project Board.

   ```powershell
   gh project item-add <project-number> --owner <owner> --url ISSUE_URL
   ```

   - If this fails with a missing scope, ask the user to run `gh auth refresh --hostname github.com -s project`, then report the blocker and the issue URL.

8. Verify and report.

   ```powershell
   gh issue view ISSUE_URL --json number,title,url,labels,assignees
   gh api graphql -f query='query($id: ID!) { node(id: $id) { ... on Issue { number url issueType { name } } } }' -F id=ISSUE_ID
   ```

   The final response must include the issue URL, title, Issue Type (or a note that Types are not enabled), labels applied, assignee, parent issue link when the issue was created as a sub-issue, and board status if changed.

## Drafting Rules

- Keep titles specific and concise, starting with a capital letter.
- Preserve the issue template's section names when a template exists.
- Select and verify a GitHub Issue Type whenever the repo has Types enabled.
- Avoid implementation promises unless the request or code context clearly supports them.
- Do not leave the issue unassigned unless the authenticated user cannot be determined or the user requests no assignee.
- Do not apply speculative labels. Missing optional labels are better than wrong labels.
- When an issue is part of a larger issue's breakdown, keep the parent issue as the summary and link each new issue as a sub-issue of it (step 6); never dissolve the parent into a pile of loose top-level issues.
