# Building it secure: the patterns to use

Read this when touching auth, access rules, secrets, input handling, dependencies, payments, uploads, rate limits or LLM features, in any language. SKILL.md "Security" has the short version. This file says how to build it right. To *audit* an existing app, use Audit mode; `references/audit/security.md` lists what goes wrong and how to find it.

## Contents
1. Secrets
2. Authentication
3. The authorization pattern (every endpoint)
4. Firestore and Storage rules that hold
5. Supabase RLS that holds
6. Input handling
7. Payments
8. Uploads and files
9. Rate limits and cost control
10. LLM features
11. Web hardening
12. Dependencies and supply chain
13. Before calling a security-sensitive change done

---

## 1. Secrets

- **Server-side only.** API keys, service-role keys, payment secret keys, SMTP/SMS credentials, signing keys and database URLs live in server env vars or a secret manager (the platform's secret store, Vault, a cloud secret manager, Doppler, 1Password).
- **Anything a client can see is public:**
  - Web build-time variables: `NEXT_PUBLIC_`, `VITE_`, `REACT_APP_`, `EXPO_PUBLIC_`, Nuxt `runtimeConfig.public`, SvelteKit `$env/*/public`.
  - Mobile and desktop builds: Expo `extra`, Flutter `--dart-define` values, Android `BuildConfig` and resources, iOS `Info.plist`, bundled `.env` or config files, Electron and Tauri app bundles.
  - The JS bundle, the APK or IPA, the desktop installer, firmware images and container images pushed to a public registry.

  A paid or privileged key belongs behind a server endpoint (a serverless function or route handler) that checks the caller.
- **Public by design (not secrets):** the Firebase client config `apiKey`, the Supabase anon key, the Stripe publishable key, and Maps client keys. Restrict them (HTTP referrers, app package + SHA-1, quotas) and rely on rules and RLS for security.
- **If you're about to type a literal secret into a file, stop** and use an env var plus `.env.example` instead.
- **If a secret ever reached git or a client bundle, rotate it first,** then remove it. Deleting the line doesn't un-leak it.
- **Run a secret scan in pre-commit** (`git-and-tooling.md` §4), with redaction on.

**Keep secrets out of the agent's own context.** Anything an AI agent reads can end up in a transcript, a log, a summary or a commit message.
- Don't open, print or grep real `.env` files, keystores, private keys or credential files. Read `.env.example` for variable names, and ask the user for a value's shape (not the value) when needed.
- Don't run commands that dump secrets: `env`/`printenv`, `heroku config`, `gh auth token`, secret-manager reads, `kubectl get secret -o yaml`.
- When a task needs a secret at runtime (a test against a sandbox API), the user puts it in `.env` or the shell environment themselves; the code reads it from the environment.
- Mask any secret you must mention: the key-type prefix and the length only (`sk_live_…(107 chars)`).
- In Claude Code, `Read` deny rules and the guard hook back this up (`git-and-tooling.md` §3).

## 2. Authentication

- **Use the platform's or framework's auth:** Firebase Auth, Supabase Auth, Clerk, Auth.js or Better Auth, Django's auth, Devise, Laravel's starter kits, ASP.NET Core Identity, Spring Security, or an identity provider (Keycloak, Auth0, Entra ID, Cognito). Never invent your own password storage, session crypto or token format. If you must store passwords, use argon2id or bcrypt, never a fast hash.
- **Native and desktop apps signing in through a provider** use OAuth 2.0 / OIDC with PKCE in the system browser, never an embedded web view collecting passwords.
- **Machine clients** (scripts, partner integrations) get scoped, revocable API tokens stored hashed on the server, never a user's password or a shared static key.
- **Admins and staff with powerful roles** get multi-factor authentication.
- **Web sessions:** `HttpOnly; Secure; SameSite=Lax` cookies with a bounded lifetime. Don't put tokens in `localStorage`.
- **Mobile and desktop:** let the SDK manage the session, and keep any extra tokens or PINs in the OS's secure storage (`../platforms/mobile.md` §2, `../platforms/desktop.md` §2).
- **Staff-only apps** (a shop's POS) disable public sign-up. With Firebase, the public API key lets anyone create an account through the Auth REST API, so "signed in" must never mean "allowed".
- **Anonymous auth** passes `request.auth != null`, so exclude it wherever access matters.
- **Roles come from trusted sources only:**
  - Firebase custom claims (`setCustomUserClaims`, from a server).
  - Supabase `app_metadata`, or a server-side roles table.
  - Never the request body, a user-editable document, or Supabase `user_metadata`, which users can edit themselves.
- **Email:**
  - Require `email_verified` for anything keyed on email.
  - Login and reset flows give the same response whether or not the account exists.
  - Reset tokens are random, single-use and expire within about an hour.
- **Removing staff:** revoke their sessions (`revokeRefreshTokens(uid)` in Firebase) and check revocation on sensitive server calls.

## 3. The authorization pattern (every endpoint)

Every route handler, controller action, serverless function, callable, Server Action, GraphQL resolver, RPC method, queue consumer and privileged CLI command follows the same order:
1. **Authenticate:** verify the token or session on the server (`verifyIdToken`, `getUser()`/`getClaims()` in Supabase server code rather than just `getSession()`, the framework's authentication middleware).
2. **Validate the input** against a schema (`architecture-and-data.md` §2 lists one per language). Copy only allowed fields; never pass the request body straight into a write (mass assignment).
3. **Load the object and check ownership or role:** `where id = ? and user_id = ?`, a membership check, or the framework's idiom (`current_user.orders.find(id)` in Rails, `get_object_or_404(Order, pk=id, owner=request.user)` in Django, a policy or authorization handler in Laravel, ASP.NET Core and Spring). This is the IDOR defence, and it's the check AI-written code skips most often.
4. **Act**, recomputing anything sensitive (prices, totals, permissions) on the server.
5. **Return only the fields the caller needs** (explicit `select`, no whole rows with hashes or internal flags).

Put steps 1-3 in one shared helper (`requireUser()`, `requireShopMember(shopId)`) so no endpoint can forget them. Remember:
- Admin credentials (`firebase-admin`, the Supabase service role, a superuser database connection) **bypass all rules**, so code using them must do this check itself.
- Middleware alone (renamed `proxy.ts` in Next 16) is not authorization; every handler checks again.
- A shared static "admin key" in a header is not auth, especially if the same key ships in an app.

**Prove it with a two-account test:** user B tries to read and modify user A's objects through every endpoint, and gets 403/404.

## 4. Firestore and Storage rules that hold

- **Deny by default.** Never use console test mode, and never a `match /{document=**}` catch-all with a loose `allow`; rules OR together, so one loose match beats every strict one.
- **Document the data model** in a comment at the top of `firestore.rules`.
- **Use helper functions:**
  ```
  function signedIn() { return request.auth != null
      && request.auth.token.firebase.sign_in_provider != 'anonymous'; }
  function isMember(shopId) { return signedIn() && request.auth.token.shopId == shopId; }
  function isRole(r) { return signedIn() && request.auth.token.role == r; }
  function unchanged(f) { return request.resource.data[f] == resource.data[f]; }
  ```
- **One validator per collection, called by both `create` and `update`:**
  - field allowlist: `keys().hasOnly([...])` plus `hasAll([...])`
  - types: `is string`, `is int`, `is timestamp`
  - `.size()` limits on strings and lists
  - ranges: `price >= 0`, `qty > 0`
  - enums with `in [...]`
- **Ownership and immutability:**
  - Create pins `ownerId == request.auth.uid` (or the shop ID from the claim).
  - Update keeps `ownerId`, `shopId` and `createdAt` unchanged.
  - Fields that grant access (`role`, `members`) can't be edited by the user they protect.
- **Server time:** `createdAt == request.time`, with the client sending `serverTimestamp()`.
- **Status transitions are listed explicitly** (`open → paid`, never `paid → open` from a client).
- **Sales, payments and stock movements are append-only:** `allow update, delete: if false`. Corrections are new documents.
- **Subcollections need their own `match`** blocks; they don't inherit rules.
- **Personal data** goes in documents only their owner can read.
- **Regex in rules needs doubled backslashes** (`\\d`).
- **Storage:**
  - Per-user or per-shop paths: `match /shops/{shopId}/{file=**}` checked with `isMember(shopId)`.
  - `request.resource.size` limits and `contentType.matches('image/.*')`.
- **Test rules in the emulator** with `@firebase/rules-unit-testing` (`assertFails` / `assertSucceeds`) against the attacks:
  - another user's or shop's data
  - self-granted role
  - update that skips validation
  - a 1 MB string
  - negative price
  - illegal status jump

  Run the tests in CI: `firebase emulators:exec --only firestore "npm test"`.
- **Deploy with `--only firestore:rules`** (or `storage`), never a bare `firebase deploy`.

## 5. Supabase RLS that holds

- **`enable row level security` on every table in an exposed schema**, in the same migration that creates it.
- **Policies:**
  - Use `(select auth.uid())`, not bare `auth.uid()`, which is re-evaluated per row.
  - Index the columns policies filter on.
  - Every `update` and `insert` policy has `with check`, or users can reassign `user_id`.
  - Scope roles explicitly (`to authenticated`), and remember anonymous sign-ins also get `authenticated`.
  - Never `using (true)` on private data.
- **Roles from `app_metadata`** (`(select auth.jwt()) -> 'app_metadata' ->> 'role'`), never `user_metadata`.
- **Privileged columns:** column-level grants (`revoke update on profiles from authenticated; grant update (display_name, avatar_url) on profiles to authenticated;`), or move them to a separate table users can't write.
- **Helper functions** used in policies:
  - Put them in a private schema as `security definer` with `set search_path = ''`.
  - They check `auth.uid()` inside, and you revoke execute from roles that shouldn't call them.
  - Don't add `security definer` to silence a permission error.
- **Views:** `with (security_invoker = true)`.
- **UPDATE also needs a matching SELECT policy,** or it silently updates zero rows.
- **Storage:**
  - Private buckets plus signed URLs for receipts, IDs and prescriptions.
  - `storage.objects` policies per bucket using `(storage.foldername(name))[1] = (select auth.uid())::text`.
  - Set `allowed_mime_types` and `file_size_limit` on the bucket.
- **Server code:** verify users with `getUser()`/`getClaims()`. Keep the service-role client in server-only modules, and do the authorization check yourself there.
- **Test it:** run `supabase db advisors` (or the dashboard advisors) before committing migrations; in CI add `--fail-on error`, because it exits 0 on findings by default. Test policies as two different users (pgTAP via `supabase test db`, or integration tests with two sessions).

## 6. Input handling

- **Validate at every boundary** with a schema and reject unknown fields.
- **SQL:** placeholders always (`?` or `$1` with arguments, an ORM's parameter binding, tagged templates from a safe driver), including local SQLite: `rawQuery('... WHERE name LIKE ?', ['%$q%'])`. Never build SQL with string interpolation, f-strings, `+` or `String.format`; dynamic column or table names come from an allowlist.
- **HTML:** render user content as text. If rich text is truly needed, sanitize with a maintained sanitizer (DOMPurify, bleach's successors such as nh3, HtmlSanitizer) using a tight allowlist. Every raw-HTML escape hatch is a review item: `dangerouslySetInnerHTML`, `innerHTML`, `v-html`, `{@html}`, `|safe`, `raw`, `{!! !!}`, `Html.Raw` (`../platforms/web.md` §13).
- **Templates:** never render user input *as* a template (server-side template injection in Jinja, Twig, ERB, Freemarker and others); pass it as data.
- **Deserialization:** never deserialize untrusted data with formats that can create arbitrary objects: Python `pickle` and `yaml.load` (use `yaml.safe_load`), Java `ObjectInputStream`, .NET `BinaryFormatter`, PHP `unserialize`, Ruby `Marshal.load` and unsafe YAML loading. Use JSON with a schema.
- **XML:** disable external entities and DTDs in XML parsers (XXE).
- **Regular expressions on user input:** avoid nested quantifiers that backtrack catastrophically (ReDoS), or use a linear-time engine (RE2), and cap input length.
- **Links:** user-supplied URLs get a scheme check (`https:` only) before going into `href`/`src`.
- **Redirects:** allow only relative paths starting with a single `/`, or allowlisted hosts.
- **Server-side fetches of user URLs** (SSRF): use a host allowlist, https only, block private and link-local IPs, and `redirect: 'error'`.
- **File paths:** never build them from user input. Generate IDs for storage keys; when a user-chosen name is unavoidable, normalize it and check the resolved path stays inside the intended folder.
- **Shell commands:** never interpolate input into a command string. Pass argument lists (`subprocess.run([...])` without `shell=True`, `execFile`/`spawn` without a shell, `exec.Command`, `ProcessBuilder`, `Process.Start` with `ArgumentList`).
- **Normalize Arabic-Indic digits** before numeric validation (`../concerns/localization-and-rtl.md` §4).

## 7. Payments

Use the gateway's hosted payment page or SDK, chosen with the user for the country and currency (`../concerns/money-and-business-rules.md` §8). Stripe doesn't serve merchants in Iraq; local clients use the gateway they bank with (FIB, ZainCash, FastPay, or a local aggregator). The rules hold for any gateway:
- The server sets the amount.
- Only a server-side check marks an order paid: a verified signature or JWT on the callback, or re-querying the gateway's status API.
- Callbacks are deduped by transaction ID.

The Stripe specifics below translate to whichever gateway you use.

- **Prices come from your server or Stripe Price IDs,** never from the client (`line_items: [{ price: product.stripePriceId, quantity }]`). Recompute totals, discounts and tax on the server.
- **Only a verified webhook marks an order paid,** never the success redirect page or the client.
  - Verify the signature on the **raw** body (Express: `express.raw({ type: 'application/json' })` on that route, mounted before `express.json()`).
  - Enforce the timestamp tolerance.
  - Dedupe by `event.id`.
- **Server-owned metadata:** `metadata` and `client_reference_id` come from the server session.
- **Idempotency keys** on charge creation, derived from the order ID.
- **Test mode end to end** with the Stripe CLI (`stripe listen --forward-to ...`), including a failed card and a retried webhook.
- **Separate keys:** test keys in dev and preview, live keys only in production.

## 8. Uploads and files

- **Validate every upload:** an allowlist of MIME types, a size cap, and magic bytes where it matters. The file extension proves nothing.
- **Storage paths** are generated (`{userId}/{uuid}.jpg`), never the user's filename. Don't `upsert` into shared paths.
- **SVG and HTML uploads** served from your own domain are stored XSS. Serve them from a separate domain or reject them.
- **Private by default.** Public buckets only for genuinely public assets (product photos), never receipts or prescriptions.
- **Images:** strip EXIF location data from user photos if they'll be shown publicly.

## 9. Rate limits and cost control

- **Rate-limit** login, sign-up, password reset, OTP and magic links, email and SMS sends, AI calls, uploads and public webhooks.
- **Use a shared store** (Redis or Valkey, Upstash, the database, or the platform's built-in limiter), never in-memory on serverless or multi-instance servers. Key on user plus IP, taking the IP from the platform's or proxy's trusted header (for example Netlify `x-nf-client-connection-ip`, or the framework's trusted-proxy setting), not a client-forgeable `x-forwarded-for`.
- **Short codes** (OTP, PIN): a cryptographic RNG (`crypto.randomInt`, Python `secrets`, `Random.secure()`, `SecureRandom`, `RandomNumberGenerator`), an expiry, single use, and an attempt limit with lockout.
- **Quotas and counters** live where users can't write them.
- **Spending caps:** per-user AI quotas plus hard spend limits at the provider, and budget alerts on Firebase/GCP and Supabase. Firebase App Check on Functions, Firestore and Storage cuts abuse from scripts. Mind the sideloaded-APK caveat in `../platforms/mobile.md` §2.

## 10. LLM features

- **Keys stay server-side.** The client calls your endpoint, which authenticates, rate-limits, sets `max_tokens`, then calls the provider. For Gemini in a Firebase app, Firebase AI Logic is the alternative: the client SDK goes through Firebase's proxy with no key in the app, provided App Check (limited-use tokens) is enforced, sign-in is required and per-user limits are set.
- **User input never goes into the system prompt.** Keep it in the user message and treat it as data.
- **Model output is untrusted:**
  - Render it as text.
  - Parse structured output against a schema before acting on it.
  - Never pass it to `eval`, SQL, a shell, file paths or `innerHTML`.
- **Tools that write data, send messages or spend money** need an explicit human confirmation step.
- **Keep sensitive context out of prompts:** no secrets, other tenants' data or more personal data than needed. Assume the system prompt will leak.
- **Retrieval (RAG):** partition retrieval by tenant (RLS on the vector table) and sanitize documents before indexing.
- **Building on Claude:** use the `claude-api` skill for current model IDs, prompt caching and tool use.
- **Design, evaluation and running costs** of LLM features: `../platforms/data-and-ai.md` §6-7.

## 11. Web hardening

- **Headers:**
  - CSP starting from `default-src 'self'`, with no `unsafe-inline`/`unsafe-eval` in `script-src` if you can avoid it.
  - HSTS, `X-Content-Type-Options: nosniff` and `frame-ancestors 'none'`.
  - `Referrer-Policy: strict-origin-when-cross-origin` and a `Permissions-Policy`.

  Set them in Netlify `_headers`, `firebase.json` `hosting.headers` or Next `headers()`. GitHub Pages can't send them.
- **CORS:** an explicit list of origins from config. Never `*` or a reflected origin on endpoints that use cookies or change data.
- **CSRF:** needed only for cookie-authenticated state changes. Use SameSite cookies plus an Origin check or a CSRF token. Next.js Server Actions check Origin against Host.
- **Error pages:** no stack traces or raw DB errors in production responses.
- **Logs:** no tokens, passwords, request bodies or personal data.
- **Source maps:** hidden, and uploaded to the error tracker rather than served.

## 12. Dependencies and supply chain

Every dependency is code you run with your users' data. AI agents add packages freely, sometimes ones that don't exist (attackers register those names), so treat each new one as a decision.

- **Before adding a package:** confirm it exists under exactly that name in the official registry, is maintained (recent releases, more than one maintainer for important ones), is widely used, and has a compatible licence. Check the spelling against typosquats (`reqeusts`, `lodahs`). Prefer the standard library or a few lines of your own code for small things.
- **Lockfiles committed and used:** CI installs exactly the locked versions (`npm ci`, `uv sync --frozen`, `cargo build --locked`, `dotnet restore --locked-mode`, `pub get --enforce-lockfile`, `bundle install` with a frozen lockfile).
- **A release cooldown,** so a freshly published version (the usual window for a hijacked package) waits a few days before it can be installed:

| Tool | Setting |
|---|---|
| npm 11.10+ | `min-release-age=7` in `.npmrc` (days) |
| pnpm 10.16+ | `minimumReleaseAge: 10080` in `pnpm-workspace.yaml` (minutes; pnpm 11 defaults to one day) |
| Yarn 4.10+ | `npmMinimalAgeGate: "7d"` in `.yarnrc.yml` (a bare number means minutes) |
| Bun | `minimumReleaseAge = 604800` under `[install]` in `bunfig.toml` (seconds) |
| uv | `exclude-newer = "7 days"` in `uv.toml` or `[tool.uv]` (relative durations since uv 0.9.17) |
| pip 26+ | `--uploaded-prior-to` (an absolute date; relative durations such as `P7D` in newer releases) |
| Poetry 2.4+ | `poetry config solver.min-release-age 7` (days) |
| Bundler | `bundle config set cooldown 7` (days, recent Bundler 4 releases) |
| Dependabot / Renovate | `cooldown: { default-days: 7 }` / `"minimumReleaseAge": "7 days"` (`git-and-tooling.md` §5) |

  Where the package manager has no setting (Cargo, Go, NuGet, Maven, Gradle, Composer, pub), rely on the lockfile plus the bot's cooldown, and review what each update changes. When an urgent security fix is younger than the cooldown, allow that one package explicitly (most tools have an exclude or pre-approved list) and say so.
- **Install scripts:** packages can run code at install time. Turn scripts off where the tool allows (`ignore-scripts`, Yarn's `enableScripts: false`, pnpm's allow-list of packages that may build) and allow only the ones that need it.
- **Audit known vulnerabilities** in CI (`npm audit`, `pip-audit`, `govulncheck`, `cargo audit`, `dotnet list package --vulnerable`, `composer audit`, `bundle-audit`, `osv-scanner`) and fix or document each High and Critical.
- **Never pipe a download into a shell** (`curl ... | bash`) from a source you haven't checked; download, read, then run.
- **CI and release supply chain:** third-party actions pinned to commit SHAs, publishing through trusted publishing or provenance where the registry supports it, and two-factor authentication on registry accounts (`../platforms/games-embedded-other.md` §4).
- **Agent tooling is supply chain too:** MCP servers, plugins and skills run with the agent's permissions. Install them from sources the user trusts, read what they do, and give them the narrowest access.

## 13. Before calling a security-sensitive change done

- The two-account test passes for every endpoint you touched.
- Rules and RLS tests pass in the emulator or local stack.
- Run Audit mode's security pass (`references/audit/security.md`) on the areas you touched, or Claude Code's `/security-review` on the diff.
- Have the user hand-review auth, payment, access-control and crypto changes line by line, as SKILL.md's Security rules say.
