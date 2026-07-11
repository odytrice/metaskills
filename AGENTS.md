# AGENTS.md - MetaSkills

## Project Overview

MetaSkills is the canonical shared agent harness for the user's coding-agent workflows. It owns reusable skills, command wrappers, and role definitions that are installed into Claude Code, opencode, and Codex user-level configuration directories.

The repository is intentionally project-agnostic: canonical skills must not bake in facts about a consuming application. They must resolve project-specific information from that project's own `AGENTS.md`, using the contract in `AGENTS.template.md`.

## Code Layout & Tech Stack

- `skills/<name>/SKILL.md` contains canonical skill instructions shared across Claude Code, opencode, and Codex.
- `commands/<name>.md` contains thin command wrappers for opencode commands and Codex prompts. Claude Code invokes skills directly as slash commands, so it does not get command wrapper copies.
- `agents/opencode/*.md` contains opencode subagent definitions.
- `agents/claude/*.md` contains Claude Code subagent definitions.
- `agents/codex/*.toml` contains Codex agent role definitions.
- `AGENTS.template.md` is the required contract for repositories that consume these shared skills.
- `sync.ps1` and `sync.sh` install the managed harness files into user-level configuration directories.
- `.opencode/skills/` contains OpenCode-only project-maintenance skills for this repository. Do not mirror these into the canonical shared `skills/` tree unless the behavior should be installed globally.

The repo is mostly Markdown, TOML, PowerShell, and Bash. Keep changes small, explicit, and portable across Windows and Unix where the sync scripts overlap.

When changing a workflow, update all affected dialects together:

- Skill behavior: update the canonical `skills/<name>/SKILL.md`.
- Command invocation: update `commands/<name>.md` only if the command handoff changes.
- Agent role behavior: keep `agents/opencode`, `agents/claude`, and `agents/codex` semantically aligned.
- Install behavior: update both `sync.ps1` and `sync.sh`.
- User-facing documentation: update `README.md` when layout, install behavior, or workflow changes.

## Build & Validation

There is no compiled application or automated test suite in this repo. Validate harness changes with targeted inspection and script dry-runs:

```powershell
git status --short
git diff --check
.\sync.ps1 -WhatIf
```

For Unix-shell changes, also review `sync.sh` and, when a Bash environment is available, run:

```bash
./sync.sh --dry-run
```

For skill or agent changes, read the changed files and verify:

- `SKILL.md` frontmatter has `name` and `description`.
- Skills do not contain project-specific repo slugs, board IDs, branch defaults, environment URLs, cluster names, image names, credentials, or local-machine-only paths.
- Skills require missing project facts to come from the consuming repo's `AGENTS.md` and stop rather than guess.
- Command wrappers remain thin `$ARGUMENTS` handoffs to same-named skills.
- Agent role definitions stay semantically aligned across Claude Code, opencode, and Codex dialects.

DB tripwire files: none. This repository has no database layer or integration database suite.

## Project Board

No GitHub Project board is currently documented for this repository. Skills that require board owner, project number, or Status option names must stop and ask for those details rather than guessing.

If a board is added later, record the owner/org, project number, and Status lifecycle here. Do not record field or option IDs; look those up live with `gh project field-list`.

## Repositories

- App repo slug: `odytrice/metaskills`.
- Deployment repo: none.
- Local deployment sibling path: none.
- Issue template path: none documented. If no template exists, issue workflows should use their fallback headings.

## Environments

This repository does not deploy an application and has no dev/staging/prod runtime environments, Kubernetes contexts, namespaces, or Docker images.

## Branch Map

- `master` is the primary integration branch for harness changes.
- No deployment pipeline is documented.
- Pull requests should target `master` unless the user explicitly names another base branch.

## Agent Login

Not applicable. This repository has no running web application, browser login flow, test credentials, or storage-state file.

## Review Notes

Review harness changes for instruction drift and cross-harness parity before style concerns.

Key review checks:

- Canonical skills must stay project-agnostic and resolve project facts from the consuming repo's `AGENTS.md`.
- Do not add hardcoded GitHub Project IDs, repository-specific branch assumptions, environment URLs, credentials, or deployment facts to canonical skills.
- Keep Claude Code, opencode, and Codex agent role behavior aligned even when their file formats differ.
- Keep opencode and Codex command wrappers thin; they should not duplicate skill workflows.
- Keep `sync.ps1` and `sync.sh` behavior equivalent when adding, renaming, or removing managed files.
- Do not alter user-level config directories directly from this repo except through the sync scripts or an explicit user request.

## CI Pipeline

No CI pipeline is currently documented for this repository. If a workflow is added, document its file, expected jobs, and expected durations here.
