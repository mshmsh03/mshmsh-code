# Offline-first apps, local databases, sync, printers and scanners

Read this when the software must keep working without internet (shops, clinics, field work, warehouses, travel), keeps data on the device, syncs between devices, or drives local hardware such as receipt printers and barcode scanners. It applies to mobile, desktop and web apps alike. Money and stock rules are in `money-and-business-rules.md`.

## Contents
1. Decide these before the first screen
2. Architecture: a local ledger plus an outbox
3. The sync protocol and conflicts
4. Local SQLite: transactions, migrations, platform notes
5. Offline web apps
6. Backups and export
7. Receipt printers, cash drawers and barcode scanners
8. Testing offline apps

---

## 1. Decide these before the first screen

Each of these is a decision for the user, offered as options (SKILL.md "Decisions"):
- **Which actions must work offline, and for how long?** "Sales and receipts for 7 days; reports can wait for the connection" is a spec; "it should work offline" isn't.
- **Where does the truth live?** For anything that must work offline (a till, a pharmacy counter, a field form), the **local database is the source of truth** and the cloud is a sync target. A cloud SDK's offline cache (Firestore's, for example) is a cache, not a ledger: it can be evicted, and pending writes disappear when the user clears data or uninstalls.
- **Conflict policy:** what happens when two devices change the same thing offline (section 3).
- **Several devices, live shared state, no internet?** Cloud sync can't do that. Either accept eventual consistency (with an oversell policy for stock) or add a local hub: one PC on the shop's network serving the others.
- **Platforms:** some cloud SDKs aren't production-ready on every platform (Firebase's own docs say its desktop support on Windows is for development, not production). A Windows till then needs a local database as its ledger plus a separate sync path (an HTTPS API, or the provider's REST API). Check this before writing screens.
- **Mixed versions:** devices run different app versions for weeks, and sideloaded apps never auto-update. Plan how old clients keep syncing.

## 2. Architecture: a local ledger plus an outbox

- **Screens read only from the local database** (reactive queries or streams). No network call sits between "Pay" and the receipt.
- **One local transaction per business action:** the sale, its line items, its stock movements and an **outbox row** are written together, or not at all. Outbox row: `op_id, entity, entity_id, op, payload_json, attempts, last_error, created_at`.
- **A sync worker drains the outbox in order,** with exponential backoff plus jitter, and deletes a row only after the server acknowledges it.
- **IDs are created on the device,** as time-ordered UUIDs (UUIDv7) or ULIDs, which index well. The same ID becomes the server's primary key or idempotency key, so a retry can never double a sale. Never use auto-increment IDs for synced tables: two devices will both create sale #57.
  - Dart: `const Uuid().v7()` from the `uuid` package.
  - JS: `v7()` from the `uuid` package; in React Native, import `react-native-get-random-values` first. `expo-crypto`'s `randomUUID()` gives v4: unique but not time-ordered.
- **Human-friendly numbers are separate from sync IDs:** a per-device prefix plus a local counter (`T2-000123`), allocated inside the same transaction.
- **Deletes are tombstones** (`deleted_at`); hard deletes never propagate.
- **Show sync health** in the UI: the number of unsynced records and the time of the last successful sync. Owners trust what they can see.

## 3. The sync protocol and conflicts

- **Push** through the outbox; the server applies each operation idempotently (keyed by `op_id` or the entity's ID) and acknowledges it.
- **Pull** changes since a **server-written cursor** (an `updated_at` set by the server, or a change sequence number), never device time: device clocks are often wrong. Warn when a device's clock is minutes off the server's.
- **Payloads carry a `schemaVersion`;** the server accepts older clients, and a remote `min_app_version` triggers an update screen when an old version can no longer sync safely.
- **Server-side triggers and webhooks run at least once.** Aggregates (stock totals, daily sums) need an idempotency marker: record `processed/{movementId}` in the same transaction that applies the change.
- **Conflict strategies** (offer the fitting ones as options):
  - **Append-only records** (sales, movements, payments) don't conflict: both devices' records are kept. Prefer modelling business data this way.
  - **Last write wins per field,** using server order, for simple settings and profile data. Simple, but it silently drops one change.
  - **Server rules decide** (for example "stock can't go below zero unless the product allows oversell"), with rejected operations shown to the user.
  - **Manual resolution:** keep both versions and ask a person, for documents where losing either edit is unacceptable.
  - **CRDTs or operational transforms** for collaborative text and real-time co-editing; use an established library, never your own.
- **Managed sync engines** exist (for example PowerSync or ElectricSQL for Postgres, and the offline modes of Firebase and similar services). They save months, but check their current status, pricing and platform support, and make the choice an explicit decision.

## 4. Local SQLite: transactions, migrations, platform notes

**Basics:**
- **Foreign keys are off by default** in SQLite, per connection. Turn them on when each connection opens (`PRAGMA foreign_keys = ON`; in sqflite, in `onConfigure`). Without that, `REFERENCES` and `ON DELETE CASCADE` do nothing.
- **Never `INSERT OR REPLACE` a parent row** once foreign keys are on: REPLACE deletes the old row first, which cascades to (or orphans) its children. Use `INSERT ... ON CONFLICT ... DO UPDATE`.
- **Power cuts** are common at shop tills. If you enable WAL mode, keep `PRAGMA synchronous = FULL` for ledgers: with `NORMAL`, a committed sale can roll back after power loss even though its receipt printed. Recommend a UPS to the client.
- **Transactions in sqflite:** inside `db.transaction((txn) async { ... })`, use `txn` only; calling `db.` in there deadlocks. `onCreate` and `onUpgrade` already run inside a transaction.
- **Bulk imports** (a product catalogue) run in one transaction, batched.
- **Indexes** on unique business keys (`UNIQUE(barcode)`, or a separate table for several barcodes per product), foreign keys (`sale_items(sale_id)`) and date filters (`sales(created_at)`). Check plans with `EXPLAIN QUERY PLAN`. Build reports in SQL, not by loading rows into app code.
- **Search** uses a normalized `search_key` column (`localization-and-rtl.md` §5) and bound parameters (`LIKE ?`), never string interpolation.

**Platform notes:**
- **Flutter on Windows:** sqflite has no Windows backend. Use `sqflite_common_ffi` (`sqfliteFfiInit(); databaseFactory = databaseFactoryFfi;`) or drift, whose `drift_flutter` covers Android, iOS, macOS, Linux and Windows.
- **Where the file lives on desktop:** the app-data directory (`getApplicationSupportDirectory()` in Flutter, `%APPDATA%`/`%LOCALAPPDATA%`, `~/Library/Application Support`, `$XDG_DATA_HOME`). Never the Documents folder, which is often synced by OneDrive or iCloud and corrupts an open database, and never the install directory, which may be read-only.
- **The SQLite version varies by device** when you use the system library (sqflite on Android does): `RENAME COLUMN` needs 3.25, `VACUUM INTO` 3.27, `DROP COLUMN` 3.35, `STRICT` tables 3.37, `ON CONFLICT DO UPDATE` 3.24. On old devices, rebuild tables instead (create new → copy → drop → rename), or bundle a current SQLite (`package:sqlite3`/drift, or your platform's equivalent).
- **Encryption at rest** for shared PCs or devices holding customer or health data: SQLCipher (via your platform's binding), with the key in secure storage.

**Migrations:**
- Run every step from the installed version to the current one, in order. Bumping the schema version without migration code means existing installs never migrate.
  ```dart
  onUpgrade: (db, from, to) async {
    for (var v = from + 1; v <= to; v++) {
      await steps[v](db);
    }
  }
  ```
- Tools help: drift's `make-migrations` (schema snapshots and generated migration tests), `PRAGMA user_version` with expo-sqlite, Room's auto-migrations on Android, Core Data or SwiftData migrations on iOS, EF Core migrations on .NET.
- **Rules:**
  - Never edit a shipped migration step.
  - Back up the database before migrating, with `VACUUM INTO` or the backup API. A plain copy of the `.db` file misses the `-wal` file.
  - Keep "create fresh" equivalent to "run all steps", and test it: compare `SELECT sql FROM sqlite_master` from a fresh install with an upgraded one.
  - Commit a fixture database from each released version, and test upgrading each one to the current schema.

## 5. Offline web apps

- **IndexedDB** (through a wrapper such as Dexie or idb) is the local database; `localStorage` is too small, synchronous and string-only for data.
- **A service worker** caches the app shell and static assets; choose a strategy per request type (cache-first for hashed assets, network-first for HTML and API reads). Version caches and clean up old ones on activate.
- **Storage can be evicted** under pressure, especially on iOS Safari. Call `navigator.storage.persist()`, check `navigator.storage.estimate()`, and treat local data as recoverable from the server.
- **Background Sync isn't available in every browser;** sync when the app is open and online, and on the `online` event.
- **Hardware access** (printers, scanners, serial devices) from the browser is limited and differs by browser (WebUSB, Web Serial and Web Bluetooth are Chromium-only). If the app depends on hardware, that's a reason to choose a native or desktop app (`../build/choosing-a-stack.md`).

## 6. Backups and export

- **Back up on a schedule** with `VACUUM INTO '<file>'` or the SQLite backup API; copying the `.db` without its `-wal` file loses the latest records.
- **Keep an off-device copy** (the owner's cloud drive, a USB stick, or the server under the shop's own path) and a restore flow **tested on a clean install**.
- **Android Auto Backup** is a decision (`allowBackup`, `dataExtractionRules`): it can restore a stale database, or secure-storage data that can no longer be decrypted.
- **Exports for accountants** follow `money-and-business-rules.md` §10.

## 7. Receipt printers, cash drawers and barcode scanners

**Thermal receipt printers:**
- Their built-in code pages can't shape Arabic script or show Sorani letters (ڕ ڵ ێ ۆ ە). Print the receipt as an **image**:
  1. Render the receipt layout to a bitmap (in Flutter, `RenderRepaintBoundary.toImage()`; elsewhere, a canvas or an HTML-to-image step).
  2. Scale it to the printer's dot width (typically 384 for 58 mm paper, 576 for 80 mm).
  3. Threshold it to 1-bit.
  4. Send it with the ESC/POS raster command (`GS v 0`).
- The cash drawer kick is `ESC p`, sent through the printer.
- **Transports:** Bluetooth Classic (most cheap printers; iOS can't use them without MFi certification), BLE, USB, or the network (raw TCP on port 9100). Android 12+ needs the runtime permissions `BLUETOOTH_CONNECT` and `BLUETOOTH_SCAN`.

**A4 invoices and driver printers:** generate a PDF with an embedded Arabic-script font and right-to-left support, then print it through the OS (in Flutter, the `pdf` and `printing` packages with `pw.TextDirection.rtl`). The built-in PDF fonts have no Arabic glyphs.

**Print only after the business action commits.** Offer a reprint button. A print failure must never create a second sale. Test with the printer off, out of paper, a 40-character Kurdish product name and a 60-line receipt.

**USB/HID barcode scanners** type fast and end with Enter:
- Keep the scan field focused, or use a global key handler. Dialogs that steal focus drop scans.
- Under an Arabic or Kurdish keyboard layout, scanned letters may arrive as Arabic characters. Test with the shop's real keyboard setting, and normalize or match on key codes.
- Camera scanning on phones needs good light and a fallback to typing the code.

## 8. Testing offline apps

- **Real SQL in host tests:** an in-memory SQLite (`sqflite_common_ffi` with `inMemoryDatabasePath` in Dart, `:memory:` elsewhere), and the provider's emulators for cloud parts (the Firebase Emulator Suite, local Supabase).
- **Migration tests** open a committed fixture database from each released version with the current code, then assert the schema and row counts.
- **Sync tests** run two simulated devices against a local server: same record edited on both, the same operation sent twice, an operation from an old schema version, a device with a wrong clock.
- **The failure matrix before every release:**
  - airplane mode in the middle of a payment
  - the app force-stopped mid-sync, then relaunched
  - seven days offline, then a sync
  - two devices selling the last unit
  - a wrong device date
  - the printer off or out of paper
  - a low-end device with a year of data (for example 100,000 sales)
  - a desktop till after an OS update, and a power cut mid-sale
- **On-device flows:** Flutter `integration_test`, Maestro (Flutter and React Native), Espresso or XCUITest for native apps. One journey per test, seeded data, no fixed sleeps.
