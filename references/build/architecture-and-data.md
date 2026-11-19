# Architecture, APIs, errors and data

Read this when choosing structure, designing a module or API, or sketching the data model, in any language. SKILL.md Build §6 has the short version. Choosing the stack itself is in `choosing-a-stack.md`; servers, jobs and backend services in `../platforms/backend-and-apis.md`; offline and sync in `../concerns/offline-first-and-sync.md`.

## Contents
1. Modules that stay easy to change
2. API and interface design
3. Error handling
4. Idempotency, retries and the "unknown" outcome
5. Data modelling
6. Queries, indexes and transactions

---

## 1. Modules that stay easy to change

- **Deep modules:** a small interface with a lot of behaviour behind it. A module's interface is everything a caller must know: types, invariants, call order, errors, config, performance. Make modules deeper by cutting methods and parameters and hiding more.
- **Deletion test:** remove the module in your head. If complexity vanishes, it was a pass-through and should be merged. If complexity spreads across its callers, it's earning its place.
- **Small files aren't the goal.** Ten tiny files you must jump between to understand one feature are worse than one coherent module. Split by responsibility, keep things that change together in one place, and organize by feature (`sales/`, `inventory/`, `customers/`) rather than by technical layer only.
- **Seams:** a seam is a boundary where you can swap an implementation, usually for testing. It's real only once it has two implementations (production plus a test fake). Classify every dependency:
  - **In-process code:** call it directly and test it directly.
  - **Has a local stand-in** (a database in a container or in memory, the Firebase emulator, local Supabase, a local queue): test against the stand-in.
  - **Your own remote service** (another service, serverless functions): an interface plus an in-memory fake.
  - **Third-party** (payment gateway, SMS, email, printer, maps): pass in an interface and fake it.
