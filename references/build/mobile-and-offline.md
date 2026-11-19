# Mobile, desktop and offline-first apps (Flutter, Expo/React Native, Firebase, SQLite)

Read this when building a phone, tablet or Windows app, especially a POS that must keep selling without internet. SKILL.md "Stack rules" has the short version.

## Contents
1. Decide these before the first screen
2. Offline-first architecture (local ledger + outbox)
3. Firestore and Firebase Auth from the app
4. Local SQLite: transactions, migrations, backups
5. Money and IQD
6. POS integrity: sales, stock, audit, cashiers
7. Receipt printing and barcode scanners
8. Kurdish/Arabic RTL in Flutter and React Native
9. Secrets and storage on devices
10. Flutter code health
11. Expo / React Native specifics
12. Testing offline apps

---

## 1. Decide these before the first screen

- **Where does the truth live?** For anything that must work offline (a till, a pharmacy counter), the **local database is the source of truth** and the cloud is a sync target. Firestore's offline cache is a cache, not a ledger: it can be evicted, and pending writes disappear on "clear data" or uninstall.
- **Windows tills:** Firebase's own docs say its desktop SDK support on Windows isn't meant for production. A Windows POS needs SQLite as its ledger plus a separate sync path (an HTTPS Cloud Function, or the Firestore REST API with Auth REST tokens). Plan this before writing screens.
- **Several tills, live stock, no internet?** Cloud sync can't do that. Either accept eventual consistency with an oversell policy (section 6) or add a LAN hub (one PC serving the others).
- **Distribution:** Play Store, App Store, or sideloaded APKs. Sideloading changes App Check (section 9 here) and signing and updates (`shipping.md` §3).
- **Languages, digits and currency** (section 5 and section 8). Agree these with the client up front.
- **State management:** pick one approach (Riverpod, Bloc or Provider in Flutter; TanStack Query plus a small store in RN) and record it in an ADR. Model screen state as sealed classes or unions with an exhaustive switch, not loose `isLoading/hasError` flags.

## 2. Offline-first architecture (local ledger + outbox)

- **Screens read only from the local DB** (drift `watch()` streams, or sqflite with a stream layer). No network call sits between "Pay" and the receipt.
- **One transaction per sale.** The sale, its line items, its stock movements and an **outbox row** are written together. Outbox row: `op_id, entity, entity_id, op, payload_json, attempts, last_error, created_at`.
- **A sync worker drains the outbox in order** with exponential backoff plus jitter, and deletes a row only after the server acknowledges it.
- **IDs are created on the device:** `const Uuid().v7()` in Dart (time-ordered, which is good for SQLite indexes). In JS/Expo, use `v7()` from the `uuid` package with `import 'react-native-get-random-values'` first. `expo-crypto`'s `randomUUID()` gives v4, which is unique but not time-ordered. The same ID becomes the Firestore document ID or the server's idempotency key, so a retry can never double a sale. Never use `AUTOINCREMENT` IDs for synced tables: two tills will both create sale #57.
- **Receipt numbers are separate from sync IDs:** a per-device prefix plus a local counter (`T2-000123`), allocated inside the sale transaction.
- **Deletes are tombstones** (`deleted_at`); hard deletes never propagate.
- **Pull changes with a server-written cursor** (`updatedAt` set by `FieldValue.serverTimestamp()` or the server), never device time; till clocks are often wrong. Warn when the device clock is minutes off server time.
- **Mixed app versions:** tills run different builds for weeks. Payloads carry `schemaVersion`, the server accepts older clients, and a Remote Config `min_app_version` triggers an update screen. Sideloaded apps never auto-update.
- **Show sync health** in the UI: unsynced sales count and last successful sync time. Owners trust what they can see.
- **Cloud Function triggers run at least once.** Aggregates (stock totals, daily sums) need an idempotency marker: create `processed/{movementId}` in a transaction before applying a change.

## 3. Firestore and Firebase Auth from the app

