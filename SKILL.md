---
name: "vibe-code"
description: "Build and audit AI-made software the way a senior engineer does (\"vibe coding\"). Build mode covers questions, design and a plan before code; day-one guardrails (git, strict types, lint, hooks, CI); test-first slices; evidence before saying done; systematic debugging; secure patterns (auth, Firebase rules, Supabase RLS, secrets, payments, LLM features); stack rules for React/Next.js, Flutter, Expo, offline-first POS on SQLite, Kurdish/Arabic RTL and IQD money; shipping. Audit mode is a hostile, read-only check before launch or handoff, security first (leaked keys and git history, rules, auth and ownership, payments, mobile bundles), then correctness, data, performance, UX/RTL, tests and readiness, with a verdict and a ranked report. Use whenever the user wants to build, extend or fix an app, site, POS or feature by describing it (\"vibe code this\", \"build me an app\", \"add a feature\"), or to check one (\"is it safe\", \"ready to launch\", \"audit my app\", \"did I leak keys\"), even if they never say \"vibe coding\"."
---

# Vibe Code

One skill, two modes:
- **Build:** making or changing software mostly by describing it ("vibe coding").
- **Audit:** a hostile, read-only check of an app before launch, client handoff or a store release.

Vibe coding is fast, and it fails in predictable ways:
- invented APIs
- the first pattern copied everywhere
- files that grow until they rot
- hardcoded secrets
- everything a demo can't show skipped: access rules, ownership checks, error states, RTL, migrations
- "done" declared before anything ran

Build mode prevents those failures; Audit mode finds them.

**The idea underneath everything:** AI output is only as good as its feedback loop. Set up fast automatic signals early (types, linter, tests, a running app you can look at, git to roll back), work in steps small enough that each signal is unambiguous, and never claim something works without fresh evidence.

## Pick the mode

- **Build** when the user wants something made, extended or fixed ("build", "add", "fix", "make it work", "vibe code this"). Follow "Rules for every change" and the Build workflow. For a trivial one-off script, skip the ceremony but keep the verification.
- **Audit** when the user wants an app checked ("check", "audit", "review my app", "pentest", "is it safe", "ready to launch", "did I leak keys", "are my Firebase rules ok"). Follow the Audit workflow. Audit mode is **read-only**: change nothing, never exploit anything, and mask every secret you quote.
- **After an audit,** fixing the findings is Build mode, starting with the Top 3.
- For a single diff or PR, Claude Code's `/review` (or `/code-review` from the code-review plugin) and `/security-review` are lighter options.

## Where you're running

- **Claude Code:** everything here applies, including the guard hook, `/review`, `/security-review` and `/simplify`.
- **Claude app (cloud workspace):** no hooks or slash commands. Offer the guard hook for the user's own Claude Code rather than installing it here, and use §11's review checklist wherever a slash command is named. Run the scripts on a copy of the repo in the workspace (a GitHub clone or an uploaded zip), or run the same checks by hand with a shell on the user's computer. Nothing built in the workspace reaches the user until you send it or push it.

## Where the details are

| Read | When |
|---|---|
| `references/build/planning.md` | Anything bigger than a quick fix: questions, design doc, prototypes, slicing, plan format, executing a plan, subagents, ADRs |
| `references/build/architecture-and-data.md` | Stack choice, modules, API shape, errors, idempotency, schema, indexes |
| `references/build/git-and-tooling.md` | Project setup, commits, the guard hook, pre-commit, CI, merge conflicts |
| `references/build/testing.md` | TDD, good tests, mocks, flaky tests, E2E, RTL tests |
| `references/build/debugging.md` | Something's broken and the first obvious fix didn't work |
| `references/build/security.md` | Building auth, Firebase rules, Supabase RLS, secrets, payments, uploads, rate limits, LLM features |
| `references/build/web-frontend.md` | Any web UI: RTL, forms, the four states, accessibility, Core Web Vitals, React/Next.js |
| `references/build/mobile-and-offline.md` | Flutter, Expo/React Native, Windows tills, offline POS, SQLite, IQD, printing, Kurdish RTL |
| `references/build/shipping.md` | Environments, deploys, signing and store release, flags, monitoring, launch checklist |
| `references/audit/security.md` | Audit: per-stack security checks, detection commands, severity calls |
| `references/audit/quality.md` | Audit: correctness, data, performance, UX/RTL, tests, readiness, and the launch verdict |

