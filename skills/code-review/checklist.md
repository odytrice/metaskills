# Code Review Checklist

Apply only the sections relevant to the changed areas. On any conflict, the project's
`AGENTS.md` § Code Layout & Tech Stack and § Review Notes override this checklist.
Always also apply `AGENTS.md` § Review Notes — it carries the project-specific checks,
known-bug interactions, and active migrations this generic checklist cannot know about.

## Backend (F# / .NET)

### F# Idioms & Functional Style
- Prefers pattern matching over if-else chains
- Uses pipe operator (`|>`) for data transformation pipelines
- Avoids mutation -- uses immutable data structures and `let` bindings
- Uses discriminated unions for domain modeling where appropriate
- No unnecessary use of classes when modules and functions suffice
- Proper use of `option` and `Result` types -- no nulls leaking into F# code
- Uses computation expressions correctly -- no careless mixing of `Task` and `Async`;
  `task { }` stays at the HTTP boundary or immediate SDK adaptation when the project
  convention says so

### Error Handling (Railway-Oriented Programming)
- Uses `Result<T, AppError>` with `FsToolkit.ErrorHandling` for error propagation
- Errors flow through `Result.bind`, `Result.map`, and the project's result computation
  expressions (`asyncResult { }` / `taskResult { }` per `AGENTS.md`)
- No swallowed exceptions -- errors are logged or propagated
- The project's `AppError` type is used consistently (not ad-hoc error strings)
- Validation errors distinguished from system errors (e.g. ValidationError vs DatabaseError)
- Error-to-log and error-to-HTTP-status mappings go through the project's designated
  helpers, and user-facing error text does not leak internal details

### Code Style & Formatting (Fantomas)
- 4-space indentation, max line length per the project's Fantomas config
- PascalCase for types, modules, and public functions
- camelCase for local bindings, private functions, and parameters
- Imports grouped by namespace: external first, then project namespaces, alphabetized
  within groups
- Formatted with the project's Fantomas configuration (`dotnet fantomas --check .`)

### Architecture & Layer Separation
- **Core/Domain**: domain models, business logic, service interfaces, error types
  - No infrastructure dependencies (no database providers, no HTTP clients) in Core
  - Services depend on interfaces defined in Core, not concrete implementations
  - Business logic lives here, not in handlers, workers, or actors
