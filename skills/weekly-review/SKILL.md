---
name: weekly-review
description: Write a weekly engineering status update to Docs/status/ from GitHub issues, PRs, commits, CI runs, board counts, and local docs. Use when asked for a weekly review, status update, or progress report.
---

# Weekly Review

Deterministic aggregation, not frontier reasoning; when delegating, prefer a cost-efficient model with `Docs/` write access and read-only `gh`/`git`.

Project facts from `AGENTS.md`: **§ Project Overview** (product, themes), **§ Repositories** (app repo; deployment repo if any), **§ Project Board** (optional; skip board counts if absent). § Repositories missing: name it and stop.

## Process

1. **Range**: last 7 days unless the user gives one.
2. **Gather**:

   ```sh
   gh issue list --state all --limit 200 --json number,title,state,labels,assignees,updatedAt,closedAt,url
   gh pr list --state all --limit 100 --json number,title,state,labels,author,updatedAt,mergedAt,url
   gh run list --repo <app-repo-slug> --limit 20
   gh run list --repo <deployment-repo-slug> --limit 20   # only when § Repositories lists one
   git log --since="7 days ago" --oneline --decorate
   gh project item-list <project-number> --owner <owner> --format json --limit 200   # only when § Project Board defines a board
   ```

   Plus `Docs/` and `Docs/status/` when present. Local validation only if the user asks or it is cheap and relevant.

3. **Themes** from the data, not a fixed list: labels and milestones present; product areas in § Project Overview; recurring subsystems in commits and paths. Always include security/auth, deployment and CI, and documentation when activity exists.
4. **Critical items**: highest-priority open issues; blocked work; stale PRs; failed CI/CD (app and deployment repos); new risks (data integrity, auth).
5. **Write** `Docs/status/YYYY-MM-DD-weekly-review.md` (create the directory if needed):

   ```md
   # Developer Team Status Update - YYYY-MM-DD
   ## Executive Summary
   ## Completed
   ## In Review
   ## In Progress
   ## Critical Items
   ## Metrics
   ## Next Week
   ```

Metrics: open issues by priority/label; top blockers opened/closed; PRs merged and open; build/test status only as observed, never claimed; last pipeline result per repo; board counts by Status when defined; milestone/ship-list status when `AGENTS.md` or `Docs/` defines one.

Link issues and PRs. Mark stale historical docs as historical if referenced. No secrets or token values.