- **Transactions fail offline** (`runTransaction` needs the server). For writes that must work offline, use `WriteBatch` and `FieldValue.increment()`, or the local ledger above.
- **Awaiting a write waits for the server.** `await doc.set(...)` doesn't complete until the server acknowledges it, so an awaited write in the checkout path freezes the till offline. In UI code that writes Firestore directly, fire the write with `unawaited()` and watch `hasPendingWrites`. The outbox worker is the exception: it awaits, because the completed Future is the server's ack that lets it delete the outbox row, and it runs off the checkout path. Confirm both with an airplane-mode test. SQLite and HTTP calls are always awaited, with errors handled.
- **A pending `serverTimestamp()` reads back as null** in local snapshots, so `as Timestamp` casts crash right after a write. Handle null.
- **Use the client ID as the doc ID:** `doc(saleId).set(...)`, never `.add(...)` inside retry or catch code.
- **Read costs:** every document read is billed. A dashboard listening to all `sales` is re-billed on every change. Keep per-day summary docs or use aggregation queries, and set a budget alert. Always `limit()` queries and paginate with `startAfterDocument`.
- **Composite indexes:** `where` plus `orderBy` on another field needs one. Keep `firestore.indexes.json` in git and deploy it with `--only firestore:indexes`. Sorting on the client is a prototype shortcut.
- **Offline cache:** the default size is 100 MB. Set `cacheSizeBytes` deliberately.
- **Error handling:** catching errors, printing them and returning `[]` makes "permission denied" look like "no data". Show the error state and report it.
- **Re-run `flutterfire configure`** after changing the application or bundle ID or adding Firebase plugins.
- **Auth:**
  - Let the SDK manage the session and call `getIdToken()` per request. Hand-stored tokens expire after an hour.
  - Roles come from custom claims, set server-side.
  - Staff-only apps should disable public sign-up, because the public API key lets anyone create accounts through the Auth REST API.

## 4. Local SQLite: transactions, migrations, backups

**Basics:**
- **Foreign keys are off by default** in SQLite, per connection. Turn them on in sqflite's `onConfigure`: `await db.execute('PRAGMA foreign_keys = ON')`. Without that, `REFERENCES` and `ON DELETE CASCADE` do nothing. Once they're on, never upsert parents with `ConflictAlgorithm.replace` / `INSERT OR REPLACE`: REPLACE deletes the old row first, which cascades to its sale items. Use `ON CONFLICT ... DO UPDATE` instead.
- **Power cuts** are common at shop tills. If you enable WAL mode on a Windows till, keep `PRAGMA synchronous = FULL`: with `NORMAL`, a committed sale can roll back after power loss, even though its receipt already printed. Recommend a UPS to the client.
- **sqflite deadlock:** inside `db.transaction((txn) async { ... })`, use `txn` only; calling `db.` in there hangs. `onCreate` and `onUpgrade` already run inside a transaction.
- **Bulk imports** (product catalogue): `batch.commit(noResult: true)` inside one transaction.
- **Indexes:** `UNIQUE(barcode)` (or a `product_barcodes` table for several barcodes per product), `sale_items(sale_id)`, `sales(created_at)`. Check them with `EXPLAIN QUERY PLAN`. Build reports in SQL (`SUM ... GROUP BY date(created_at)`), not by loading rows into Dart.
- **Search:** a `search_key` column holding normalized text (section 8), `LIKE ? ` with bound args, never string interpolation.

