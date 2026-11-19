# Shipping: environments, release, monitoring, launch

Read this before the first deploy and before every release, whatever the software is. SKILL.md Build §13 has the short version. Platform specifics live in `../platforms/` (desktop installers and signing in `../platforms/desktop.md` §3, CLI and package distribution in `../platforms/cli-scripts-automation.md` §8 and `../platforms/games-embedded-other.md` §4, firmware updates in `../platforms/games-embedded-other.md` §2).

## Contents
1. Environments and config
2. Deploying web apps and services
3. Releasing mobile and desktop apps
4. Feature flags, staged rollout and rollback
5. Monitoring, crash reporting, logs, alerts
6. Migrations without breaking installed apps
7. Launch checklist
8. The first hour after a release

---

## 1. Environments and config

- **Separate dev and prod completely:** separate databases, accounts or projects, credentials and storage buckets. For Firebase, one project per environment (`myapp-dev`, `myapp-prod`) with `.firebaserc` aliases (`firebase use dev`), and app flavors each with its own config files; for Supabase, separate projects; for your own servers, separate databases and secrets per environment. Never test against production data.
- **Payments:** the gateway's sandbox credentials and a test callback URL for dev and preview, live credentials only in production. With Stripe, each webhook endpoint has its own `whsec_` secret.
- **Secrets:**
  - `.env.example` is committed; `.env` never is.
  - CI secrets go in GitHub Secrets, and production secrets in the host's secret store. A GitHub Environment (`environment: production`) adds prod-only secrets plus a required reviewer.
  - CI that runs on pull requests never holds production secrets.
- **Validate config at startup and fail immediately when something is missing:** a schema over the environment (zod in JS, Pydantic settings in Python, envconfig in Go, options validation in .NET, `@ConfigurationProperties` validation in Spring); in Dart, a startup check that throws when any key from `--dart-define-from-file=env/prod.json` is empty. Don't use `assert`, which release builds strip. A missing key should crash at boot, not at the first payment.
- **Build-time config is baked in and public:** `NEXT_PUBLIC_*`, `VITE_*`, `EXPO_PUBLIC_*`, `--dart-define`, mobile build configs. A staging build can't be promoted to production; build once per environment, or load config at runtime.
- **Cap the bill:**
  - Set budget alerts (cloud providers, Supabase, AI providers). Firebase and most cloud budgets only alert; they don't stop spending.
  - Cap autoscaling. Firebase App Hosting `maxInstances` defaults high; set it low for a shop site.
  - Set hard spend limits at LLM providers.

## 2. Deploying web apps and services

