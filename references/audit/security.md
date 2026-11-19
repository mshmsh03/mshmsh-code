# Security pass: checks, detection, severity

The deep half of the audit, for any language. Sections 1, 4-9, 13 and 14 apply to every codebase; work through the others when their stack is present. Detect the stack from its files:

| Stack | Files that give it away |
|---|---|
| Firebase / Supabase | `firebase.json`, `*.rules`, `firebase_options.dart`, `google-services.json` / `supabase/`, `supabase/config.toml` |
| Next.js / other JS frameworks | `next.config.*`, `nuxt.config.*`, `svelte.config.*`, `angular.json`, `vite.config.*` |
| Expo / React Native, Flutter, native mobile | `app.json`, `app.config.*`, `eas.json` / `pubspec.yaml` / `AndroidManifest.xml`, `Info.plist`, `*.xcodeproj` |
| Python web | `manage.py`, `settings.py` (Django); `app.py` or `main.py` importing FastAPI or Flask |
| Ruby, PHP | `Gemfile`, `config/routes.rb` (Rails) / `composer.json`, `artisan`, `routes/` (Laravel) |
| Java/Kotlin, .NET | `pom.xml`, `build.gradle*`, `application.yml` (Spring) / `*.csproj`, `Program.cs`, `appsettings*.json` |
| Go, Rust | `go.mod` / `Cargo.toml` |
| Desktop | `electron` in `package.json`, `tauri.conf.json`, `*.csproj` with WPF/WinUI, `CMakeLists.txt` with Qt |
| Infrastructure and delivery | `Dockerfile`, `docker-compose.yml`, `*.tf`, `Pulumi.yaml`, Kubernetes manifests, `.github/workflows/`, `netlify.toml`, `_headers`, `vercel.json` |
| Payments | Stripe or local gateway SDKs in dependencies, webhook routes |

Detection lines are starting points: open the code and confirm before reporting.

