# Backends and APIs: servers, databases, jobs, serverless, Firebase and Supabase

Read this when building anything that runs on a server or talks to one: APIs, web backends, background jobs, webhooks, serverless functions, or an app built on a backend-as-a-service. API shape, errors, idempotency and data modelling are in `../build/architecture-and-data.md`; authentication, access rules and secrets in `../build/security.md`.

## Contents
1. The shape of a service
2. Choosing the API style
3. Databases from a server
4. Background jobs, queues and schedules
5. Serverless and edge functions
6. Backend-as-a-service: Firebase and Supabase
7. Files and object storage
8. Observability
9. Performance and scaling
10. Traps by language
11. Testing services

---

## 1. The shape of a service

- **Layers with one direction of dependency:** handler (HTTP, queue, CLI) → application or service logic → domain rules (pure) → repositories and clients (database, other services). Handlers parse and authorize; they don't hold business rules.
- **Config from the environment, validated at startup:** a schema over the env vars (zod, Pydantic settings, envconfig, Spring's `@ConfigurationProperties` with validation, .NET options validation). A missing secret crashes at boot, not at the first payment.
- **Every entry point** follows the five steps in SKILL.md "Security": authenticate, validate, load and check ownership, act, return only what's needed.
- **Health checks:** a liveness endpoint (the process is up) and a readiness endpoint (dependencies such as the database are reachable). Keep them cheap and unauthenticated, and leak nothing.
- **Graceful shutdown:** on SIGTERM, stop accepting work, finish in-flight requests and jobs within a deadline, close pools.
- **Timeouts everywhere:** incoming requests, outgoing HTTP calls, database statements. One slow dependency must not hang every request.
- **Stateless processes:** no user data in memory between requests, so instances can restart and scale. Sessions, caches and rate limits live in shared storage when there's more than one instance.

## 2. Choosing the API style

| Style | Fits | Costs |
|---|---|---|
| REST with JSON | Most apps, public APIs, mobile clients, caching through HTTP | Over- or under-fetching; versioning discipline needed |
| Typed RPC in one codebase (tRPC, server functions, Server Actions) | A web front end and backend in the same TypeScript repo | Couples client and server; not for third parties; every procedure is still a public endpoint |
| GraphQL | Many clients with different data needs, deeply related data | Per-field authorization, query cost limits and N+1 batching are on you |
| gRPC | Service-to-service calls, streaming, strict contracts | Browser support needs a proxy; harder to debug by hand |
| Webhooks (outgoing) | Telling other systems about events | Signing, retries, idempotency and replay protection |

Pick one style per boundary and offer the choice when it isn't obvious. Whatever the style: typed contracts, one error shape, pagination, and authorization per record (`../build/architecture-and-data.md` §3).

## 3. Databases from a server

- **Migrations through a tool,** committed, reviewed, run before the code that needs them, never edited after deploy: Prisma Migrate or Drizzle Kit, Alembic or Django migrations, golang-migrate, goose or Atlas, Flyway or Liquibase, EF Core migrations, Laravel or Rails migrations, sqlx or Diesel for Rust.
- **Destructive migrations** (dropping or renaming columns, changing types) use expand → migrate → contract (`../build/planning.md` §3), and a backup is taken and restorable before running them in production.
- **Connection pooling:** one pool per process, sized to the database's limits. Serverless functions connect through a pooler in transaction mode (for example Supabase's pooler on port 6543), with prepared statements disabled where the driver requires it.
- **ORMs:** watch for N+1 queries (lazy loading in loops), for loading whole tables, and for raw-query helpers that interpolate strings. Log the SQL in development and read it.
- **Transactions** wrap each business operation that writes more than one row; keep them short and never call external APIs inside one.
- **Least privilege:** the application's database user can't drop tables or alter roles; migrations run with a separate role.

## 4. Background jobs, queues and schedules

