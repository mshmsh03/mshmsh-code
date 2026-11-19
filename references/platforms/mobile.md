# Mobile apps: iOS and Android, native, Flutter, React Native/Expo

Read this when building a phone or tablet app in any framework. Offline use, local databases, sync and printers are in `../concerns/offline-first-and-sync.md`; right-to-left layout in `../concerns/localization-and-rtl.md`; signing, store submission and release tracks in `../build/shipping.md` §3; backend services such as Firebase and Supabase in `backend-and-apis.md`.

## Contents
1. Decide these before the first screen
2. Secrets and storage on devices
3. Permissions, background work and battery
4. App structure and state
5. Flutter code health
6. React Native and Expo
7. Native iOS and Android
8. Performance on real devices
9. Testing on devices

---

## 1. Decide these before the first screen

Offer each as options (SKILL.md "Decisions"):
- **Framework** (`../build/choosing-a-stack.md` §4): Flutter, React Native/Expo, native, or Kotlin Multiplatform.
- **Where the truth lives:** a server you call, a backend-as-a-service with access rules, or a local database that syncs (anything that must work offline).
- **Distribution:** App Store, Play Store, or sideloaded APKs (common for shop tablets). Sideloading changes signing, updates and device attestation (`../build/shipping.md` §3).
- **Minimum OS versions and devices,** including the cheapest phone or tablet the users actually own.
- **Languages, digits and currency** (`../concerns/localization-and-rtl.md` §1).
- **State management and architecture:** one approach, recorded in an ADR (section 4).
- **Push notifications, deep links, in-app purchases:** each brings platform setup and store rules; decide early whether they're in v1.

## 2. Secrets and storage on devices

- **"Use env vars" is web advice.** In apps, env values become constants inside the binary:
  - `--dart-define` and `String.fromEnvironment` compile into the app's native library.
  - A `.env` listed under `flutter: assets:` ships as a plain file.
  - `EXPO_PUBLIC_*` values and `app.config.*` `extra` are readable from the JS bundle.
  - `BuildConfig` fields, `Info.plist` and resource files are readable in any APK or IPA.

  **Paid or privileged keys must stay on a server** (a small proxy endpoint). Check what ships: `unzip -l app-release.apk`, then `strings` over the native libraries or `assets/index.android.bundle`.
- **Client identifiers that are meant to be public** (Firebase config, Maps keys) still need restricting in the provider's console (Android package plus signing-certificate SHA, iOS bundle ID), with quotas and budget alerts. Never ship an admin or service-account credential to get around access rules.
- **Tokens and PINs** go in the platform's secure storage (Keychain on iOS, Keystore-backed storage on Android): `flutter_secure_storage`, `expo-secure-store`, or the native APIs. Never `SharedPreferences`, `UserDefaults` or `AsyncStorage`. Never store passwords at all.
  - `flutter_secure_storage` on Windows needs the C++ ATL build component; exclude secure-storage files from Android Auto Backup.
  - `expo-secure-store` doesn't work on web. The iOS Keychain can survive an uninstall, so wipe stale entries on the first launch after a fresh install.
- **Device attestation** (App Check with Play Integrity or App Attest) blocks requests from tampered or unofficial clients. Sideloaded APKs can't pass Play Integrity's default "recognized by Play" check, and there's no built-in provider for Windows, so enforcing it can lock out your own tills: relax or skip enforcement for those. Keep debug tokens in debug builds only.
- **Release hardening:** no cleartext traffic (`usesCleartextTraffic="true"`, `NSAllowsArbitraryLoads`), no debuggable release builds, no exported Android components without a reason, HTTPS everywhere, and certificate pinning only if you have a plan for rotating certificates.

## 3. Permissions, background work and battery

- **Ask for a permission at the moment it's needed,** with a sentence saying why, and handle "denied" and "denied forever" with a path to settings. Request only what the feature needs; store reviewers reject unexplained permissions.
- **Every permission needs its declaration:** Android manifest entries (and runtime requests for dangerous permissions, notifications on Android 13+, Bluetooth on Android 12+), iOS purpose strings (`NS…UsageDescription`) that say why in plain words.
- **Background work is restricted and differs by platform.** Android 14+ requires a declared foreground-service type (for example `location`, `dataSync`); iOS allows only specific background modes and short tasks. Use the platform's schedulers (WorkManager, BGTaskScheduler, or the framework's wrappers) for deferred work, and never assume a timer keeps running in the background.
- **Phone makers' battery savers** (Xiaomi, Oppo, Huawei and others) kill background work aggressively. Test on those devices if background location or sync matters, and guide users to exempt the app when needed.
- **Location in the background** needs extra store declarations and a strong user-facing reason.

## 4. App structure and state

- **Layers:** UI → state/logic → repositories → data sources (local database, network). Repositories hide whether data comes from the local database or the server. The `flutter-apply-architecture-best-practices` skill covers Flutter's version of this.
- **Pick one state approach** and record it: Riverpod, Bloc or Provider in Flutter; TanStack Query for server data plus a small store in React Native; ViewModels with StateFlow (Android) or Observable models (SwiftUI) natively.
- **Model screen state as sealed classes or unions** with an exhaustive switch (`Loading | Empty | Error(message) | Data(items)`), not loose `isLoading`/`hasError` flags that allow impossible combinations.
- **Every async screen** has loading, empty, error and success states (`web.md` §3 applies to apps too).
- **Navigation and deep links:** validate route parameters before use; a deep link is untrusted input.
- **Lifecycle:** apps are paused, killed and restored at any time. Save drafts, restore state after process death, and never assume `main()` runs only once per session of use.

