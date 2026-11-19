# Quality passes: correctness, data, performance, UX, tests, readiness

The second half of the audit, for any language and kind of software. Go to triage depth everywhere, and deep wherever the software's purpose makes an area critical: money, stock and sync in a POS; personal data in a clinic or pharmacy app; payments anywhere; data correctness in a pipeline; safety limits in firmware. `scripts/scan.sh` surfaces many of these as leads. Read the code before reporting. Sections labelled with a framework apply only when it's present.

## Contents
1. Correctness and AI-code bugs
2. Data integrity
3. Performance
4. UX, accessibility and RTL
5. Tests and tooling
6. Production readiness
7. Maintainability
8. The launch verdict

---

## 1. Correctness and AI-code bugs

**Code that doesn't exist or doesn't run:**
- **Hallucinated APIs:** imports of packages that aren't in the manifest or lockfile, methods the installed version doesn't have, config keys the framework ignores. The build and type check catch most of these. For the rest, check the installed version (the lockfile: `package-lock.json`, `uv.lock`, `go.sum`, `Cargo.lock`, `pubspec.lock`, `packages.lock.json`, `composer.lock`, `Gemfile.lock`) against its types or docs.
- **Fake implementations:** functions that return hardcoded success, `TODO: implement`, mock or sample data in production paths (`John Doe`, `test@example.com`, `lorem`), feature flags that are always on, "payment" that just navigates to a success page.
- **Unfinished paths:** handlers that ignore some branch (`status === 'refunded'` never handled), `switch` statements without a default over open-ended values.

**Broken wiring (trace one critical flow end to end):**
- Does the client send what the server requires? A typical miss is an API client that never attaches the `Authorization` header the server checks, so every call 401s.
- Do request and response field names match on both sides?
- Does every server error reach the user as a message, not a spinner?
- Are packages imported but missing from the manifest? Is type checking configured where the language supports it (`tsconfig`, mypy or pyright config, nullable reference types in .NET)?
- **Desktop/Windows Flutter:** `sqflite` has no Windows backend. Without `sqflite_common_ffi` initialised (`sqfliteFfiInit(); databaseFactory = databaseFactoryFfi;`), or drift, the Windows till throws on the first DB call. Firebase's Windows SDK isn't meant for production either.

**Errors that disappear:**
- **Swallowed errors:** empty `catch`, `catch (e) {}` in Dart, `except: pass` or bare `except:`, `.catch(() => null)`, Go `_ = err` or an unchecked `err`, Rust `let _ =` on a `Result`, Java or C# `catch (Exception e) {}`, or a `catch` that prints and returns `[]`. In money, stock or sync paths, **Critical**: sales or payments vanish while the UI says it worked. Elsewhere, **Medium**.
- **Fail-open catches** in auth or payment code. Covered in `security.md` §4.
- **Unchecked results:** Supabase `const { data } = await ...` with `error` never read; HTTP responses used without checking the status.

**Async and concurrency mistakes** (judge them by the store involved):
- **Python:** a coroutine called without `await` (it never runs), blocking calls (`requests`, `time.sleep`, sync database drivers) inside `async` code.
- **C#:** `async void` outside event handlers, `.Result`/`.Wait()` (deadlocks), fire-and-forget tasks whose exceptions vanish.
- **Go:** goroutines without cancellation or error collection, shared maps written from several goroutines without a lock (run tests with `-race`).
- **Java/Kotlin:** `CompletableFuture`s never joined or with no exception handling; blocking calls on coroutine or reactive threads.
- **SQL and HTTP calls:** a missing `await` means errors go uncaught and work can run after the response, which serverless platforms may kill. Flag `forEach(async ...)` and `.forEach(x => x.ref.update(...))` without `Promise.all`.
- **Firestore in offline-capable apps:** the reverse. An *awaited* `set/update/add` blocks until the server acknowledges it, so in a checkout path the till freezes offline. Unawaited Firestore writes are correct there, provided errors and `hasPendingWrites` are surfaced somewhere.
- **Firestore transactions fail offline.** `runTransaction` on a path that must work offline is a bug.
- **Flutter:** using `context` after an `await` without a `mounted` check; `.listen(` inside `build()`; futures created inside `build()`.

