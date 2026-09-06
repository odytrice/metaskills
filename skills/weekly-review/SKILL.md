---
name: weekly-review
description: Aggregate engineering activity into Docs/status/. Use for a weekly review, status update, or progress report.
---

# Weekly Review

Deterministic aggregation; when delegating, prefer a cost-efficient model with `Docs/` writes and read-only `gh`/`git`.

From `AGENTS.md`: **§ Project Overview** (product/themes), **§ Repositories** (app/deployment repos), **§ Project Board**. Explicit `board: none`: skip counts per `issue-plan`. Missing/incomplete board facts or required sections: name them and stop.

## Process

1. **Range**: last 7 days unless the user gives one.
2. **Gather**:

   ```sh
   gh api --paginate 'repos/<owner>/<repo>/issues?state=all&per_page=100'
   gh api --paginate 'repos/<owner>/<repo>/pulls?state=all&per_page=100'
   gh api --paginate 'repos/<owner>/<repo>/actions/runs?per_page=100'
   git log --since="7 days ago" --oneline --decorate
   ```

   Use documented app repo; repeat runs only for documented deployment repo. Exclude `pull_request` issue entries. Fully paginate before date filtering; retain open items for backlog metrics. Board counts: `issue-plan` § Board Status Transitions' complete read, consuming-repo Issue filter, retained URL/repo identity. Samples are not totals; unavailable/incomplete data is unknown, never zero/complete. Read existing `Docs/` and `Docs/status/`. Local validation only if requested or cheap and relevant.

3. **Themes**: derive from labels/milestones, § Project Overview areas, recurring commit/path subsystems. Include active security/auth, deployment/CI, documentation themes.
4. **Critical items**: highest-priority open issues, blockers, stale PRs, failed app/deployment CI/CD, new data-integrity/auth risks.
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

Metrics: open issues by priority/label; top blockers opened/closed; merged/open PRs; observed-only build/test status; latest pipeline per repo; defined board Status counts; milestone/ship-list status if defined in `AGENTS.md`/`Docs/`.

Link issues/PRs; mark stale docs historical. No secrets/token values.
