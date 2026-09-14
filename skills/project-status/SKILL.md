---
name: project-status
description: Group every not-done issue by how the items relate and summarize each group. Use for a project status, board overview, backlog map, open-work landscape, or "what is left" question.
---

# Project Status

Read-only analysis: no issue, label, board, or code writes. Report in the conversation; write `Docs/status/YYYY-MM-DD-project-status.md` only when the user asks for a file.

From `AGENTS.md`: **§ Project Overview** (product areas), **§ Code Layout & Tech Stack** (subsystems), **§ Repositories** (app repo), **§ Project Board** (status names, which option is done). Explicit `board: none`: open issues are the population and status is not reported. Missing/incomplete facts or sections: name them and stop.

## Process

1. **Scope**: all not-done items by default: open issues in the app repo, excluding `pull_request` entries; with a board, also read each item's status and drop the done option. The user may narrow by label, milestone, status, assignee, or issue list. Closed issues are done regardless of board status; report closed-but-not-done and open-but-off-board items as anomalies, not group members.
2. **Gather** completely:

   ```sh
   gh api --paginate 'repos/<owner>/<repo>/issues?state=open&per_page=100'
   gh api --paginate 'repos/<owner>/<repo>/issues/<number>/sub_issues?per_page=100'
   gh api --paginate 'repos/<owner>/<repo>/issues/<number>/comments?per_page=100'
   ```

   Board statuses: `issue-plan` § Board Status Transitions' complete lookup (returned count = `totalCount`), filtered to consuming-repo Issues and matched by canonical URL. Fetch sub-issues for every item whose `sub_issues_summary.total` > 0. Read comments only where the body leaves relations unclear (plan ledgers, "blocked by" notes). Incomplete enumeration: stop and say what is missing; never group a sample as the whole.
3. **Relate** items by the strongest signal, in this order:
   - parent/sub-issue hierarchy
   - explicit references: `#n`, issue URLs, "blocks", "blocked by", "depends on", "duplicate of"
   - shared milestone
   - shared label, product area (§ Project Overview), or subsystem (§ Code Layout; a quick path search only when titles name files)
   - the same user-visible outcome or the same root cause in title/body

   Record the signal behind every link; never infer relations from vague wording.

4. **Group**: linked items share a group. Split a group that mixes unrelated outcomes even when it shares a label; name each group by outcome, not by label. Each item has one primary group; note cross-group links. Unrelated items stay in a final **Standalone** list, never forced into a group. Keep groups at roughly 2 to 10 items; sub-group larger clusters.
5. **Report**, groups ordered by blocking impact then size:

   ```md
   # Project Status - YYYY-MM-DD
   ## Summary
   Totals: items, groups, standalone, anomalies. One-paragraph landscape.
   ## <Group name> (n items)
   Why related: <signal(s)>
   Summary: two to four sentences: outcome, current state, dependencies, blockers, risk.
   - #n title [status] [labels/milestone]: one-line role in the group
   ## Standalone (n)
   ## Anomalies
   Closed-but-not-done, open-but-off-board, likely duplicates, stale (no update in 90+ days), unassigned high-priority.
   ## Suggested next steps
   Groups worth `backlog-refine` or `burndown`, in dependency order.
   ```

Link every issue; counts are complete reads, never estimates. No secrets/token values. Recommendations only: never close, relabel, merge, or transition anything.