- **Keep the domain pure.** Business rules (money math, stock, discounts, permissions, scheduling, sync conflict resolution) live in plain functions with no framework, UI or network imports. They're the easiest code to test and the most expensive to get wrong.
- **Return results instead of mutating inputs** (`calculateTotals(cart)` returns new totals; it doesn't modify `cart`).
- **Design it twice** for important interfaces. Sketch 2-3 deliberately different shapes (minimal, flexible, trivial common case), compare them, then choose or merge. When the choice affects the user (a public API, a data format others depend on), offer the shapes as options.
- **Enforce boundaries mechanically** once the code grows: other code imports only a module's public entry, and there are no import cycles (dependency-cruiser or eslint rules in JS/TS, import-linter in Python, ArchUnit in Java, `internal/` packages in Go, project references or analyzers in .NET). Prove each rule fails on a deliberate violation once.
- **Naming:** use the domain glossary (for a shop: sale, shift, batch, expiry, void). One concept, one name, everywhere.
- **Hard to test means badly designed.** If testing needs ten mocks, inject dependencies or move logic into pure functions.

## 2. API and interface design

- **Contract first:** define input and output types before the implementation, with separate types for input and output, and runtime validation at the edge (zod or valibot in TypeScript, Pydantic in Python, struct tags plus a validator in Go, serde in Rust, data classes or records with Bean Validation in Java/Kotlin, FluentValidation or data annotations in C#, Dart classes). Model results and states as discriminated unions or sealed types with an exhaustive `switch`/`match`, not a loose `isLoading/hasError/data` trio.
- **Validate only at boundaries** (requests, forms, third-party responses, env vars at startup) and trust typed data inside.
- **Status codes:**
  - 400 malformed, 401 not logged in, 403 not allowed, 404 not found, 409 conflict, 422 semantically invalid, 429 rate-limited (with `Retry-After`).
  - 500 carries no internals; 201 is the answer for a create.
  - Never return 200 with `success: false`.
- **One error shape everywhere:** `{ "error": { "code": "STOCK_INSUFFICIENT", "message": "...", "details": {...} } }`. Don't mix throwing, returning null and returning `{error}` across endpoints.
- **Authorization per record, not just per route:** load the object, check the caller owns it or has the role, then act. See `security.md` §3.
- **Additive changes only:** new fields are optional; never rename a field or change its type in place. Old app versions and offline clients keep sending old payloads for months.
- **Paginate from day one:**
  - Cursors for growing data: fetch `limit + 1` to know whether there's a next page; in Firestore, `limit()` + `startAfterDocument()`.
  - Offsets only for small admin lists.
  - Cap page size on the server.
- **Timeouts on every external call.** A call without a timeout can hang a request, or a till, forever.

## 3. Error handling

- **Never swallow errors.** An empty `catch`, or a `catch` that logs and returns `[]` or `null`, turns "permission denied" into "no data" and "payment failed" into "success". Either handle the error meaningfully (retry, fallback, user message) or let it propagate.
- **No silent fallbacks for config:** required env vars and keys fail at startup. `process.env.X || 'default'` for a secret is a bug.
- **Two audiences:**
  - The user gets a clear message with a next step ("Couldn't reach the server. Your sale is saved and will sync").
  - Logs get the details (error code, IDs, stack).
  - Never show raw `error.message` or stack traces to users.
- **Error boundaries in UIs** (a React error boundary, Flutter's `ErrorWidget.builder`, a global handler in desktop and mobile apps) for render crashes, plus explicit error states for async work.
- **Language idioms:** exceptions where the language uses them; returned errors in Go (wrapped with `%w`, never ignored); `Result` in Rust (no `unwrap()` on input); typed result values where the team prefers them. Pick one style per codebase.
- **Log with context:** what was attempted, with which IDs, and the error. No secrets or personal data.
- **Fail-closed in security checks:** if the permission lookup fails, the answer is "no".

## 4. Idempotency, retries and the "unknown" outcome

- **Every call has three outcomes:** success, failure and **unknown** (timeout, lost connection after sending). Design for unknown: retrying must be safe.
- **Idempotency keys come from the business intent** (the sale UUID created when the sale started, `charge:v1:${orderId}`), never a fresh random value or timestamp per attempt.
  - Claim the key with a unique-constraint insert, not "check then insert".
  - The same key with a different body is a 422.
  - Keep keys at least as long as the longest retry path. Stripe may drop idempotency keys after ~24 hours, so keep your own dedupe.
- **Webhooks and queues deliver at least once.** Dedupe by `event.id` with a unique constraint before acting.
- **Outbox pattern:** write the intent to an outbox row in the same transaction as the business change, then deliver it asynchronously and reconcile unknowns.
- **Retries:** retry only transient errors (network, 429, 5xx), with exponential backoff, random jitter and a cap. Never retry 4xx validation errors.
- **Serverless state isn't shared:** a rate limiter, queue or cache in a module-level variable inside a serverless function isn't shared across instances, disappears when the function sleeps, and grows without bound. Work started after the response is sent can be lost (`../platforms/backend-and-apis.md` §5).

## 5. Data modelling

Sketch the data model before the UI: entities, relationships, who owns what, and how it's persisted. Put a rough schema in the plan file; it doesn't need to be a formal diagram.

**Types:**
- Primary keys: `bigint generated always as identity` for server-generated IDs; UUIDv7 or ULID when devices create IDs offline or IDs are exposed. Random v4 primary keys fragment big indexes, and unguessable IDs never replace authorization.
- `text`, rather than `varchar(n)` by habit.
- Timestamps: `timestamptz` (or the database's UTC timestamp type), stored in UTC and displayed in the user's zone (for example `Asia/Baghdad`). Never store device-local time strings. Date-only values (birthdays, due dates) are `date`, not timestamps.
- Money: integer minor units (or whole units for currencies like IQD) or `numeric(12,2)`, plus a currency code. **Never float or real** (`../concerns/money-and-business-rules.md` §1).
- Enums: check constraints or enum types. Booleans as `boolean`, not strings.
- Numbers as numbers: an odometer or quantity stored as `text` sorts "1000" before "200".

**Constraints in the database, not just the UI:**
- `not null`, `check (price >= 0)`, `check (qty > 0)`, `unique (shop_id, barcode)`, and foreign keys with a deliberate `on delete` (`cascade`, `restrict` or `set null`).
- Add constraints idempotently in migrations: `add constraint if not exists` isn't valid Postgres, so wrap them in a `do $$ ... $$` block that checks `pg_constraint`.

**Audit fields:**
- `created_at`, `updated_at` and `created_by` on business tables.
- Soft-delete (`deleted_at`) where history matters or sync needs tombstones.
- Append-only tables for sales, payments and stock movements.

**Naming:** lowercase `snake_case` (quoted camelCase in Postgres is a lifelong annoyance). Migrations go through the tool (`../platforms/backend-and-apis.md` §3 lists one per language), are never edited after deploy, and run before the code that needs them.

**Document databases** (Firestore, MongoDB, DynamoDB): model for your queries, since there are no joins; denormalize what screens need; keep documents small; split public and private fields into separate documents when rules apply per document; use client-generated IDs for anything retried. Firestore specifics are in `../platforms/backend-and-apis.md` §6.

## 6. Queries, indexes and transactions

- **Index every foreign-key column** (Postgres doesn't do it automatically) and every column used in RLS policies (`user_id`, `shop_id`).
  - Composite indexes put equality columns first, range columns last.
  - Partial indexes serve hot filters (`where deleted_at is null`).
  - GIN indexes cover jsonb, arrays and full-text search.
- **Pagination:** keyset (`where (created_at, id) < ($1, $2) order by created_at desc, id desc limit 20`), not deep `offset`.
- **N+1:** one query with `where id = any($1)`, a join, or a Supabase nested select, instead of a query per row in a loop. In Firestore, batch with `whereIn` (in chunks) or denormalize.
- **Upserts:** `insert ... on conflict (key) do update set ... = excluded....` instead of select-then-insert. SQLite has this from 3.24. Where the device's system SQLite is older (check with `select sqlite_version()`), either bundle SQLite (`sqlite3`/drift), or run `UPDATE` and then `INSERT` if no row changed, in one transaction. **Never use `INSERT OR REPLACE` / `ConflictAlgorithm.replace` on a table with child rows:** REPLACE deletes the old row first, and with foreign keys on, that delete cascades to (or orphans) its line items.
- **Atomic updates for counters and stock:** `update products set stock = stock - $1 where id = $2 and stock >= $1 returning *`, or `FieldValue.increment()`, or a transaction. Never read, compute in app code, then write.
- **Transactions:**
  - Keep them short, and never make network calls (payment APIs, emails) while holding locks.
  - Lock rows in a consistent order to avoid deadlocks.
  - Use `for update skip locked` for job queues.
  - Firestore transaction callbacks can re-run, so keep side effects (printing, local writes) out of them.
- **Serverless + Postgres:** connect through the pooler in transaction mode (Supabase port 6543), with prepared statements disabled where the driver needs it (postgres.js `prepare: false`, Prisma `?pgbouncer=true`).
- **Find slow queries:** `explain (analyze, buffers)` (look for sequential scans on big tables and high "rows removed by filter"), and `pg_stat_statements` ordered by total time. For search, use a generated `tsvector` with a GIN index instead of `like '%x%'`.