- **Move slow or unreliable work out of the request:** emails, SMS, image processing, reports, calls to flaky third parties. Return quickly and let a worker do it.
- **Jobs run at least once,** so every job is idempotent: keyed by the business intent, checked with a unique constraint or a processed-marker before acting.
- **Retries** with exponential backoff and jitter, a maximum attempt count, and a dead-letter queue (or failed-jobs table) that someone looks at.
- **Use an established queue** for your stack rather than a hand-rolled table poller: for example BullMQ (Node), Celery, RQ or Dramatiq (Python), Sidekiq (Ruby), Hangfire (.NET), Laravel queues, or a managed queue. A Postgres-backed queue (`for update skip locked`) is fine at small scale.
- **Scheduled jobs** (cron, cloud schedulers, CI schedules): prevent overlapping runs with a lock, write times in UTC, log every run's outcome, and alert when a run fails or doesn't happen at all.
- **Work started after the response is sent can be lost** on serverless platforms unless the platform offers a "wait until" or after-response hook. Use a queue for anything that must happen.

## 5. Serverless and edge functions

- **No shared memory between invocations:** a rate limiter, cache or queue in a module-level variable isn't shared across instances, vanishes when the function sleeps, and grows without bound while it lives.
- **Timeouts and cold starts:** keep functions small, initialize clients outside the handler (reused while warm), and move long work to a queue.
- **Edge runtimes** lack parts of the standard library (filesystem, some Node APIs, native modules). Check before choosing one.
- **Secrets** come from the platform's secret store, scoped per environment; never bundled into client-side code by a shared config file.
- **Costs scale per invocation:** cap concurrency and set budget alerts, especially for anything a stranger can trigger.

## 6. Backend-as-a-service: Firebase and Supabase

When clients talk to the database directly, **the access rules are the backend.** Writing and testing them is in `../build/security.md` §4-5; auditing them in `../audit/security.md` §2-3. The usage traps:

**Firestore from apps and web:**
- **Model for your queries.** There are no joins: denormalize what screens need (copy the product name onto the sale line), and remember every document read is billed.
- **Documents:** at most 1 MiB; a single document sustains roughly one write per second, so hot counters need sharding or server-side aggregation; rules apply to whole documents, so split public and private fields (`users_public` / `users_private`).
- **Paths:** subcollections for owned data (`shops/{shopId}/sales/{saleId}`) keep multi-tenant rules simple.
- **Client-generated IDs** for anything that can be retried: `doc(id).set(...)`, never `.add(...)` in retry or catch code.
- **Transactions need the server,** so they fail offline. For writes that must work offline, use batched writes and `FieldValue.increment()`, or a local ledger (`../concerns/offline-first-and-sync.md`).
- **Awaiting a write waits for the server.** An awaited `set()` in a checkout path freezes the UI while offline. In UI code that writes directly, don't block on the write (in Dart, `unawaited()`), and watch `hasPendingWrites`. A sync worker is the exception: it awaits, because completion is the server's acknowledgement.
- **A pending `serverTimestamp()` reads back as null** in local snapshots; handle null instead of casting.
- **Read costs:** a dashboard listening to every sale is re-billed on every change. Keep summary documents or use aggregation queries, always `limit()` queries, paginate with cursors, and set a budget alert.
- **Indexes:** `where` plus `orderBy` on another field needs a composite index. Keep `firestore.indexes.json` in git and deploy it with `--only firestore:indexes`.
- **Offline cache size** defaults to about 100 MB; set it deliberately.
- **Auth:** let the SDK manage sessions and fetch fresh ID tokens per request (they expire after an hour); roles come from custom claims set on the server; staff-only apps disable public sign-up, because the public API key lets anyone create accounts through the Auth REST API.
- **Re-run `flutterfire configure`** after changing the bundle or application ID or adding Firebase plugins.

**Supabase:**
- **RLS on every table in an exposed schema,** with policies for each operation, tested with two users; the `anon` and `authenticated` roles reach the database directly through the API.
- **The service-role (secret) key bypasses RLS:** server-only, never in a client, never in a `NEXT_PUBLIC_` or similar variable.
- **Database functions** (`security definer`) run with their owner's rights: set `search_path`, check the caller inside, and revoke execute from `public` where needed.
- **Run the security advisors** (`supabase db advisors`, CLI 2.81+, or the dashboard) after schema changes.
- **Storage buckets** have their own policies; private by default.
- **Migrations** live in `supabase/migrations`, created with `supabase migration new`, tested on a local stack (`supabase start`) before `db push`.

