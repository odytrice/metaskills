---
name: harness-parity-check
description: Check MetaSkills harness consistency across canonical skills, command wrappers, and Claude/opencode/Codex agent role definitions before syncing or releasing harness changes.
---

# Harness Parity Check

Use when the user asks to verify, audit, review, or sanity-check changes to this MetaSkills repository before syncing them into local agent harnesses.

## Goals

- Canonical skills in `skills/<name>/SKILL.md` stay project-agnostic and resolve project facts from the consuming project's `AGENTS.md`.
- Command wrappers in `commands/<name>.md` stay thin `$ARGUMENTS` handoffs to the same-named skill.
- Agent role bodies are identical across `agents/opencode`, `agents/claude`, and `agents/codex`; only frontmatter/permission syntax differs.
- Shared mechanics keep one owner (board transitions and ledger creation in `issue-plan`, sub-issue linking in `issue-raise`, worktree and PR workflow in `issue-implement`, review worktree and merge in `code-review`, the revision-loop bound in `dev-cycle`); other skills reference, not restate.
- Role boundaries hold: `issue-refine` never designs; `issue-plan` is architect-only; `issue-implement` never plans or claims; `dev-cycle` and `burndown` never write code, post plans, transition the board, or merge.
- The sync scripts install the same managed set `README.md` describes.

## Workflow

1. Run the mechanical lint first; it covers frontmatter, wrapper/skill pairing, dialect coverage, and PowerShell-only shell samples:

   ```sh
   ./sync.sh --check        # macOS/Linux
   .\sync.ps1 -Check        # Windows
   ```

2. Inspect the changed files (`git status --short`, `git diff --name-only`).

3. For changed skills, read the full `SKILL.md` and confirm it contains no project facts (repo slugs, board IDs, URLs, cluster or image names, credentials, branch defaults, stack-specific tooling or idioms) and that required facts come from named `AGENTS.md` sections with the missing-section rule applied.

4. For changed agent roles, diff the body of the same role across the three dialects; anything beyond frontmatter and tool-name wording is a finding.

5. When files are added, renamed, or removed, confirm `README.md` still describes the managed set (the sync scripts discover files automatically and remove stale installs via their manifests).

6. Report findings first. If there are none, say so and name any residual risk (e.g. sync not yet run, PowerShell script not exercised on this OS).

## Rules

- Do not auto-edit during a parity check unless the user asks you to fix findings.
- Intentional dialect differences are not findings when behavior is equivalent.
- Critical or High: anything that would install stale instructions, omit a managed file, introduce project-specific facts into canonical skills, let a workflow guess missing project facts, or leave two skills owning the same mechanic with different text.