**Races and duplicates:**
- Read-modify-write on counters, stock or balances (`stock - qty` computed in app code and written back) is a race. Two tills, two tabs or a retry will corrupt it. **Critical** for stock and money (oversold stock, lost updates), **Medium** elsewhere.
- Double submit: no disabled state or idempotency key on "Pay", "Complete sale" or "Place order".
- Retries that mint a new ID per attempt (`.add()` inside retry or catch logic) duplicate records.

**Classic bugs by language:**
- **Python:** mutable default arguments, `is` used for value comparison, integer vs float division surprises, naive `datetime` objects compared with aware ones.
- **Go:** writing to a nil map, loop variables captured by closures (before Go 1.22), a shadowed `err` in an inner scope.
- **Java/Kotlin:** `==` on strings or boxed numbers, `Optional.get()` without a check, `!!` on values that can be null.
- **C#:** comparing floating-point money with `==`, `DateTime.Now` where UTC was meant, disposing objects still in use.
- **SQL:** `NOT IN` with a subquery that can return NULL (returns nothing), joins that multiply rows before a `SUM`.
- **React and JS:**
- `{count && <X/>}` renders "0" (and crashes React Native when outside `<Text>`).
- `key={index}` on mutable lists.
- Components defined inside components.
- Effects without abort or cleanup (stale responses overwrite newer ones).
- Effects with missing dependencies, often hidden behind `eslint-disable-next-line react-hooks/exhaustive-deps`: the screen keeps showing data for the previous ID.
- `.sort()` mutating props or state.
- `qty || 1` turning 0 into 1 (`||` where `??` was meant).
- Null assertions (`data()!`, `!.`) on documents that can be missing.
- Off-by-one in pagination.

**Locale bugs:**
- Parsing user input without normalizing Arabic-Indic digits (U+0660-0669, and the Persian forms U+06F0-06F9 that some Kurdish keyboard layouts type): `int.tryParse('١٢٣')` is null in Dart, `Number('١٢٣')` is NaN in JS, and an Arabic decimal separator breaks `float()` in Python. Type ٣ into a price field to prove it.
- `toLocaleDateString()` / `toLocaleString()` with no explicit locale and time zone (server and client disagree; hydration mismatch).

## 2. Data integrity

**Types:**
- **Money in floating point:** `double`, `REAL`, `float`, `parseFloat`, or `toFixed` used for prices or totals. IQD shown with 2 decimals. **Medium**, High when totals are summed over many sales.
- **Timestamps:**
  - Device-local strings (`DateTime.now().toString()`), `timestamp` without time zone, or client clocks used as truth for ordering or sync cursors.
  - Firestore `createdAt` not checked against `request.time`.
- **Numbers stored as text** (odometer, quantity, price): wrong sorting and comparisons.

**Schema:**
- Missing `not null`, `check` and `unique` constraints (e.g. `unique (shop_id, barcode)`).
- Foreign keys without a deliberate `on delete`.
- FK columns without indexes.

**SQLite specifics:**
- `PRAGMA foreign_keys = ON` missing, so `REFERENCES` and `CASCADE` silently do nothing.
- Calling `db.` inside `db.transaction((txn) ...)` in sqflite: it deadlocks.

**Migrations:**
- sqflite `version` bumped without `onUpgrade`, so existing installs never migrate. **Critical**: the app crashes or corrupts data for every existing customer. (A first-version database with `version: 1` and only `onCreate` is fine.)
- Shipped migration steps edited later (`git log -p` on the migrations).
- `onCreate` out of sync with the upgrade path.
- `RENAME COLUMN` / `DROP COLUMN` on old Android system SQLite.
- `NOT NULL` added without a default.
- A rename or drop shipped in the same release as the code switch.
- No upgrade tests from older versions.

**Offline sync (POS):**
- Is the local DB the ledger, with an outbox?
- Are IDs generated on the device (UUIDv7) and reused as server IDs? `AUTOINCREMENT` on synced tables collides across tills.
- Are deletes tombstones?
- Is the pull cursor server time?
- Is there an explicit oversell policy for two offline tills selling the last unit?
- Do Cloud Function triggers dedupe (at-least-once delivery)?

