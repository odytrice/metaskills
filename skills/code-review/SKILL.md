---
name: code-review
description: Review a GitHub PR/branch or the local uncommitted diff for bugs, regressions, missing tests, architecture drift, and release-readiness risks. PR mode reviews from a separate agent and worktree, posts findings as a PR comment, and may auto squash-merge. Local mode reviews the working tree as a pre-commit gate where any Critical or High finding blocks the commit.
---

# Code Review

Use this skill when asked to review a PR, branch, diff, GitHub issue implementation, or the current uncommitted changes.

This skill is project-agnostic. All project facts come from the repository's `AGENTS.md`
(see the harness contract). Before starting, confirm `AGENTS.md` provides:

- **§ Branch Map** — base branches for PRs and review worktrees.
- **§ Build & Validation** — validation commands and the DB tripwire file list.
- **§ Code Layout & Tech Stack** — where code lives and the conventions to enforce.
- **§ Review Notes** — project-specific checks layered on top of `checklist.md`.

If a required section is missing, say which one and stop — do not guess.

## Modes

- **PR mode** (default when given a PR number, PR URL, or branch): review from a separate
  agent and a separate review worktree, post the review as a PR comment, and squash-merge
  only when the automatic merge criteria are met.
- **Local mode** (when asked to review uncommitted working-tree changes, or when invoked
  as the pre-commit gate of a deploy/commit flow): review the local diff in place and
  report to the user. Any Critical or High finding blocks the commit.

Both modes use `checklist.md` (in this skill directory) as the detailed checklist and
`output-format.md` as the output structure.

## Review Stance (both modes)

Lead with findings. Prioritize:

- Security bugs, auth/access-control regressions, and tenant/user data-isolation bugs.
- Incorrect business logic in primary features (calculations, workflows, state transitions).
- Data-loss risks, destructive migrations, and repository/mapping bugs.
- API/DTO mismatches between backend transfer types and frontend usage.
- Frontend route/load/auth issues and SSR hazards.
- Missing tests for changed behavior.
- Secrets or production-only config changes.
- Violations of `AGENTS.md` or `checklist.md`.

Also apply the project-specific checks in `AGENTS.md` § Review Notes, including
interactions with known existing bugs and areas under active migration. Do not spend
review energy on style nits unless they hide a real maintenance or correctness risk.

Check the trajectory, not just the output:

- Confirm the diff matches the linked issue's stated scope; flag silent scope expansion
  (files, endpoints, or behavior changed beyond what was asked).
- Confirm new or changed tests actually exercise the changed behavior, not merely exist
  or assert trivially; a passing suite that skips the risky path is a worse signal than
  a visible failure.
- Confirm the change reaches the dangerous last 20% (edge cases, error handling,
  integration points) rather than only the happy path that "looks right."
- Note any place the implementer should have stopped to ask instead of guessing a
  business-logic assumption.

---

## PR Mode

### Agent Boundary

Run the review from a different agent than the one that implemented the change.

- If the current agent authored or substantially edited the implementation, stop and
  spawn a separate review agent.
- Pass the review agent only the PR number/URL, linked issue, and any necessary
  validation expectations.
- The review agent must not reuse the implementation worktree or inherit implementation
  context unless explicitly needed for a narrow question.
- The review agent posts the review as a PR comment.
- The review agent may squash-merge the PR only when the automatic merge criteria below
  are met. Otherwise, merging remains the coordinator's responsibility.

### Review Worktree

Determine the PR's base branch (`baseRefName` from `gh pr view`, cross-checked against
`AGENTS.md` § Branch Map) and create a separate review worktree from it:

```powershell
git fetch origin <base-branch>
git worktree add .worktrees/review-pr-<number> origin/<base-branch>
Set-Location .worktrees/review-pr-<number>
gh pr checkout <number>
```

Run all review reads, diffs, and validation from the review worktree. When finished and
the PR comment is posted, return to the original repo and remove the review worktree:

```powershell
git worktree remove .worktrees/review-pr-<number>
git worktree prune
```

Before removing the review worktree, verify the resolved path is inside the repo's
`.worktrees/` directory. If cleanup fails or the worktree is dirty, stop and report the
path and reason.

### Process

