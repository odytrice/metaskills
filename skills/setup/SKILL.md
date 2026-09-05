---
name: setup
description: Set up, repair, or reconfigure the project's local, Docker Compose, CI, or deployment-preparation environment from its AGENTS.md. Use when asked to set up, install, bootstrap, or fix the dev environment.
---

# Setup

Project facts from `AGENTS.md`: **§ Build & Validation** (toolchain versions, commands, compose targets; missing: name it and stop, never guess commands or versions), **§ Code Layout & Tech Stack**, **§ Environments** and **§ Repositories** (deployment preparation), **§ Agent Login** (local auth wiring, mock auth).

Modes: local development; Docker Compose (infrastructure in containers, app on the host unless `AGENTS.md` says otherwise); CI; Kubernetes preparation via the deployment repo when § Repositories documents one (deploys themselves are `deploy`). Ask which if unclear.

## Local Development

1. **Toolchain.** Verify presence and version of each tool § Build & Validation names. Missing tools are environment gaps, not code failures.
2. **Infrastructure.** Start backing services with the compose command or target § Build & Validation names. Reset the local database only when explicitly needed (`docker compose down -v`, then restart).
3. **Restore, build, test** each layer with exactly the commands § Build & Validation lists, from the directories it specifies; skip undefined targets.
4. **Run** with the documented run command.

## Rules

- Host-to-container connections use `127.0.0.1`, not `localhost`; container-to-container use compose service names. `AGENTS.md` may override explicitly.
- Never commit secrets (`.env`, credentials, API keys, user overrides); example config stays non-secret. Production secrets come from CI/CD secrets or external secret management, never source-controlled files. Secrets found in config: stop, rotate if real, replace with placeholders before continuing.
- Mock auth: enable only where § Agent Login says, only with the runtime set to development, never in staging or production config. No mock auth documented: configure the real provider per that section.
- Package restore failing on PATH, versions, or sandbox network is an environment issue, not a code failure; say so.

## Verification And Output

Run the minimum § Build & Validation checks (each layer's test/check commands; the full build for a complete setup). Report: mode; tool versions checked; services started; config files changed; validation commands and results; remaining manual steps.
