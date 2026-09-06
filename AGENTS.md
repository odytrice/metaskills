# AGENTS.md - MetaSkills

## Project Overview

MetaSkills owns the user's canonical shared skills, command wrappers, and agent roles, installed into Claude Code, opencode, and Codex user-level configs.

Canonical skills are project-agnostic: resolve facts from the consuming project's `AGENTS.md` under `AGENTS.template.md`; stop rather than guess missing facts. Never embed repo slugs, board IDs, branch defaults, environment URLs, cluster/image names, credentials, deployment facts, or local-machine-only paths.

## Code Layout & Tech Stack

- `skills/<name>/SKILL.md`: canonical skills shared across all three harnesses.
- `commands/<name>.md`: thin same-named skill + `$ARGUMENTS` handoffs for opencode commands and Codex prompts, never duplicated workflows. Claude Code uses skills directly as slash commands; no wrapper copies.
- `agents/opencode/*.md`, `agents/claude/*.md`, `agents/codex/*.toml`: subagent/role definitions with identical bodies across dialects; configuration syntax differs.
- `AGENTS.template.md`: required consuming-project contract.
- `sync.ps1`, `sync.sh`: managed harness installers.
- `.opencode/skills/`: OpenCode-only repository maintenance. Mirror into `skills/` only if behavior should install globally.

Mostly Markdown, TOML, PowerShell, and Bash. Keep changes small, explicit, and portable across Windows/Unix.

Update affected surfaces together:

- Skills: canonical `skills/<name>/SKILL.md`; commands only when handoffs change.
- Roles: all three dialects.
- Installation: both sync scripts, including added/renamed/removed managed files.
- Layout, installation, or workflows: `README.md`.

## Build & Validation

No compiled application. Run sync lint first, then inspect and dry-run:

```powershell
git status --short
git diff --check
.\sync.ps1 -Check
.\sync.ps1 -WhatIf
```

For Unix-shell changes, also review `sync.sh` and run when Bash is available:

```bash
./sync.sh --check
./sync.sh --dry-run
```

`--check` / `-Check` verifies skill frontmatter (`name`, `description`), bidirectional skill/command pairing, three-dialect agent body parity, PowerShell-only shell samples, and em/en dashes. Both scripts must report identical findings.

Run `python3 tests/test_installers.py` (or `python` on Windows) for isolated installer regression tests. Unavailable Bash/PowerShell runtimes are skipped, not validated. Installer tests must cover hard-linked metadata as well as symlinks, and byte-sensitive fixtures must avoid platform newline translation. `tests/workflow-scenarios.md` contains manual instruction evaluations, not executable behavioral tests.

Read changed skills/agents to verify the project-fact contract and layout invariants above; lint alone does not validate behavior.

DB tripwire files: none. This repository has no database layer or integration database suite.

## Project Board

No board documented. Skills needing board owner, project number, or Status option names must stop and ask.

If added, record owner/org, project number, and Status lifecycle here. Look up field/option IDs live with `gh project field-list`; never record them.

## Repositories

- App repo slug: `odytrice/metaskills`.
- Deployment repo: none.
- Issue template path: none documented. If no template exists, issue workflows should use their fallback headings.

## Environments

None. This repository has no running environments.

## Branch Map

- `master`: primary integration branch and PR base unless the user explicitly names another base.

## Agent Login

Not applicable. This repository has no running web application, browser login flow, test credentials, or storage-state file.

## Review Notes

Prioritize instruction drift and cross-harness parity over style. Enforce the project-fact, wrapper, role, and installer invariants above. Never alter user-level configs except through sync scripts or an explicit user request.