**Either service:** separate projects for dev and prod, budget alerts, and the client's own account as the owner (`../build/shipping.md` §1 and §3).

## 7. Files and object storage

- **Uploads go to object storage** (S3-compatible, Firebase Storage, Supabase Storage), not the app server's disk, which disappears on redeploy and doesn't scale.
- **Direct uploads with short-lived signed URLs** keep large files off your server; the server signs only after authorizing, with size and type limits.
- **Validate on the server:** size, content type by magic bytes (not the extension), and image re-encoding or malware scanning where risk warrants it (`../build/security.md` §8).
- **Private by default;** serve private files through short-lived signed URLs, never public buckets with guessable names.
- **Generated file names** (UUIDs), never the user's file name as a path.

## 8. Observability

- **Structured logs** (JSON) with a request ID carried through every log line and passed to downstream calls. No secrets, tokens or personal data in logs.
- **Error tracking** (Sentry or similar) with release versions, proven with a deliberate test error.
- **Metrics that matter:** request rate, error rate and latency (p50, p95, p99) per endpoint; queue depth and job failures; database connections and slow queries.
- **Tracing** (OpenTelemetry) once there's more than one service or a slow request you can't explain from logs.
- **Alerts** on symptoms users feel (error rate, latency, failed jobs, a scheduled job that didn't run), routed to someone who will act.

## 9. Performance and scaling

- **Measure first.** Find the slow endpoint and its slow part (a trace, the database's slow-query log, a profiler) before changing code.
- **The usual culprits:** N+1 queries, missing indexes, unbounded queries, serial calls that could run in parallel, large payloads, and synchronous work that belongs in a job.
- **Cache** only what's measured to be hot and safe to serve stale, with an explicit expiry and invalidation story. Every cache adds a staleness bug to think about.
- **Scale out** stateless processes behind a load balancer before reaching for microservices or a new database.
- **Rate-limit and paginate** every endpoint that lists or searches, and cap request body sizes.

## 10. Traps by language

- **Node/TypeScript:** blocking the event loop with CPU work or sync file calls; unhandled promise rejections (crash or silent failure); `await` in loops where `Promise.all` with a concurrency limit fits; trusting `req.body` types without runtime validation.
- **Python:** blocking calls inside `async` code (use async drivers or run them in a thread); mutable default arguments; catching bare `except:`; `pickle` or `yaml.load` on untrusted data; Django or SQLAlchemy lazy loading in loops.
- **Go:** goroutine leaks (no cancellation), ignoring returned errors, writes to a nil map, missing `context` propagation and timeouts, loop variables captured in closures in older Go versions, `defer` inside loops.
- **Java/Kotlin:** N+1 through lazy JPA relations; `@Transactional` that does nothing on private or self-invoked methods; blocking calls on reactive or coroutine threads; catching and ignoring exceptions.
- **C#/.NET:** `async void` outside event handlers; `.Result` or `.Wait()` causing deadlocks; a `DbContext` shared across threads or kept as a singleton; `HttpClient` created per request instead of through `IHttpClientFactory`.
- **PHP:** mass assignment without `$fillable`/`$guarded`; raw queries with interpolated input; disabled CSRF middleware; `unserialize` on user data.
- **Ruby/Rails:** unpermitted params (strong parameters), N+1 without `includes`, `html_safe`/`raw` on user input, callbacks hiding business logic.
- **Rust:** `unwrap()`/`expect()` on fallible input in request paths; blocking calls inside async runtimes; unbounded channels.

## 11. Testing services

- **Unit tests** for domain rules, with no I/O.
- **Integration tests against a real database** of the same engine and version (a container, for example with Testcontainers, or a local Postgres), never only mocks or a different engine like SQLite standing in for Postgres.
- **API tests** call the real HTTP layer (supertest, FastAPI's TestClient, `httptest`, `WebApplicationFactory`, Spring's MockMvc) and include auth failures: no token, another user's token, a wrong role.
- **Contract tests** when another team or app depends on your API: check responses against the published schema (OpenAPI) in CI.
- **Rules tests** for Firebase and Supabase run against the emulator or local stack with at least two users and an anonymous client.
- **Jobs and webhooks:** deliver the same event twice and assert one effect; make the downstream call fail and assert the retry.
