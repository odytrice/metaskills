---
name: setup
description: Configure project environments from AGENTS.md. Use to set up, install, bootstrap, or repair local, Docker Compose, or CI environments.
---

# Setup

From `AGENTS.md`: **§ Build & Validation** (versions, commands, compose targets; missing: name it and stop, never guess), **§ Code Layout & Tech Stack**, **§ Agent Login** (local/mock auth).

Modes: local; Docker Compose (container infrastructure, host app unless documented otherwise); CI. Ask if unclear.

## Local Development

1. **Toolchain.** Verify every documented tool/version. Missing tools are environment gaps, not code failures.
2. **Infrastructure.** Start backing services with documented compose commands/targets. Reset local DB only when explicitly needed (`docker compose down -v`, then restart).
3. **Restore, build, test** each layer using exact § Build & Validation commands/directories; skip undefined targets.
4. **Run** with the documented run command.

## Rules

- Host-to-container: `127.0.0.1`, not `localhost`; container-to-container: compose service names. Only explicit `AGENTS.md` overrides.
- Never commit secrets (`.env`, credentials, API keys, user overrides); examples stay non-secret. Production uses CI/CD or external secret management, never source control. Config secrets: stop, rotate real ones, replace with placeholders before continuing.
- Mock auth only as § Agent Login documents, runtime development, never staging/production config. Otherwise configure its real provider.
- Report PATH/version/sandbox-network restore failures as environment issues, not code failures.

## Verification And Output

Run § Build & Validation minimum checks per layer; full build for complete setup. Report mode, verified tool versions, started services, changed configs, validation commands/results, remaining manual steps.