Version numbers, CVE floors and store deadlines in these files are snapshots (last checked Nov 2026). Check the current docs or advisories before relying on one.

**Scripts:**
- `scripts/scan.sh`: the audit's first-pass lead finder. It masks secrets, scans the whole git history, and is read-only.
- `scripts/guard-commands.mjs`: a Claude Code hook that blocks destructive git commands and asks before production deploys. Setup is in `references/build/git-and-tooling.md` §3.

**Related skills, when installed:**
- `interview-me` (or `grill-me`), `spec-driven-development`, `domain-modeling`
- `designa-xoshaka` (or `impeccable` / `unslop-ui`) for how a UI looks, including Kurdish/Arabic layout; `unslop-code`
- `doubt-driven-development`, `flutter-apply-architecture-best-practices`, `claude-api`

# Rules for every change

## Verify before you say done

Before claiming done, fixed or passing, run the command that proves it, fresh and in full, and read the output and exit code.

| Claim | Evidence required |
|---|---|
| Tests pass | the full suite, run now: 0 failures |
| It builds | the build command, exit 0 (a clean lint is not a build) |
| Bug fixed | the original reproduction, now passing |
| The new test works | seen red without the fix, green with it |
| The UI works | the running app driven and looked at (browser automation, a device, a screenshot) |
| A subagent says success | its diff read and its tests re-run |
| Requirements met | checked line by line against the spec or plan |

- **Watch for invented APIs:** functions, options and methods that sound right but don't exist. For anything unfamiliar or version-sensitive, check the installed version's types or docs rather than recall. Check that packages are real, maintained, and the ones you meant.
- **Suspiciously perfect output for a hard problem is a reason to check more.** "Should work" or "probably fine" before evidence is a red flag. Say what you verified and, as clearly, what you didn't.
- **Scan your own diff for cheap greens:**
  - new `@ts-ignore`, `eslint-disable` or `// ignore:`
  - skipped or deleted tests, weakened assertions
  - empty `catch` blocks
  - stubs where code should be

  Loosening any check must be announced and justified.

## Security

- **Secrets stay on servers.** Anything that reaches a client is public:
  - `NEXT_PUBLIC_`/`VITE_`/`EXPO_PUBLIC_` values
  - Expo `extra`, Flutter `--dart-define` values, bundled `.env` assets
  - the JS bundle and the APK

  Paid and privileged keys go behind a server endpoint (for Gemini in a Firebase app, Firebase AI Logic with App Check enforced is the alternative). If you're about to type a literal key into a file, stop. A leaked key is rotated, not just deleted.
- **Every endpoint, function, Server Action and RPC follows the same steps:**
  1. Authenticate on the server.
  2. Validate the input against a schema, copying only allowed fields.
  3. Load the object and check ownership or role.
  4. Act, recomputing prices and totals on the server.

  Put the steps in one shared helper. `firebase-admin` and the Supabase service role bypass all rules, so code using them checks for itself.
- **Firebase rules and Supabase RLS:**
  - Deny by default.
  - Roles from custom claims or `app_metadata`, never from user-editable data.
  - "Signed in" never means "allowed": anyone can create a Firebase account with the public API key.
  - The same validation on create and update.
  - Sales and payments append-only.
  - Tested in the emulator or local stack with a second user.
- **Payments** (Stripe where it serves the merchant; for Iraqi clients, gateways such as FIB, ZainCash or FastPay):
  - The amount comes from the server.
  - "Paid" is set only by a callback verified on the server (signature, or re-querying the gateway).
  - Callbacks are idempotent by transaction ID.
- **Rate-limit** auth, OTP, email/SMS, uploads and AI endpoints, with a shared store and provider spend caps.
- **Auth, payments, access control and migrations get line-by-line review** by the user, and an Audit-mode security pass (or `/security-review`) before they're called done.
- **Dependencies:** pin them with a committed lockfile. If the project will be sold or open-sourced, flag dependency licences.

