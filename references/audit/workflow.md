# Audit workflow details: commands, attack surface, severity, report

Read this at the start of every audit. SKILL.md "Audit workflow" has the ground rules and the steps; this file has the details for the automated sweep, the attack-surface map, the severity scale, the report and what to offer afterwards.

## Contents
1. Automated sweep
2. Mapping the attack surface
3. Severity
4. Report format
5. After the report

---

## 1. Automated sweep

Run the lead finder with the Bash tool (Git Bash on Windows; from PowerShell, a plain `bash` may start WSL). Strip Windows line endings first: a copy saved with CRLF fails at once with `$'\r': command not found`.

```bash
tr -d '\r' < <this-skill-dir>/scripts/scan.sh > /tmp/vibe-scan.sh && bash /tmp/vibe-scan.sh <repo>   # leads only; masks secrets; read-only
```

Its output is leads, not findings: trace each one to a real code path before it goes in the report.

Then run the project's own checks, with the precautions in SKILL.md's ground rules (lockfile installs with scripts off, no live backends), and note what's missing:

| Stack | Commands |
|---|---|
| JavaScript/TypeScript | `npx tsc --noEmit`, `npm run lint`, `npm audit --omit=dev`; tests and builds only against an emulator or local stack. For Next.js, compare the lockfile's `next` version with the newest security release (`security.md` §10) |
| Python | `ruff check`, `mypy` or `pyright` if configured, `pip-audit`, `pytest` |
| Go | `go vet ./...`, `staticcheck ./...` if installed, `govulncheck ./...`, `go test ./...` |
| Rust | `cargo clippy --all-targets`, `cargo audit` if installed, `cargo test` |
| Java/Kotlin | `./gradlew check` or `mvn verify`, plus the project's dependency-check task if any |
| C#/.NET | `dotnet build -warnaserror`, `dotnet list package --vulnerable --include-transitive`, `dotnet test` |
| PHP | `composer audit`, `vendor/bin/phpstan analyse` if configured, `vendor/bin/phpunit` |
| Ruby | `bundle exec rubocop`, `bundle exec bundle-audit check --update` or `bundler-audit`, the test suite |
| Dart/Flutter | `dart analyze` / `flutter analyze`, `flutter test`, `osv-scanner` on `pubspec.lock` |
| Any lockfile | `osv-scanner scan source -r .` if installed |
| Supabase | `supabase db advisors --remote --type security`, if the CLI is linked and the user agrees (CLI 2.81+; without `--remote` it checks the local database) |
| Secrets | `gitleaks git -v --redact --no-banner .` if installed (scan.sh already uses it when present) |

- A failing build, type check or test run is itself a finding.
- A missing check (no tests, no linter, no lockfile, no CI) is a finding for the Tests & tooling row.
- Don't install global tools without asking. If a tool isn't available, say which check it would have run and list it under "couldn't check".

## 2. Mapping the attack surface

List every entry point and who can reach it, before the deep security pass:
- routes and handlers in every framework, serverless and edge functions
- Server Actions and other framework RPC (each `'use server'` export is a public POST endpoint), GraphQL resolvers, gRPC methods
- database functions callable over an API, and database rules and policies
- webhooks, queue and event consumers, cron jobs, admin tools and privileged CLIs
- everything shipped to clients: web bundles, app binaries, desktop installers, firmware (treat it as public)
- paid APIs and who can trigger them (each call costs the owner money)

For each entry point note: authentication (none, any signed-in user, a role), whose data it touches, and which check stops a stranger or another customer. The gaps in that column are where the Critical and High findings usually are.

## 3. Severity

Judge by impact times who can trigger it, then sort worst-first.

| Level | Meaning | Typical examples |
|---|---|---|
| **Critical** | Anyone, or any self-registered user, can read others' data, take or skip payment, run up bills, take over accounts, run code on the server or destroy data, right now. Also: the software silently loses or corrupts money, stock or user records in normal use | Service-role or live payment key exposed; database rules open to all; unverified payment callback; client-set prices; admin action with no auth; SQL or command injection on a public input; unsafe deserialization of request data; migrations that never run on existing installs |
| **High** | Serious harm needing a little effort or a specific condition | IDOR on orders; SSRF; stored XSS (Critical where staff view it); brute-forceable OTP; debug mode on in production; signing passwords committed (Critical if the repo is public) |
| **Medium** | Real weakness or bug with limited blast radius | Token in plain storage; stack traces to clients; unbounded queries; swallowed errors outside money paths; broken right-to-left layout |
| **Low** | Hardening, hygiene, polish | Missing headers; missing `.env.example`; minor accessibility gaps |

## 4. Report format

- **Verdict first,** in one line: **Blocked** / **Risky: internal or pilot only** / **Launchable with caveats** / **Ready**, plus the findings that decide it. Any Critical means Blocked; the other caps are in `quality.md` §8. Then say what was audited (languages, commit or date, scope) and what couldn't be checked.
- **In plain words,** for the owner: 3-5 sentences without jargon. What a stranger, a customer or an employee could do today, what it could cost, and roughly how long the top fixes take.
- **Scorecard:** one row each for Security, Correctness & data, Performance, UX/a11y/localization, Tests & tooling and Production readiness, rated **OK**, **Issues** or **Blocking** with a short reason.
- **Findings,** worst-first. Keep cells short: no code blocks, and no `||` rule snippets, which break tables.

  | # | Severity | Area | File:line | Problem | Exploit or failure scenario | Fix (one line, effort S/M/L) |
  |---|---|---|---|---|---|---|

  - Then a numbered **Details** block for each Critical and High row: the full scenario, the exact fix and the code that won't fit in a cell.
  - Be specific: "`STRIPE_SECRET_KEY` hardcoded at `src/lib/stripe.ts:4`", not "exposed API key".
  - Every fix names the actual change; a leaked key's fix starts with "rotate".
  - Use one row per root cause, and include every confirmed finding, Lows too (group them by area if there are many).
- **Top 3 to fix today:** the highest-leverage fixes, not always the three worst rows.
- **Checked and fine:** notable areas verified clean, and worries that turned out to be paper tigers, with the reason.
- **Evidence:** the commands run and their results, the evidence still missing, and one concrete next action.

If the user asked about one area only, keep the same table, the Top 3 and the "couldn't check" line, scoped to that area.

## 5. After the report

Offer the fixes as decisions (SKILL.md "Decisions"), so the owner chooses what gets fixed and how:
- The Top 3 first, then the rest worst-first.
- Where a finding has more than one reasonable fix, show the options with their trade-offs. Common pairs: a quick guard now or a redesign; a patch or a data migration; tightening a rule or moving the operation to the server; rotating a key now and moving it behind an endpoint next.
- Where there's one obvious fix, offer it as fix now or later, with the effort.
- A leaked live key is the exception: say to rotate it now, before anything else, whatever else they choose.

Fixing is Build mode: reproduce each finding with a failing test, fix it, re-run the checks, and re-audit the touched paths.
