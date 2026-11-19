# Desktop apps: Windows, macOS and Linux

Read this when building an app that installs on a computer: Electron, Tauri, Flutter desktop, .NET (WPF, WinUI, WinForms, Avalonia, MAUI), Qt, or native Swift/AppKit. Offline data, sync, printers and scanners are in `../concerns/offline-first-and-sync.md`; right-to-left layout in `../concerns/localization-and-rtl.md` §9.

## Contents
1. Decide these first
2. Where files and data live
3. Installers, signing and updates
4. Electron security
5. Tauri security
6. .NET, Flutter desktop and Qt notes
7. The environment you don't control
8. Testing

---

## 1. Decide these first

Offer each as options (SKILL.md "Decisions"):
- **Framework** (`../build/choosing-a-stack.md` §4): installer size, memory use, native look, and which languages the team knows.
- **Platforms at launch:** Windows only (most business tills and offices), or also macOS and Linux. Each adds signing, packaging and testing work.
- **Distribution:** a direct download, the Microsoft Store, the Mac App Store, winget or Homebrew, or installs done by hand on a few shop PCs.
- **Updates:** automatic (the app checks and installs), notify-only, or manual. Offline PCs need a plan.
- **Multi-user PCs:** per-user or per-machine install, and whether data is shared between Windows accounts.
- **Admin rights:** many office and shop PCs don't give users admin rights; per-user installs avoid the problem.

## 2. Where files and data live

- **App data** goes in the platform's app-data directory: `%APPDATA%` or `%LOCALAPPDATA%` on Windows, `~/Library/Application Support/<app>` on macOS, `$XDG_DATA_HOME` (default `~/.local/share`) on Linux. Use the framework's API for the path (`app.getPath('userData')`, Tauri's path API, `getApplicationSupportDirectory()`, `Environment.GetFolderPath`).
- **Never write to the install directory** (Program Files is read-only for normal users) or the current working directory.
- **Never keep a live database in Documents or Desktop:** they're often synced by OneDrive or iCloud, which corrupts open database files.
- **Logs** in a logs folder under app data, rotated, with no secrets or personal data; give support staff a "copy logs" button.
- **Secrets** in the OS store: Windows Credential Manager or DPAPI, the macOS Keychain, the Secret Service on Linux. Reach them through the framework: Electron's `safeStorage`, a keyring or Stronghold plugin in Tauri, .NET's `ProtectedData`, or a maintained keyring library for your language.
- **Paths:** build them with the language's path API, handle spaces and non-Latin characters (a Kurdish Windows user name is a real case), and don't assume `C:`.

## 3. Installers, signing and updates

- **Sign everything you ship.** Unsigned Windows apps trigger SmartScreen warnings ("Windows protected your PC"); unsigned or un-notarized macOS apps are blocked by Gatekeeper. Budget for a code-signing certificate or a signing service (`../build/discovery-and-specs.md` §8).
  - **Windows:** Authenticode signing of the installer and the executables, with a timestamp so signatures outlive the certificate. Reputation builds over time; new certificates may still warn at first.
  - **macOS:** a Developer ID certificate, the hardened runtime, and notarization (`notarytool`), then stapling.
  - **Linux:** AppImage, Flatpak, Snap, or `.deb`/`.rpm` packages; sign repositories and packages where the format supports it.
- **Packaging:** MSIX or a classic installer (Inno Setup, WiX, NSIS) on Windows; a signed `.dmg` or `.pkg` on macOS. Test the installer on a clean virtual machine with no developer tools installed, so missing runtimes show up (for example the Visual C++ runtime DLLs a Flutter or native Windows build needs).
- **Auto-update:** use the framework's updater (electron-updater, Tauri's updater with signed update bundles, Sparkle on macOS, MSIX with an `.appinstaller` file, the Microsoft Store). Updates must be signed and fetched over HTTPS, and the app must survive a failed or interrupted update.
- **Version checks for offline or sideloaded installs:** a JSON file you host with the latest version, the minimum supported version and the download link.
- **Uninstall** cleanly, and ask whether to keep user data.

## 4. Electron security

Electron apps are a browser with Node attached: a single XSS can become code running on the user's machine.
- Keep the secure defaults: `contextIsolation: true`, `nodeIntegration: false`, `sandbox: true` for renderers. Never turn them off to make a tutorial work.
- Expose only narrow, named functions through a preload script with `contextBridge`; never expose `ipcRenderer` or `require` whole.
- **Validate every IPC message** in the main process (the sender and the arguments), as you would an HTTP request.
- Load only local, bundled content in privileged windows; never load remote websites with Node access. Set a strict Content Security Policy.
- Validate URLs before `shell.openExternal`, and block unexpected navigation and new windows (`will-navigate`, `setWindowOpenHandler`).
- Keep Electron current: each release carries Chromium security fixes.
- Turn on the security-relevant Electron fuses in packaged builds (for example disabling `ELECTRON_RUN_AS_NODE`).

## 5. Tauri security

- Grant the minimum **capabilities and permissions** per window; don't enable broad filesystem or shell access "for now".
- Rust commands are entry points: validate their arguments, and scope file access to the directories the feature needs.
- Set a Content Security Policy, and load remote content only in windows without IPC access.
- Sign update bundles and keep the updater's private key out of the repo and CI logs.

## 6. .NET, Flutter desktop and Qt notes

- **.NET (WPF, WinUI, WinForms, Avalonia, MAUI):** MVVM with a community toolkit keeps logic testable; `async`/`await` on the UI thread without `.Result`; publish self-contained or framework-dependent deliberately; trimming and single-file publishing can break reflection-heavy libraries, so test the published build.
- **Flutter desktop:** check every plugin's desktop support before depending on it; some cloud SDKs aren't production-ready on Windows (`../concerns/offline-first-and-sync.md` §1); ship the whole release folder with its runtime DLLs.
- **Qt:** pick the licence (LGPL or commercial) deliberately; deploy with `windeployqt`/`macdeployqt`.
- **Native macOS (Swift):** sandbox entitlements for the Mac App Store; hardened runtime for Developer ID distribution.

## 7. The environment you don't control

- **Antivirus** may quarantine new or unsigned executables and slow file-heavy operations. Signing helps; so does not writing executable files at runtime.
- **High-DPI and multiple monitors:** test at 100%, 150% and 200% scaling, and moving windows between monitors.
- **Old or locked-down PCs:** the minimum Windows version you support, missing runtimes, no admin rights, proxies on office networks, and clocks set wrong.
- **Power and sleep:** laptops sleep mid-operation; tills lose power. Write data in transactions and resume work on wake.
- **Accessibility:** keyboard navigation, screen readers (Narrator, VoiceOver) through the framework's accessibility APIs, and the OS's text-size settings.

## 8. Testing

- **Most logic is tested without the UI:** domain rules, repositories against a temporary database, file handling against temporary folders.
- **UI automation:** Playwright for Electron, the framework's own tooling for others (Flutter `integration_test`, Appium or UI Automation-based tools for Windows apps).
- **Before release:** install, upgrade from the previous version, run, and uninstall on a clean VM for each supported OS; a non-admin user; a Kurdish or Arabic Windows display language if supported; the app started offline.