## 5. Flutter code health

- **Analyzer:** use strict analysis options (`../build/git-and-tooling.md` §1), including `unawaited_futures`. Wrap deliberate fire-and-forget calls in `unawaited()`.
- **`context` after an `await`** crashes navigation and dialogs; check `mounted` (or `context.mounted`) first.
- **Lifecycle:** dispose controllers, subscriptions and timers created in `initState`. Never call `.listen(` inside `build()`.
- **Futures:** don't create a future inside `build()` (`FutureBuilder(future: fetch())` refetches on every rebuild). Create it in `initState` or use a provider.
- **Lists:** `ListView.builder` for anything longer than a screen, never `ListView(children: rows.map(...))` over database rows. Use `const` constructors where possible.
- **Errors:** set `FlutterError.onError`, `PlatformDispatcher.instance.onError` and a release `ErrorWidget.builder` (`../build/shipping.md` §5). Every `FutureBuilder`/`StreamBuilder` handles `hasError`, not just loading and data.
- **Platform channels and plugins:** check each plugin's platform support (Android, iOS, web, Windows, macOS, Linux) before depending on it, and its maintenance status.

## 6. React Native and Expo

- **Lists:** use FlashList or LegendList, memoize rows and pass them primitive props, hoist `renderItem`, provide a `keyExtractor`, and keep scroll position in refs or Reanimated shared values, not `useState`. Use `expo-image` with thumbnails at about twice the display size.
- **Native crash traps:** `{count && <X/>}` with `0` or `""` renders a string outside `<Text>`, which crashes on native (on web it just shows "0"). So does a raw string directly inside a `<View>`. Use `count > 0 ? <X/> : null`, and enable `react/jsx-no-leaked-render`.
- **Effects that fetch** need an abort or ignore flag, so stale responses can't overwrite newer ones. Prefer TanStack Query.
- **Validate route and deep-link params** (zod or similar) before use, and run `tsc --noEmit` in CI.
- **Expo builds:**
  - Build profiles live in `eas.json`, and signing credentials stay on EAS or in a secure store.
  - Over-the-air updates are for JS and asset changes only, under a `runtimeVersion` policy; native changes need a store build.
  - Run `npx expo-doctor` and `npx expo install --check` before releases.
- **Background location** (a delivery or car tracker): `expo-location` with `expo-task-manager`, the Android `location` foreground-service type, Play's background-location declaration, and testing against aggressive battery savers.
- **The rest of React's rules** (`web.md` §9) apply: no components defined inside components, derived state computed during render, stable keys.

## 7. Native iOS and Android

**iOS (Swift, SwiftUI):**
- UI work on the main actor; use Swift concurrency (`async`/`await`, actors) instead of nested completion handlers.
- Keychain for secrets; `UserDefaults` only for preferences.
- Turn on strict concurrency checking where the Swift version supports it; data races are a top source of crashes.
- Privacy: purpose strings for every permission, and the privacy manifest for the APIs and SDKs that require it.

**Android (Kotlin, Jetpack Compose):**
- Survive configuration changes and process death: state in ViewModels with `SavedStateHandle`, not in activities.
- Coroutines with structured concurrency (`viewModelScope`, `lifecycleScope`); never `GlobalScope`.
- Keystore-backed encryption for secrets.
- R8/ProGuard rules for reflection-based libraries; test the minified release build, because shrinking bugs never show in debug.
- Room with exported schemas and migration tests for local data.

## 8. Performance on real devices

- **Test on the cheapest supported device,** not just a flagship or emulator. Profile in release or profile mode (Flutter DevTools, React Native's performance monitor and Hermes profiler, Android Studio and Xcode Instruments).
- **Startup:** defer non-essential work (analytics, remote config fetches, large database queries) until after the first frame.
- **Images:** decode at display size, cache, and use thumbnails in lists.
- **Lists of database rows** page or stream from the database; never load 100,000 rows into memory.
- **App size:** watch the download size per release; split per ABI (App Bundles do this) and remove unused assets and fonts.

## 9. Testing on devices

- **Logic** is tested on the host, without a device: domain functions, repositories against an in-memory database, state classes.
- **Widgets and components:** Flutter widget tests, React Native Testing Library, Compose UI tests, SwiftUI previews plus XCTest.
- **On-device journeys:** Flutter `integration_test`, Maestro (Flutter, React Native, native), Detox, Espresso or XCUITest. One journey per test, seeded data, no fixed sleeps.
- **Matrix before release:** the cheapest supported phone, the newest OS, a tablet if supported, right-to-left and large text, dark mode, permissions denied, no network, and the release build (not debug).
- **Backend rules** (Firestore rules, Supabase RLS) are tested against the emulator or a local stack with two users (`backend-and-apis.md` §6).