**Business records:**
- Paid sales editable or deletable. Voids and refunds should be new records with user and reason.
- No audit trail for discounts, price overrides and drawer opens.

**Backups:**
- None, or never test-restored.
- Raw `.db` copies without the `-wal` file.
- Android Auto Backup restoring a stale DB.
- Windows DB stored under OneDrive-synced Documents or Program Files.

## 3. Performance

**Database:**
- **Unbounded reads:** `collection(...).get()` / `.snapshots()` with no `limit`/`where`, `select('*')` with no range, `findMany()` with no `take`. Firestore bills every document read, so these are cost findings as well.
- **N+1:** an `await` inside a loop fetching one row or document per item; per-user queries in an admin page loop.
- **Indexes:** missing on FK columns and on columns used in RLS policies; RLS calling `auth.uid()` per row instead of `(select auth.uid())`; Firestore composite queries without `firestore.indexes.json`.

**Backend code:** blocking the event loop (Node) or the async runtime (Python, Rust) with CPU work or sync I/O; calls to other services in a loop instead of batched or parallel with a limit; no caching of expensive, rarely changing data; no timeouts, so one slow dependency stalls every request.

**Data code:** row-by-row Python loops over data frames where a vectorized or SQL operation fits; loading whole tables into memory to filter them; recomputing everything on each run where incremental processing fits.

**Flutter:**
- `FutureBuilder(future: fetch())` refetching on every rebuild.
- `ListView(children: rows.map(...))` over DB rows instead of `ListView.builder`.
- Reports computed in Dart instead of SQL.
- Undisposed controllers and subscriptions.

**React Native:** `ScrollView` + `.map()` over long lists (use FlashList/FlatList); unmemoized row components; full-resolution images in lists.

**Web:**
- Request waterfalls (sequential independent `await`s).
- `'use client'` on layouts or pages.
- Heavy libraries in the initial bundle.
- The LCP image lazy-loaded or set as a CSS background.
- Images without width/height (layout shift).
- Arabic fonts without subsetting.
- Render-blocking scripts.
- Thresholds: LCP ≤2.5 s, INP ≤200 ms, CLS ≤0.1 (p75). If you can run Lighthouse locally on a production build, report medians of 3 runs on throttled mobile; otherwise say "not measured". Never invent numbers.

## 4. UX, accessibility and RTL

**States and actions:**
- **Four states per async screen:** loading, empty, error and success. A spinner that never ends on error, a blank screen when there's no data, or raw error text are findings.
- **Double submit and destructive actions:** buttons stay enabled during requests; delete and void happen with no confirm or undo.

**Forms:**
- Placeholder-only inputs (no label).
- Missing `autocomplete` / `inputmode` / `keyboardType="numeric"`.
- Paste blocked; zoom disabled (`user-scalable=no`, `maximum-scale=1`).
- Errors not linked to their fields.
- No validation before submit.

**Keyboard and semantics:**
- `div`/`span onClick` instead of buttons.
- `outline: none` without a `:focus-visible` replacement.
- Positive `tabindex`.
- Icon-only buttons without labels (`aria-label`; React Native `accessibilityLabel`/`accessibilityRole`).
- Images without `alt`.
- Modals that aren't `<dialog>.showModal()` or a vetted library.

**Visual numbers:**
- Contrast 4.5:1 for text, 3:1 for large text (≥24 px, or ≥18.66 px bold), UI parts and focus rings.
- Touch targets ≥24 px, ideally 44-48.
- Reflow at 320 px wide.

**RTL** (critical for Kurdish and Arabic users):
- **Flutter:**
  - The whole app wrapped in `Directionality(textDirection: TextDirection.ltr)`. **Medium-High**: it breaks every screen.
  - `Locale('ckb')` with only the stock `GlobalMaterialLocalizations.delegates`. Flutter has no built-in `ckb` localizations. It warns that no MaterialLocalizations delegate supports `ckb`, widgets that need localizations throw, and the default WidgetsLocalizations lays the app out **LTR**. The fix is custom fallback delegates that load the Arabic localizations for `ckb`.
  - Physical layout: `EdgeInsets.only(left/right)`, `EdgeInsets.fromLTRB`, `Alignment.centerLeft`, `Positioned(left:)`, `TextAlign.left` (use the `...Directional` / `start`/`end` forms).
