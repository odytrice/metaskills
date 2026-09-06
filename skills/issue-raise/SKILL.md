---
name: issue-raise
description: Create correctly classified, assigned GitHub issues and native sub-issues. Use to raise, file, open, create, or log an issue, bug, task, or follow-up.
---

# Raise Issue

Project facts from `AGENTS.md`: **§ Repositories** (repo slug, issue template path), **§ Project Board** (owner, project number, new-issue status). Missing section: name it and stop.

Explicit `board: none` is valid per `issue-plan` § Board Status Transitions: skip board operations and report it. Missing board facts still stop.

## Workflow

1. Read the § Repositories issue template (absent: fallback below). If unsure, confirm repo with `gh repo view --json owner,name`. Use requested assignee; "me"/unspecified: `gh api user --jq .login`.
2. Clarify only ambiguous problem/outcome, uninferable Type/labels, or breakdown parent number. Put non-blocking unknowns in `Notes`.
3. Load live Types and labels. If Types are enabled, select exactly one; otherwise note it. Labels never substitute. Use the smallest useful existing label set; omit questionable optional labels; create none unless asked.

   ```sh
   gh api graphql -f query='query($owner: String!, $repo: String!) { repository(owner: $owner, name: $repo) { issueTypes(first: 20) { nodes { id name description isEnabled } } } }' -F owner=OWNER -F repo=REPO
   gh api --paginate repos/OWNER/REPO/labels --jq '.[] | {name, description}'
   ```

4. Use template headings, otherwise `## Summary` (problem/change), `## Context` (background, impacted flow, current behavior, links/logs), `## Expected outcome` (testable success), `## Notes` (assumptions/unknowns/placeholders). Body = What; tasks belong in `issue-plan`'s ledger. In template task sections, leave a one-line ledger pointer. Use a specific, concise title; no unsupported implementation promises.
5. Stage `.tmp-issue-body.md` with a file-write tool; create, then set Type (no create flag); delete the file afterward. Report exact auth/permission/network blockers, never fabricated completion.

   ```sh
   gh issue create --repo OWNER/REPO --title "..." --body-file .tmp-issue-body.md --label "label-a,label-b" --assignee LOGIN
   gh issue view ISSUE_URL --json id --jq .id
   gh api graphql -f query='mutation($id: ID!, $issueTypeId: ID!) { updateIssue(input: {id: $id, issueTypeId: $issueTypeId}) { issue { number url issueType { name } } } }' -F id=ISSUE_ID -F issueTypeId=ISSUE_TYPE_ID
   ```

6. Link under the parent when applicable (Sub-Issue Linking).
7. Unless board is `none` or user opts out, add the item and set new-issue Status per `issue-plan` § Board Status Transitions; statusless items appear in no column.

   ```sh
   gh project item-add <project-number> --owner <owner> --url ISSUE_URL
   ```

8. Verify and report URL, title, Type (or "Types not enabled"), labels, assignee, parent link, verified board status.

   ```sh
   gh issue view ISSUE_URL --json number,title,url,labels,assignees
   gh api graphql -f query='query($id: ID!) { node(id: $id) { ... on Issue { number url issueType { name } } } }' -F id=ISSUE_ID
   ```

## Sub-Issue Linking (shared mechanics)

For `issue-refine`/`burndown` splits, retain the summary parent and attach native sub-issues (progress bar), never loose issues or text-only tracking. Link by child's integer REST database `id`, not number; repo from § Repositories:

```sh
gh api repos/OWNER/REPO/issues/CHILD_NUMBER --jq '.id'
gh api --method POST repos/OWNER/REPO/issues/PARENT_NUMBER/sub_issues -F sub_issue_id=<child-id>
gh api repos/OWNER/REPO/issues/PARENT_NUMBER/sub_issues --jq '.[].number'
```

Verify and report parent/child numbers. Endpoint unavailable (older `gh`, 404/410): report both for UI linking; never silently orphan a child.
