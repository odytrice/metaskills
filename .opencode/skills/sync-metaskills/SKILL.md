---
name: sync-metaskills
description: Preview or install MetaSkills changes into Claude Code, opencode, and Codex via repo sync scripts.
---

# Sync MetaSkills

Use for requested install, sync, update, preview, or propagation to local harnesses.
Repo-local maintenance only; never edit canonical `skills/`.

## What It Installs

- Claude Code: `~/.claude/skills`, `~/.claude/agents`.
- opencode: `~/.config/opencode/skill`, `~/.config/opencode/agent`, `~/.config/opencode/command`.
- Codex: `~/.codex/skills`, `~/.codex/agents`, `~/.codex/prompts`.

Each target's `.metaskills-manifest` tracks installs; subsequent runs remove previously listed files no longer shipped. Never touch unrelated user files.

## Workflow

1. Inspect `git status --short`.
2. Lint first; failure blocks install:

   ```sh
   ./sync.sh --check        # macOS/Linux
   .\sync.ps1 -Check        # Windows
   ```

3. Preview if requested or installation intent is unclear:

   ```sh
   ./sync.sh --dry-run
   .\sync.ps1 -WhatIf
   ```

4. Install only when requested:

   ```sh
   ./sync.sh
   .\sync.ps1
   ```

5. Report command, completion, and manifest removals.

## Rules

- Sync never replaces review/validation.
- Direct user-config edits require script failure AND explicit manual-repair authorization.
- Report exact permission, missing-directory, or shell-policy blockers and stop.
