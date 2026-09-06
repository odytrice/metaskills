# Workflow Regression Scenarios

These are manual, scenario-based evaluations of agent instructions, not executable tests. Evaluate with mocked tool responses or instruction walkthroughs; do not make live GitHub writes. Record pass/fail and the observed action sequence for each case. The executable `./sync.sh --check` checks harness structure/parity, not these behaviors.

| Scenario / Fixture | Expected Actions |
|---|---|
| Initial implementation; unique ledger, current-cycle claim, in-progress | Developer executes initial mode in an isolated worktree; opens one fully resolving PR; verifies exactly the intended closing URL; transitions to in-review. |
| Revision; open matching PR, in-review, authorized dispatch with enumerated findings | Developer accepts revision preconditions, fixes only findings on the same branch, validates and rechecks closing reference; no new PR or claim. |
| Revision with only a PR number, wrong issue/repo, or closed PR | Stop before edits; do not infer authorization or apply initial mode. |
| First implementation blocker in this cycle | Coordinator supplies ownership evidence and the ledger REST id/link for one architect repair; architect updates that ledger and applies the approval gate; continue only if blockers clear. |
| Second blocker, unresolved design decision, or unrelated parked ledger | Stop/park and report; no generic resume, second repair, or coordinator design answer. |
| Existing ledger on ready, in-progress, or boardless issue; ordinary or batch dispatch | Report claimed without modifying it. Explicit user resume is required; an apparently abandoned ledger is not permission. |
| Explicit board: none; new issue with no ledger | Skip every board command; create and verify the single ledger with numeric-id tie-break; preserve authorization checks in implementation and revision; report board: none. |
| Missing/incomplete board configuration in a workflow requiring board facts | Stop for missing facts, including weekly-review; never reinterpret it as board: none. |
| Local diff review with missing board configuration | Review in place using layout, validation, and review guidance; no board reads or missing-board blocker. PR mode still requires board facts. |
| Boardless batch with no list, label query, or milestone | Ask for scope; do not invent a ready/backlog candidate set. |
| Existing ledger appears only on REST comment page 2; GraphQL id also available | Fetch all REST pages, retain numeric id and URL, update only the authorized unique ledger by REST PATCH; never send a GraphQL id to PATCH/DELETE. |
| Ledger creation/update succeeds or fails | Keep freshly written temp body through POST/PATCH and verification; remove afterward on either path, report failure honestly. Never delete it before PATCH. |
| Concurrent ledger creators | Re-fetch all pages, compare numeric ids; later creator deletes only its own new comment and yields. Multiple pre-existing ledgers stop as ambiguous. |
| Closing references empty, wrong repo with same number, or intended issue plus an extra issue | Reject handoff; fix references and verify exact singleton canonical URL. Unregisterable base is a blocker, not an endless retry. |
| Partial implementation versus standalone partial PR review | issue-implement/dev-cycle stop for repair or approved split, never use Refs as delivery. code-review may review/merge an unrelated partial PR if criteria hold; never mark a merely referenced issue done. |
| Board exceeds 200 items; same issue number in two repos; PR and draft items present | Obtain totalCount, fetch actual total, verify completeness, filter consuming-repo Issues and match canonical URL uniquely. Batch/report preserve repository identity; exclude unrelated items. |
| Board changes during enumeration; zero or multiple canonical URL matches | Retry changed totals; stop if completeness cannot be established. Zero matches asks, multiple matches stop; never choose the first or silently add. |
| Issue/PR/report data spans multiple pages | Fetch all applicable pages, apply scope/range filters, exclude REST PR entries from issue counts; incomplete report data is unknown, not zero or a complete metric. |
| PR head changes during fetch, review, or just before merge | Detached checkout must equal captured head; review pinned base/head diff and validate. Changed head requires fresh checkout and re-review; merge uses --match-head-commit with the actual reviewed SHA. Rejection never permits a blind retry with the new SHA. |
| Base moves or review checkout is dirty during cleanup | Refresh review/validation for changed base; dirty worktree is left with a report. Detached review creates no local branch to delete. |
| Pre-existing local PR-head branch, including additional unpushed commits | Merge the reviewed remote SHA without --delete-branch; preserve the local branch and its tip. Remote cleanup is left to repository automation or explicit request. |
| Batch cleanup with retained user/implementation branches | Remove only clean, skill-owned temporary artifacts; preserve branches and user work, reporting retained artifacts. |
| Review requests changes for important Medium findings only | Coordinator reports the unmet merge criterion and leaves the PR open for the user; no invented revision or merge path. |
| Consuming-project template declares board: none | No lifecycle options or automation metadata required; use ledger ownership/tie-break and explicit-resume safeguards. |
| Every command wrapper, including QA | Preserve frontmatter and dispatch only to the same-named skill with $ARGUMENTS; no duplicated mode/default/workflow policy. |
| Project-manager in each dialect | Same prose: local shell read-only, file writes only Docs/ and temp bodies, GitHub writes only as skill-authorized and approved. Existing tools/permissions/sandbox remain unchanged. |

Residual concurrency limit: board transitions and ledger edits are not atomic locks or compare-and-swap updates. Re-fetching and the creation tie-break reduce races but cannot eliminate all simultaneous claimant/editor races; ambiguous ownership must stop rather than overwrite.
