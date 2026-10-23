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

Permission envelopes are not identical: OpenCode uses per-tool/path rules,
Claude exposes tool allowlists, and Codex uses sandbox and approval settings.
Matching prose does not prove capability parity; validate effective permissions
in each harness before relying on a role boundary.

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
  paper-doc/   document theme, HTML specimen, C4 viewer, and Python scaffold
commands/      thin slash-command wrappers (shared text)
agents/
  opencode/    mode/permission frontmatter dialect (.md)
  claude/      name/description/tools frontmatter dialect (.md)
  codex/       name/description/developer_instructions dialect (.toml)
AGENTS.template.md   the per-project AGENTS.md contract
sync.ps1       installs everything into ~/.claude, ~/.config/opencode, ~/.codex
sync.sh        same installer for macOS/Linux
tests/         installer and document regressions, plus manual workflow scenarios
docs/          GitHub Pages site: the illustrated workflow guide (not installed)
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

The [workflow guide](https://odytrice.github.io/metaskills/) walks through
this lifecycle with diagrams, starting from the four agents: who hands work
to whom, which agent owns each status move, how the thirteen skills group,
`dev-cycle` and `burndown` step by step, and the shared rules.
Its source is `docs/index.html`, a single paper-doc page with the PlantUML or
draw.io source of each diagram embedded beside the figure. It describes the skills at
the commit named in its masthead.

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
environments; `weekly-review` reports; `project-status` maps every not-done
issue into related groups with a short summary per group.

For document authoring, [`paper-doc`](skills/paper-doc/SKILL.md) turns source
material into standalone HTML documentation, specs, reports, and summaries.
It can explain an issue's design or a project's architecture without requiring
the issue-delivery lifecycle. Its detailed usage is below.

Core mechanics:

- **Foreground orchestration**: all subagent dispatches default to foreground;
  background execution requires an explicit user request, including nested cycles
  and QA. Independent workers may run concurrently through foreground calls;
  otherwise they run sequentially. Dispatch mechanics live in `dev-cycle`.
- **Status-as-lock**: the board Status field is an optimistic claim lock.
  `issue-plan` claims from `Ready`, `issue-implement` moves to `In review`,
  `code-review` handles `Done`; coordinators never transition status. Two
  simultaneous claimants are told apart by the ledger comment (lowest id
  wins, the other deletes its own and yields), and an issue already in
  progress is never silently resumed, so two burndowns on the same scope
  degrade to skipped issues, not duplicate PRs. No skill writes batch
  state into the project; the board and issue comments are the only state.
- **Boardless delivery**: explicit `board: none` skips board operations; missing
  configuration does not. The ledger remains the ownership signal and an
  existing ledger still requires explicit resume. One same-cycle blocked-plan
  repair is allowed with ownership evidence, not as a general takeover path.
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
  performs the after-merge steps (board `Done` for closed issues when automation
  is off, detached review-worktree cleanup). Existing local branches are left
  alone. Review and merge are pinned to the reviewed head SHA; changed heads
  require re-review. `dev-cycle` and `burndown` never merge themselves.
- **Converging re-review**: a re-review only re-checks prior findings plus
  regressions the fix introduced; `dev-cycle` caps this at two fix-and-re-review
  rounds, then parks the PR; `burndown` keeps the batch moving around it.
- **One severity ladder**: Critical/High/Medium/Low everywhere; Critical or
  High blocks commits and merges.
- **Fully resolving delivery**: `issue-implement` and `dev-cycle` require
  `Closes #n` as the final PR-body line and exactly the intended issue URL in
  `closingIssuesReferences`. Partial work stops for repair or an approved split.
  Standalone review can handle partial PRs without marking referenced issues done.
- **Shared mechanics have one owner**: board transitions live in `issue-plan`,
  sub-issue linking in `issue-raise`, review worktrees and merge in
  `code-review`; other skills reference them instead of restating.
- **Harness feedback**: recurring review findings become proposed amendments
  to AGENTS.md or the skills; the harness is designed to compound.

## Paper-and-ink documents

[`paper-doc`](skills/paper-doc/SKILL.md) creates portable HTML documentation,
specs, reports, RFCs, architecture guides, and summaries using the paper-and-ink
aesthetic extracted from the IcePanel prep brief. The bundled design includes
warm textured paper, Newsreader headings, Inter body text, JetBrains Mono labels,
ruled sections, red accents, and responsive layouts.

### Use the skill

After [installing](#install), invoke `paper-doc` in your harness. In Claude Code
and opencode, examples are:

```text
/paper-doc Document this project's architecture with C1, C2, and a focused C3 view.
/paper-doc Turn this proposal into a spec with requirements, tradeoffs, and acceptance criteria.
/paper-doc Summarize these findings as a short paper-and-ink brief, without diagrams.
```

The skill reads the supplied sources and consuming-project guidance, selects a
document structure, authors the content, and verifies the actual HTML output.
Open the [visual specimen](skills/paper-doc/assets/template/index.html) directly
from a local checkout to preview the components and fictional example model.

### Scaffold directly

The scaffold uses Python 3.10+ and its standard library. From this repository:

```text
python skills/paper-doc/scripts/scaffold.py <output-dir> --title "Architecture guide" --kind documentation --c4
python skills/paper-doc/scripts/scaffold.py <output-dir> --title "API proposal" --kind spec
python skills/paper-doc/scripts/scaffold.py <output-dir> --title "Decision brief" --kind summary
```

Use `python3` where that is the interpreter name. The destination must be empty
or not yet exist, and its parent must exist. Optional `--subtitle` and `--date`
set the lede and document date. The scaffold prints the output's `file://` URL.

The output contains `index.html`, `theme.css`, and `document.js`. `--c4` adds
`c4.css`, `model.js`, `c4.js`, and `c4-ui.js`. The scaffold produces a starter:
replace its draft prose, metadata, sources, and fictional model before sharing.
Keep the whole output folder together so relative assets continue to work.

### Components and architecture diagrams

Document behaviors include reading progress, active-section navigation,
document-scoped checklists, notes visibility, image lightboxes, and print support.
Native details/summary elements provide expandable explanations.

The optional C4 explorer uses native JavaScript and SVG. It supports C1/C2/C3
drill-down, inspectors, tag highlighting, supporting systems, relationship
roll-ups, runtime flows, pan/zoom, fullscreen, and Structurizr DSL export.
Views are manually laid out. The DSL exports the model and static views, not
the manual positions or animated flows.

| Reference | Contents |
|---|---|
| [Design system](skills/paper-doc/references/design-system.md) | Theme tokens, typography, component markup, responsive and print behavior |
| [Document recipes](skills/paper-doc/references/document-recipes.md) | Documentation, specification, summary, and ADR outlines |
| [C4 contract](skills/paper-doc/references/c4.md) | Model schema, layout, flow definitions, JavaScript API, export limits, and browser checks |

### Runtime and installation

Generated documents open directly in a modern browser through a `file://` URL.
No npm install, build step, or preview server is needed. Google Fonts are the
only default external requests; offline use falls back to local fonts while
the content and diagrams continue to work. The runtime respects reduced motion,
and essential prose remains available with JavaScript disabled.

Both sync scripts discover `skills/paper-doc/` and `commands/paper-doc.md`
automatically. The complete skill tree is installed into all three harnesses;
the wrapper goes to opencode commands and Codex prompts. Claude Code invokes
the skill directly. Managed manifests handle future updates and renames.

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

Both installers lint sources and preflight every destination before changing
anything. Unsafe manifest names, linked paths, and unmanaged same-name collisions
stop the run, including previews. Unmanifested legacy files are no longer deleted.
For an unmanaged collision, inspect and back up or relocate the conflicting item
before retrying; the installer does not silently adopt or overwrite it. Run only
one installer at a time: preflight is not a filesystem lock or rollback mechanism.

After syncing new or renamed skills, restart the running harness so it reloads
the installed definitions. In particular, quit and restart opencode before
using a newly installed command.

## Validation

Run `python3 tests/test_installers.py` on Linux or in a Linux container. The
standard-library suite uses temporary repositories and isolated home directories,
never live agent configuration. It exercises the Bash installer and skips
entirely outside Linux; it does not provide PowerShell installer coverage.

The `paper-doc` regressions run on Windows and Unix without third-party packages
(Python 3.10+ for scaffolding; Node.js 18+ for the JavaScript tests):

```text
python tests/test_paper_doc_scaffold.py
node --test tests/test_paper_doc_c4.cjs
```

They cover all three document recipes with and without diagrams, HTML escaping,
local assets and navigation, preservation of existing work, model validation,
hierarchical relationships, supporting systems, and DSL generation. Browser
checks for layout and interaction are described in the
[C4 contract](skills/paper-doc/references/c4.md#verification).

`tests/workflow-scenarios.md` contains manual instruction walkthroughs for
ownership, recovery, GitHub identity, merge races, and document authoring.
`skills/paper-doc/evals/evals.json` provides three representative authoring
prompts. These are evaluation fixtures, not automated proof of agent behavior
or live GitHub integration.

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
