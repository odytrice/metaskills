# Code Review Checklist

Apply relevant sections only. Stack idioms in `AGENTS.md` § Code Layout & Tech Stack and § Review Notes/detail file override conflicts.

## Scope and trajectory

- Matches linked issue/ledger; no silent file/endpoint/behavior expansion.
- Covers edge cases, error paths, integration points, not just happy paths.
- Flags guessed business-logic assumptions.

## Security and access control

- Protected routes/actions authenticate and authorize requesting user/tenant; no cross-tenant reads/writes.
- Dev-only shortcuts (mock auth, seeded credentials, debug endpoints) cannot activate outside local development.
- No source/client/log secrets; local secret files gitignored.
- Validate input before storage/rendering; parameterize queries; no raw user HTML or disabled CSRF/CORS.
- No `localhost`/developer-machine assumptions in host-side/production config.

## Data integrity and migrations

- Backward-compatible migrations follow project convention; destructive changes have explicit path and PR disclosure.
- Transactional multi-step writes where partial failure corrupts state.
- IDs/timestamps/enums follow project scheme; reuse defined domain types.
- Touched DB tripwire (§ Build & Validation): live-database suite passed.

## Architecture and boundaries

- Business logic in designated layer, not handlers/UI/jobs/data access; inward dependencies.
- Thin handlers: validate, authorize, delegate, map. No boundary-type business logic.
- Update both cross-language contract mirrors.
- Register new files for required build order/modules.

## Error handling

- Propagate errors via project mechanism; never silently swallow.
- Distinguish validation/system errors; map intended status/message.
- No user-facing internal leaks (stack traces, SQL, paths).

## Background processing

- Thin workers/jobs/consumers reuse synchronous core logic.
- Deliberate retries/dead-lettering/logging; no silent loop crashes.
- No blocking calls in async/event-loop contexts.

## Frontend

- Project component/routing/state patterns; no parallel state model.
- Guard browser-only APIs during server rendering.
- Explicit nullable API handling; loading/error states on every primary path.
- Designated client layer for API calls.
- Keyboard-reachable, labelled interactions; image alt text; controls implement advertised behavior, no inert buttons/placeholders.
- Validate upload type/size before sending.

## Testing

- Test new/changed behavior in § Code Layout & Tech Stack locations; exercise risky paths, not trivial assertions.
- Isolated unit dependencies; real integration infrastructure.
- Behavioral test names match surrounding suite style.

## Configuration and operations

- Environment-appropriate config; no incidental production-only changes.
- Inspect touched CI/Dockerfiles/manifests: image tags, secrets handling, resource limits.
- Appropriate structured log levels; preserve metrics/tracing.

## Style (only where it hides risk)

- Follow formatter config, never invent manual rules.
- No intent-obscuring dead code, unused imports, commented-out blocks.
- Misleading naming: at most Low.
