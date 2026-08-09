---
name: setup
description: Set up, repair, or reconfigure a development, Docker Compose, CI, or deployment-preparation environment for the current project, driving toolchain versions, commands, services, and configuration from the project's AGENTS.md.
---

# Setup

Use this skill when asked to set up, repair, or reconfigure the project's environment. All project facts come from `AGENTS.md` at the repository root; this skill contains none.

## Resolve Project Facts First

Read `AGENTS.md` and resolve:

| Fact | AGENTS.md section |
|------|-------------------|
| Toolchain and versions, build/test/lint/format commands | § Build & Validation |
| Code layout (backend/frontend paths, stacks) | § Code Layout & Tech Stack |
| Environments and deployment repo (for Kubernetes preparation) | § Environments, § Repositories |
| Local auth wiring (mock auth, test credentials) | § Agent Login |

If § Build & Validation is missing, say so and stop; do not guess commands or versions.

## Supported Modes

- Local development.
- Docker Compose development (infrastructure services in containers, app on host, unless AGENTS.md says otherwise).
- CI environment.
- Kubernetes dev/staging/prod preparation via the deployment repo, when § Repositories documents one (actual deploys belong to the `deploy` skill).

Ask which mode if it is not clear.

## Local Development Setup

### 1. Check the toolchain

Verify each tool is present at the versions AGENTS.md specifies; do not assume versions:

```powershell
dotnet --info
node --version
npm --version
docker --version
gh --version
kubectl version --client
```

Adjust the list to the stacks the project actually uses. Do not treat missing local tools as code failures; report them as environment gaps.

### 2. Start infrastructure

Start the project's backing services (database, cache, object storage, etc.) with Docker Compose:

```powershell
docker compose up -d infrastructure
```

Use the compose target AGENTS.md names; if there is no `infrastructure` service group, `docker compose up -d` the individual services. Do not bring up the full app in containers unless AGENTS.md says the project runs that way; the server and frontend typically run on the host.

### 3. Restore, build, and test the backend

Run the backend commands from § Build & Validation from the directories it specifies, for example:

```powershell
dotnet restore
dotnet build
dotnet test
```

### 4. Install and check the frontend

Run the frontend commands from § Build & Validation, for example:

```powershell
npm install
npm run check
npm run lint
```

Skip targets the project does not define (some projects have no lint target; use whatever § Build & Validation lists).

### 5. Run the app

Use the run command § Build & Validation documents (a build-script target, or running server and frontend dev server individually).

## Configuration Rules

- **Host-side config must use `127.0.0.1`, not `localhost`** for connections from the host to containerized services, unless AGENTS.md explicitly says otherwise.
- Docker Compose service-to-service config uses compose service names (e.g. `postgres`, `redis`, `minio`), never `127.0.0.1`.
- Do not commit real secrets: no `.env` files, credentials, API keys, or user-specific config overrides. Keep example/config-template files safe and non-secret.
- Production secrets come from CI/CD secrets, Kubernetes secret generators in the deployment repo, or external secret management; never from source-controlled files.

## Mock Authentication

If AGENTS.md (§ Agent Login) documents a mock-auth mode for local development:

- Enable it only where AGENTS.md says (typically a frontend env flag plus a backend user-config flag).
- Keep the backend environment set to Development.
- Never enable mock auth in staging or production config.

If AGENTS.md documents no mock auth, configure the real auth provider per its instructions instead.

## Common Checks

### Backend cannot connect to the database

- Verify the compose service is running.
- Verify the connection string key matches what the app expects (per AGENTS.md).
- Host-side: `Host=127.0.0.1`. Compose-internal: the compose service name.
- Reset the local database only when explicitly needed: `docker compose down -v` then restart infrastructure.

### Frontend cannot reach the API

- Check the API base URL env var or dev-proxy configuration AGENTS.md documents.
- Use `127.0.0.1` for host-side dev URLs.
- Confirm backend CORS includes the frontend origin.

### Auth fails locally

- Decide whether this environment should use the real provider or mock auth, then verify the corresponding settings on both frontend and backend.

### Package restore unavailable

- Confirm PATH and installed versions.
- In sandboxed environments, package restore may need network permission.
- Do not treat missing tools or blocked networks as code failures.

### Secrets found in config

- Stop setup.
- Rotate the secrets if they were real.
- Replace with safe placeholders or external secret references before continuing.

## Verification

Run the minimum validation from § Build & Validation, typically the backend test command and the frontend check/lint commands, and the full build target for a complete setup.

## Output

When setup is complete, report:

- Mode configured.
- Tool versions checked (against what AGENTS.md specifies).
- Services started.
- Config files changed.
- Validation commands run and results.
- Remaining manual steps.
