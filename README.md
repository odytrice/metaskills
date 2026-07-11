# metaskills

A single, canonical agent harness — skills, commands, and agent roles — shared
across three coding-agent harnesses with as much parity as each allows:

| | Claude Code (`~/.claude`) | opencode (`~/.config/opencode`) | Codex (`~/.codex`) |
|---|---|---|---|
| **Skills** | `skills/<name>/` | `skill/<name>/` | `skills/<name>/` |
| **Commands** | — (skills double as `/<name>` slash commands) | `command/*.md` | `prompts/*.md` |
| **Agents** | `agents/*.md` (Claude dialect) | `agent/*.md` (opencode dialect) | `agents/*.toml` (Codex dialect) |

Skills are written once and installed verbatim into all three harnesses.
Commands are thin `$ARGUMENTS` wrappers around same-named skills. Agent role
definitions exist in three dialects with near-identical bodies.

## Design

**Skills are project-agnostic.** Every project fact — board numbers, URLs,
branch maps, image names, build commands, login flows — is resolved at runtime
from the project's `AGENTS.md`, which must satisfy the contract in
[`AGENTS.template.md`](AGENTS.template.md). If a required section is missing,
skills say so and stop rather than guess.

**Claude Code projects** additionally need a `CLAUDE.md` whose first line is
`@AGENTS.md` so the same contract is loaded there.

**Precedence:** all three harnesses resolve project-level config over
user-level, so a project can still override any skill locally by shipping its
own copy (e.g. a project-specific `agent-login`).

## Layout

```
skills/        one directory per skill (SKILL.md + supporting files)
commands/      thin slash-command wrappers (shared text)
agents/
  opencode/    mode/permission frontmatter dialect (.md)
  claude/      name/description/tools frontmatter dialect (.md)
  codex/       name/description/developer_instructions dialect (.toml)
AGENTS.template.md   the per-project AGENTS.md contract
sync.ps1       installs everything into ~/.claude, ~/.config/opencode, ~/.codex
sync.sh        same installer for macOS/Linux
```

## The workflow the skills compose into

```
issue-raise -> issue-refine -> issue-plan -> dev-cycle -> code-review -> deploy
   (create)     (-> Ready)    (claim,   (worktree,     (PR or        (gate,
                               ledger)   PR)            local mode)    ship, watch CI)
```

tracked on the project board as `Backlog -> Ready -> In progress -> In review -> Done`,
with `burndown` as the batch orchestrator (one developer worker per issue, a
separate architect reviewer per PR), `quality-assurance` driving the Playwright CLI against staging,
`setup` provisioning environments, and `weekly-review` reporting.

Core mechanics preserved from the best project variants:

- **Status-as-lock**: the board Status field is an optimistic claim lock.
- **Plan ledger**: one living `<!-- plan-ledger -->` comment per issue is the
  shared execution checklist (UTF-8, no BOM).
- **Worktree isolation**: implementation and review each run in their own
  `.worktrees/` checkout, with path-safety checks before removal.
- **Implementer =/= reviewer**: reviews always run in a fresh context; on
  harnesses without subagents the coordinator must still use a clean context
  for review.
- **One severity ladder**: Critical/High/Medium/Low everywhere; Critical or
  High blocks commits and merges.
- **Exactly one ticket reference**: `Closes #n`/`Refs #n` as the final line of
  a PR body.
- **Harness feedback**: recurring review findings become proposed amendments
  to AGENTS.md or the skills — the harness is designed to compound.

## Install

```powershell
.\sync.ps1          # install/update all three harnesses (Windows)
.\sync.ps1 -WhatIf  # preview
```

```bash
./sync.sh           # install/update all three harnesses (macOS/Linux)
./sync.sh --dry-run # preview
```

The script only touches items this repo manages; other skills, agents, and
commands in the target directories are left alone.

## Adopting a project

1. Write (or restructure) the project's `AGENTS.md` to satisfy every section
   of `AGENTS.template.md`.
2. For Claude Code, add a `CLAUDE.md` containing `@AGENTS.md`.
3. Delete the project's local copies of these skills/commands/agents so the
   user-level versions apply (keep a project-level skill only where behavior
   genuinely diverges, e.g. a rich `agent-login`).
4. Models are deliberately not pinned in agent frontmatter — control model
   choice per harness instead.