- **Infrastructure**: repositories, database context/connections, external services
  - Repositories implement interfaces defined in Core
  - Data-access usage (EF Core, Linq2Db, or the project's provider) confined to
    Infrastructure
  - Migrations use FluentMigrator conventions
  - Infrastructure exceptions map to `AppError` at the boundary
- **Background processing** (workers, actors, or hosted services per the project)
  - Thin orchestrators -- business logic stays in Core services
  - Proper message/job types defined for communication
  - Failures handled gracefully (retry, dead-letter, or log) -- never crash silently
  - No blocking calls in async processing loops
- **Web**: HTTP handlers, routes, middleware, mappers
  - Handlers are thin -- delegate to Core services -- and enforce auth/authorization
  - Request/response mapping in the project's designated mapper location
  - Routes follow the existing pattern in the project's routes file

### Domain Model Integrity
- All entities use **ULID** identifiers (not GUIDs or ints)
- Models follow the existing patterns in the project's domain model files
- Transfer/DTO types are kept at API boundaries and contain no business logic
- DTO mirrors stay in sync between F# transfer types and TypeScript usage

### Giraffe HTTP Handlers
- Handlers use Giraffe's `HttpHandler` type (`HttpFunc -> HttpContext -> Task<HttpContext option>`)
- Proper use of Giraffe operators and combinators (`>=>`, `choose`, `route`, `GET`, `POST`, etc.)
- Project-local custom operators used consistently
- JSON serialization/deserialization handled correctly
- HTTP status codes are appropriate and match the project's error-to-status mapping
- Request validation before processing

### Database & Repository Patterns
- Repositories follow the interface contracts defined in Core
- Queries are efficient -- no N+1 problems, proper use of joins/includes, parameterized
  queries
- Transactions used for multi-step operations
- Migrations are backward-compatible (no destructive changes without a migration path)
- Connection/context disposal handled properly

### Storage, Caching & Messaging (where the project uses them)
- Blob/object storage used for large binary data; operations handle errors
  (connection failures, missing objects)
- Cache keys are meaningful, consistent, and include everything that varies the response
  (e.g. query string, user/tenant scope)
- Queue/message payloads serialized and deserialized correctly; consumers handle
  processing failures gracefully

### Security (Backend)
- Auth checks on protected endpoints; authorization scoped to the requesting
  user/tenant -- no cross-tenant or cross-user data access
- Development-only auth shortcuts (mock auth, seeded credentials) never active outside
  the Development environment
- No secrets in source code (connection strings, API keys, tokens); local secret files
  stay gitignored and uncommitted
- No `localhost` or developer-machine assumptions in host-side/production config
- Input validation and sanitization before database operations
- SQL injection prevention (parameterized queries)

### Testing (Backend)
- New features/services have corresponding tests in the locations given by
  `AGENTS.md` § Code Layout & Tech Stack
- Tests exercise the changed behavior and its risky paths, not just trivial assertions
- Unit tests mock dependencies; integration tests use real infrastructure
- Test names describe the behavior under test, following the surrounding suite's style

### Compilation Order (.fsproj)
- New files added to the `.fsproj` in correct dependency order
- Files that define types come before files that consume them
- The project still compiles after changes

### Performance & Observability
- No blocking calls in async contexts (no `.Result` or `.Wait()` on tasks/async)
- Structured logging at appropriate levels (Debug, Info, Warning, Error)
- Existing metrics/tracing instrumentation not broken by changes
- No unnecessary allocations in hot paths

---

## Frontend (Svelte 5 / TypeScript)

### Svelte 5 Patterns
- Uses Svelte 5 runes (`$state`, `$derived`, `$effect`, `$props`) correctly -- not
  legacy `$:` reactive statements or `export let` props
- Follows the project's routing conventions (SvelteKit `+page`/`+layout`/`+server`
  files, or the client-side router the project uses)
- In SvelteKit projects: initial data loads via `load` functions, form actions for
  mutations where appropriate, `$app/` imports used properly
- Guard against browser-only APIs (e.g. `import { browser } from "$app/environment"`
  or equivalent) -- watch for SSR hazards

### TypeScript & Code Quality
- Strict TypeScript: no `any` types, proper type annotations on function signatures
- Imports follow the project's alias conventions; external imports before internal,
  alphabetized within groups
- No unused imports, variables, or dead code
- PascalCase for types/interfaces, camelCase for variables/functions

### Formatting & Style
- Formatted with the project's Prettier configuration (including its Svelte plugin
  options) -- do not hand-enforce rules the config does not set

### API & Data Patterns
- API calls go through the project's designated client/proxy pattern (see
  `AGENTS.md` § Code Layout & Tech Stack) -- respect the client-side vs server-side
  API boundary and prefixes
- Proper error handling on API calls (try/catch, user-facing error messages)
- No secrets, tokens, or credentials hardcoded in client-side code
- Sensitive operations handled server-side, not in client components
- Nullable/optional data from the API handled explicitly

### Component Design
- Components are focused and single-responsibility
- Props are typed with interfaces/types
- Events/callbacks use Svelte 5 patterns (callback props, not `createEventDispatcher`)
- Reusable components live in the project's shared component location
- No direct DOM manipulation -- use Svelte reactivity instead

### Accessibility & UX
- Interactive elements have proper ARIA attributes
- Form inputs have associated labels
- Images have alt text
- Keyboard navigation support for custom interactive elements
- Loading states and error states handled in the UI
- UI text and controls match implemented behavior -- no placeholder metrics, inert
  buttons, or manual refresh where automatic updates are expected

### Security (Frontend)
- No `{@html}` with unsanitized user input (XSS risk)
- Auth guards on protected routes not bypassed
- No sensitive data in client-side stores that persists beyond the session
- File uploads validated (type, size) before sending
- Framework CSRF protections not disabled or worked around

### Testing (Frontend)
- New components/features have corresponding tests in the locations given by
  `AGENTS.md` § Code Layout & Tech Stack
- Tests focus on behavior, not implementation details
