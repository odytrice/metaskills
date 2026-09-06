---
name: harness-parity-check
description: Audit MetaSkills skill, command, and agent parity before sync or release.
---

# Harness Parity Check

Use for requested verification, audits, reviews, or sanity checks of MetaSkills changes.

## Goals

- Enforce `AGENTS.md`'s project-fact, thin same-name `$ARGUMENTS` wrapper, identical three-dialect role-body, and installer invariants.
- One owner per mechanic: `issue-plan` owns board transitions/ledger creation; `issue-raise`, sub-issue linking; `issue-implement`, worktrees/PRs; `code-review`, review worktree/merge; `dev-cycle`, revision-loop bound. Others reference, never restate.
- Preserve boundaries: `issue-refine` never designs; `issue-plan` is architect-only; `issue-implement` never plans/claims; `dev-cycle` and `burndown` never code, post plans, transition boards, or merge.
- Installed managed files match `README.md`.

## Workflow

1. Run mechanical lint first (coverage in `AGENTS.md`):

   ```sh
   ./sync.sh --check        # macOS/Linux
   .\sync.ps1 -Check        # Windows
   ```

2. Inspect changes: `git status --short`, `git diff --name-only`.

3. Read changed `SKILL.md` files fully: no embedded project facts, including stack-specific tooling/idioms; resolve required facts from named consuming-project `AGENTS.md` sections, applying the missing-section rule.

4. Diff changed role bodies across all three dialects; body differences are findings.

5. For added/renamed/removed files, verify `README.md`'s managed set. Installers auto-discover files and remove stale installs through manifests.

6. Report findings first, or explicitly none; name residual risks such as unrun sync or PowerShell validation.

## Rules

- No edits unless fixes are requested; no unrequested install. Use `sync-metaskills` for preview/install.
- Equivalent dialect configuration syntax is not a finding; role bodies must remain identical.
- Critical/High: stale instructions, omitted managed files, canonical project facts, guessed missing facts, or conflicting duplicate mechanic ownership.
