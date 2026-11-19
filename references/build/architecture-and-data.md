# Architecture, APIs, errors and data

Read this when choosing structure, designing a module or API, or sketching the data model. SKILL.md "Stack, data model, architecture" has the short version. Offline and mobile specifics live in `mobile-and-offline.md`.

## Contents
1. Default stacks to propose
2. Modules that stay easy to change
3. API and interface design
4. Error handling
5. Idempotency, retries and the "unknown" outcome
6. Data modelling (SQL and Firestore)
7. Queries, indexes and transactions

---

## 1. Default stacks to propose

Prefer boring, popular, well-documented tools. Propose one stack with a one-line reason, say what would change your mind, and record the choice in an ADR.

| Project | Default | Why |
|---|---|---|
| Restaurant menu, portfolio, company site | Static site (Vite + React, or Astro) on Netlify; content in JSON/Markdown or a small CMS | Fast, cheap, nothing to hack; link previews work if prerendered |
| Admin dashboard / internal tool | Next.js or Vite + React, with Supabase (Postgres + RLS) or Firebase | Auth and rules out of the box |
| POS / offline counter app (Android + Windows) | Flutter + local SQLite (drift or sqflite_common_ffi) as the ledger, syncing to Firestore or your own API | Works offline; one codebase for tablet and PC |
| Consumer mobile app | Expo (React Native) or Flutter, plus Firebase or Supabase | Store builds and OTA updates are handled |
| Payments | The gateway's hosted payment page, never your own card form: Stripe Checkout where Stripe serves the merchant; for Iraqi clients, the gateway they bank with (FIB, ZainCash, FastPay, or a local aggregator) | Card data never touches your server |

Niche stacks starve both the AI and future maintainers of examples; deviate only with a reason the user agrees with.

## 2. Modules that stay easy to change

- **Deep modules:** a small interface with a lot of behaviour behind it. A module's interface is everything a caller must know: types, invariants, call order, errors, config, performance. Make modules deeper by cutting methods and parameters and hiding more.
- **Deletion test:** remove the module in your head. If complexity vanishes, it was a pass-through and should be merged. If complexity spreads across its callers, it's earning its place.
- **Small files aren't the goal.** Ten tiny files you must jump between to understand one feature are worse than one coherent module. Split by responsibility, keep things that change together in one place, and organize by feature (`sales/`, `inventory/`, `customers/`) rather than by technical layer only.
- **Seams:** a seam is a boundary where you can swap an implementation, usually for testing. It's real only once it has two implementations (production plus a test fake). Classify every dependency:
  - **In-process code:** call it directly and test it directly.
  - **Has a local stand-in** (in-memory SQLite, the Firebase emulator, local Supabase): test against the stand-in.
  - **Your own remote service** (Cloud Functions, your API): an interface plus an in-memory fake.
  - **Third-party** (Stripe, SMS, printer, barcode scanner, maps): pass in an interface and fake it.