Details: `references/build/security.md`.

## Stack rules AI-written code usually gets wrong

**Kurdish/Arabic and RTL:**
- Web: `<html lang="ckb" dir="rtl">` in the served HTML, and logical CSS (`margin-inline-start`, Tailwind `ms-/me-`).
- Flutter has **no built-in `ckb` localizations**. Add fallback delegates to Arabic, or the app renders left-to-right. Use `EdgeInsetsDirectional` and `AlignmentDirectional`, and never wrap the app in an LTR `Directionality`.
- Normalize Arabic-Indic digits (٠-٩, ۰-۹) before parsing: `int.tryParse('١٢٣')` is null and `Number('١٢٣')` is NaN.
- Normalize ي/ی and ك/ک for search.
- Isolate phone numbers and barcodes as LTR.
- Use a font with ڕ ڵ ێ ۆ ە, and no letter-spacing on Arabic script.

**Money:**
- Integers end to end (IQD in whole dinars), one rounding function, totals derived from line items.
- Format with an explicit `IQD` and 0 decimals. Plain `ar` locales default to other currencies and `.00`.

**Offline POS:**
- The local SQLite DB is the ledger, with an outbox, device-generated UUIDv7 IDs and tombstones.
- Firestore transactions fail offline, and awaited Firestore writes in the checkout path freeze the till.
- Stock is a sum of movements with an explicit oversell policy.
- Firebase's Windows SDK isn't meant for production, so Windows tills need their own sync path.
- Turn on `PRAGMA foreign_keys`. Never use `REPLACE` upserts on rows that have children.
- Test migrations from every shipped version.

**Web:**
- Loading, empty, error and success states on every async view.
- Real labels on inputs; never block paste or zoom.
- No component defined inside a component; derive state instead of syncing it with effects.
- Image dimensions set, and the hero image never lazy-loaded.
- Server Actions check auth themselves.
- OG tags in the served HTML, so WhatsApp previews work.

**Mobile:**
- Release builds signed with a real, backed-up key; the Flutter template signs them with the debug key.
- Tokens in secure storage.
- Builder lists (`ListView.builder`, FlashList).
- Crash reporting from day one.
- Native libraries (SQLite builds, printer and scanner SDKs) built for 16 KB memory pages, or Play rejects the update.

Details: `references/build/web-frontend.md`, `references/build/mobile-and-offline.md`, `references/build/shipping.md` §3.

## Git