1. Gather context.
   - `gh pr view <number> --json title,body,files,commits,baseRefName,headRefName,headRefOid,url`
   - `gh pr diff <number>`
   - `gh issue view <number>` for linked issues.
   - `git status --short` in the review worktree.
2. Read the changed files.
   - Use `AGENTS.md` § Code Layout & Tech Stack to navigate the change: respect
     compile/build order, check DTO mirrors on both sides of the API boundary, route
     wiring and handler auth, migrations and data mappings, and frontend route loads,
     stores, and nullable data handling.
3. Apply the checklist.
   - Work through the relevant sections of `checklist.md` for the changed areas, plus
     `AGENTS.md` § Review Notes.
4. Validate where practical.
   - Run the validation commands from `AGENTS.md` § Build & Validation for the layers
     the PR touches (backend tests, frontend type-check/lint/build, full-app build).
   - If the PR touches any DB tripwire file listed in `AGENTS.md` § Build & Validation,
     confirm the live-database integration suite ran and passed (in CI or locally)
     before approving.
   - For deployment/infra PRs, inspect Dockerfiles, CI workflows, and any deployment
     manifests; verify no secrets are committed.
5. Post the review as a PR comment using `output-format.md`, with a header line:

   ```md
   **Review complete** -- [View PR](<pr-url>)
   ```

   If a job/action URL is available, link it as `View job` instead. Do not fabricate
   elapsed time, actor handles, or job URLs; use neutral wording when that metadata is
   unavailable.

### Automatic Squash Merge

After posting the review comment, squash-merge the PR only when all of these are true:

- The overall assessment is `Approve`.
- There are no Critical or High findings.
- There are no important Medium findings that should be fixed before merge.
- Required GitHub checks have passed.
- Validation did not reveal a production-breaking issue.
- The PR is mergeable against its base branch.

Use the PR's commit subject when it already follows `AGENTS.md`; otherwise use a short
single-line imperative subject that follows `AGENTS.md`, including the issue prefix when
available. Do not add a merge commit body unless the repository workflow explicitly
requires one.

Do not auto-merge when the assessment is `Changes requested` or `Critical issues found`,
when required checks are pending/failing, when the merge state is blocked/dirty, or when
the user explicitly asks for review only. Check `AGENTS.md` § Branch Map for what
merging the base branch triggers (e.g. a deployment pipeline); do not merge if the user
wants to control deploy timing.

After posting the comment and performing any eligible squash merge, report the PR
comment URL, the merge commit if merged, and review worktree and local branch cleanup
status.

After removing the review worktree, delete the local PR head branch if GitHub confirms the
PR is merged and its tip still matches `headRefOid`. Force deletion is allowed for squash
merges. Otherwise, leave the branch intact and report why.

---

## Local Mode

Local mode reviews the current working tree — typically as the pre-commit gate in a
deploy or commit flow. No worktree or separate agent is required; review in place.

### Process

1. Identify changed files.
   - `git diff --name-only` and `git diff --cached --name-only` (staged).
   - If specific file paths were provided, review those instead.
   - If there are no changed files, report that there is nothing to review and stop.
2. Determine scope. Map the changed files to the code areas in `AGENTS.md` § Code
   Layout & Tech Stack and apply only the relevant `checklist.md` sections.
3. Read the changed files and their diffs (`git diff -- <path>`,
   `git diff --cached -- <path>`).
4. Apply the checklist sections for the changed areas, plus `AGENTS.md` § Review Notes.
5. Validate where practical using the commands from `AGENTS.md` § Build & Validation
   for the touched layers. If any DB tripwire file is touched, the live-database
   integration suite must run before the change is committed.
6. Report the review to the user (not a PR comment) using `output-format.md`.

### Commit Gate

Any **Critical** or **High** finding blocks the commit. State the block explicitly in
the Summary ("Commit blocked: <n> Critical/High finding(s)") and list what must be
fixed. Do not proceed with (or recommend proceeding with) the commit until those
findings are resolved and re-reviewed. Medium and Low findings do not block, but must
be reported.

---

## Harness Feedback

In either mode, when a finding recurs across reviews or reveals a missing durable
guardrail, propose a concrete `AGENTS.md` rule (usually under § Review Notes) or a
`checklist.md` line that would have caught it. Include this in the Harness Feedback
section of the output only when there is something durable to add — the goal is a
compounding rule set, not noise.
