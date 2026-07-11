---
name: sync-metaskills
description: Install or preview the MetaSkills harness into Claude Code, opencode, and Codex user-level config directories using the repo sync scripts. Use after changing skills, commands, or agent role definitions.
---

# Sync MetaSkills

Use this skill when the user asks to install, sync, update, preview, or propagate this repository's harness files into the local coding-agent configuration directories.

This is an OpenCode project-local maintenance skill. Do not edit the canonical shared `skills/` tree as part of syncing.

## What It Installs

The sync scripts install files managed by this repository into:

- Claude Code: `~/.claude/skills` and `~/.claude/agents`.
- opencode: `~/.config/opencode/skill`, `~/.config/opencode/agent`, and `~/.config/opencode/command`.
- Codex: `~/.codex/skills`, `~/.codex/agents`, and `~/.codex/prompts`.

The scripts only replace managed names from this repo; unrelated user-level skills, agents, commands, and prompts are left alone.

## Workflow

1. Check the worktree state first:

   ```powershell
   git status --short
   ```

2. If the user asked for a preview or you are unsure whether installation is desired, run the dry-run command:

   ```powershell
   .\sync.ps1 -WhatIf
   ```

3. If the user asked to actually install/update, run:

   ```powershell
   .\sync.ps1
   ```

4. Report which command ran and whether it completed successfully.

## Rules

- On Windows, prefer `sync.ps1`; on macOS/Linux, use `sync.sh` or `sync.sh --dry-run`.
- Do not run sync as a substitute for reviewing or validating harness changes.
- Do not modify user-level config files directly unless the sync script fails and the user explicitly asks for a manual repair.
- If a sync failure points to permissions, missing directories, or shell policy, report the exact blocker and stop.
