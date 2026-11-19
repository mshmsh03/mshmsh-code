# Building it secure: the patterns to use

Read this when touching auth, rules or policies, secrets, payments, uploads, rate limits or LLM features. SKILL.md "Security" has the short version. This file says how to build it right. To *audit* an existing app, use Audit mode; `references/audit/security.md` lists what goes wrong and how to find it.

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
12. Before calling a security-sensitive change done

---

## 1. Secrets

- **Server-side only.** API keys, service-role keys, Stripe secret keys, SMTP/SMS credentials and DB URLs live in server env vars or a secret manager.
- **Anything a client can see is public:**
  - `NEXT_PUBLIC_`, `VITE_`, `REACT_APP_` and `EXPO_PUBLIC_` values.
  - Expo `extra`, Flutter `--dart-define` values and bundled `.env` assets.
  - The JS bundle and the APK.

  A paid or privileged key belongs behind a server endpoint (a Cloud Function or route handler) that checks the caller.
- **Public by design (not secrets):** the Firebase client config `apiKey`, the Supabase anon key, the Stripe publishable key, and Maps client keys. Restrict them (HTTP referrers, app package + SHA-1, quotas) and rely on rules and RLS for security.
- **If you're about to type a literal secret into a file, stop** and use an env var plus `.env.example` instead.
- **If a secret ever reached git or a client bundle, rotate it first,** then remove it. Deleting the line doesn't un-leak it.
- **Run a secret scan in pre-commit** (see `git-and-tooling.md`).

## 2. Authentication

- **Use the platform's auth** (Firebase Auth, Supabase Auth, Clerk, Auth.js). Never invent your own password storage or token format. If you must store passwords, use argon2id or bcrypt, never a fast hash.
- **Web sessions:** `HttpOnly; Secure; SameSite=Lax` cookies with a bounded lifetime. Don't put tokens in `localStorage`.
- **Mobile:** let the SDK manage the session, and keep any extra tokens or PINs in `flutter_secure_storage` / `expo-secure-store`.
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

Every route handler, Cloud Function, callable, Server Action and RPC function follows the same order:
1. **Authenticate:** verify the token or session on the server (`verifyIdToken`, `getUser()`/`getClaims()` in Supabase server code, never just `getSession()`).
2. **Validate the input** against a schema (zod, or Dart classes). Copy only allowed fields; never pass `req.body` straight into a write (mass assignment).
3. **Load the object and check ownership or role:** `where id = ? and user_id = ?`, or the shop membership check. This is the IDOR defence, and it's the check AI-written code skips most often.
4. **Act**, recomputing anything sensitive (prices, totals, permissions) on the server.
5. **Return only the fields the caller needs** (explicit `select`, no whole rows with hashes or internal flags).

Put steps 1-3 in one shared helper (`requireUser()`, `requireShopMember(shopId)`) so no endpoint can forget them. Remember:
- `firebase-admin` and the Supabase service role **bypass all rules**, so code using them must do this check itself.
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

- **Validate at every boundary** with a schema (zod, valibot, or Dart model classes) and reject unknown fields.
- **SQL:** placeholders always (`?` with arguments, `$1`, tagged templates from a safe driver), including local SQLite: `rawQuery('... WHERE name LIKE ?', ['%$q%'])`, never interpolation into the SQL string.
- **HTML:** render user content as text. If rich text is truly needed, sanitize with DOMPurify using a tight allowlist. Never `dangerouslySetInnerHTML` or `innerHTML` with user or DB content.
- **Links:** user-supplied URLs get a scheme check (`https:` only) before going into `href`/`src`.
- **Redirects:** allow only relative paths starting with a single `/`, or allowlisted hosts.
- **Server-side fetches of user URLs** (SSRF): use a host allowlist, https only, block private and link-local IPs, and `redirect: 'error'`.
- **File paths:** never build them from user input. Generate IDs for storage keys.
- **Shell commands:** never interpolate input into a command string.
- **Normalize Arabic-Indic digits** before numeric validation (see `mobile-and-offline.md` §8).

## 7. Payments

Stripe doesn't serve merchants in Iraq. For local clients, use the gateway they bank with (FIB, ZainCash, FastPay, or a local aggregator) through its hosted payment page. The rules hold for any gateway:
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
- **Use a shared store** (Upstash or Redis), never in-memory on serverless. Key on user plus IP, taking the IP from the platform's header (e.g. Netlify `x-nf-client-connection-ip`), not a client-forgeable `x-forwarded-for`.
- **Short codes** (OTP, PIN): a cryptographic RNG (`crypto.randomInt`, `Random.secure()`), an expiry, single use, and an attempt limit with lockout.
- **Quotas and counters** live where users can't write them.
- **Spending caps:** per-user AI quotas plus hard spend limits at the provider, and budget alerts on Firebase/GCP and Supabase. Firebase App Check on Functions, Firestore and Storage cuts abuse from scripts. Mind the sideloaded-APK caveat in `mobile-and-offline.md`.

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

## 12. Before calling a security-sensitive change done

- The two-account test passes for every endpoint you touched.
- Rules and RLS tests pass in the emulator or local stack.
- Run Audit mode's security pass (`references/audit/security.md`) on the areas you touched, or Claude Code's `/security-review` on the diff.
- Have the user hand-review auth, payment, access-control and crypto changes line by line, as SKILL.md's Security rules say.
