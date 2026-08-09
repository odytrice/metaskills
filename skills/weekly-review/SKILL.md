---
name: weekly-review
description: Generate a weekly developer status update from GitHub issues, PRs, commits, CI runs, project board signals, and local docs, written to Docs/status/. Use when the user asks for a weekly review, status update, or team progress report.
---

# Weekly Review Generation

Use this skill to produce a weekly engineering status update for the current project. This is deterministic aggregation, not frontier reasoning; when delegating, prefer a cost-efficient model with `Docs/` write access and read-only `gh`/`git`.

## Prerequisites

Read the repository's `AGENTS.md` first. This skill depends on:

- **§ Project Overview**: to understand what the product is and pick sensible themes.
- **§ Repositories**: app repo slug, and the deployment repo slug if one exists.
- **§ Project Board**: owner/org, project number, and Status option names (optional; skip board counts if absent).

If `AGENTS.md` or § Repositories is missing, say so and stop rather than guess.

## Data Sources

- GitHub issues: `gh issue list`, `gh issue view`
- GitHub PRs: `gh pr list`, `gh pr view`
- Git commits: `git log --since`
- CI/CD: `gh run list` for the app repo, **and** for the deployment repo when AGENTS.md § Repositories lists one (deploy state lives there)
- Project board: `gh project item-list` per AGENTS.md § Project Board, when defined
- Local docs: `Docs/`, `Docs/status/`, `Docs/plans/` when present
- Local validation only if the user asks or it is cheap and relevant

## Process

1. **Determine date range.** Default to the last 7 days; use the user's range if provided.

2. **Gather GitHub activity.**

```powershell
gh issue list --state all --limit 200 --json number,title,state,labels,assignees,updatedAt,closedAt,url
gh pr list --state all --limit 100 --json number,title,state,labels,author,updatedAt,mergedAt,url
gh run list --repo <app-repo-slug> --limit 20
# Only when AGENTS.md § Repositories lists a deployment repo:
gh run list --repo <deployment-repo-slug> --limit 20
git log --since="7 days ago" --oneline --decorate
```

When AGENTS.md § Project Board defines a board:

```powershell
gh project item-list <project-number> --owner <owner> --format json --limit 200
```

3. **Group by theme.** Derive themes from the data; do not use a fixed list. Sources for themes, in order:
   - Issue/PR labels and milestones actually present in the gathered data.
   - Product areas described in AGENTS.md § Project Overview.
   - Recurring subsystems visible in commit messages and file paths.

   Always include cross-cutting themes when activity exists: security/auth, deployment and CI, documentation.

4. **Identify critical items.** Call out:
   - Highest-priority issues (P0 or equivalent label) still open.
   - Blocked work.
   - Stale PRs.
   - Failed validation or failed CI/CD pipelines (app and deployment repos).
   - New risks discovered, including data-integrity or auth risks.

5. **Write the document.** Create (making the directory if needed):

```text
Docs/status/YYYY-MM-DD-weekly-review.md
```

Use this structure:

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

## Metrics To Include

- Open issues by priority/label when labels support it.
- Highest-priority blockers open/closed this week.
- PRs merged this week; PRs currently open.
- Test/build status if known; never claimed, only observed.
- CI/deployment pipeline status: last run result per repo (app, and deployment repo when one exists).
- Project board counts by Status option when a board is defined in AGENTS.md.
- Milestone/ship-list ticket status when AGENTS.md or `Docs/plans/` defines a launch or milestone scope.

## Rules

- Do not claim validation passed unless you checked it.
- Do not expose secrets or token values in the report.
- Link to GitHub issues and PRs.
- Keep stale historical docs clearly marked as historical if referenced.