- **Web:** physical CSS (`margin-left`, `ml-`/`pl-`, `left:`, `text-align: left`); `dir` set client-side instead of in the HTML; `flex-row-reverse` added "for RTL" (double flip); directional icons not mirrored.
- **React Native:** `marginLeft`/`paddingLeft` instead of `Start`/`End`; RTL never tested with `forcesRTL`.
- **Text handling:**
  - Phone numbers, barcodes and amounts not isolated as LTR inside RTL text.
  - Search that doesn't normalize ي/ی and ك/ک.
  - Fonts missing Sorani letters (ڕ ڵ ێ ۆ ە).
  - `letter-spacing` on Arabic script.
  - Hardcoded English UI strings in a localized app.

**Sharing:** OG tags set client-side in an SPA (WhatsApp and Facebook previews come out blank), or a relative `og:image`.

**Desktop apps:** no keyboard navigation, blurry rendering at 150-200% scaling, windows that don't remember size and position, errors shown as raw exception dialogs, no progress for long operations.

**CLIs:** no `--help` or `--version`, errors as stack traces, exit code 0 on failure, data and messages mixed on stdout, destructive commands without confirmation or `--dry-run` (`../platforms/cli-scripts-automation.md` §2).

## 5. Tests and tooling

- **Run what exists:** build, type check, lint, tests. Report the exact commands and results. A red suite, or one that can't run, is a finding in itself.
- **Coverage of what matters:** are money math, stock updates, auth/permission checks, sync and migrations tested at all? No tests on those paths is **High** for a POS or payments app.
- **Fake tests** (the AI-written-test smells):
  - Assertions only on mocks (`toHaveBeenCalled`, `verify(`) with no real outcome checked.
  - A test that asserts the mock's own canned return value.
  - Expected values recomputed with the code's own logic.
  - Mocked query-builder chains (`from().select().eq()` as `jest.fn`), which pass whatever query was written.
  - `expect(true)`, `expect(true, isTrue)`.
  - `.only` / `.skip` / `skip: true` left in.
  - Async assertions without `await`.
  - Fixed sleeps (`waitForTimeout`, `Future.delayed`).
  - Giant snapshots nobody reads.