**Pick the target with the user** (`choosing-a-stack.md` §7): static hosting, a platform service, serverless functions, containers, a plain server, or on-premises. Whatever the target:
- **Build once, test that artifact, deploy the same artifact** to staging and then production (a build folder, a container image tagged with the git SHA, a release binary).
- **Migrations run before the code that needs them,** as a separate, logged step (§6).
- **Zero-downtime deploys** where users are active: rolling or blue-green, with a health check gating traffic.
- **Containers:** small base images, a non-root user, no secrets baked into layers (pass them at runtime), pinned base image versions, and an image scan in CI.
- **A plain server (VPS):** a process manager (systemd, a container runtime), a reverse proxy with automatic TLS, automatic security updates, a firewall allowing only the needed ports, SSH keys instead of passwords, and backups copied off the machine.
- **Infrastructure as code** (Terraform, OpenTofu, Pulumi, the platform's config file) once there's more than a couple of resources, reviewed like code, with `plan` before `apply`.

The provider notes below cover common static and web hosts.


- **Build once, test it, ship those exact files.** Preview deploys for every PR (Netlify deploy previews, `firebase hosting:channel:deploy pr-123 --expires 3d`), then promote the tested build (`firebase hosting:clone <site>:<channel> <site>:live`) rather than rebuilding. Previews send `noindex`; production must not.
- **Firebase Hosting:**
  - `public` points at the build output (`dist`, `build/web`), never `.`, which would publish your source tree.
  - Put `/api/**` rewrites **before** the SPA catch-all.
  - Never run a bare `firebase deploy`; it also pushes rules, functions and indexes. Use `--only hosting`.
- **Netlify:**
  - Set env vars per deploy context (`[context.production]`, `[context.deploy-preview]`).
  - SPA rule in `_redirects`: `/* /index.html 200`.
  - Headers go in `_headers` or `netlify.toml`. Check them on the live site, not just in config.
- **GitHub Pages:**
  - No custom headers (no real CSP; `frame-ancestors` can't be set), and the cache time is fixed.
  - Deep links 404 unless `index.html` is copied to `404.html` or you use a hash router.
  - Next.js there means `output: 'export'`: no Server Actions, middleware or ISR, and `next/image` needs `unoptimized`.
  - A Pages site from a private repo is still public.
- **Cache headers:** HTML `no-cache`; hashed assets `public, max-age=31536000, immutable`.
- **Deploys delete old chunks that open tabs still request.** Reload once on `vite:preloadError` / `ChunkLoadError`. Watch for a missing `.js` coming back as `index.html` with status 200 under an SPA catch-all.
- **Agents deploy to preview by default.** Production happens only when the user explicitly asks; ask before any push that triggers a deploy.

## 3. Releasing mobile and desktop apps

**Accounts belong to the client:**
- Publish client apps from the client's own developer accounts, with you invited as admin. An organization account needs a D-U-N-S number.
- The same goes for the Firebase or Supabase project, the domain and billing, so the client isn't stuck if you part ways.
- New *personal* Google Play developer accounts must run a closed test with at least 12 testers for 14 days before they get production access. Organization accounts are exempt. Plan the timeline around that.

**Android signing:**
- The Flutter template signs release builds with the **debug key** until you configure `signingConfigs`. Fix that before the first release.
- Create the upload key once:
  ```bash
  keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
  ```
- Keep the keystore, its passwords and the alias out of git, in a password manager plus an offline encrypted copy.
- On Google Play, enroll in Play App Signing so a lost upload key can be reset.
- **For sideloaded APKs (common for shop tills) a lost key is unrecoverable.** The next build won't install over the old one, the shop must uninstall, and it loses its local data.

**Versions and IDs:**
- In `version: 1.4.0+27` (Flutter), the `+27` is the build number and must exceed every build ever shipped; Android blocks downgrades. Set it from CI (`--build-number=$GITHUB_RUN_NUMBER`).
- Expo uses `android.versionCode` / `ios.buildNumber`, or EAS auto-increment.
- Never ship `com.example.*` application IDs: Play rejects them, and IDs are permanent.

**Flutter release builds:**
- Build with `flutter build appbundle --obfuscate --split-debug-info=build/symbols/<version>`. Archive the symbols for every version (not in git) and upload them to Crashlytics.
- Tap through the **release** build on a real low-end device. Obfuscation and R8 bugs never show in debug.

**Expo:**
- `eas update` ships only JS and assets. Native dependencies, permissions and SDK upgrades need a new store build.
- Set a `runtimeVersion` policy so an update never lands on an incompatible binary.
- Run `npx expo-doctor` and `npx expo install --check` before each release.

**Native iOS and Android:** archive and upload with Xcode or Fastlane (TestFlight), and `bundleRelease` with Gradle for Play; keep signing in CI secrets or a managed signing service, never in the repo.

**Windows desktop (Flutter):**
- Ship the whole `build\windows\x64\runner\Release` folder plus the VC++ runtime DLLs (`msvcp140.dll`, `vcruntime140.dll`, `vcruntime140_1.dll`).
- Package it as an MSIX or with Inno Setup, code-sign it, and test on a clean VM.

**Other desktop frameworks** (Electron, Tauri, .NET, Qt, macOS): signing, notarization, installers and auto-update are in `../platforms/desktop.md` §3.

**Updates outside the stores:** sideloaded APKs and Windows tills never auto-update. Either ship a version check against a JSON file you host (latest version, minimum supported version, download link), or use an MSIX with an `.appinstaller` file on Windows.

**Store requirements:**
- A privacy policy URL.
- The Play Data safety form, declaring what Crashlytics and Analytics collect.
- In-app account deletion when users can create accounts.
- Apple's privacy manifest and permission purpose strings.
- Play's target-API deadline, which moves every year (API 36 from 31 Aug 2026).
- 16 KB memory page support, required for Play submissions targeting Android 15+ since Nov 2025. Apps without native code are fine; plugins that ship `.so` files (SQLite/SQLCipher builds, printer, scanner and payment SDKs) need versions built for it. Play Console lists the libraries that fail.

**Tracks:**
- Android: internal testing → closed testing → staged production rollout (5% → 20% → 50% → 100%).
- iOS: TestFlight → phased release, which can be paused.
- Halting a rollout doesn't uninstall updates that already went out.

## 4. Feature flags, staged rollout and rollback

- **A shipped binary can't be rolled back.** Put risky features (the sync engine, printing, payments) behind a flag whose **in-app default is the safe state**. Offline tills can run on stale flag values for days.
- **Remote Config:**
  - Ship in-app defaults.
  - At startup, activate the values fetched last time and fetch new ones in the background, so behaviour never changes mid-sale.
  - Never put secrets in Remote Config; clients can read it.
  - Keep the template in git: `firebase remoteconfig:get -o remote_config.json`, then review changes before deploying.
- **Forced update:** a `min_supported_build` value shows an update screen. It must never stop a shop from selling while offline.
- **Flag lifecycle:** deploy with the flag off → turn it on for the team → 5% → 25/50/100%. Delete the flag and its dead code within about two weeks. Every flag has an owner, and flags are never nested.
- **Rollout gates:**
  - **Advance** while crash-free users and the error rate hold steady.
  - **Hold** if errors rise 10-100%.
  - **Roll back** at 2x the baseline error rate or above, or when a new error type affects more than 0.1% of sessions.
- **Write the rollback plan before deploying:** the trigger, the steps, what happens to data, and how long it takes. Rough times: flag off <1 min, web redeploy <5 min, database restore <15 min.
  - **Firebase Hosting:** roll back from the release history.
  - **Netlify:** publish an older deploy.
  - **Vercel:** `vercel rollback`.
  - **Mobile:** halt the rollout, turn the flag off, then ship a fix with a higher build number.

## 5. Monitoring, crash reporting, logs, alerts

Before instrumenting, write the 2-4 questions you'll ask during an incident ("are sales syncing?", "which shops crash since 1.5?"). Every signal should help answer one.

Use the error tracker that fits the stack (Sentry, Crashlytics, Bugsnag, Rollbar, the cloud provider's error reporting), with the release version attached to every report and source maps or symbols uploaded so stack traces are readable.

**Flutter crash reporting:**
```dart
// Crashlytics supports Android/iOS (not Windows or web), and Windows builds share main.dart.
final crashlytics = !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
if (crashlytics) {
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (e, s) {
    FirebaseCrashlytics.instance.recordError(e, s, fatal: true);
    return true;
  };
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
}
```
- Add a release `ErrorWidget.builder` that shows a friendly screen instead of the grey or red box.
- POS bugs mostly surface as **caught** errors. Report them: `recordError(e, s, reason: 'sync_push_failed')` in sync, print and payment paths.
- Leave breadcrumbs with `FirebaseCrashlytics.instance.log()`.
- Set custom keys: version, opaque shop ID, schema version, online/offline, pending-queue size.
- Prove the pipeline once: force a test crash, relaunch the app (reports send on the next launch), confirm it shows up in the console, then remove the crash.
- Crashlytics doesn't support Windows desktop. Use Sentry there (`sentry_flutter`) or log to a file the owner can send you.

**Web:**
- Wrap the app in a root error boundary and add `error`/`unhandledrejection` listeners that report to Sentry or a similar service.
- Make source maps `hidden` and upload them to the error tracker; never serve them publicly.

**Services and jobs:** an error tracker in every process, request IDs in logs, metrics for rate, errors and latency, and alerts on failed or missing scheduled jobs (`../platforms/backend-and-apis.md` §8).

**Desktop and CLI tools:** a crash reporter or a log file the user can send, with the version and OS in every report.

**Logs:**
- Use structured events (a stable event name plus fields), never interpolated prose.
- Levels: error = an invariant broke, warn = degraded but handled, info = business event. Debug is off in production.
- Put a request or correlation ID on every line.
- Never log tokens, passwords, full request bodies or patient/customer names; use opaque IDs.

**Alerts:**
- Alert on what users feel, not on causes like CPU: error rate above 1% for 5 minutes, crash-free users dropping, the sync backlog getting old.
- Every alert must be actionable and link a three-line runbook: what it means, what to check first, who to call.
- Turn on Crashlytics' new-fatal and regression alerts.

**Know what's running:** a health endpoint that returns the version and git SHA, and the app version and build on an About screen.

**Uptime:** an external monitor on the main URL and the health endpoint. After each deploy, check for status 200, key elements present, assets returning 2xx with the right content type, and no new console errors.

## 6. Migrations without breaking installed apps

- **Expand → migrate → contract:**
  1. Add the new field as nullable and write both old and new.
  2. Backfill in small, re-runnable batches.
  3. Switch reads over.
  4. Drop the old field in a later, separate release.

  Additions can ship any time; drops and renames ship alone.
- **Mobile stretches this to months.** Old app versions keep writing the old shape:
  - Firestore readers tolerate missing or extra fields, and rules accept both shapes.
  - Writes carry `clientVersion` / `schemaVersion`.
  - The old shape is removed only when analytics shows almost no old clients.
- **On-device SQLite:**
  - Migrations are forward-only, numbered, and never edited once shipped.
  - Back up the DB before upgrading, with `VACUUM INTO` or the backup API. A plain file copy misses the `-wal` file.
  - Test the upgrade from **every** shipped version (users jump from v3 straight to v9), using a committed fixture DB for each released schema.
  - Assert that a fresh install's schema equals an upgraded one.
  - See `../concerns/offline-first-and-sync.md` §4 for the mechanics.
- **Server databases:**
  - Keep schema (DDL) and data (DML) migrations separate.
  - Test on production-sized data.
  - Back up first (Firestore scheduled backups or point-in-time recovery; Supabase backups).
  - In production, a rollback is a new forward migration unless a tested `down` exists.
- **Deprecations:**
  1. Prove the replacement in production first.
  2. Announce a removal date and migrate the consumers yourself.
  3. Confirm zero usage, then delete the code, tests, docs and config.
  4. Record the removal in the context file so agents don't recreate it.

## 7. Launch checklist

Use the sections that fit what you're shipping; every kind of software gets the "Every release" list.

**Every release:**
- The full test suite and the build green in CI on the exact commit being released.
- A pre-mortem done, and its launch-blocking risks closed (`decisions-and-problem-solving.md` §10).
- The rollback plan written (§4), backups taken and restorable (§6).
- Monitoring proven with a test error (§5), and someone named to watch the first hour (§8).
- Version number, changelog and release notes written; signing keys backed up.
- An Audit-mode run on the release candidate, with no Critical findings.

**APIs and services:** health checks, rate limits, timeouts, pagination, structured logs without personal data, alerts that reach a person, and documented API changes for clients (old app versions keep calling the old shapes).

**Mobile and desktop apps:** the release build tested on the cheapest supported device and a clean machine, store listings and privacy forms complete (§3), the forced-update path tested, and offline behaviour checked.

**CLIs and libraries:** `--help` and `--version` correct, install tested from the published package in a clean environment, changelog and migration notes for breaking changes.

**Every web page:**
- A unique `<title>` and meta description, and a self-referencing canonical.
- `<meta charset>` first, then the viewport tag.
- `<html lang dir>` set correctly (for example `lang="ckb" dir="rtl"` for Sorani, `lang="ar" dir="rtl"` for Arabic).
- One `<h1>` and a sensible heading order.
- hreflang for each language version, plus `x-default`.

**Sharing previews** (WhatsApp, Facebook and Telegram scrapers don't run JS):
- `og:title`, `og:description` and an **absolute** `og:image` (~1200×630) in the served HTML, plus `og:locale`.
- A client-rendered SPA shows blank previews unless those pages are prerendered.
- Test by pasting the link into the apps.

**Discoverability:**
- A `robots.txt` that doesn't block CSS or JS. Watch that a staging `Disallow: /` doesn't ship to production.
- A `sitemap.xml` of canonical URLs, submitted in Search Console.
- `LocalBusiness` structured data (`Restaurant`, `Store`, `Pharmacy`) with address, phone, opening hours and geo, matching what's visible on the page. Validate it with the Rich Results Test.

**Performance budget:**
- LCP ≤ 2.5 s, INP ≤ 200 ms, CLS ≤ 0.1.
- Initial JS ≤ ~200 KB gzipped.
- Test on a mid-range Android with CPU throttling. Details in `../platforms/web.md` §7 and §12.

**Legal and trust:**
- A privacy policy that names what's collected (Analytics and Crashlytics included), how long it's kept, and a contact.
- A working account-deletion path that also covers backups and analytics copies.
- Cookie consent only if you actually set non-essential cookies.

**Analytics:** a handful of named events that answer launch questions (for a shop app: `sale_completed`, `sync_failed`, `receipt_printed`), with no personal data in the parameters.

**Error pages:** a real 404 page, a friendly 500 page, and an offline screen for apps.

**Basics:** favicon and app icons, `theme-color`, and the right contact details everywhere.

**Last:** run Audit mode on the release candidate.

## 8. The first hour after a release

Release when someone can watch: not right before your day off (in Iraq the weekend is Friday-Saturday), and not right before a client's busiest hours. For the first hour:
- the health check returns 200
- no new error types appear
- crash-free users hold steady
- you've run through the critical flow by hand (for a shop app: make a sale, sync, print)
- logs are flowing

Tell the client what changed, in plain words, and how to reach you.