- **Keep the domain pure.** Money math, stock rules, discounts and sync conflict resolution live in plain functions with no framework, UI or network imports. They're the easiest code to test and the most expensive to get wrong.
- **Return results instead of mutating inputs** (`calculateTotals(cart)` returns new totals; it doesn't modify `cart`).
- **Design it twice** for important interfaces. Sketch 2-3 deliberately different shapes (minimal, flexible, trivial common case), compare them, then choose or merge.
- **Enforce boundaries mechanically** once the app grows. For example, dependency-cruiser rules: other code imports only a feature's public entry, there are no import cycles, and barrel files don't re-export whole trees. Prove each rule fails on a deliberate violation once.
- **Naming:** use the domain glossary (sale, shift, batch, expiry, void). One concept, one name, everywhere.
- **Hard to test means badly designed.** If testing needs ten mocks, inject dependencies or move logic into pure functions.

## 3. API and interface design

- **Contract first:** define input and output types (zod schemas, Dart classes) before the implementation, with separate types for input and output. Model results and states as discriminated unions or Dart 3 sealed classes with an exhaustive `switch`, not a loose `isLoading/hasError/data` trio.
- **Validate only at boundaries** (requests, forms, third-party responses, env vars at startup) and trust typed data inside.
- **Status codes:**
  - 400 malformed, 401 not logged in, 403 not allowed, 404 not found, 409 conflict, 422 semantically invalid, 429 rate-limited (with `Retry-After`).
  - 500 carries no internals; 201 is the answer for a create.
  - Never return 200 with `success: false`.
- **One error shape everywhere:** `{ "error": { "code": "STOCK_INSUFFICIENT", "message": "...", "details": {...} } }`. Don't mix throwing, returning null and returning `{error}` across endpoints.
- **Authorization per record, not just per route:** load the object, check the caller owns it or has the role, then act. See `security.md`.
- **Additive changes only:** new fields are optional; never rename a field or change its type in place. Old app versions and offline clients keep sending old payloads for months.
- **Paginate from day one:**
  - Cursors for growing data: fetch `limit + 1` to know whether there's a next page; in Firestore, `limit()` + `startAfterDocument()`.
  - Offsets only for small admin lists.
  - Cap page size on the server.
- **Timeouts on every external call.** A call without a timeout can hang a request, or a till, forever.

## 4. Error handling

- **Never swallow errors.** An empty `catch`, or a `catch` that logs and returns `[]` or `null`, turns "permission denied" into "no data" and "payment failed" into "success". Either handle the error meaningfully (retry, fallback, user message) or let it propagate.
- **No silent fallbacks for config:** required env vars and keys fail at startup. `process.env.X || 'default'` for a secret is a bug.
- **Two audiences:**
  - The user gets a clear message with a next step ("Couldn't reach the server. Your sale is saved and will sync").
  - Logs get the details (error code, IDs, stack).
  - Never show raw `error.message` or stack traces to users.
- **Error boundaries in UIs** (React error boundary, Flutter `ErrorWidget.builder`) for render crashes, plus explicit error states for async work.
- **Log with context:** what was attempted, with which IDs, and the error. No secrets or personal data.
- **Fail-closed in security checks:** if the permission lookup fails, the answer is "no".

## 5. Idempotency, retries and the "unknown" outcome

- **Every call has three outcomes:** success, failure and **unknown** (timeout, lost connection after sending). Design for unknown: retrying must be safe.
- **Idempotency keys come from the business intent** (the sale UUID created when the sale started, `charge:v1:${orderId}`), never a fresh random value or timestamp per attempt.
  - Claim the key with a unique-constraint insert, not "check then insert".
  - The same key with a different body is a 422.
  - Keep keys at least as long as the longest retry path. Stripe may drop idempotency keys after ~24 hours, so keep your own dedupe.
- **Webhooks and queues deliver at least once.** Dedupe by `event.id` with a unique constraint before acting.
- **Outbox pattern:** write the intent to an outbox row in the same transaction as the business change, then deliver it asynchronously and reconcile unknowns.
- **Retries:** retry only transient errors (network, 429, 5xx), with exponential backoff, random jitter and a cap. Never retry 4xx validation errors.
- **Serverless state isn't shared:** a rate limiter, queue or cache in a module-level `Map` inside a Netlify, Vercel or Cloud Function isn't shared across instances, disappears when the function sleeps, and grows without bound. Work started after the response is sent can be lost.

## 6. Data modelling (SQL and Firestore)

Sketch the data model before the UI: entities, relationships, who owns what, and how it's persisted. Put a rough schema in the plan file; it doesn't need to be a formal diagram.

**Types:**
- Primary keys: `bigint generated always as identity` for server-generated IDs; UUIDv7 or ULID when devices create IDs offline or IDs are exposed. Random v4 primary keys fragment big indexes, and unguessable IDs never replace authorization.
- `text`, rather than `varchar(n)` by habit.
- Timestamps: `timestamptz`, stored in UTC and displayed in the user's zone (`Asia/Baghdad`). Never store device-local time strings.
- Money: integer minor units (or whole dinars for IQD) or `numeric(12,2)`, plus a currency code. **Never float or real.**
- Enums: check constraints or enum types. Booleans as `boolean`, not strings.
- Numbers as numbers: an odometer or quantity stored as `text` sorts "1000" before "200".

**Constraints in the database, not just the UI:**
- `not null`, `check (price >= 0)`, `check (qty > 0)`, `unique (shop_id, barcode)`, and foreign keys with a deliberate `on delete` (`cascade`, `restrict` or `set null`).
- Add constraints idempotently in migrations: `add constraint if not exists` isn't valid Postgres, so wrap them in a `do $$ ... $$` block that checks `pg_constraint`.

**Audit fields:**
- `created_at`, `updated_at` and `created_by` on business tables.
- Soft-delete (`deleted_at`) where history matters or sync needs tombstones.
- Append-only tables for sales, payments and stock movements.

**Naming:** lowercase `snake_case` (quoted camelCase in Postgres is a lifelong annoyance). Migrations go through the tool (`supabase migration new <name>`, Prisma migrate), are never edited after deploy, and run before the code that needs them.

**Firestore modelling:**
- **Model for your queries.** Firestore has no joins, so denormalize what screens need (e.g. copy the product name onto the sale line). Every document read is billed.
- **Documents:**
  - Max 1 MiB each.
  - A single document takes roughly one sustained write per second, so hot counters need increments aggregated server-side or sharded counters.
  - Rules apply to whole documents: split public and private fields into separate documents (`users_public` / `users_private`).
- **Paths:**
  - Subcollections for owned data (`shops/{shopId}/sales/{saleId}`) make multi-shop rules simple.
  - Use client-generated IDs (`doc(id).set()`) for anything that can be retried.
- **Timestamps:** use real Firestore `Timestamp` / `serverTimestamp()` fields, not date strings.
- **Indexes:** keep `firestore.indexes.json` in git.

## 7. Queries, indexes and transactions

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
