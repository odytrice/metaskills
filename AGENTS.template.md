# AGENTS.md Harness Contract

Every project that uses the shared (user-level) harness skills MUST provide an
`AGENTS.md` at the repository root containing the sections below, with these
exact headings. The shared skills contain no project facts — they resolve
everything through these sections at runtime. If a section is missing, the
skill should say so and stop rather than guess.

Claude Code note: the project must also have a `CLAUDE.md` whose first line is
`@AGENTS.md` so the contract is loaded there too.

**Static vs. detail files.** AGENTS.md is static context — every token is
loaded into every session, whatever the task. Keep it lean. Sections that
nearly every task needs (Project Overview, Code Layout & Tech Stack, Build &
Validation, Project Board, Repositories, Environments, Branch Map) stay
inline. Sections consumed by a single workflow (CI Pipeline, Review Notes,
the detail of Agent Login) should be a few summary lines plus a pointer to a
detail file under `Docs/agents/` (e.g. `Docs/agents/ci-pipeline.md`), which
the relevant skill loads on demand. A skill reading a section that names a
detail file MUST read that file before acting on the section.

---

## Project Overview

One or two paragraphs: what the product is, who uses it, current phase.

## Code Layout & Tech Stack

Where the backend/frontend/tests live, the language/framework versions, and
the architectural conventions reviewers must enforce (error-handling style,
ID scheme, layer boundaries, etc.).

## Build & Validation

The exact commands agents run to build, test, lint, and format each part of
the codebase, plus:

- **DB tripwire files**: the list of files that, when touched, require the
  live-database integration suite to run before a PR is opened or merged.

## Project Board

- Owner/org and project number (e.g. `orgs/<org>/projects/<n>`)
- The Status field's option names in lifecycle order
  (e.g. `Backlog → Ready → In progress → In review → Done`)
- Skills must look up field/option IDs live via `gh project field-list`;
  never record IDs here.

## Repositories

- App repo slug (e.g. `org/app`)
- Deployment repo slug and its local sibling path, if one exists
- Issue template path (e.g. `.github/ISSUE_TEMPLATE/issue.md`)

## Environments

For each environment (dev/staging/prod): URL, cluster/context name,
namespace, and the Docker image names published for it.

## Branch Map

Which branch integrates to which environment, and which CI workflow file
each branch/PR triggers (e.g. `main → staging via develop.yaml`,
`prod → production via prod.yaml`, `PR → validate.yaml`). This is the single
source of truth for base branches in dev-cycle/code-review.

## Agent Login

How a browser/QA agent authenticates against a running instance: URLs, auth
mechanism, test credentials or seeding procedure, storage-state locations,
MFA/OTP handling in non-prod, and what must never be captured in issues or
logs. Projects with complex flows may keep a project-level `agent-login`
skill instead and point to it from here.

## Review Notes

Project-specific review guidance layered on top of the shared checklist:
known existing bugs reviewers should flag interactions with, extra checks,
and areas of the codebase under active migration (with what supersedes what).

## CI Pipeline (optional)

Job names, expected durations, and polling guidance for the deploy monitor.
If absent, the deploy skill falls back to `gh run watch` with a generic
polling cadence.