- **Mutation probe** (optional, and only with the user's OK, in a throwaway `git worktree`, never in their working tree): flip one condition in money or stock logic and run the tests. If they stay green, the tests don't protect that logic.
- **CI:**
  - Missing entirely, or never required before merge.
  - `continue-on-error: true` or `|| true` on test steps; `--passWithNoTests`.
  - `npm install` instead of `npm ci`; lint and type check absent.
  - Third-party actions not pinned to SHAs.
  - Production secrets available to PR jobs.
- **Lint and type strictness:**
  - No linter or type-checker config for the language (`analysis_options.yaml`, ESLint or Biome, Ruff and mypy/pyright, golangci-lint, clippy, .NET analyzers with warnings as errors, PHPStan, RuboCop); TypeScript not `strict`.
  - Suppressions piling up: `@ts-ignore`, `eslint-disable`, `// ignore:`, `as any`, `# type: ignore`, `# noqa`, `//nolint`, `#[allow(...)]`, `@SuppressWarnings`, `#pragma warning disable`.
  - Flutter lints missing: `unawaited_futures`, `use_build_context_synchronously`.
- **Hooks and hygiene:**
  - No versioned pre-commit hooks (`.husky/`, `lefthook.yml`, `.pre-commit-config.yaml`, `core.hooksPath`); a hooks folder that isn't versioned protects nobody.
  - No lockfile, or two lockfiles.
  - No `.gitattributes` on a Windows-developed repo.

## 6. Production readiness

**Crash and error reporting:**
- Flutter without `FlutterError.onError`, `PlatformDispatcher.instance.onError` and a release `ErrorWidget.builder`.
- Web without an error tracker or a root error boundary.
- Caught errors in sync, print and payment paths never reported.
- Crashlytics on Windows (unsupported) with no alternative.

**Environments:**
- One Firebase or Supabase project for everything (testing on production data).
- Stripe live keys used in development.
- No `.env.example`.
- Startup doesn't validate config.

**Release, mobile:**
- Release builds signed with the **debug key**: the Flutter template does this until `signingConfigs` is set. Grep `signingConfig signingConfigs.debug` / `getByName("debug")` in `android/app/build.gradle*`. **High.**
- Keystore and passwords committed, or not backed up anywhere. For sideloaded apps a lost key means every shop must uninstall and loses its local data.
- `com.example` application IDs.
- A build number that doesn't increase.
- No obfuscation, or debug symbols not archived.
- Store requirements missing: privacy policy, account deletion, data safety form.

**Release, web:**
- No preview environment, or no rollback path anyone knows.
- `"public": "."` in `firebase.json` (a security finding: see `security.md` §12).
- Catch-all rewrites placed before API rewrites.
- HTML cached as immutable.
- Missing `404.html` / SPA fallback.

**Release, services and containers:**
- No health or readiness endpoint, no graceful shutdown, no timeouts on outgoing calls.
- Config not validated at startup; secrets baked into images.
- No migration step in the deploy, or migrations run by hand.

**Release, desktop, CLIs and libraries:**
- Unsigned installers or binaries (SmartScreen and Gatekeeper warnings), no update path.
- No version number shown or `--version`, no changelog, breaking changes in minor versions.

**Operations:**
- No backups, or backups never restored.
- No health endpoint or version display.
- No uptime monitor or alerts.
- No runbook for the most likely incident (for a POS: "sales aren't syncing").

**Launch basics:**
- Missing title, description, `lang`/`dir`, favicon, OG tags.
- No `robots.txt` or sitemap.
- A staging `noindex` shipped to production.
- No privacy policy when collecting personal data.
- README without setup or run steps.

## 7. Maintainability

- **Size:** giant files, the classic vibe-coding tell:
  ```bash
  git ls-files -z '*.dart' '*.ts' '*.tsx' '*.js' '*.jsx' '*.vue' '*.svelte' '*.py' '*.go' '*.rs' '*.java' '*.kt' '*.cs' '*.php' '*.rb' '*.swift' '*.c' '*.cpp' \
    ':!:*.g.dart' ':!:*.freezed.dart' ':!:*.min.js' | xargs -0 wc -l | sort -rn | head -20
  ```
  Files over ~500-1000 lines doing several jobs.
- **Duplicated concepts:** two money formatters, two API clients, two date helpers, copy-pasted validation.
- **Leftovers:** dead code, `_unused` variables, commented-out blocks, compatibility shims, `// removed` comments.
- **AI tells:** narrating comments, generic names (`data`, `handleStuff`, `processData`), over-engineering (factories with one product, interfaces with one implementation and no test fake). Point to the `unslop-code` skill if installed.
- **Mixed patterns:** three state-management styles, two folder conventions, inconsistent error shapes.
- **History:** commits like "fix", "update", "wip"; giant mixed commits; untagged releases.

## 8. The launch verdict

Open the report with one line, choosing one of:

| Verdict | When |
|---|---|
| **Blocked** | Any Critical finding, or any of: sensitive data reachable without auth; live secrets in the repo, bundle or logs; payments that can be skipped or faked; data loss in normal use (non-atomic stock, migrations that don't run, swallowed sale failures) |
| **Risky: internal or pilot only** | High findings remain, or CI is red, or the critical path (the main user journey: a sale, a checkout, a sync, the CLI's main command) was never run end to end, or there's no rollback for a high-impact release |
| **Launchable with caveats** | Only Medium/Low findings, with the caveats listed |
| **Ready** | Nothing above Low, tests cover the paths that hurt (money, auth, data integrity, sync), crash reporting and backups verified |

Then list **Evidence checked** (files, commands and their results) and **Evidence missing** (consoles, devices, live URLs, deployed rules), and finish with **one concrete next action**. Green CI is not the same as production-ready, and saying so plainly is part of the job.
