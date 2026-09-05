---
name: issue-raise
description: Create a GitHub issue with the repo template, Issue Type, existing labels, assignee, and board placement; link it as a native sub-issue when it is part of a parent's breakdown. Use when asked to raise, file, open, create, or log an issue, bug, task, or follow-up.
---

# Raise Issue

Project facts from `AGENTS.md`: **§ Repositories** (repo slug, issue template path), **§ Project Board** (owner, project number, new-issue status). Missing section: name it and stop.

## Workflow

1. Read the issue template at the § Repositories path (absent: use the fallback headings below). Confirm the repo with `gh repo view --json owner,name` when in doubt. Assignee: the user's choice; "me" or unspecified means `gh api user --jq .login`.
2. Ask only what a useful issue needs: the problem if the request is too vague; the expected outcome if "done" would be ambiguous; Type or labels only when not inferable; the parent number when this is a piece of a breakdown. Non-blocking unknowns go in `Notes`.
3. Load Issue Types and labels. If Types are enabled, select exactly one (live list is the source of truth; never substitute labels for Type); otherwise note it. Existing labels only, the smallest useful set; never create labels unless asked; a missing optional label beats a wrong one.

   ```sh
   gh api graphql -f query='query($owner: String!, $repo: String!) { repository(owner: $owner, name: $repo) { issueTypes(first: 20) { nodes { id name description isEnabled } } } }' -F owner=OWNER -F repo=REPO
   gh label list --repo OWNER/REPO --limit 200
   ```

4. Draft the body with the template headings, otherwise `## Summary` (problem or requested change), `## Context` (background, impacted flow, current behavior, links, logs), `## Expected outcome` (concrete success criteria; defines "done"), `## Notes` (assumptions, unknowns, placeholders). The body is the What; no task checklist (that is the plan ledger, see `issue-plan`); if the template has a tasks section, leave a one-line pointer to the ledger. Title specific and concise; no implementation promises the request or code does not support.
5. Create, then set the Type (`gh issue create` has no Type flag). Stage the body in `.tmp-issue-body.md` with a file-write tool; delete it afterward. On auth, permission, or network failure report the exact blocker; never fabricate completion.

   ```sh
   gh issue create --repo OWNER/REPO --title "..." --body-file .tmp-issue-body.md --label "label-a,label-b" --assignee LOGIN
   gh issue view ISSUE_URL --json id --jq .id
   gh api graphql -f query='mutation($id: ID!, $issueTypeId: ID!) { updateIssue(input: {id: $id, issueTypeId: $issueTypeId}) { issue { number url issueType { name } } } }' -F id=ISSUE_ID -F issueTypeId=ISSUE_TYPE_ID
   ```

6. Link under the parent when applicable (Sub-Issue Linking).
7. Board (unless § Project Board is `none` or the user says not to): add the item, then set its Status to the new-issue status per `issue-plan` § Board Status Transitions; an item without a status appears in no column.

   ```sh
   gh project item-add <project-number> --owner <owner> --url ISSUE_URL
   ```

8. Verify and report URL, title, Type (or "Types not enabled"), labels, assignee, parent link, verified board status.

   ```sh
   gh issue view ISSUE_URL --json number,title,url,labels,assignees
   gh api graphql -f query='query($id: ID!) { node(id: $id) { ... on Issue { number url issueType { name } } } }' -F id=ISSUE_ID
   ```

## Sub-Issue Linking (shared mechanics)

`issue-refine` and `burndown` delegate splitting here. Keep the parent as the high-level summary and attach each piece as a native sub-issue so the parent shows a progress bar; never dissolve a parent into loose top-level issues or track a breakdown only as text. The API links by the child's REST database `id` (integer), not its number; `<owner>/<repo>` from § Repositories:

```sh
gh api repos/OWNER/REPO/issues/CHILD_NUMBER --jq '.id'
gh api --method POST repos/OWNER/REPO/issues/PARENT_NUMBER/sub_issues -F sub_issue_id=<child-id>
gh api repos/OWNER/REPO/issues/PARENT_NUMBER/sub_issues --jq '.[].number'
```

Verify, then report parent and child numbers. If the endpoint is unavailable (older `gh`, 404/410), say so and surface both numbers for the UI; never leave a child silently orphaned.
