# metaskills

A single, canonical agent harness (skills, commands, and agent roles) shared
across three coding-agent harnesses with as much parity as each allows:

| | Claude Code (`~/.claude`) | opencode (`~/.config/opencode`) | Codex (`~/.codex`) |
|---|---|---|---|
| **Skills** | `skills/<name>/` | `skill/<name>/` | `skills/<name>/` |
| **Commands** | not used (skills double as `/<name>` slash commands) | `command/*.md` | `prompts/*.md` |
| **Agents** | `agents/*.md` (Claude dialect) | `agent/*.md` (opencode dialect) | `agents/*.toml` (Codex dialect) |

Skills are written once and installed verbatim into all three harnesses.
Commands are thin `$ARGUMENTS` wrappers around same-named skills. Agent role
definitions exist in three dialects with identical bodies; only the
frontmatter/permission syntax differs.

## Design

**Skills are project-agnostic.** Every project fact (board numbers, URLs,
branch maps, image names, build commands, login flows, stack idioms) is
resolved at runtime from the project's `AGENTS.md`, which must satisfy the
contract in [`AGENTS.template.md`](AGENTS.template.md). If a required section
is missing, skills say so and stop rather than guess. Shell samples in skills
are plain `gh`/`git` invocations that run unchanged in bash, zsh, and
PowerShell.

**Agents are thin.** Each role is identity, which skill to load, the
permission envelope, and what to return; nothing from the skill is restated.
The three dialect bodies are byte-identical; `sync.sh --check` verifies it.

**Token budget.** Skill descriptions are loaded into every session, so they
say only what the skill does and when to trigger it. Rules live in exactly
one skill and are referenced from others. Login rules that apply to every
project live in the `qa` skill, not in each project's AGENTS.md.

**Claude Code projects** additionally need a `CLAUDE.md` whose first line is
`@AGENTS.md` so the same contract is loaded there.

**Precedence:** all three harnesses resolve project-level config over
user-level, so a project can still override any skill locally by shipping its
own copy (e.g. a project-specific `agent-login` that the project's
`AGENTS.md § Agent Login` points to).

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
.opencode/skills/    repo-local maintenance skills (not installed)
```

## The workflow the skills compose into

```
issue-raise -> issue-refine -> [ dev-cycle ............................... ]
   (create,     (the What:      issue-plan  -> issue-implement -> code-review
    Backlog)     -> Ready)      architect      developer          architect
                                the How,       worktree,          review,
                                                                 claim, ledger  ledger, PR         merge, Done
```

Progress is tracked on the project board as
`Backlog -> Ready -> In progress -> In review -> Done`.

Deployment is out of scope: it means something different in every project,
so it lives in the consuming repo (its own skill, or `AGENTS.md`), not here.

`dev-cycle` is the unit of delivery for one issue: it dispatches each phase to
the role that owns it (architect plans, developer implements, a separate
architect reviews and merges) and runs a bounded revision loop; it writes no
code itself. `burndown` is `dev-cycle` in batches: triage, dependency-ordered
waves, one cycle per issue with wave concurrency, then a closing `qa` sweep
that files regressions back to `Backlog`. Around that spine: `backlog-refine`
grooms `Backlog` into `Ready` in dependency-ordered waves after one up-front
question gate; `qa` is also invocable on its own; `setup` provisions
environments; `weekly-review` reports.

Core mechanics:

- **Status-as-lock**: the board Status field is an optimistic claim lock.
  `issue-plan` claims from `Ready`, `issue-implement` moves to `In review`,
  `code-review` handles `Done`; coordinators never transition status. Two
  simultaneous claimants are told apart by the ledger comment (lowest id
  wins, the other deletes its own and yields), and an issue already in
  progress is never silently resumed, so two burndowns on the same scope
  degrade to skipped issues, not duplicate PRs. No skill writes batch
  state into the project; the board and issue comments are the only state.
- **Body is the What, ledger is the How**: `issue-refine` settles scope and
  acceptance criteria in the issue body (feasibility reading only, no design);
  `issue-plan`, always run by an architect, designs the approach, touch points,
  validation, risks, and tasks into one living `<!-- plan-ledger -->` comment
  per issue (UTF-8, no BOM), asking for approval only when a real trade-off
  needs the user. `issue-implement` executes that ledger and never creates one.
- **Worktree isolation**: implementation and review each run in their own
  `.worktrees/` checkout, with path-safety checks before removal.
- **Implementer =/= reviewer, reviewer = merger**: reviews always run in a
  fresh context; `code-review` squash-merges when its criteria hold and
  performs the after-merge steps (board `Done` when automation is off, local
  branch cleanup). `dev-cycle` and `burndown` record the result and never
  merge themselves.
- **Converging re-review**: a re-review only re-checks prior findings plus
  regressions the fix introduced; `dev-cycle` caps this at two fix-and-re-review
  rounds, then parks the PR; `burndown` keeps the batch moving around it.
- **One severity ladder**: Critical/High/Medium/Low everywhere; Critical or
  High blocks commits and merges.
- **Exactly one ticket reference**: `Closes #n`/`Refs #n` as the final line of
  a PR body, verified via `closingIssuesReferences`.
- **Shared mechanics have one owner**: board transitions live in `issue-plan`,
  sub-issue linking in `issue-raise`, review worktrees and merge in
  `code-review`; other skills reference them instead of restating.
- **Harness feedback**: recurring review findings become proposed amendments
  to AGENTS.md or the skills; the harness is designed to compound.

## Install

```powershell
.\sync.ps1          # install/update all three harnesses (Windows)
.\sync.ps1 -WhatIf  # preview
.\sync.ps1 -Check   # lint the repo (frontmatter, skill/wrapper pairing both ways, dialect parity)
```

```bash
./sync.sh           # install/update all three harnesses (macOS/Linux)
./sync.sh --dry-run # preview
./sync.sh --check   # lint the repo (frontmatter, skill/wrapper pairing both ways, dialect parity)
```

The script only touches items this repo manages. It writes a
`.metaskills-manifest` into each target directory and, on the next run,
removes anything listed there that the repo no longer ships, so renames and
deletions clean up after themselves.

## Adopting a project

1. Write (or restructure) the project's `AGENTS.md` to satisfy every section
   of `AGENTS.template.md`, including the harness conventions block. Put
   stack-specific review checks in a detail file `§ Review Notes` points to.
2. Add `.worktrees/` and `.tmp-*` to the project's `.gitignore`.
3. For Claude Code, add a `CLAUDE.md` containing `@AGENTS.md`.
4. Delete the project's local copies of these skills/commands/agents so the
   user-level versions apply (keep a project-level skill only where behavior
   genuinely diverges, e.g. a project-specific `agent-login`).
5. Models are deliberately not pinned in agent frontmatter; control model
   choice per harness instead.
