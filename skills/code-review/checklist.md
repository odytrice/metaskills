# Code Review Checklist

Stack-neutral; apply only the sections relevant to the changed areas. `AGENTS.md` § Code Layout & Tech Stack and § Review Notes (and its detail file) carry the stack's idioms and override this list on conflict.

## Scope and trajectory

- Diff matches the linked issue and plan ledger; no silent expansion of files, endpoints, or behavior.
- Reaches the risky last 20% (edge cases, error paths, integration points), not only the happy path.
- Any business-logic assumption guessed instead of asked is called out.

## Security and access control

- Protected routes/actions authenticate; authorization is scoped to the requesting user/tenant; no cross-tenant reads or writes.
- Dev-only shortcuts (mock auth, seeded credentials, debug endpoints) cannot activate outside local development.
- No secrets in source, client code, or logs; local secret files stay gitignored.
- Input validated before storage or rendering; queries parameterized; user HTML never rendered raw; CSRF/CORS not disabled.
- No `localhost`/developer-machine assumptions in host-side or production config.

## Data integrity and migrations

- Migrations follow the project convention and are backward-compatible; destructive changes have an explicit path and are called out in the PR.
- Multi-step writes are transactional where partial failure corrupts state.
- IDs, timestamps, enums follow the project scheme; no ad-hoc types for concepts the domain already defines.
- A touched DB tripwire file (§ Build & Validation) means the live-database suite ran and passed.

## Architecture and boundaries

- Business logic in the designated layer, not in handlers, UI, jobs, or data access; layers depend inward.
- Handlers thin: validate, authorize, delegate, map. Boundary types carry no business logic.
- Cross-language contract mirrors updated on both sides.
- New files registered where the project requires explicit build order or module registration.

## Error handling

- Errors propagate via the project mechanism; none swallowed silently.
- Validation errors distinguishable from system errors and mapped to the intended status/message.
- User-facing errors leak no internals (stack traces, SQL, paths).

## Background processing

- Workers/jobs/consumers are thin orchestrators over the same core logic as the synchronous path.
- Failures retried, dead-lettered, or logged deliberately; nothing crashes the loop silently.
- No blocking calls in async/event-loop contexts.

## Frontend

- Follows the project's component, routing, and state patterns; no parallel state model.
- Browser-only APIs guarded where server rendering applies.
- Nullable API data handled explicitly; loading and error states on every primary path.
- API calls through the designated client layer.
- Interactive elements keyboard-reachable and labelled; images have alt text; controls match implemented behavior (no inert buttons or placeholders).
- Uploads validated (type, size) before sending.

## Testing

- New or changed behavior has tests where § Code Layout & Tech Stack names, exercising the risky path rather than asserting trivially.
- Unit tests isolate dependencies; integration tests use real infrastructure.
- Test names describe behavior in the surrounding suite's style.

## Configuration and operations

- Config changes environment-appropriate; production-only settings not altered incidentally.
- Touched CI workflows, Dockerfiles, and manifests inspected: image tags, secrets handling, resource limits.
- Structured logging at appropriate levels; metrics/tracing not broken.

## Style (only where it hides risk)

- Formatting per the project's formatter config; do not hand-enforce rules it does not set.
- No dead code, unused imports, or commented-out blocks that obscure intent.
- Misleading naming is at most a Low finding.