- Start each task from a clean state, on a feature branch, never directly on `main`.
- **Commit locally after every green step,** with a message that says what and why, in the repo's convention: `fix(sync): upsert sales by client UUID so retries can't duplicate them`, never "update" or "fix". The user set this skill up to commit like this on working branches. Pushing, merging and deploying still need an explicit ask.
- Stage explicit paths and read `git diff --staged` first; `git add .` is how `.env` files get committed. Keep each commit to one logical change, with no formatting mixed into behaviour changes.
- To undo, use git (`revert`, `restore`), not code reconstructed from memory.
- Never force-push, skip hooks or run destructive commands. The bundled guard hook blocks them once installed; if the user explicitly wants one, they run it themselves.

Details: `references/build/git-and-tooling.md`.

# Build workflow

## 1. Check that vibe coding fits

Vibe coding fits prototypes, internal tools, MVPs and anything where iteration speed matters most. Slow down for:
- security- or money-critical logic
- data migrations and production data
- billing and stock counts
- hot paths where "it works" isn't "it's fast enough"

For those, review the code like a junior engineer's, or write the sensitive core by hand, and tell the user plainly. A prototype built to answer a question is fine, as long as it's labelled throwaway and rewritten properly if it survives.

## 2. Understand

- **Size it out loud:**
  - Quick task (a bug fix, a one-file change): do it, then say what you assumed.
  - Small change (one module or screen with clear requirements): state the approach and assumptions in 2-3 lines, or at the top of a short plan file, then build test-first. Ask first only when the choice is the user's: the data model, money or stock rules, UX, deleting anything.
  - Project (a new app, work across modules or sessions, or anything touching auth, payments between systems, or sync): questions, design, plan, then build.

  Step up a size if a "small change" turns out to touch auth, sync or the schema.
- **Look things up before asking.** The repo, docs, data and history are your job; only decisions go to the user. For technical owners, ask in numbered rounds, each question with a recommended answer they can accept with "yes".
- **Questions meant for a client:** draft them for the user to forward, in plain words, each tied to a real moment ("the last time a customer returned something"), most important first.
- **Cover:**
  - who uses it, and the one job it must do well
  - what success looks like
  - constraints: offline? devices? languages, digits, currency? deadline?
  - what exists, and what's out of scope

  Say every default out loud and label guesses. Push back on weak ideas, with the reason.
- **One concrete task at a time,** with real reference material: mockups, the client's product list, existing code to match.

## 3. Design (projects)

- **Propose 2-3 approaches** with trade-offs and a recommendation, and prefer the simplest that meets the goal. Make "done" concrete with mockups, example inputs and outputs, or a receipt layout. For tricky business rules (returns, debts, discounts, stock), a clickable one-file logic prototype beats any description.
- **MVP = one user job done well,** aimed at the riskiest assumption, with later phases listed but not built.
- **For projects, nothing is scaffolded, installed or coded until a written design is approved** (`docs/specs/YYYY-MM-DD-<topic>-design.md`). "Sounds good" to an idea in chat is not approval of a design nobody wrote down.
- **Client work:** approvals in writing, a Not Doing list, and trade-offs explained in plain words. These are what you point to when scope creeps.

Details: `references/build/planning.md` §1-6.

## 4. Plan (projects)

- **Write the plan to a file** (`docs/plans/YYYY-MM-DD-<feature>.md`) so it survives context resets.
- **Slice vertically.** The first slice is a tracer bullet: the thinnest path through every layer (DB → logic → UI → test). Risky pieces go first: sync, payment callbacks, Arabic-script printing.
- **Every task names:**
  - the files and interfaces
  - the failing test, with literal values
  - the command, with expected FAIL and then PASS
  - the commit message

  "Add error handling" is not a task; say which errors.
- **Execution:** a checkpoint every 2-3 tasks, and a short ledger of finished tasks and the small calls you made. Inside an approved plan, don't ask "should I continue?". Stop only for destructive steps, security-sensitive changes the plan didn't spell out, anything outside the branch, or a plan that turns out broken.

Details: `references/build/planning.md` §6-8.

## 5. Stack, data model, architecture

- **Default to a popular, well-documented stack.** Per-project defaults are in `references/build/architecture-and-data.md` §1.
- **Sketch the data model before the UI:** entities, relationships, ownership, persistence. Get the types right from the start:
  - money as integers or `numeric`
  - server timestamps
  - numbers as numbers
  - constraints and indexes in the database
- **Deep modules,** organized by feature. Domain logic (money, stock, discounts, sync) lives in pure functions with no UI or network imports.
- **Contracts first:** typed inputs and outputs, one error shape, validation at boundaries, pagination from day one.
- **Never swallow errors,** and make every write safely retryable (client-generated IDs, idempotency keys).
- **Standards set early stick,** so review the first few files carefully. Left alone, AI appends; schedule refactor passes that split big files, delete dead code and merge duplicate helpers.

## 6. Guardrails on day one

Scale them to what you're building:
- A new repository that will live on (a client app, anything that will get a remote) gets the full list below.
- A prototype or a standalone module gets git, `.gitignore`, strict types and tests. Add hooks, CI and Dependabot when it gets a remote or a second contributor.
- Inside an existing project, use its tooling rather than adding new tools.

The full list:
- `.gitignore` written **first** (`.env*`, build output, keystores, `key.properties`, service-account JSON). Also `.gitattributes`, `.env.example` and committed lockfiles.
- Strict types, linter and formatter (settings in `references/build/git-and-tooling.md` §1).
- A test runner with one passing test.
- Fast pre-commit hooks: format, lint and secret scan on staged files.
- CI on every push and PR, required before merging.
- **The guard hook** is a one-time install in the user's Claude Code settings. Check whether it's there; if not, offer it once. On GitHub, branch protection with "do not allow bypassing" (admins bypass by default; private repos need a paid plan).
- One command per check (lint, typecheck, test, test-one, build, dev), recorded in the context file.

## 7. Living context file

Keep `CLAUDE.md` (or equivalent) with what can't be looked up elsewhere:
- the exact commands
- conventions and things not to do
- gotchas and decisions, each with its reason
- pointers to the spec, plan and ADRs
- removed features that must not come back

Don't restate `package.json` or `pubspec.yaml`, because copies go stale. When you're told the same thing twice, add it. Update the file after any session that produced a correction, and read it first in every new session. After a rough session, ask which mistake a lint rule, hook or test could have caught, and add that check.

## 8. Context hygiene and subagents

- **If a problem survives ~3 attempts, stop iterating blindly.** Summarize what was tried and consider a fresh session.
- **Compact or reset at task boundaries,** never mid-implementation. Before ending a session, write a handoff: decisions, task status, files changed, verification commands and results, open questions.
- **Subagents get a full brief:** the task with exact values, interfaces from earlier tasks, your rulings, and the reply format. Never hand over the whole session history.
  - Run them in parallel only on independent problems, each in its own worktree if they write code.
  - For risky work, add a reviewer subagent that checks the diff against the brief.
  - Verify what subagents claim before passing it on.

Details: `references/build/planning.md` §8.

## 9. Build test-first, in small slices

AI-generated code is implementation-first with little testing, so testing has to be a forced step.
- **Red → green → refactor:**
  1. Write one test for one behaviour.
  2. Watch it **fail for the right reason** (the assertion, not an import error).
  3. Write the least code that passes.
  4. Refactor on green, as its own commit.
- **Every bug starts as a failing test** that reproduces it.
- **Expected values come from an independent source,** never recomputed with the code's own logic.
- **Mock only what you don't own** (payment gateways, SMS, printers). For your own stack, use real local stand-ins: in-memory SQLite, the Firebase emulator, local Supabase.
- **Test the paths that hurt:** money, stock, sync, auth, migrations, and failures (offline, timeout, 500, double tap). E2E only for critical journeys, with no fixed sleeps.

Details: `references/build/testing.md`.

## 10. Debugging

- **Reproduce first** with a fast, deterministic loop (a failing test, a curl script, a replayed payload). Ask for raw error text, not paraphrases.
- **Check what changed** (`git diff`, recent commits, env vars). `NEXT_PUBLIC_`/`VITE_`/`EXPO_PUBLIC_` values are baked in at build time.
- **Form 3-5 ranked hypotheses** with predictions and test one variable at a time. Use tagged temporary logs at boundaries, and drive the real app for UI bugs. If the code used to work, run `git bisect run`.
- **Fix the source, not the symptom.** Add the regression test, remove the debug logs, and explain to the user what actually went wrong.
- **If a third fix fails,** or each fix exposes new coupling, stop patching and discuss the design.

Details: `references/build/debugging.md`.

## 11. Review and refactor

- **Before presenting work, review your own diff as a stranger would:**
  - Does it do what was asked, and nothing extra?
  - Are there tests?
  - Any swallowed errors, hardcoded values or debug leftovers?
  - Is it the simplest version?
- **For risky changes, review on two axes,** ideally in fresh-context subagents or with `/review`: does it meet the spec, and is the code sound?
- **Receiving review:** verify each point against the code, push back with evidence when it's wrong for this codebase, and fix one item at a time with a test.
- **Refactor only on green,** in commits that change no behaviour. Before handing code over, strip AI tells (narrating comments, generic names, over-engineering) with `/simplify` or `unslop-code`.

## 12. Shipping

Running locally isn't done:
- **Preview first;** production only when the user asks. Keep dev and prod as separate projects, with sandbox payment credentials outside production.
- **Crash reporting** (Crashlytics on mobile, Sentry on web and Windows), proven with a test crash. Logs carry no secrets or personal data.
- **A rollback plan,** risky features behind flags whose default is safe, and backups restored at least once.
- **Mobile releases:** a backed-up upload key, increasing build numbers, archived symbols, and a staged rollout.
- **The launch checklist** (`references/build/shipping.md` §7), a README with setup and env vars, and an Audit-mode run on the release candidate.

Code exported from an app builder (v0, Lovable, Bolt, Replit) gets the §6 guardrails and an audit before anyone builds on it.

# Audit workflow

Audit the app the way a senior engineer would if hired to find every way it leaks data, loses money, falls over in production or embarrasses its owner. Be paranoid: comments, function names and README claims prove nothing until the code path confirms them. But report only what you can show. Look hardest at what a demo can't show: access rules, ownership checks, webhook signatures, atomic writes, error handling, migrations, RTL, real tests.

## Ground rules

- **Read and report.** Change nothing unless the user asks afterwards; fixing is Build mode.
- **Never exploit.**
  - No requests against production, no trying a found credential, no brute forcing.
  - TruffleHog verifies keys with the provider by default, so always add `--no-verification`; gitleaks never verifies.
- **Builds and tests run project code, so they are not read-only:**
  - Check dependency names for typosquats first, and list install scripts without installing (`grep -n '"hasInstallScript": true' package-lock.json`).
  - If tests or the build use the live Firebase, Supabase or payment project and no emulator or local stack exists, skip them and list them under "couldn't check".
  - Install only if `node_modules` is missing, with `npm ci --ignore-scripts`. For Flutter, use `flutter pub get --enforce-lockfile`.
- **Mask secrets everywhere you write.** Show only the prefix that names the key type, plus the length (`sk_live_…(107 chars)`, `sb_secret_…`, `AKIA…`). Passwords, PINs and values with no known prefix get no characters: `storePassword=…(10 chars)`.
- **Evidence or it didn't happen.**
  - Every finding needs file:line and the path you followed: who can reach it, what it touches, what stops them.
  - What needs a console you can't see (deployed Firebase rules, Supabase dashboard, gateway webhook config) is reported as "needs confirmation in <place>".
- **Don't stop at the first hit.** One leaked key usually means three; one endpoint missing an ownership check usually means all of them.
- **Don't grade your own work.** If this session built the code, run the audit in a fresh session or subagent that hasn't seen the build, and say which you did.

## Steps

1. **Scope.** What the app does, who uses it, and what's worth stealing or breaking: personal data, money, stock, accounts, the sending domain, the paid API bill. Note the stack, deployment and distribution (web, APK, store, desktop). Default to a full audit. If the user names one area, audit it with the same rigor and report format.

2. **Automated sweep.** Run the lead finder with the Bash tool (Git Bash on Windows; from PowerShell, a plain `bash` may start WSL). Strip Windows line endings first: a copy saved with CRLF fails at once with `$'\r': command not found`.
   ```bash
   tr -d '\r' < <this-skill-dir>/scripts/scan.sh > /tmp/vibe-scan.sh && bash /tmp/vibe-scan.sh <repo>   # leads only; masks secrets; read-only
   ```
   Then run the project's own checks, with the precautions above, and note what's missing:

   | Stack | Commands |
   |---|---|
   | Node/Next/Expo | `npx tsc --noEmit`, `npm run lint`, `npm audit --omit=dev`; `npm test` and `npm run build` only against an emulator or local stack. For Next.js, compare the lockfile's `next` version with the newest security release (`references/audit/security.md` §10) |
   | Flutter | `flutter analyze`, `flutter test`, `osv-scanner` on `pubspec.lock` |
   | Python | `pip-audit -r requirements.txt`, `ruff check`, `pytest` |
   | Supabase | `supabase db advisors --remote --type security`, if the CLI is linked and the user agrees (CLI 2.81+; without `--remote` it checks the local database) |
   | Secrets | `gitleaks git -v --redact --no-banner .` if installed |

   A failing build, type check or test run is itself a finding. Don't install global tools without asking.

3. **Map the attack surface.** List every entry point and who can reach it:
   - routes and Cloud/Edge Functions
   - Server Actions (each `'use server'` export is a public POST endpoint)
   - RPC-callable database functions
   - Firestore/RTDB/Storage rules; Supabase tables, policies, views, buckets
   - webhooks, cron jobs, admin tools
   - everything shipped to clients (treat it as public)
   - paid APIs and who can trigger them

4. **Security pass (deep)** with `references/audit/security.md`: secrets and history, backend rules, auth and ownership (IDOR), money and business logic, webhooks and payment callbacks (Stripe, ZainCash, FIB, FastPay, Qi Card), paid APIs and LLMs, injection and unsafe sinks, sessions/CORS/headers, mobile and desktop specifics, dependencies, logging.

5. **Quality passes.** Walk **every line** of `references/audit/quality.md` against the code: correctness, data integrity, performance, UX/accessibility/RTL, tests and tooling, production readiness. Most lines take seconds, and skipped lines are where audits miss things. Trace deeply only where the app's purpose makes an area critical, like money and stock in a POS or personal data in a pharmacy. Trace at least one critical flow end to end, client to server and back.

6. **Confirm, merge, prune.** Trace every lead to a real path, merge findings with one root cause, and drop what you can't support. List what you ruled out, one line each.

7. **Report** in the format below.

## Severity

Judge by impact times who can trigger it, then sort worst-first.

| Level | Meaning | Typical examples |
|---|---|---|
| **Critical** | Anyone, or any self-registered user, can read others' data, take or skip payment, run up bills, take over accounts or destroy data, right now. Also: the app silently loses or corrupts sales, stock or money records in normal use | Service-role or live payment key exposed; rules open to all; unverified payment callback; client-set prices; admin action with no auth; stock oversold across tills; migrations that never run on existing installs |
| **High** | Serious harm needing a little effort or a specific condition | IDOR on orders; SSRF; stored XSS (Critical where staff view it); brute-forceable OTP; keystore passwords committed (Critical if the repo is public) |
| **Medium** | Real weakness or bug with limited blast radius | Token in plain storage; stack traces to clients; unbounded queries; swallowed errors outside money paths; forced LTR |
| **Low** | Hardening, hygiene, polish | Missing headers; index keys; missing `.env.example`; minor a11y gaps |

## Report format

- **Verdict first,** in one line: **Blocked** / **Risky: internal or pilot only** / **Launchable with caveats** / **Ready**, plus the findings that decide it. Any Critical means Blocked; the other caps are in `references/audit/quality.md` §8. Then say what was audited (stack, commit or date, scope) and what couldn't be checked.
- **In plain words,** for the owner: 3-5 sentences without jargon. What a stranger, a customer or a cashier could do today, what it could cost, and roughly how long the top fixes take.
- **Scorecard:** one row each for Security, Correctness & data, Performance, UX/a11y/RTL, Tests & tooling and Production readiness, rated **OK**, **Issues** or **Blocking** with a short reason.
- **Findings,** worst-first. Keep cells short: no code blocks, and no `||` rule snippets, which break tables.

  | # | Severity | Area | File:line | Problem | Exploit or failure scenario | Fix (one line, effort S/M/L) |
  |---|---|---|---|---|---|---|

  - Then a numbered **Details** block for each Critical and High row: the full scenario, the exact fix and the code that won't fit in a cell.
  - Be specific: "`STRIPE_SECRET_KEY` hardcoded at `src/lib/stripe.ts:4`", not "exposed API key".
  - Every fix names the actual change; a leaked key's fix starts with "rotate".
  - Use one row per root cause, and include every confirmed finding, Lows too (group them by area if there are many).
- **Top 3 to fix today:** the highest-leverage fixes, not always the three worst rows.
- **Checked and fine:** notable areas verified clean.
- **Evidence:** the commands run and their results, the evidence still missing, and one concrete next action.

If the user asked about one area only, keep the same table, the Top 3 and the "couldn't check" line, scoped to that area. After the report, offer to fix the findings in Build mode, starting with the Top 3: reproduce with a failing test, fix, re-run the checks, and re-audit the touched paths.