**Platform notes:**
- **Windows:** sqflite has no Windows backend. Use `sqflite_common_ffi` (`sqfliteFfiInit(); databaseFactory = databaseFactoryFfi;`) or drift (`drift_flutter`'s `driftDatabase()` covers Android, iOS, macOS, Linux and Windows).
- **Windows DB location:** `getApplicationSupportDirectory()`. Never Documents, which is often OneDrive-synced and corrupts an open DB, and never `Directory.current`, which may be read-only Program Files.
- **SQLite version varies with the device.** sqflite uses the phone's built-in SQLite: `RENAME COLUMN` needs 3.25, `VACUUM INTO` 3.27, `DROP COLUMN` 3.35, `STRICT` tables 3.37. On old Android tablets, rebuild tables instead (create new → copy → drop → rename), or use `package:sqlite3`/drift, which bundles a current SQLite.

**Migrations:**
- sqflite:
  ```dart
  onUpgrade: (db, from, to) async {
    for (var v = from + 1; v <= to; v++) {
      await steps[v](db);
    }
  }
  ```
  Bumping `version` without `onUpgrade` means existing installs never migrate.
- drift: `dart run drift_dev make-migrations` generates schema snapshots, step-by-step helpers and migration tests.
- expo-sqlite: `PRAGMA user_version` inside `SQLiteProvider`'s `onInit`.
- **Rules:**
  - Never edit a shipped step.
  - Back up the DB before migrating, with `VACUUM INTO` or the backup API. A plain copy of the `.db` file misses the `-wal` file.
  - Keep `onCreate` equivalent to running all the steps, and test it: compare `SELECT sql FROM sqlite_master` from a fresh install against an upgraded one.
  - Commit a fixture DB from each released version and test upgrading it to current.

**Backups and export:**
- Back up on a schedule with `VACUUM INTO '<file>'` or the SQLite backup API. Copying the `.db` file without its `-wal` file loses the latest sales.
- Keep an off-device copy (the owner's Drive, a USB stick, or Storage under the shop's path), and a restore flow tested on a clean install.
- Accountant exports: CSV with ASCII digits, no thousands separators, ISO dates, and UTF-8 **with BOM** so Excel shows Arabic script correctly.
- Decide Android Auto Backup on purpose (`allowBackup`, `dataExtractionRules`). It can restore a stale DB, or secure-storage data that can no longer be decrypted.
- For shared PCs or rooted phones holding pharmacy or customer data, consider SQLCipher (`package:sqlite3` hook options or `sqflite_sqlcipher`), with the key in secure storage.

## 5. Money and IQD

- **Integers end to end.** Store minor units, or for IQD whole dinars, plus a currency code. Never `double`, `REAL`, `parseFloat` or `toFixed` for prices and totals. In Dart, `1.005 * 1000` gives `1004.9999999999999`.
- **One money module** with integer math (e.g. `(amount * pct + 50) ~/ 100` for percentages), one rounding function, and a decision made once: round per line or per invoice. Table-driven tests cover 100% discount, quantity 0, refunds and split payments.
- **Derive totals from line items** in a pure function. Never keep a separate `total` in state, where it can drift.
- **IQD has no practical subunit.** ISO 4217 lists 3 decimals, CLDR and `intl` use 0, and formatters silently round fractions.
  - Flutter: `NumberFormat.currency(locale: 'ar', name: 'IQD', decimalDigits: 0)`. Plain `locale: 'ar'` defaults to EGP with `.00`.
  - Web/RN: `new Intl.NumberFormat('ar-IQ', { style: 'currency', currency: 'IQD', maximumFractionDigits: 0 })`. `ar-IQ` and `ckb` give Arabic-Indic digits; plain `ar` gives Western digits. Create formatters once, at module level.
- **Cash rounding** to the smallest note in circulation is its own visible line on the receipt, never hidden inside the total.
- **Dual currency (USD + IQD):** store each payment in its own currency, snapshot the exchange rate on each sale as an integer (`iqdPerUsd`), allow change in the other currency, and report both on the end-of-day report.

## 6. POS integrity: sales, stock, audit, cashiers

- **A paid sale is immutable.** Voids and refunds are new rows with a reason, the user and the time. Log discounts, price overrides and drawer opens. This audit trail is the owner's anti-theft tool.
- **Stock is a sum of append-only movements** (sale, return, receive, adjust, transfer), not one `quantity` field synced last-write-wins, which silently erases a sale. Two offline tills *can* sell the last unit, and no check can stop that offline. Choose a policy explicitly:
  - allow negative stock, with an "oversold" alert to the owner
  - or require online confirmation for chosen products
- **Online stock decrements** are atomic: a Firestore transaction or `FieldValue.increment(-qty)`, or SQL `UPDATE ... SET stock = stock - ? WHERE id = ? AND stock >= ?`. Never read, compute, write.
- **Cashiers:**
  - PINs are salted and hashed with a slow KDF, with lockout after failed attempts.
  - Permissions (void, discount, see profit, open the drawer) are enforced in code and rules, not just by hiding buttons.
- **End-of-day (Z) report:** totals per payment method and currency, expected vs counted cash, locked after closing.
- **Pharmacy:**
  - Record batch and expiry on stock movements and sell first-expiring first.
  - Store box/strip/unit conversions as integer base units.
  - Warn on expired and near-expiry stock at the counter.
- **Double taps:** "Complete sale" disables while processing, and the sale ID is created once when the sale starts, so a double tap or a retry can't create two sales.

## 7. Receipt printing and barcode scanners

**Thermal printers:**
- Their code pages can't shape Arabic script or show Sorani letters (ڕ ڵ ێ ۆ ە). Print the receipt as an **image**:
  1. Render the receipt widget with `RenderRepaintBoundary.toImage()`.
  2. Scale it to the printer's dot width (typically 384 for 58 mm, 576 for 80 mm).
  3. Threshold it to 1-bit.
  4. Send it with the ESC/POS raster command (`GS v 0`).
- The cash drawer kick is `ESC p`.

**A4 invoices and Windows driver printers:** use the `pdf` + `printing` packages with an embedded Arabic-script TTF and `pw.TextDirection.rtl`. The built-in PDF fonts have no Arabic glyphs.

**Transports:**
- Bluetooth Classic (most cheap printers; iOS can't use them without MFi certification), BLE, USB, or LAN (raw TCP on port 9100).
- Android 12+ needs the runtime permissions `BLUETOOTH_CONNECT` and `BLUETOOTH_SCAN`.

**Print only after the sale commits.** Offer a reprint button. A print failure must never create a second sale. Test with the printer off, out of paper, a 40-character Kurdish product name and a 60-line receipt.

**USB/HID barcode scanners** type fast and end with Enter:
- Keep the scan field focused, or use a global key handler (`HardwareKeyboard`, `Focus(onKeyEvent:)`). Dialogs that steal focus drop scans.
- Under an Arabic or Kurdish OS keyboard layout, scanned letters may arrive as Arabic characters. Test with the shop's real keyboard setting.

## 8. Kurdish/Arabic RTL in Flutter and React Native

**Flutter has no built-in Kurdish (`ckb`) localizations.** `kMaterialSupportedLanguages` has no `ckb` or `ku`. With `Locale('ckb')`, Material and Cupertino widgets get no localizations and the app renders **left-to-right** (the log warns "locale ckb is not supported by all of its localization delegates").
- Fix it with fallback delegates whose `isSupported` accepts `ckb` and whose `load` returns the Arabic localizations (`GlobalMaterialLocalizations.delegate.load(const Locale('ar'))`). Do the same for Cupertino, and for Widgets, which supplies RTL.
- Supply Sorani month and day names yourself; `intl` has no `ckb` or `ar_IQ`.
- Re-check after Flutter upgrades.

**Never wrap the app in `Directionality(textDirection: TextDirection.ltr)`** to fix one layout. Fix the layout instead.

**Directional widgets everywhere** (grep for the physical ones):

| Use | Not |
|---|---|
| `EdgeInsetsDirectional` | `EdgeInsets.only(left:/right:)`, `fromLTRB` |
| `AlignmentDirectional` | `Alignment.centerLeft` etc. |
| `PositionedDirectional` | `Positioned(left:/right:)` |
| `BorderRadiusDirectional` | `BorderRadius.only(topLeft:...)` |
| `TextAlign.start` / `.end` | `TextAlign.left` / `.right` |

Mirror back arrows and chevrons; leave logos, media controls and checkmarks unmirrored.

**Digits:**
- `int.tryParse('١٢٣')` returns null in Dart, and `Number('١٢٣')` is NaN in JS. Normalize Eastern Arabic (U+0660-0669) and Persian (U+06F0-06F9) digits to ASCII at the input boundary, before parsing or validating.
- Display digits are a client setting (Western or Arabic-Indic). Storage, APIs, exports and barcodes stay ASCII.

**Search:**
- Arabic keyboards type ي and ك; Kurdish text uses ی and ک. Normalize both sides (ك→ک, ي/ى→ی), handle ة/ه per the client's spelling, and strip diacritics and tatweel (ـ).
- Store the normalized form in a `search_key` column.

**Fonts:**
- Bundle one font that covers Sorani letters (ڕ ڵ ێ ۆ ە ڤ پ چ ژ گ) and set it in `ThemeData.fontFamily`; verify by rendering a real Kurdish sentence.
- Arabic script needs more line height and clips in fixed-height boxes, so test at 1.3x text scale. No letter-spacing on Arabic script.

**Mixed direction:**
- Phone numbers, barcodes, SKUs and amounts with units ("25,000 د.ع") inside RTL text go in an LTR island: Unicode isolates U+2066…U+2069, or a `Directionality(textDirection: TextDirection.ltr)` subtree.
- Phone and barcode inputs use `TextField(textDirection: TextDirection.ltr)`.

**React Native / Expo:**
- Recent SDKs support RTL by default; `expo-localization`'s config has `supportsRTL` / `forcesRTL`.
- `I18nManager.forceRTL()` takes effect on the next start, so call `Updates.reloadAsync()` after it.
- Use `marginStart/End`, `paddingStart/End` and `start/end`, never `marginLeft` etc.
- Walk every screen with RTL forced on.
- Hermes relies on the device's locale data, so check `Intl` output for `ckb` on a real low-end Android.

**Tests:** run widget and golden tests under `Directionality(textDirection: TextDirection.rtl)`, with the real fonts loaded (unregistered fonts render as boxes).

## 9. Secrets and storage on devices

- **"Use env vars" is web advice.** In apps, env values become constants inside the binary:
  - `--dart-define` and `String.fromEnvironment` compile into `libapp.so`.
  - A `.env` listed under `flutter: assets:` ships as a plain file.
  - `EXPO_PUBLIC_*` and `app.config.*` `extra` are readable from the bundle.

  **Paid or privileged keys must stay on a server** (a Cloud Function proxy). Check what ships: `unzip -l app-release.apk`, and `strings` over `lib/arm64-v8a/libapp.so` or `assets/index.android.bundle`.
- **Firebase config and Maps client keys are public identifiers.** Restrict them in Google Cloud (Android package + SHA-1, iOS bundle ID) and set quotas and budget alerts. Never ship an Admin SDK service-account JSON to "get around" rules.
- **Tokens and PINs** go in `flutter_secure_storage` or `expo-secure-store`, never `SharedPreferences` or `AsyncStorage`. Never store passwords at all.
  - `flutter_secure_storage` on Windows needs the C++ ATL build component. Exclude it from Android Auto Backup.
  - `expo-secure-store` doesn't work on web. On iOS the Keychain can survive an uninstall, so wipe stale entries on the first launch after install.
- **App Check with sideloaded APKs:** they can't pass Play Integrity's default "recognized by Play" check, and there's no built-in Windows provider. Enforcing App Check can lock out your own tills; relax the requirement or don't enforce for those. Keep debug tokens inside debug builds only (`buildTypes.debug`, not `defaultConfig`).
- **Release hardening:** no `usesCleartextTraffic="true"` or `NSAllowsArbitraryLoads`, no debuggable release, no exported components without a reason, HTTPS everywhere.

## 10. Flutter code health

- **Analyzer:**
  - Use the `analysis_options.yaml` from `git-and-tooling.md` §1 (strict modes plus `unawaited_futures`). Wrap deliberate Firestore offline writes in `unawaited()`.
  - Using `context` after an `await` crashes navigation and dialogs; check `mounted` first.
- **Lifecycle:** dispose controllers, subscriptions and timers created in `initState`. Never call `.listen(` inside `build()`.
- **Futures:** don't create the future inside `build()` (`FutureBuilder(future: fetch())` refetches on every rebuild). Create it in `initState` or use a provider.
- **Lists:** `ListView.builder` for anything longer than a screen, never `ListView(children: rows.map(...))` over DB rows. Use `const` constructors where possible.
- **Errors:** set `FlutterError.onError`, `PlatformDispatcher.instance.onError` and a release `ErrorWidget.builder` (see `shipping.md`). Every `FutureBuilder`/`StreamBuilder` handles `hasError`, not just loading and data.
- **Structure:** UI / logic / data layers (the `flutter-apply-architecture-best-practices` skill covers this). Repositories hide whether data comes from SQLite or Firestore.

## 11. Expo / React Native specifics

- **Lists:**
  - Use FlashList or LegendList.
  - Memoize rows and pass them primitive props.
  - Hoist `renderItem` and provide a `keyExtractor`.
  - Use `expo-image` with thumbnails at about twice the display size.
  - Keep scroll position in Reanimated shared values or refs, not `useState`.
- **Native crash traps:** `{count && <X/>}` with `0` or `""` renders a string outside `<Text>`, which crashes on native (on web it just shows "0"). So does a raw string directly inside a `<View>`. Use `count > 0 ? <X/> : null`, and enable `react/jsx-no-leaked-render`.
- **Effects that fetch** need an abort or ignore flag, so stale responses can't overwrite newer ones. Prefer TanStack Query.
- **Validate route and deep-link params** with zod before use, and run `tsc --noEmit`.
- **Expo builds:**
  - Profiles live in `eas.json`, and credentials stay on EAS.
  - OTA updates are for JS-only changes, under a `runtimeVersion` policy.
  - Run `npx expo-doctor` before releases.
- **Background location** (e.g. a car tracker):
  - `expo-location` + `expo-task-manager`.
  - The Android 14 `location` foreground-service type.
  - Play's background-location declaration.
  - Test against aggressive battery savers on Xiaomi, Oppo and Huawei phones.
- **UUIDs:** `uuid`'s `v7()`, with `react-native-get-random-values` imported first. `expo-crypto`'s `randomUUID()` is v4 (not time-ordered).

## 12. Testing offline apps

- **Unit and integration:** `sqflite_common_ffi` with `inMemoryDatabasePath` gives real SQL in host tests. Use the Firebase Emulator Suite for Firestore and Auth, and `@firebase/rules-unit-testing` for rules.
- **Migration tests:** open a committed fixture DB from each released version with current code, then assert the schema and row counts.
- **Failure matrix before every release:**
  - airplane mode mid-payment
  - force-stop mid-sync, then relaunch
  - seven days offline, then sync
  - two tills selling the last unit
  - wrong device date
  - printer off or out of paper
  - a low-end Android with 100k sales rows
  - the Windows till after a Windows update
  - a power cut mid-sale on the Windows till
- **On-device flows:** Flutter `integration_test`, or Maestro for Flutter and RN. One journey per test, seeded data, no sleeps.
