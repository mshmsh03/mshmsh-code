# Games, embedded and IoT, browser extensions, libraries and packages

Read the section for the kind of software you're building. Each one lists the decisions to put to the user, the traps AI-written code falls into, and how to test.

## Contents
1. Games
2. Embedded and IoT
3. Browser extensions
4. Libraries and packages

---

## 1. Games

**Decide first** (as options): engine and language (`../build/choosing-a-stack.md` §4), platforms and input methods (touch, keyboard and mouse, controller), 2D or 3D, the minimum hardware and target frame rate, online play, monetization, and save data.

**Build:**
- **Frame-rate independence:** movement and timers use the frame's delta time; physics runs on a fixed timestep, so behaviour doesn't change on a faster or slower device.
- **Input through an abstraction** (actions such as "jump", mapped to keys, buttons and touch), so remapping and new devices are cheap.
- **Game state separate from rendering** where practical; rules that can be tested without the engine running.
- **No allocations in the per-frame loop** in garbage-collected engines (Unity C#, JS): reuse objects, pool bullets and particles, avoid creating strings and closures every frame.
- **Assets:** compress textures and audio for the target platform, load asynchronously, and unload what's no longer needed; memory is the usual crash on low-end phones.
- **Save data** is versioned and migrated like a database schema, written atomically (temporary file, then rename), and backed up before migration. A corrupted save is the review players never forget.
- **Multiplayer:** the server is authoritative; clients send inputs, not results; never trust client-reported scores, positions or purchases. Validate in-app purchases with the store's server API.
- **Engine habits:** Godot (scenes, signals, typed GDScript or C#), Unity (MonoBehaviour lifecycle order, `Update` vs `FixedUpdate`, ScriptableObjects for data), Unreal (C++ for systems, Blueprints for content, garbage-collected `UObject` pointers marked with `UPROPERTY`).

**Test:** unit tests for rules and math; automated play tests or scripted inputs for core loops; profiling on the minimum target hardware, not the development PC; save and load across versions.

## 2. Embedded and IoT

**Decide first** (as options): the board and chip, power source and battery-life target, connectivity (Wi-Fi, BLE, LoRa, cellular), how firmware is updated in the field, the cloud or local server it talks to, and the safety limits of anything it controls.

**Build:**
- **Memory is fixed:** avoid dynamic allocation after start-up, check stack sizes per task, and keep large buffers static. Out-of-memory in the field looks like random reboots.
- **Interrupt handlers stay short:** set a flag or push to a queue, and do the work in a task. Shared data between interrupts and tasks uses `volatile` correctly plus atomics or critical sections.
- **A watchdog** resets the device when the main loop hangs; feed it from the loop's healthy path, not from a timer that keeps running when the logic is stuck.
- **Power:** sleep modes between readings, radios off when idle, and the battery-life target checked with real measurements.
- **Over-the-air updates** are signed, verified before installing, and use A/B partitions (or equivalent) with automatic rollback when the new firmware fails to boot or check in. A failed update must never brick a device in a customer's wall.
- **Security:** unique credentials per device (never one key shared by every unit and compiled into the firmware), TLS to the server, secure boot and flash encryption where the chip supports them, debug ports locked in production, and no default passwords.
- **Time:** sync from the network (NTP) and handle having no valid time after boot.
- **Hardware abstraction:** keep chip-specific code behind a small interface so the logic can be tested on a PC.
- **Safety:** physical limits (temperature, motor current, valve positions) are enforced in firmware, not only in the app or cloud, and fail to a safe state.

**Test:** host-side unit tests for logic with the hardware layer faked; hardware-in-the-loop tests on a real board for drivers and timing; long soak tests for memory leaks and reboots; update and rollback tested, including power loss mid-update.

## 3. Browser extensions

**Decide first** (as options): which browsers, which sites the extension touches, the permissions it truly needs, what data it stores or sends, and whether it's published to stores or installed privately.

**Build:**
- **Manifest V3:** background code is event-driven and can be stopped at any time (a service worker in Chromium), so state lives in `chrome.storage`/`browser.storage`, not in global variables.
- **Least privilege:** request narrow host permissions instead of `<all_urls>`, and use optional permissions requested at the moment a feature needs them. Store reviewers reject broad permissions without a reason.
- **Content scripts run on hostile pages:** treat page content as untrusted, never inject it as HTML, and keep secrets out of content scripts.
- **Messages between parts** (content script, background, popup) are validated like API requests, including the sender.
- **No remote code:** stores forbid loading and running code from the network; all logic ships in the package.
- **Privacy:** collect the minimum, disclose it in the store listing and a privacy policy, and never send browsing data without explicit consent.
- **Frameworks** such as WXT help target several browsers from one codebase.

**Test:** unit tests for logic; end-to-end tests that load the unpacked extension in a real browser (Playwright supports this for Chromium); manual checks on the actual target sites, which change without notice.

## 4. Libraries and packages

**Decide first** (as options): the languages and versions supported, the public API, the licence, the platforms, and the release process.

**Build:**
- **A small public API.** Everything exported is a promise; keep internals private, and design the API twice before publishing (`../build/architecture-and-data.md` §2).
- **Semantic versioning:** breaking changes only in major versions, with a migration guide; deprecate before removing.
- **Dependencies:** as few as possible, with wide compatible version ranges (libraries don't pin exact versions the way apps do), and no heavy dependency for a small helper.
- **Types and docs:** type definitions or annotations, and a README with installation, a quick example and the main use cases; examples are tested so they don't rot.
- **Errors:** specific, documented error types; never print to stdout or exit the process from library code.
- **Compatibility:** a CI matrix over the supported language versions and operating systems.
- **Publishing securely:** two-factor authentication on the registry account, publishing from CI with trusted publishing (OIDC) or provenance where the registry supports it (npm, PyPI, crates.io and others), signed tags, and a changelog for every release.
- **Licence:** choose one deliberately (the user decides), include the file, and check that dependencies' licences are compatible.

**Test:** unit tests of the public API (not the internals), property-based tests for parsers and data structures, and an install test of the built package in a clean environment before each release.