**Rank by reachability:** anyone, with no account > anyone who can sign up (the public Firebase API key allows that even without a sign-up screen) > an existing customer or staff account > an admin, or someone holding the device or the repo > unconfirmed (label it "unverified"). Impact (other users' data, money, whole shops) sets the severity within each rung.

## Contents
1. Secrets: working tree, history, bundles, binaries
2. Firebase: Firestore, Storage, RTDB rules and Auth
3. Supabase and Postgres
4. Authentication and authorization (all stacks)
5. Money, business logic and races
6. Webhooks and callbacks
7. Paid APIs, rate limits and LLM features
8. Injection, XSS, SSRF, uploads, paths
9. Sessions, cookies, CSRF, redirects, account flows
10. Next.js specifics
11. Mobile and desktop apps
12. Web headers and deployment
13. Dependencies, supply chain, MCP
14. Logging, exposure and privacy
15. What the repo can't show
16. Containers, CI, infrastructure and other kinds of software

---

## 1. Secrets: working tree, history, bundles, binaries

- **Scan the whole history, not the last few commits.**
  - **With gitleaks:** `gitleaks git -v --redact --no-banner .` (older versions: `gitleaks detect -v --redact --source .`). Findings print only with `-v`, and it exits 1 when it finds leaks; that's not an error.
  - **With TruffleHog:** always pass `--no-verification`. Verification calls the provider with the found key, which this skill forbids.
  - **Check for a shallow clone** (`git rev-parse --is-shallow-repository`). A depth-1 clone has no history to scan, so say so; don't report "history clean".
  - **Without tools:**
    ```bash
    git log --all --oneline -E -G'sk_live_|rk_live_|sk_test_|whsec_|sb_secret_|AKIA[0-9A-Z]{16}|ghp_|github_pat_|glpat-|xox[bp]-|sk-ant-|sk-proj-|AIza[0-9A-Za-z_-]{35}|BEGIN [A-Z ]*PRIVATE KEY|"type": "service_account"|postgres(ql)?://[^:]+:[^@]+@'
    git log --all --name-only --format= | sort -u | grep -iE '(^|/)\.env|\.pem$|\.key$|\.p12$|\.jks$|\.keystore$|key\.properties|service.?account|adminsdk|credentials'
    ```
    Then `git show <sha> --stat`, and mask any value you quote.
- **Tracked env files:** `git ls-files | grep -iE '(^|/)\.env'`. `.env.example` may hold placeholders only.
- **Framework secrets in config files:** Django `SECRET_KEY` in `settings.py`, Rails `config/master.key` (the key that decrypts `credentials.yml.enc`), Laravel `APP_KEY`, connection strings with passwords in `appsettings*.json` or `application.properties`/`application.yml`, JWT signing secrets hardcoded as literals. **High**, Critical if the repo is public.
- **Secrets outside source files:** `terraform.tfstate` (holds resource secrets in plain text), Jupyter notebook outputs, Dockerfile `ENV`/`ARG` values, CI workflow files, `docker-compose.yml`, Kubernetes manifests with `kind: Secret` (base64 is not encryption), and log or dump files committed by accident.
- **Setup docs that leak by instruction:** a README or setup guide that tells developers to put server keys (service role, Resend, Stripe secret) in the *app's* `.env`, next to client-exposed variables. That's one `extra:` or prefix away from shipping. **Low-Medium.**
- **Service-account keys** have varied names; grep file *contents* for `"type": "service_account"` and `BEGIN PRIVATE KEY`, including under `assets/`. **Critical.**
- **Client-exposed values ship to every user:** web build prefixes (`NEXT_PUBLIC_`, `VITE_`, `REACT_APP_`, `EXPO_PUBLIC_`, Nuxt `runtimeConfig.public`, SvelteKit `$env/*/public`), mobile build configs, desktop app bundles. A secret behind one of them is public. **Critical** for OpenAI/Anthropic/Gemini, Stripe secret, Resend/SendGrid/Twilio, the Supabase service role and DB URLs.
- **Not a leak:** the Firebase config `apiKey` (in `firebase_options.dart`, `google-services.json`, the web config) is an identifier; its safety depends on the rules. Don't report it as a leaked secret. Do suggest API-key restrictions in Google Cloud. Watch for the reverse mistake: a Gemini or Maps *server* key also starts with `AIza`, and that one is a billable leak. Check which API the key is used with.
- **Fix wording:** "Rotate the key now, then remove it from the code and history." A key that reached a remote is burned; history rewriting can't reach clones, forks or caches. Never write "delete the file" as the whole fix.

## 2. Firebase: Firestore, Storage, RTDB rules and Auth

Get the **deployed** rules. The repo's `firestore.rules` may be stale or missing, and rules edited in the console never reach the repo. Ask the user to paste them from the console (Firestore → Rules, Storage → Rules, Realtime Database → Rules). Never run `firebase init` or `firebase deploy` in their repo: init is interactive and rewrites `firestore.rules` and `firebase.json`. Report "needs confirmation" if you can't see the deployed rules.

**Rules mistakes, worst first:**
- **Test mode left on:** `allow read, write: if request.time < timestamp.date(...)` opens everything until that date. Grep `request.time <`. The Realtime Database form is `".read": "now < 1767225600000"`. **Critical.**
- **Recursive wildcards:** rules are OR'd together, so a `match /{document=**}` (or `/shops/{rest=**}`) with a loose `allow` opens everything beneath it, however strict the other rules are. A plain parent match like `/shops/{shopId}` does *not* cover its subcollections. Grep `=**}`. **Critical** if the condition is loose.
- **`if true`, or an `allow` with no condition:** **Critical** on any write, and on reads of anything not meant to be public. `allow read: if true` on a published catalogue or menu is fine; list it under "checked and fine".
- **"Signed in" used as "allowed":** a condition that is only `request.auth != null`, on business or personal data. Firebase Auth's sign-up endpoint works with the public API key even when the app has no sign-up screen, so anyone can create an account. Anonymous auth also passes this check. **Critical** for sales, stock, customers and patients; High otherwise. Fix: membership or role from custom claims (`request.auth.token.role`, `request.auth.token.shopId`), plus disabling public sign-up for staff-only apps.
- **Authority read from data the client writes:** rules that trust `request.resource.data.role/isAdmin/ownerId`, or an `isAdmin()` that `get()`s a `users/{uid}` doc the user can write. **Critical.**
  - Safe pattern: create forces the lowest role (`request.resource.data.role == 'cashier'`).
  - Update keeps `role == resource.data.role` unless the caller is an admin by claim.
- **Update bypass:** validation runs only on `create`, or `allow write`/`update` only checks ownership. The user creates a valid doc, then updates it to add a role, a 1 MB string, a negative price or wrong types. Every `allow update` must call the same `isValidX(request.resource.data)` as create. **High.**
- **Ownership not pinned:**
  - Create must require `request.resource.data.ownerId == request.auth.uid`.
  - Update must keep `ownerId`, `shopId` and `createdAt` unchanged.
  - Access fields (`members`, `role`, `editors`) must be locked for non-owners:
    ```
    !request.resource.data.diff(resource.data).affectedKeys().hasAny(['members','role'])
    ```
  **Critical.**
- **`affectedKeys().hasOnly([...])` without an owner check:** it limits *which* fields change, not *who* changes them. Grep `hasOnly(`. **High.**
- **Multi-shop data:** every `shops/{shopId}/...` path must check membership (a claim, or `exists(/databases/$(database)/documents/shops/$(shopId)/members/$(request.auth.uid))`), and members must not be able to write the members list. **Critical.**
- **Subcollections don't inherit rules.** Map every `collection(`/`doc(` path in the code to a `match` and confirm each one. **High.**
- **Listing and enumeration:** a loose `allow list` lets anyone query a whole collection, and `allow get: if true` with guessable IDs (phone numbers, invoice numbers) allows enumeration. **Medium-High.**
- **PII in readable documents:** rules cover whole documents, so a `users` doc other users can read leaks its phone and email. Split it into `users_public`/`users_private`. **Medium.**
- **Money and quantity unchecked:** no range checks (`price >= 0`, `qty > 0`) means negative totals and refund tricks. **High** in a POS.
- **Client-set timestamps:** require `request.resource.data.createdAt == request.time` (the client sends `serverTimestamp()`), or sales can be back-dated. **Medium.**
- **Status jumps:** allow only listed transitions (`open → paid`, never `paid → open` from a client) and check enums with `in [...]`. **High** for orders and invoices.
- **Schema checks missing:** `keys().hasOnly([...])` plus `hasAll([...])`, type checks (`is string|int|number|bool|timestamp|list|map`), and `.size()` bounds on strings and lists. **Low-Medium** (abuse, cost).
- **Hardcoded admin email** (`request.auth.token.email == '...'`) is acceptable only together with `request.auth.token.email_verified == true`. Without it: **High**, and **Critical** if anyone can still register that address (for example, the owner signs in with Google while email/password sign-up is open).
- **Regexes in rules** need doubled backslashes (`\\d`); a single backslash silently breaks validation.
- **Rules so strict the app can't work** get "fixed" later by opening everything. Flag them: **Low** now, High later.

**Storage rules:** the common `allow read, write: if request.auth != null` lets any user read, overwrite or delete anyone's files (**High**). Target:
```
match /users/{uid}/{file=**} {
  allow read: if request.auth != null && request.auth.uid == uid;
  allow create, update: if request.auth != null && request.auth.uid == uid
    && request.resource.size < 5 * 1024 * 1024
    && request.resource.contentType.matches('image/.*');
  allow delete: if request.auth != null && request.auth.uid == uid;
}
```
Keep `delete` separate: `request.resource` is null on delete, so a size check under `allow write` stops users deleting their own files, and owners then "fix" it by loosening the rule.

**Realtime Database (`database.rules.json`):** `".read": true`, `".write": true` or `"auth != null"` near the root. A grant on a parent path can't be revoked by a child rule. **Critical.**

**Auth and server code:**
- **`firebase-admin` bypasses all rules**, exactly like Supabase's service role. Every `onRequest`/`onCall` function or server route using it must:
  - verify the caller: `request.auth` in v2 callables, `verifyIdToken()` for HTTP
  - check ownership or role

  Grep `firebase-admin|onRequest\(|onCall\(`. **Critical** if missing.
- **Roles belong in custom claims** (`setCustomUserClaims`), not in user-writable docs. Clients see new claims after the next token refresh (up to an hour) or `getIdToken(true)`.
- **Config the client can read is public:** keys in Firebase Remote Config, or in a Firestore `config` document any signed-in user can read. **Critical** for billable keys.
- **Removed staff keep access** until their ID token expires (about an hour). Use `revokeRefreshTokens(uid)`, plus `verifyIdToken(token, true)` on sensitive operations. **Medium.**
- **Email-based checks need `email_verified`.** Also flag account enumeration messages ("no account with this email") and `localhost` left in authorized domains. **Low-Medium.**
- **Cost abuse:**
  - Blaze budgets only alert; they don't cap spending.
  - Look for App Check enforcement (`enforceAppCheck: true` on callables, enforcement on Firestore and Storage).
  - Look for SMS region limits if phone auth is on.

  Report these as "needs confirmation in console". **Medium.**
- **Unbounded client queries cost money.** Rules can cap them: `allow list: if request.query.limit <= 100 && ...`. **Medium.**

## 3. Supabase and Postgres

The publishable key (`sb_publishable_…`, or the legacy anon JWT) is public by design. Security is RLS, grants, and what server code does with the secret key. A `sb_secret_…` key, or the legacy service_role JWT, outside server code is **Critical**.

- **Tables without RLS:** compare `create table` vs `enable row level security` in `supabase/migrations/`. With DB access: `select tablename from pg_tables where schemaname='public' and not rowsecurity;` and `supabase db advisors --remote --type security` (CLI 2.81+; without `--remote` it checks the local database, and older CLIs spell it `--linked`). **Critical.**
- **`user_metadata` / `raw_user_meta_data` in policies or authorization code:** users can edit it themselves (`auth.updateUser({ data: {...} })`). Use `app_metadata`. **Critical.**
- **Loose policies:**
  - `using (true)`
  - `auth.uid() is not null`
  - `to authenticated` with no ownership predicate (anonymous sign-ins also get `authenticated`)
  - the deprecated `auth.role()`

  Grep `using\s*\(\s*true|is not null\)|auth\.role\(\)`. **Critical/High.**
- **Update/insert policies without `with check`:** users can reassign `user_id` to someone else. **High.**
- **Privileged columns users can update** (`is_admin`, `credits`, `plan`, `role`): fix with column grants, e.g. `revoke update on profiles from authenticated; grant update (display_name, avatar_url) on profiles to authenticated;`, or move them to a private table. **Critical.**
- **Views without `security_invoker = true`** (Postgres 15+) run as the owner and skip RLS. **Critical** if in an exposed schema.
- **`security definer` functions in `public`** are callable by anon through `/rest/v1/rpc/<name>`, because EXECUTE goes to PUBLIC by default. They need:
  - a private schema
  - `set search_path = ''`
  - an `auth.uid()` check inside
  - `revoke execute ... from public, anon, authenticated` where appropriate

  **Critical.** Definer added "to fix a permission error" is a red flag.

  Functions that `returns trigger`, such as Supabase's documented `handle_new_user()`, aren't callable through `/rpc`. For those, check only `set search_path = ''` and what they copy. Copying `full_name` from user metadata is fine; copying `role`, `shop_id` or `plan` is **Critical**.
- **Edge Functions with `verify_jwt = false`** (in `supabase/config.toml`, or deployed with `--no-verify-jwt`) are public, so each must check the caller itself. **High** if it doesn't.
- **Dynamic SQL in plpgsql** (`execute '...' || param`): needs `format('%I', ...)`/`%L` or `execute ... using`. **High** (Critical inside security definer).
- **PostgREST filter strings built from input** (`.or('name.ilike.%' + q + '%')`) let input inject extra filter clauses. Use the typed filter methods. **Medium.**
- **Storage:**
  - `public = true` buckets holding receipts, IDs or prescriptions. **High.**
  - No `storage.objects` policies per bucket.
  - Per-user paths not enforced (`(storage.foldername(name))[1] = (select auth.uid())::text`).
  - No `allowed_mime_types` / `file_size_limit` on the bucket.
- **Server code trusting `auth.getSession()`:** it isn't revalidated against the auth server. Use `getUser()` or `getClaims()`. **High.**
- **ORMs (Prisma, Drizzle) connecting as the owner `postgres` role or with the service role bypass RLS entirely,** so authorization must live in code. Check that it does. **High.**
- **Deleted users' access tokens stay valid** until expiry. For sensitive operations, check the session and keep JWT expiry short. **Medium.**
- **A full-access Supabase personal access token** in `.mcp.json` or CI: replace it with a scoped token. **Medium.**
- **Performance smell (report as Low/Medium):** policies calling `auth.uid()` without the `(select auth.uid())` wrapper, and unindexed columns used in policies.

## 4. Authentication and authorization (all stacks)

- **Inventory every entry point** (routes, controllers, functions, callables, RPC functions, Server Actions, GraphQL resolvers, queue consumers, admin tools) and fill in for each: who can call it, what it reads and writes, what check stops a stranger. An endpoint missing from the inventory is an endpoint you didn't check (`workflow.md` §2).
- **Framework defaults that open endpoints:** Django REST Framework views with `AllowAny` (or no global `DEFAULT_PERMISSION_CLASSES`), missing `@login_required`/`LoginRequiredMixin`; Rails controllers with `skip_before_action :authenticate_user!`; Laravel routes outside the `auth` middleware group; Spring Security `permitAll()` or `csrf().disable()` on broad matchers; ASP.NET `[AllowAnonymous]` or no fallback authorization policy; Express or Fastify routes registered before the auth middleware; Go handlers not wrapped by the auth middleware. **High-Critical** depending on what they expose.
- **Object-level authorization (IDOR/BOLA):** any lookup by an ID from params, query or body must also be scoped to the caller or tenant (`where: { id, userId: session.user.id }`, `.eq('id', id).eq('user_id', uid)`, `current_user.orders.find(id)`, `get_object_or_404(..., owner=request.user)`, or rules/RLS you've confirmed). Grep `params\.id|searchParams\.get\(|req\.(params|query|body)\.\w*[iI]d\b|\.doc\(|objects\.get\(|\.find\(params\[|findById\(|FindAsync\(` and read the query that follows. **High-Critical.**
  - Give the owner a two-account test: user B asks for user A's object in the emulator or staging. It's a leak only if B actually gets A's data; a 200 alone proves nothing.
- **Function-level authorization:** admin routes, callables and RPCs need a role check from a trusted source (custom claims, `app_metadata`, a server-side table), never from the request body. **High.**
- **Mass assignment:** `data: req.body`, `{...body}`, `Object.assign(row, body)`, `.update/.insert/.set` called straight on the input, `Model(**request.data)`, `params.permit!`, Laravel models with `$guarded = []`, binding request bodies straight onto JPA or EF entities. Users can then set `role`, `price` or `ownerId`. Validate against a schema, then copy only allowed fields. **High.**
- **ORM operator injection:** `findFirst({ where: req.body })` lets `{"email":{"contains":""}}` match every row. **High.**
- **Over-exposure:** whole rows returned to clients (password hashes, reset tokens, admin flags, other users' phones). Use explicit `select`; in Next.js, mark data modules `server-only`. **Medium-High.**
- **JWT handling:** `jwt.decode(` used for trust instead of `verify` with pinned algorithms, issuer, audience and expiry. **Critical.**
- **Fail-open error handling:** a `catch` in an auth, permission or payment check that returns true, calls `next()`, or treats "lookup failed" as allowed. Read every `catch` in `requireUser/isAdmin/authorize/middleware`. **High.**
- **Shared static keys as auth** (`if (req.headers['x-admin-key'] === '...')`), especially when the same key ships in a mobile app. That's **Critical**: anyone can unzip the app and read the key.

## 5. Money, business logic and races

- **Client-supplied prices, totals, discounts, credits, plan or status:** look up prices on the server (Stripe Price IDs: `line_items: [{ price: product.stripePriceId, quantity }]`). Grep `unit_amount|amount:|total` near `body`. **Critical.**
- **Checkout metadata** (`metadata`, `client_reference_id`, user id, plan) must come from the server session, not the request body. **High.**
- **Paid status set by the client, or by a redirect page:** only a server-verified callback may mark something paid. **Critical.** This holds for every gateway. ZainCash, FIB, FastPay and Qi Card callbacks are webhooks too: verify their JWT or signature with the merchant secret on the server, and re-query the transaction status before fulfilling.
- **Workflow skipping:** "complete order", "mark paid" or "activate plan" callable without the earlier step. Verify state transitions on the server. **High.**
- **Check-then-act races** on stock, balances, coupons, first-order discounts and refunds. Use one guarded statement:
  - SQL: `update products set stock = stock - $1 where id = $2 and stock >= $1 returning *`
  - unique constraints with `on conflict do nothing`
  - Firestore: `runTransaction`, or `FieldValue.increment()`

  Detect a read followed by a separate write of a computed value. **High.**
- **POS records editable by cashiers:** if the client writes sales, invoices or stock moves directly, they must be append-only (`allow update, delete: if false`). Voids and refunds become new documents carrying `byUid == request.auth.uid`. Totals are re-verified server-side, and audit fields are locked. **High.**
- **Offline POS:** Firestore transactions fail without a connection, so offline sales can oversell. The design needs stock-movement records reconciled on the server, not client-side read-modify-write. **High** if the app sells offline.
- **Idempotency:** retried requests and double taps must not create duplicate sales or charges. Look for client-generated IDs (`doc(saleUuid).set()`, not `.add()`) and unique constraints. **Medium-High.**

## 6. Webhooks and callbacks

- **No signature verification** (Stripe `constructEvent`, Svix/Clerk `verify`, HMAC with `timingSafeEqual`, the gateway's JWT verified with `jwt.verify`/`jose`). Reading the `stripe-signature` header into a variable doesn't count. **Critical** for payment and auth events.
- **HMAC computed over parsed-then-reserialized JSON** instead of the raw body silently breaks verification. Stripe in Express needs `express.raw({ type: 'application/json' })` on that route, mounted before any global `express.json()`.
- **No timestamp tolerance:** replay exposure. **Medium.**
- **Not idempotent:** providers retry, so store `event.id` under a unique constraint before acting. **Medium.**
- **Secrets logged or echoed in error responses.** **Medium.**
- **Async work not awaited before responding** (`forEach(async ...)`, fire-and-forget writes): serverless platforms can freeze the function right after the response, losing writes. **Medium.**

## 7. Paid APIs, rate limits and LLM features

- **Rate limits are needed on:** login, sign-up, password reset, OTP and magic links, email and SMS sends, AI calls, uploads and conversions, public webhooks. **High** on auth/AI/SMS, Medium elsewhere.
- **In-memory limiters** (the default `express-rate-limit` store, a module-level `Map`) don't work on serverless or across instances. They need a shared store (Redis, Upstash). **Medium-High.**
- **Limit keys:** key on IP and user together. Take the IP from the platform header (Netlify `x-nf-client-connection-ip`), not the first `x-forwarded-for` hop, which the client can forge. **Medium.**
- **Counters and quotas** stored where the user can write them (their own Firestore doc, a `public` Supabase table) can be reset by the user. **High.**
- **Short codes** (4-6 digit OTP or PIN) need attempt limits, expiry, single use and a cryptographic RNG. `Math.random()` codes are predictable. **High.**
- **LLM endpoints:**
  - Auth plus per-user quotas, with hard provider spend caps on top. **High** if a public AI feature has neither.
  - Max tokens set per request, and agent loops capped.
  - User input concatenated into system prompts: prompt injection. **Medium-High.**
  - Model output is untrusted: never `innerHTML`, `eval`, SQL, a shell or file paths. Parse it, validate against a schema, map to allowlisted actions. **High.**
  - Tool calls that write data, send messages or spend money need a human approval step. **High.**
  - RAG over multiple tenants needs per-tenant partitioning (RLS on the vectors table). **High.**
  - Keep secrets, other tenants' data and the full system prompt out of the model context; assume the system prompt leaks.
  - Calling the provider directly from the client ships the key. **Critical.**
  - Exception: **Firebase AI Logic** (`firebase/ai`, `firebase_ai`) calls Gemini from the client by design, through Firebase's proxy, so no Gemini key ships. Check its guards instead: App Check enforced with limited-use tokens, sign-in required, per-user rate limits, budget alerts. Missing App Check is **High** (anyone with the public config can spend the quota); confirm the rest in the console.

## 8. Injection, XSS, SSRF, uploads, paths

- **SQL built from strings:** JS template literals into `query()`, `$queryRawUnsafe`/`$executeRawUnsafe`; Python f-strings or `%` into `cursor.execute`, Django `.raw()`/`.extra()` with interpolation; Java `Statement` with `+`; C# `SqlCommand` with concatenation or `FromSqlRaw($"...")`; Go `fmt.Sprintf` into `db.Query`; PHP `mysqli_query`/`PDO::query` with concatenation; Ruby `where("name = '#{...}'")`; Dart `rawQuery/rawInsert/execute` with `$var`. Use placeholders. **High** server-side. For local SQLite, **Medium**, rising if input comes from sync, import, QR or barcode scans.
- **Unsafe deserialization and code execution:** Python `pickle.loads`, `yaml.load` without `SafeLoader`, `eval`/`exec`; Java `ObjectInputStream`, unsafe Jackson polymorphic typing, XStream; .NET `BinaryFormatter`, `TypeNameHandling.All`; PHP `unserialize`, `include`/`require` with user input; Ruby `Marshal.load`, `YAML.load` on untrusted data, `send`/`constantize` with user input; JS prototype pollution through deep-merge helpers on request bodies. **Critical** on untrusted input.
- **Template injection:** user input rendered *as* a template (`render_template_string(user_input)`, Twig or Freemarker templates built from strings). **Critical.**
- **XXE:** XML parsers with external entities or DTDs enabled on uploaded or posted XML. **High.**
- **XSS sinks:**
  - `dangerouslySetInnerHTML`, `.innerHTML =`, `insertAdjacentHTML`, `document.write`
  - `eval(`, `new Function(`
  - markdown rendered with raw HTML (`rehype-raw`)
  - user URLs in `href`/`src` without a scheme check (`javascript:`)
  - WebViews fed user HTML (`loadHtmlString`, `runJavaScript`)

  Fix: render as text, or sanitize with DOMPurify using a tight allowlist. **High.** **Critical** where staff or admins will view the content: in a Firebase web app, auth state sits in IndexedDB where any script can read it, so XSS means account takeover.
- **SSRF:** server code fetching a URL the user influences (import-from-URL, image proxies, link previews, URL-to-PDF, webhook targets, AI browse tools). Fix:
  - https only
  - a host allowlist
  - resolve DNS and reject private, loopback and link-local addresses (cloud metadata lives at `169.254.169.254`)
  - `redirect: 'error'`

  **High.**
- **Uploads:**
  - Allowlist MIME types, cap the size, and check magic bytes where it matters; the extension proves nothing.
  - SVG or HTML served from your own origin is stored XSS.
  - The storage path must not come from the user's filename.
  - `upsert: true` lets users overwrite each other's files when paths collide.

  **Medium-High.**
- **Path traversal:** `path.join(dir, input)` passed to `readFile/unlink/createReadStream/sendFile`. Resolve with `realpath` first, then require the path to be under an allowlisted root and owned by the caller. **High.**
- **Shell:** input inside a command string: Node `exec(`, `execSync(`, `spawn(..., { shell: true })`; Python `os.system`, `subprocess` with `shell=True`; Java `Runtime.exec(String)`; C# `Process.Start("cmd", "/c " + input)`; Go `exec.Command("sh", "-c", ...)`; PHP `exec`/`system`/`shell_exec`/backticks; Ruby `system`/backticks with interpolation. **Critical.**
- **HTML escaping turned off in server templates:** `|safe`, `mark_safe`, `{% autoescape off %}`, `raw`/`html_safe`, `{!! !!}`, `Html.Raw`, Go `text/template` used for HTML or `template.HTML(...)` on user input. **High.**

## 9. Sessions, cookies, CSRF, redirects, account flows

- **Cookies:** `HttpOnly; Secure; SameSite=Lax` (Strict can break OAuth returns), with a bounded `Max-Age`. Flag `sameSite: 'none'` or missing flags in `cookies().set(`, `res.cookie(` and `Set-Cookie`. **Medium.**
- **Tokens in `localStorage`** (`localStorage.setItem(...token...)`): **Medium**, High if any XSS exists.
- **CSRF protection switched off:** Django `@csrf_exempt`, Rails `skip_forgery_protection`/`protect_from_forgery with: :null_session` on cookie sessions, Laravel `$except` lists in the CSRF middleware, Spring `csrf().disable()`, ASP.NET `[IgnoreAntiforgeryToken]`. **High** on cookie-authenticated state changes.
- **CSRF** matters only for cookie-authenticated state changes. Bearer tokens (Firebase ID tokens) aren't sent automatically by the browser. Cookie auth needs SameSite plus a CSRF token or an Origin check. **Medium-High.** Next.js Server Actions already accept only POST and compare Origin with Host, so flag only a wide `serverActions.allowedOrigins`. Cookie-authenticated POST, PUT and DELETE handlers in `route.ts` need their own Origin check.
- **CORS:** browsers refuse `*` together with credentials, so that combination can't happen. What matters:
  - a reflected origin (`origin: true`, echoing `req.headers.origin`, an unanchored regex) with `credentials: true`: **High**
  - `*` without credentials: **Low** on public or bearer-token APIs; for cookie auth the risk is CSRF (above)
- **Password reset:** the token must be random, single-use and expire within about an hour, and be invalidated on password change. The response must be the same whether or not the email exists, and the endpoint rate-limited. **High** if tokens are reusable or long-lived.
- **Email-keyed rules or policies** (`auth.jwt()->>'email'`, `token.email`) without `email_verified` / with email confirmation off can be spoofed. **High.**
- **Open redirects:** `redirect(searchParams.get('next'))`, `router.push(returnTo)`, `window.location = param`. Allow only relative paths starting with a single `/`, or allowlisted hosts. Watch `origin + next` with `next = "@evil.com"`. **Medium** (High inside OAuth or magic-link flows).
- **Subscription and plan checks** must read the webhook-synced DB on each request, not a claim set at login or a client flag. **Medium-High.**

## 10. Next.js specifics

- **Server Actions are public POST endpoints.** Every export in a `'use server'` file needs input validation, authentication and an ownership check at the top. Grep `use server`. **High** (Critical with the service role).
- **Middleware-only auth:**
  - Middleware matchers miss paths; `/api/admin` isn't covered by a matcher for `/admin`.
  - Middleware is bypassable on unpatched versions (CVE-2025-29927, the `x-middleware-subrequest` header; fixed in 12.3.5 / 13.5.9 / 14.2.25 / 15.2.3).
  - Checking that a cookie *exists* proves nothing.
  - Middleware lives in `middleware.ts`, or in `proxy.ts` from Next 16.

  Re-check auth in every Route Handler, Server Action and data function. **High-Critical.**
- **Known CVEs: compare against the newest security release, not a list in this file.** Next.js shipped security releases in Jan, May, Aug, Sept, Oct and Nov 2026 alone, so any frozen version list goes stale within weeks. Read the exact `next`, `react-server-dom-*` and `sharp` versions from the lockfile (not the `^` range in `package.json`), then check nextjs.org/blog and the GitHub advisories for the current floor. `npm audit` can lag behind them.
  - Snapshot (19 Nov 2026): the floor is **16.4.5** for 16.x and **15.5.29** for 15.x. 13.x and 14.x are end-of-life and get no fixes, so being on them is itself a finding.
  - **Critical** when a known unauthenticated RCE applies: React2Shell (CVE-2025-55182 / CVE-2025-66478) below 15.0.5, 15.1.9, 15.2.6, 15.3.6, 15.4.8, 15.5.7 or 16.0.7; the October 2026 `use cache` RCE below 16.4.1, and the SVG/`sharp` RCE below 16.4.1 or 15.5.28 (15.x also needs `sharp` ≥ 0.35.5, which an old lockfile keeps out).
  - Otherwise rate it by the worst advisory that matches how the app is built (App Router, Server Actions, middleware/proxy, Cache Components, image optimization).
  - After an RCE-class upgrade, rotate secrets: they may already have been read.
- **Module-level mutable variables** in server code that hold request or user data leak between users. **High.**
- **`'use client'` on layouts or pages** sends the whole subtree to the browser. Check that nothing server-only (keys, internal URLs) is imported there.
- **`images.remotePatterns` with `hostname: '**'`** makes the image optimizer an open proxy (cost, abuse). **Low-Medium.**
- **Production source maps** (`productionBrowserSourceMaps`): **Low-Medium**, High if they expose secrets.

## 11. Mobile and desktop apps

- **Everything in the binary is public:**
  - the JS bundle (even as Hermes bytecode)
  - `EXPO_PUBLIC_*` and `app.config.*` `extra` (readable from the manifest)
  - `react-native-config` values
  - Flutter `flutter_dotenv` assets: grep `pubspec.yaml` `assets:` for `.env`
  - `--dart-define`/`String.fromEnvironment` values, compiled into `libapp.so`; `--obfuscate` doesn't hide string literals

  Secret keys must sit behind a backend. **Critical.**
- **Scan the build output too, if one exists,** using the regexes from section 1: run `strings` over an unzipped APK's `lib/arm64-v8a/libapp.so`, the RN `assets/index.android.bundle`, the Windows build's `build/windows/x64/runner/Release/data/app.so` and `data/flutter_assets/` (a bundled `.env` sits there in plain text), and web `build/`/`dist/`/`.next/static`.
- **Signing material committed:** `android/key.properties`, `*.jks`, `*.keystore`, `*.p12`. **High**; **Critical** if the repo is public. The upload key or its password controls app identity and updates. (`embedded.mobileprovision` ships inside every IPA and isn't a secret; the `.p12` is.)
- **Self-updates of sideloaded APKs or Windows EXEs:** they must download over HTTPS from a URL only you control, with signed installers. Otherwise anyone on the shop's network can push a build. **High.**
- **Token storage:** use `flutter_secure_storage`, `expo-secure-store` or the Keychain, not `shared_preferences` or `AsyncStorage`. **Medium.** A stored plaintext password is **High**: passwords should never be stored at all.
- **Cleartext:** `http://` API URLs, `usesCleartextTraffic="true"`, `NSAllowsArbitraryLoads`. **High** for API traffic carrying tokens.
- **Release flags:** `android:debuggable="true"`, verbose logging of sessions or tokens. **Low-Medium.**
- **Deep links** (intent filters, `CFBundleURLSchemes`, router configs): validate every parameter, never put tokens or access-granting IDs in links, and confirm before destructive actions. **Medium.**
- **Biometric gates** that only flip a local boolean can be bypassed on rooted devices. If they protect server actions, the server must verify a signed challenge. **Low-Medium.**
- **On-device SQLite is plaintext** and copyable from rooted phones or backups. For pharmacy or customer data, consider SQLCipher with the key in secure storage, and review `android:allowBackup`. **Medium.**
- **Native Android:** exported activities, services, receivers or providers without permissions; WebViews with JavaScript enabled plus `addJavascriptInterface` on untrusted content; `MODE_WORLD_READABLE` files. **High.**
- **Electron:** `contextIsolation: false`, `nodeIntegration: true`, `sandbox: false` or `webSecurity: false`; a preload that exposes `ipcRenderer` or `require` whole; IPC handlers that act without validating arguments or the sender; `shell.openExternal` with unvalidated URLs; remote content loaded in a window with Node access. **Critical** when remote or user content can reach a privileged window.
- **Tauri:** broad capabilities (filesystem or shell access to all paths), commands that take paths or commands from the front end without validation, no CSP. **High.**
- **Desktop updates and installers:** unsigned installers or update bundles, updates over HTTP, an updater that doesn't verify signatures. **High.**

## 12. Web headers and deployment

- **Baseline headers:**
  - CSP starting from `default-src 'self'`
  - HSTS `max-age=31536000; includeSubDomains`
  - `X-Content-Type-Options: nosniff`
  - `frame-ancestors 'none'` (or `X-Frame-Options: DENY`)
  - `Referrer-Policy: strict-origin-when-cross-origin`
  - a `Permissions-Policy` that disables unused features

  **Medium** for apps with accounts, Low for static brochure sites.
- **Where headers live:** Netlify `_headers` or `[[headers]]` in `netlify.toml`; `hosting.headers` in `firebase.json`; Next `headers()`. **GitHub Pages can't send custom headers;** a meta CSP can't set `frame-ancestors`. Say so rather than demanding impossible headers.
- **CSP quality:** `'unsafe-inline'` or `'unsafe-eval'` in `script-src` makes the CSP close to useless against XSS. **Medium.**
- **Preview and branch deploys** must use test keys (scope env vars per deploy context); anyone with the URL can open them. **Medium.**
- **`"public": "."` in `firebase.json`** publishes the whole project folder, including source, `key.properties` and any service-account JSON. **High.**
- **Live checks** (`curl -sI <url>`, probing `/.git/config` or `/.env`) are requests against production. Do them only with the user's explicit OK, and check the status code only (`curl -s -o /dev/null -w '%{http_code}\n' https://site/.env`). Never print the body, or production secrets land in the transcript.

## 13. Dependencies, supply chain, MCP

- **Known vulnerabilities:** run the ecosystem's audit against the committed lockfile (`npm audit --omit=dev`, `pnpm audit`, `pip-audit`, `govulncheck ./...`, `cargo audit`, `dotnet list package --vulnerable --include-transitive`, `composer audit`, `bundle-audit`); `osv-scanner` covers most lockfiles, `pubspec.lock` included. Triage by reachability (runtime vs dev-only). Never run `npm audit fix --force` or any automatic upgrade as part of an audit.
- **No release cooldown** for new dependency versions (`../build/security.md` §12) and no update bot: **Low**, a hygiene finding, raised to Medium for apps handling money or personal data.
- **Lockfiles:** no lockfile for an application, two lockfiles in one folder, or CI installing without the lockfile (`npm install` instead of `npm ci`, `pip install -r` without hashes or a lock, `cargo build` without `--locked`) means installs aren't reproducible. **Medium.**
- **Typosquats** (one character off a popular name), `postinstall` scripts in unfamiliar packages, and packages with tiny download counts doing security-relevant work.
- **MCP and agent configs** (`.mcp.json`, `.cursor/`, `.vscode/`, `.windsurf/`): these run on the developer's machine, so rate them **Low-Medium** and keep them out of the launch verdict unless they run in CI or ship with the app.
  - A bare package name, `@latest` or any dist-tag is the riskier end.
  - A semver range is weaker; an exact version is OK.
  - A Docker image without `@sha256:` is also the riskier end.
  - Broad scopes (filesystem write, shell, unrestricted network) need a reason.
  - Never run a configured command to "check" it.

## 14. Logging, exposure and privacy

- Logs that include `req.body`, prompts, full LLM responses, sessions, tokens, passwords or personal data. **Medium.**
- Error responses leaking stack traces or raw DB errors. **Low-Medium.**
- `.git`, `.env`, `.DS_Store`, `swagger.json` or source maps reachable on the deployed site (live check only with permission).
- **Privacy:**
  - Classify fields as non-personal, personal or sensitive; prescriptions and health data are sensitive.
  - Sensitive data needs tighter access and audit logging.
  - "Delete account" that only sets a flag is a finding (**Medium**).
  - Personal data sent to analytics, crash reporting or LLM vendors needs a reason.

## 15. What the repo can't show

Always list these under "couldn't check", with the place to confirm each:
- Deployed Firestore/Storage rules (if missing or stale in the repo)
- Supabase dashboard auth settings: email confirmation, sign-up enabled, JWT expiry
- Firebase console: sign-up providers, anonymous auth, App Check enforcement, API key restrictions, budgets
- Stripe dashboard: webhook endpoints and signing secrets
- Hosting env vars per deploy context
- Cloud consoles: IAM roles, bucket and database exposure, firewall rules, secret-manager access
- App store and signing settings: Play App Signing, App Store Connect roles, code-signing certificates
- Logging and alerting (never visible from code)

## 16. Containers, CI, infrastructure and other kinds of software

**Containers:**
- Images running as root (no `USER`), secrets in `ENV`/`ARG` or copied files (they stay in image layers), `latest` base images, `COPY . .` without a `.dockerignore` (ships `.env` and `.git`). **Medium-High.**
- `docker-compose.yml` publishing databases on `0.0.0.0` with default passwords. **High** if the host is reachable.

**CI/CD (`.github/workflows/` and others):**
- `pull_request_target` or `workflow_run` combined with checking out and running PR code: secrets exposed to forks. **Critical.**
- `${{ github.event.* }}` (titles, branch names, comments) interpolated directly into `run:` steps: command injection. **High.**
- Third-party actions not pinned to a commit SHA, `permissions: write-all` or missing `permissions`, production secrets available to PR jobs. **Medium.**
- Self-hosted runners on public repositories. **High.**

**Infrastructure as code and cloud config:**
- Public buckets, security groups or firewall rules open to `0.0.0.0/0` on database or admin ports, wildcard IAM policies (`"Action": "*"`), unencrypted databases or backups, `terraform.tfstate` committed. **High-Critical.**
- Kubernetes: privileged containers, `hostPath` mounts, secrets in plain manifests, no resource limits, the default service account with broad permissions. **Medium-High.**

**CLIs, scripts and bots:** secrets passed as flags or printed in logs, `shell=True`-style command building, scheduled jobs running with admin credentials, webhooks and chat bots without signature or sender checks (`../platforms/cli-scripts-automation.md`). **Medium-High.**

**Data and ML:** notebooks committed with outputs containing personal data or keys, pipelines with credentials in code, models or datasets loaded from untrusted sources with `pickle` (including `torch.load` on untrusted files), LLM features without the guards in section 7. **Medium-Critical.**

**Embedded and IoT:** one credential shared by every device and compiled into firmware, unsigned or unverified OTA updates, debug ports (JTAG, UART shells) open in production, no TLS to the server, default passwords. **High-Critical.**

**Browser extensions:** `<all_urls>` or broad host permissions without need, remote code loading, page content inserted as HTML into extension pages, unvalidated messages from content scripts or `externally_connectable` origins. **Medium-High.**

**Libraries and packages:** registry accounts without two-factor authentication, publishing from a laptop instead of CI with provenance, install scripts that download code. **Medium.**
