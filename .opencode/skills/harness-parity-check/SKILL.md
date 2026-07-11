---
name: harness-parity-check
description: Check MetaSkills harness consistency across canonical skills, command wrappers, and Claude/opencode/Codex agent role definitions before syncing or releasing harness changes.
---

# Harness Parity Check

Use this skill when the user asks to verify, audit, review, or sanity-check changes to this MetaSkills repository before syncing them into local agent harnesses.

## Goals

- Canonical skills in `skills/<name>/SKILL.md` remain project-agnostic and derive project facts from the consuming project's `AGENTS.md`.
- Command wrappers in `commands/<name>.md` stay thin and point at the same-named skill.
- Agent role definitions remain aligned across `agents/opencode`, `agents/claude`, and `agents/codex` where each harness supports the same behavior.
- The sync scripts install the same managed set described in `README.md`.

## Workflow

1. Inspect changed files:

   ```powershell
   git status --short
   git diff --name-only
   ```

2. For changed skills, read the full `SKILL.md` and confirm:

   - Frontmatter includes `name` and `description`.
   - The skill contains no project-specific facts such as repository slugs, board IDs, URLs, cluster names, image names, credentials, or hardcoded branch defaults.
   - Required project facts are resolved from the target project's `AGENTS.md` sections.
   - The skill says to stop rather than guess when a required `AGENTS.md` section is missing.

3. For changed command wrappers in `commands/`, confirm each wrapper is only a short `$ARGUMENTS` handoff to the same-named skill.

4. For changed agent roles, compare the same role across all dialects:

   - `agents/opencode/<role>.md`
   - `agents/claude/<role>.md`
   - `agents/codex/<role>.toml`

   Confirm the role purpose, hard rules, and returned output expectations match, allowing only syntax/frontmatter differences required by the harness.

5. Check installer coverage when files are added, renamed, or removed:

   - `sync.ps1`
   - `sync.sh`
   - `README.md`

6. Report findings first. If there are no findings, say that explicitly and mention any residual risk, such as not running the sync script.

## Rules

- Do not auto-edit files during a parity check unless the user explicitly asks you to fix findings.
- Do not treat intentional dialect differences as findings when behavior remains equivalent.
- Critical or High findings are anything that would install stale instructions, omit a managed file from sync, introduce project-specific facts into canonical skills, or let a workflow guess missing project facts.
