---
name: sync-metaskills
description: Install or preview the MetaSkills harness into Claude Code, opencode, and Codex user-level config directories using the repo sync scripts. Use after changing skills, commands, or agent role definitions.
---

# Sync MetaSkills

Use when the user asks to install, sync, update, preview, or propagate this repository's harness files into the local coding-agent configuration directories. This is a repo-local maintenance skill; it does not edit the canonical `skills/` tree.

## What It Installs

- Claude Code: `~/.claude/skills`, `~/.claude/agents`.
- opencode: `~/.config/opencode/skill`, `~/.config/opencode/agent`, `~/.config/opencode/command`.
- Codex: `~/.codex/skills`, `~/.codex/agents`, `~/.codex/prompts`.

Each target directory gets a `.metaskills-manifest`; the next run removes anything the previous manifest listed that the repo no longer ships. Unrelated user-level files are never touched.

## Workflow

1. `git status --short` to know what is about to be installed.
2. Lint first; do not install a tree that fails:

   ```sh
   ./sync.sh --check        # macOS/Linux
   .\sync.ps1 -Check        # Windows
   ```

3. Preview when asked, or when unsure installation is wanted:

   ```sh
   ./sync.sh --dry-run
   .\sync.ps1 -WhatIf
   ```

4. Install when asked:

   ```sh
   ./sync.sh
   .\sync.ps1
   ```

5. Report which command ran, whether it completed, and anything the manifest removed.

## Rules

- Sync is not a substitute for reviewing or validating harness changes.
- Do not modify user-level config files directly unless the sync script fails and the user explicitly asks for a manual repair.
- On permission, missing-directory, or shell-policy failures, report the exact blocker and stop.
