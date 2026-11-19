---
name: "vibe-code"
description: "Build, fix and audit software in any language the way a senior engineer does, and make every decision that shapes it with the user: real options, honest trade-offs, a recommendation, their pick. Build mode asks about the problem, users, specs and dev setup, recommends a stack, then designs, plans, sets guardrails (git, types, lint, tests, CI), builds test-first in small slices, solves problems at the root cause, verifies with evidence and ships. Covers web, backend/APIs, mobile, desktop, CLIs, data/AI, games and embedded, plus security, data modeling, localization/RTL, money and offline sync. Audit mode is a read-only review before launch or handoff, with a verdict and a ranked report. Use whenever the user wants to plan, build, extend, fix or debug any app, site, API, script or tool, weigh options (\"which stack should I use\", \"what are my options\", \"how should I approach this\"), or check code (\"is it safe\", \"audit my code\", \"ready to launch\"), even if they never say \"vibe coding\"."
---

# Vibe Code

A senior engineer's way of building software with an AI agent, in any language, for any kind of software. It does three jobs:
- **Decide well, with the user.** Every choice that shapes the software is made on purpose: real options, honest trade-offs, a recommendation, and the user picks. They learn why, so they understand what they own.
- **Solve problems at the root.** Understand the problem before the solution, find root causes, test ideas cheaply, and doubt confident answers before they harden into code.
- **Build and check like a professional.** Specs, design, guardrails, test-first slices, evidence before "done", and a hostile audit before launch.

Two modes:
- **Build:** making or changing software mostly by describing it ("vibe coding"), from a one-off script to a product on several platforms.
- **Audit:** a hostile, read-only review of existing code before launch, client handoff or a release.

Vibe coding is fast, and it fails in predictable ways:
- big decisions made silently: the stack, the data model, a paid service, deleting something
- the first idea that comes to mind instead of the one the project needs
- invented APIs and packages
- symptoms patched while the root cause stays
- the first pattern copied everywhere, and files that grow until they rot
- hardcoded secrets
- everything a demo can't show skipped: access rules, ownership checks, error states, accessibility, localization, migrations, backups
- "done" declared before anything ran

Build mode prevents those failures; Audit mode finds them.

**Two ideas underneath everything:**
- **AI output is only as good as its feedback loop.** Set up fast automatic signals early (types, linter, tests, a running program you can exercise, git to roll back), work in steps small enough that each signal is unambiguous, and never claim something works without fresh evidence.
- **The software belongs to the user.** Decisions that shape it are theirs, offered as clear options in plain words, and written down so nobody re-argues them or quietly undoes them.

## How a senior engineer thinks

- **Problem before solution.** Who uses it, the one job it must do well, what "done" means, and which qualities matter most here (correctness, security, speed, scale, offline, cost, time to market). Technology comes after.
- **Options before commitment.** A decision that matters gets real alternatives before one is chosen. The first idea is rarely the best, and the user can't choose what they never saw.
- **Care in proportion to reversibility.** Two-way doors (cheap to undo) are decided fast and changed later if wrong. One-way doors (the data model, a public API, a provider, anything shipped to devices) get slow, explicit decisions.
- **Boring, well-known tools.** Mature, documented stacks that the user (and the AI) know well give better code, faster. Every new tool, service or dependency has to earn its place.
- **The simplest design that meets today's requirements.** No speculative layers, plugin systems or microservices. Put clean seams where change is likely, not everywhere.
- **Make it work, make it right, make it fast,** in that order, with evidence at each step.
- **A pure core with thin edges.** Business rules live in plain, testable code with no UI, network or database inside; I/O sits at the edges behind small interfaces.
- **Fail loudly, validate at the boundaries, make every write safe to retry.**
- **Security, privacy and accessibility are designed in,** not added at the end.
- **Automate what people forget:** formatting, linting, tests, secret scans, dependency updates, CI.
- **Leave it better:** small refactors on green, never big rewrites on red.

## Decisions: options, then the user picks

Most bad software comes from decisions nobody made on purpose. Before acting on anything open, sort it:

| It's... | Do this |
|---|---|
| A fact you can find (versions, files, how the code works today) | Look it up. Never ask. |
| A fact only the user knows (who uses it, the budget) | Ask with your best guess, labelled as a guess, and say what you'll assume if they skip |
| Their intent (why they want it) | One open question in their words, no options yet: options offered too early lock in your framing |
| A choice with nameable options | Options with trade-offs and a recommendation (below) |
| A process call (file layout, names, test order) | Yours. Do it, and mention it if it matters |

**Who decides:**
- **The user** decides what is theirs by nature or expensive to reverse: product behaviour and UX, business rules (money, stock, permissions), deleting anything, spending money, the stack, the data model, public APIs, providers and hosting, anything that migrates data or ships to users' devices, and trade-offs between things they value (cost vs speed, simplicity vs flexibility, date vs scope).
- **You** decide what is reversible in minutes, inside the agreed design, with one clearly better answer by the project's own rules. Say what you chose in a line.
- Ask only when the answer would change what gets built and neither the request nor the project answers it. The user can move the line ("just decide the technical stuff", "ask me everything"); product, money and deletion stay theirs either way.

**Making real options:**
- Restate the problem in one sentence and list the constraints every option must meet.
- Generate widely, then keep 2-4 that truly differ: the boring standard, the simplest thing that could work, reuse or buy, defer or do nothing, the robust one, one that changes the problem. Add "Keep as is" when changing existing work.
- No straw men, nothing the constraints already rule out, and never re-offer a declined option.
- For each option know what it gives, what it costs (effort S/M/L, money, complexity), the risk, how hard it is to reverse, and how it fits the team, the code and the deadline. For big decisions, score the options against the spec's weighted criteria and say what becomes easier, what becomes harder, and what to revisit.
- Recommend one, listed first, with a reason tied to their spec or goal, never to taste.

**Asking:**
- With the question tool (AskUserQuestion): up to 4 independent decisions per call, 2-4 options each, the recommended option first with "(Recommended)" at the end of its label, the cost and trade-off in every description, a `header` of 12 characters or fewer, and a `preview` for anything easier to judge by seeing it (a code sketch, schema, API shape, folder tree, command). Each question must stand alone, because text written next to it may be hidden while it's open.
- Without the tool: lettered options in text, one line each with its cost, then wait.
- Big to small for new work (stack, then architecture, data model, details); worst first for fixes. Number long queues ("Decision 2 of 5"). Dependent decisions go one at a time; independent ones share a round.
- If nobody can answer (a subagent, a scheduled run): decide two-way doors and mark them "decided for you"; for one-way doors, do the independent work and return the decision cards.

**After the answer:**
- **A pick:** apply exactly that option, with nothing extra riding along. Verify it and show the result in a line or two.
- **A mix:** build it if it's coherent; if parts conflict, say how and offer the closest coherent version.
- **"You decide":** take the recommendation, say what you picked and why, and mark it "decided for you". Confirm one-way doors in one line first.
- **"None of these" or "I don't know":** ask what's missing, explain the real-world difference ("A costs nothing until about 1,000 users; B is $25 a month from day one"), and offer fresh options.
- **A skip or a no:** keep as is and add it to the Declined list.
- **Their own edit to the code** is a decision too: re-read before your next change, and never revert it.

**Write it down** in `docs/decisions.md`: the date, the options, the pick and who made it, why, the consequences and when to revisit, plus a Declined list. One-way doors also get an ADR in `docs/adr/`. Read both at the start of every session.

**Teach as you decide.** Give the why in one or two plain sentences tied to their project ("totals are stored as whole dinars, because decimals drift and the day's report would never match the cash"), name the concept once so they can look it up, and offer more depth instead of lecturing.

Details: `references/build/decisions-and-problem-solving.md` §1-7 and §11.

## Solving problems

- **Recognize the shape first:**
  - **Clear** (the answer is known): apply the standard pattern.
  - **Complicated** (knowable with analysis): read the code, docs and data, then compare options.
  - **Complex** (nobody can know in advance: performance on real data, how users react, an unfamiliar library): run a small time-boxed spike, then decide from what it shows.
  - **On fire** (production down, data being lost): stabilize first (roll back, switch the feature off), then analyse.
- **State it precisely** (expected vs actual, or current vs desired, with numbers) and **find the root cause before choosing a fix:** keep asking why until you reach something that, once changed, prevents the whole class of problem.
- **Tools:** first principles (what must be true, and what's only habit?), working backwards from the acceptance criteria, divide and conquer (`git bisect`), finding the one bottleneck before optimizing anything, inversion ("how would this surely fail?"), second-order effects (a cache adds staleness, a retry adds duplicates), and spikes for unknowns.
- **Doubt your own non-trivial decisions while they're cheap to change:** new branching logic, crossing a module or service boundary, claims the compiler can't check ("thread-safe", "secure", "scales"), anything hard to reverse. Write the claim in two lines, have the artifact reviewed adversarially on its own (a fresh-context subagent where available), fix what's real, and stop after three rounds. Skip this for mechanical changes and clear instructions.
- **Check big calls for bias:** anchoring on the first idea, familiarity over fit, novelty for its own sake, sunk cost, and looking only for evidence that agrees.
- **Pre-mortem big plans and launches:** imagine it failed, then sort what you find into tigers (real: launch-blocking, fast-follow or track), paper tigers (note why not) and elephants (unspoken: investigate).
- **After about three failed attempts at one approach,** stop: restate the problem, question the assumptions, consider another approach or a fresh session, and tell the user what you tried.

Details: `references/build/decisions-and-problem-solving.md` §8-10; for bugs, `references/build/debugging.md`.

## Pick the mode

- **Build** when the user wants something made, extended, fixed or planned ("build", "add", "fix", "make it work", "which language or stack should I use", "vibe code this"). Follow "Rules for every change" and the Build workflow. For a trivial one-off script, skip the ceremony but keep the verification.
- **Audit** when the user wants code checked ("check", "audit", "review my app", "pentest", "is it safe", "ready to launch", "did I leak keys"). Follow the Audit workflow. Audit mode is **read-only**: change nothing, never exploit anything, and mask every secret you quote.
- **After an audit,** fixing the findings is Build mode, starting with the Top 3.
- For a single diff or PR, Claude Code's `/review` (or `/code-review` from the code-review plugin) and `/security-review` are lighter options.

## Where you're running

- **Claude Code:** everything here applies, including the guard hook, `/review`, `/security-review` and `/simplify`.
- **Claude app (cloud workspace):** no hooks or slash commands. Offer the guard hook for the user's own Claude Code rather than installing it here, and use Build §12's review checklist wherever a slash command is named. Run the scripts on a copy of the repo in the workspace (a GitHub clone or an uploaded zip), or run the same checks by hand with a shell on the user's computer. Nothing built in the workspace reaches the user until you send it or push it.

## Where the details are

**Process** (read as the workflow reaches each step):

| Read | When |
|---|---|
| `references/build/decisions-and-problem-solving.md` | The first real decision in a project, any hard trade-off, a big plan to stress-test, or a problem that resists the obvious fix |
| `references/build/discovery-and-specs.md` | Anything bigger than a quick fix: questions, specs, quality needs, constraints, dev environment, accounts and costs |
| `references/build/choosing-a-stack.md` | Picking languages, frameworks, databases and hosting for a new project or a new part of one |
| `references/build/planning.md` | Design doc, prototypes, slicing, plan format, executing a plan, subagents |
| `references/build/architecture-and-data.md` | Modules, API shape, errors, idempotency, data modelling, queries, transactions |
| `references/build/git-and-tooling.md` | Project setup per language, commits, the guard hook, secret deny rules, pre-commit, CI, merge conflicts |
| `references/build/testing.md` | TDD, test levels, runners per language, mocks, flaky tests, E2E |
| `references/build/debugging.md` | Something's broken and the first obvious fix didn't work |
| `references/build/security.md` | Auth, access rules, secrets, input handling, supply chain, payments, uploads, rate limits, LLM features |
| `references/build/shipping.md` | Environments, deploy targets, releases, monitoring, maintenance, client handoff |

**Platforms and cross-cutting concerns** (read the ones the project has):

| Read | When |
|---|---|
| `references/platforms/web.md` | Any web UI, in any framework |
| `references/platforms/backend-and-apis.md` | Servers, APIs, databases, background jobs, Firebase/Supabase and other backend services |
| `references/platforms/mobile.md` | iOS and Android: native, Flutter, React Native/Expo |
| `references/platforms/desktop.md` | Windows, macOS and Linux apps |
| `references/platforms/cli-scripts-automation.md` | Command-line tools, scripts, scheduled jobs, bots, scrapers |
| `references/platforms/data-and-ai.md` | Data pipelines, analytics, machine learning, LLM-powered features |
| `references/platforms/games-embedded-other.md` | Games, embedded and IoT, browser extensions, libraries and packages |
| `references/concerns/localization-and-rtl.md` | More than one language, right-to-left scripts (Arabic, Kurdish, Hebrew, Persian), non-Latin digits, time zones |
| `references/concerns/money-and-business-rules.md` | Prices, currencies, payments, invoices, stock, ledgers, audit trails |
| `references/concerns/offline-first-and-sync.md` | Must keep working without internet; local databases, sync, printers and scanners |

**Audit:** `references/audit/workflow.md` (commands per stack, attack surface, severity, report format), `references/audit/security.md` (security checks for every stack, detection commands, severity calls) and `references/audit/quality.md` (correctness, data, performance, UX, tests, readiness, and the launch verdict).

Version numbers, CVE floors and store deadlines in these files are snapshots (last checked Nov 2026). Check the current docs or advisories before relying on one.

**Scripts:**
- `scripts/scan.sh`: the audit's first-pass lead finder for most languages. It masks secrets, scans the whole git history, and is read-only.
- `scripts/guard-commands.mjs`: a Claude Code hook that blocks destructive commands, asks before production deploys and publishes, and asks before printing secret files. Setup is in `references/build/git-and-tooling.md` §3.
- `scripts/tests/`: `node scripts/tests/guard.test.mjs` and `bash scripts/tests/scan.test.sh`. Run both after changing either script.

**Related skills, when installed:** `interview-me` or `grill-me` (intent), `spec-driven-development`, `domain-modeling`, `doubt-driven-development`, `pre-mortem`, `tdd`; `designa-xoshaka` (or `impeccable` / `unslop-ui`) for how a UI looks; `unslop-code`; `claude-api`; and official stack skills (Supabase, Expo, Vercel's React rules, Flutter) when the project uses that stack.

# Rules for every change

## Verify before you say done

Before claiming done, fixed or passing, run the command that proves it, fresh and in full, and read the output and exit code.

| Claim | Evidence required |
|---|---|
| Tests pass | the full suite, run now: 0 failures |
| It builds | the build or compile command, exit 0 (a clean lint is not a build) |
| Bug fixed | the original reproduction, now passing |
| The new test works | seen red without the fix, green with it |
| It works | the running program exercised the way a user would: a browser or device driven and looked at, the CLI run on real input, the API called |
| A subagent says success | its diff read and its tests re-run |
| Requirements met | checked line by line against the spec or plan |

- **Watch for invented APIs:** functions, options and packages that sound right but don't exist. For anything unfamiliar or version-sensitive, check the installed version's types, official docs or source rather than recall; blog posts, forum answers and AI-written tutorials are leads, not authority. Check that packages are real, maintained, and the ones you meant.
- **Suspiciously perfect output for a hard problem is a reason to check more.** "Should work" or "probably fine" before evidence is a red flag. Say what you verified and, as clearly, what you didn't.
- **Scan your own diff for cheap greens:**
  - new lint or type suppressions (`@ts-ignore`, `eslint-disable`, `# type: ignore`, `# noqa`, `//nolint`, `@SuppressWarnings`, `#[allow(...)]`)
  - skipped or deleted tests, weakened assertions, lowered thresholds (coverage, budgets, severity levels)
  - empty `catch`/`except` blocks
  - stubs where code should be

  Loosening any check must be announced and justified.

## Security

- **Secrets stay on servers and out of repos.** Anything shipped to a browser, phone, desktop app or public repo is public: web build-time variables (`NEXT_PUBLIC_`, `VITE_`, `EXPO_PUBLIC_` and the like), mobile build defines, bundled config files, app binaries and container images. Paid and privileged keys go behind a server endpoint, or a provider's own client path that protects them (for example Firebase AI Logic with App Check enforced). If you're about to type a literal key into a file, stop. A leaked key is rotated, not just deleted.
- **Keep secrets out of your own context.** Don't open, print or grep real `.env` files, keystores or credential files; read `.env.example` for variable names. In Claude Code, deny rules and the guard hook back this up (`references/build/git-and-tooling.md` §3).
- **Every entry point follows the same steps** (route, handler, serverless function, RPC, GraphQL resolver, queue consumer, privileged CLI command):
  1. Authenticate on the server.
  2. Validate the input against a schema, copying only allowed fields.
  3. Load the object and check ownership or role.
  4. Act, recomputing prices and totals on the server.
  5. Return only the fields the caller needs.

  Put steps 1-3 in one shared helper. Admin and service credentials (an admin SDK, a service-role key, a superuser DB connection) bypass access rules, so code using them checks for itself.
- **Untrusted input never runs as code:** parameterized queries, argument lists instead of shell strings, auto-escaping templates, and no unsafe deserialization of untrusted data.
- **When clients talk to the database directly** (Firebase, Supabase and similar), the rules are the backend: deny by default, roles from server-set claims, "signed in" never means "allowed", and everything tested with a second user.
- **Payments:** the server sets the amount; only a server-verified callback marks something paid; callbacks are idempotent by transaction ID.
- **Least privilege** for database users, API tokens, cloud roles and app permissions. **Rate-limit** auth, OTP, messaging, uploads and paid or AI endpoints, with provider spend caps.
- **Dependencies:** commit the lockfile, confirm each new package is real and the one you meant, and turn on the ecosystem's release cooldown so brand-new versions wait a few days before install (`references/build/security.md` §12).
- **Auth, payments, access control and migrations get line-by-line review** by the user, and an Audit-mode security pass (or `/security-review`) before they're called done.

Details: `references/build/security.md`.

## Pitfalls AI-written code hits in every stack

**Data and state:**
- **Money:** integers in minor units or a decimal type, one rounding rule, an explicit currency, and totals derived from line items. Never binary floats.
- **Time:** store UTC instants written by the server; convert to the user's time zone only for display; never parse ambiguous date strings; a date-only value (a birthday, a due date) is not a timestamp.
- **Retries and races:** client-generated IDs or idempotency keys on every write that can be retried, unique constraints in the database, and atomic updates or transactions instead of read-compute-write.
- **Migrations** run on existing data and on every installed version still in use; backups are restored at least once.

**Text and people:**
- UTF-8 everywhere, locale-aware formatting of numbers, dates and currency, and whole translated sentences instead of concatenated fragments.
- Right-to-left scripts, non-Latin digits (`Number('١٢٣')` is `NaN` in JavaScript, and most parsers need them normalized first) and fonts that cover every letter you need.
- Accessibility: real labels, keyboard and screen-reader support, contrast, and layouts that survive larger text.

**Failure and limits:**
- No swallowed errors: one error shape, a clear message for the user, the details in logs.
- Every async view has loading, empty, error and success states.
- Timeouts on every network call, pagination on every list, size limits on uploads and queries.
- Flaky or missing internet is normal for mobile, field and shop apps.

**Release:**
- Release builds signed with real, backed-up keys, debug settings off, crash reporting from day one.

Details: `references/concerns/` for money, localization and offline; each `references/platforms/` file for its platform's traps.

## Git

- Start each task from a clean state, on a feature branch, never directly on `main`.
- **Commit locally after every green step,** with a message that says what and why, in the repo's convention: `fix(sync): upsert sales by client UUID so retries can't duplicate them`, never "update" or "fix". The user set this skill up to commit like this on working branches. Pushing, merging and deploying still need an explicit ask.
- Stage explicit paths and read `git diff --staged` first; `git add .` is how `.env` files get committed. Keep each commit to one logical change, with no formatting mixed into behaviour changes.
- To undo, use git (`revert`, `restore`), not code reconstructed from memory.
- Never force-push, skip hooks or run destructive commands. The bundled guard hook blocks them once installed; if the user explicitly wants one, they run it themselves.

Details: `references/build/git-and-tooling.md`.

# Build workflow

## 1. Check that vibe coding fits

Vibe coding fits prototypes, internal tools, MVPs, scripts and anything where iteration speed matters most. Slow down for:
- security- or money-critical logic
- data migrations and production data
- billing, stock and anything that must add up
- concurrency, hot paths and anything where "it works" isn't "it's fast enough"
- firmware and other code that's hard to update once shipped

For those, review the code like a junior engineer's, or write the sensitive core by hand, and tell the user plainly. A prototype built to answer a question is fine, as long as it's labelled throwaway and rewritten properly if it survives.

## 2. Discover the problem, the specs and the setup

- **Size it out loud:**
  - Quick task (a bug fix, a one-file change, a small script): do it, then say what you assumed.
  - Small change (one module or screen with clear requirements): state the approach and assumptions in 2-3 lines, or at the top of a short plan file, then build test-first. Stop to ask only for the user's own decisions (see Decisions).
  - Project (a new app or service, work across modules or sessions, or anything touching auth, payments, sync or more than one platform): discovery, stack choice, design, plan, then build.

  Step up a size if a "small change" turns out to touch auth, sync, the schema or a public API.
- **Look things up before asking.** The repo, its manifests and lockfiles, docs, data, history and the installed tools are your job.
- **Intent first.** Until you know why they want it, ask open questions in their words. Listen for "should want" answers ("scalable", "clean architecture", "the standard way") and ask what they would want if they didn't have to justify it.
- **Then ask in numbered rounds:** every question whose prerequisites are already answered, each with your best guess or recommended default, worded so "yes" accepts it. Questions that depend on unanswered ones wait for the next round.
- **For projects, cover:**
  - **Goal and users:** who uses it, the one job it must do well, what success looks like.
  - **Functional specs:** the main user flows as short stories with acceptance criteria, and what's out of scope.
  - **Quality needs:** users and data volume, speed targets, offline use, security and privacy, languages, currency and time zones, accessibility, devices and platforms, uptime.
  - **Constraints:** budget for hosting, paid services and store fees; the deadline; existing systems and data to integrate or migrate; who maintains it afterwards.
  - **The dev setup:** operating system and machine, languages and tools already installed (check versions yourself where you can), editor, hardware limits (iOS builds need a Mac), and the accounts and keys the project will need.
- **Questions meant for a client:** draft them for the user to forward, in plain words, each tied to a real moment ("the last time a customer returned something"), most important first.
- **Play it back before building:** outcome, users, success, the binding constraint and what's out of scope, in their words, and get an explicit yes. "Whatever you think" is not a yes: offer two concrete options instead.
- **Write it down** as a short spec (`docs/specs/YYYY-MM-DD-<topic>-spec.md`). Say every default out loud and label guesses. Push back on weak ideas, with the reason.

Details: `references/build/discovery-and-specs.md`.

## 3. Choose the stack: ask, then recommend

The stack is the first one-way door, so it gets the full Decisions treatment.
- **An existing project keeps its stack.** Use its language, framework, libraries and conventions; don't add a second way of doing what it already does.
- **For a new project or a new part, offer 2-3 stacks.** For each: the stack in one line, why it fits these specs, its trade-offs (learning curve, hosting cost, ecosystem maturity, performance, how well AI tools know it, who can maintain it), and which one you recommend. A language the user already knows counts strongly in its favour.
- **Match the tool to the job, not to habit:** a static site doesn't need a SPA framework, a script doesn't need a server, and a team of one rarely needs microservices or Kubernetes.
- **Record the choice** in an ADR (`docs/adr/0001-stack.md`): the options, the choice, the reasons.
- **Set up and verify the dev environment before writing code:** install or confirm the toolchain, pin versions in the repo (`.nvmrc`, `.python-version`, `rust-toolchain.toml`, `global.json`, `.tool-versions`), and run the platform's own check where one exists (`flutter doctor`, `npx expo-doctor`, `dotnet --info`, `go env`).

Details: `references/build/choosing-a-stack.md`.

## 4. Design (projects)

- **Sketch the architecture first:** the parts (clients, services, databases, queues, third-party APIs), how data flows between them, and where the trust boundaries are.
- **Offer 2-3 approaches as options** and prefer the simplest that meets the goal. Make "done" concrete with mockups, example inputs and outputs, sample API calls or a receipt layout. For tricky business rules (returns, debts, discounts, stock, permissions), a clickable one-file prototype beats any description.
- **MVP = one user job done well,** aimed at the riskiest assumption, with later phases listed but not built.
- **For projects, nothing is scaffolded, installed or coded until a written design is approved** (`docs/specs/YYYY-MM-DD-<topic>-design.md`). "Sounds good" to an idea in chat is not approval of a design nobody wrote down. Pre-mortem the design before asking for that approval.
- **Client work:** approvals in writing, a Not Doing list, and trade-offs explained in plain words. These are what you point to when scope creeps.

Details: `references/build/planning.md` §1-3.

## 5. Plan (projects)

- **Write the plan to a file** (`docs/plans/YYYY-MM-DD-<feature>.md`) so it survives context resets.
- **Slice vertically.** The first slice is a tracer bullet: the thinnest path through every layer (storage → logic → interface → test). Risky pieces go first: sync, payment callbacks, hardware integration, the slowest query.
- **Every task names:**
  - the files and interfaces
  - the failing test, with literal values
  - the command, with expected FAIL and then PASS
  - the commit message

  "Add error handling" is not a task; say which errors.
- **Execution:** a checkpoint every 2-3 tasks, and a short ledger of finished tasks and the small calls you made. Inside an approved plan, don't ask "should I continue?". Stop only for destructive steps, security-sensitive changes the plan didn't spell out, a decision that belongs to the user, anything outside the branch, or a plan that turns out broken.

Details: `references/build/planning.md` §3-5.

## 6. Data model and architecture

- **Sketch the data model before the interface:** entities, relationships, ownership, persistence. Get the types right from the start:
  - money as integers or decimals
  - server-written UTC timestamps
  - numbers as numbers, enums as enums
  - constraints and indexes in the database
- **Deep modules,** organized by feature. Domain logic (money, stock, permissions, sync) lives in pure functions with no UI, network or database imports.
- **Contracts first:** typed inputs and outputs, one error shape, validation at boundaries, pagination from day one.
- **Never swallow errors,** and make every write safely retryable (client-generated IDs, idempotency keys).
- **Standards set early stick,** so review the first few files carefully. Left alone, AI appends; schedule refactor passes that split big files, delete dead code and merge duplicate helpers.

Details: `references/build/architecture-and-data.md`.

## 7. Guardrails on day one

Scale them to what you're building:
- A new repository that will live on (a client app, anything that will get a remote) gets the full list below.
- A prototype, script or standalone module gets git, `.gitignore`, the strictest practical type checking and tests. Add hooks, CI and dependency bots when it gets a remote or a second contributor.
- Inside an existing project, use its tooling rather than adding new tools.

The full list (the tools for each language are in `references/build/git-and-tooling.md` §1):
- `.gitignore` written **first** (`.env*`, build output, keystores and signing files, service-account JSON, local databases). Also `.gitattributes`, `.env.example`, pinned toolchain versions and committed lockfiles.
- Strict types or compiler warnings as errors where the language has them, a linter and a formatter.
- A test runner with one passing test.
- Fast pre-commit hooks: format, lint and secret scan on staged files.
- CI on every push and PR, required before merging.
- A release cooldown for dependencies, and Dependabot or Renovate with a cooldown of its own.
- **The guard hook and secret deny rules** are a one-time install in the user's Claude Code settings. Check whether they're there; if not, offer them once. On GitHub, branch protection with "do not allow bypassing" (admins bypass by default; private repos need a paid plan).
- One command per check (lint, typecheck, test, test-one, build, run), recorded in the context file.

## 8. Living context file

Keep `CLAUDE.md` (or `AGENTS.md`, or both) with what can't be looked up elsewhere:
- the exact commands
- conventions and things not to do
- gotchas, each with its reason
- pointers to the spec, plan, decision log and ADRs
- removed features that must not come back

Don't restate the manifest (`package.json`, `pyproject.toml`, `go.mod`, `pubspec.yaml`), because copies go stale. When you're told the same thing twice, add it. Update the file after any session that produced a correction, and read it first in every new session. After a rough session, ask which mistake a lint rule, hook or test could have caught, and add that check.

## 9. Context hygiene and subagents

- **Compact or reset at task boundaries,** never mid-implementation. Before ending a session, write a handoff: decisions (and the log entries), task status, files changed, verification commands and results, open questions.
- **Subagents get a full brief:** the task with exact values, interfaces from earlier tasks, the decisions already made, and the reply format. Never hand over the whole session history, and never let a subagent make a decision that belongs to the user.
  - Run them in parallel only on independent problems, each in its own worktree if they write code.
  - For risky work, add a reviewer subagent that checks the diff against the brief.
  - Verify what subagents claim before passing it on.

Details: `references/build/planning.md` §5.

## 10. Build test-first, in small slices

AI-generated code is implementation-first with little testing, so testing has to be a forced step.
- **Red → green → refactor:**
  1. Write one test for one behaviour.
  2. Watch it **fail for the right reason** (the assertion, not an import or compile error).
  3. Write the least code that passes.
  4. Refactor on green, as its own commit.
- **Every bug starts as a failing test** that reproduces it.
- **Expected values come from an independent source,** never recomputed with the code's own logic.
- **Mock only what you don't own** (payment gateways, SMS, email, printers). For your own stack, use real local stand-ins: an in-memory or containerized database, the platform's emulators, a local server.
- **Test the paths that hurt:** money, permissions, sync, migrations, concurrency, and failures (offline, timeout, 500, double submit, bad input). E2E only for critical journeys, with no fixed sleeps.

Details: `references/build/testing.md`.

## 11. Debugging

- **Reproduce first** with a fast, deterministic loop (a failing test, a curl script, a replayed payload, a CLI call). Ask for raw error text, not paraphrases.
- **Check what changed:** `git diff`, recent commits, dependency updates, env vars and config. Values baked in at build time (web build variables, mobile build defines) need a rebuild, not a restart.
- **Form 3-5 ranked hypotheses** with predictions and test one variable at a time. Use tagged temporary logs at boundaries, and drive the real program for UI bugs. If the code used to work, run `git bisect run`.
- **Fix the source, not the symptom.** When the fix itself is a real choice (a workaround now or a redesign, a patch or a migration), offer it as options.
- **Close with a short report:** what was wrong, the root cause, the fix, the regression test, and what prevents it next time. Remove the debug logs.
- **If a third fix fails,** or each fix exposes new coupling, stop patching and discuss the design.

Details: `references/build/debugging.md`.

## 12. Review and refactor

- **Before presenting work, review your own diff as a stranger would,** on five axes:
  - **Correctness:** does it do what was asked, and nothing extra, including the edge and failure cases? Are there tests?
  - **Simplicity:** is it the simplest version? Does every abstraction earn its place?
  - **Architecture:** does it follow the project's patterns and keep logic in the layer that owns it?
  - **Security:** input, auth, ownership, secrets, the data it returns.
  - **Performance:** queries in loops, unbounded lists, work that runs on every render or request.
- **Keep changes reviewable:** about 100-300 changed lines; split larger ones. Approve a change when it clearly improves the code's health, not only when it's perfect.
- **For risky changes, review in fresh-context subagents or with `/review`:** does it meet the spec, and is the code sound?
- **Receiving review:** verify each point against the code, push back with evidence when it's wrong for this codebase, and fix one item at a time with a test.
- **Refactor only on green,** in commits that change no behaviour. Before handing code over, strip AI tells (narrating comments, generic names, over-engineering) with `/simplify` or `unslop-code`.

## 13. Ship and maintain

Running locally isn't done:
- **Preview or staging first;** production only when the user asks. Keep dev and prod as separate projects and databases, with sandbox payment credentials outside production.
- **The deploy target fits the project:** static hosting, a platform service, containers, serverless, app stores, desktop installers, package registries or firmware updates (`references/build/shipping.md` §2-3).
- **Observability:** crash and error reporting proven with a test error, structured logs with no secrets or personal data, health checks and alerts for services.
- **A rollback plan,** risky features behind flags whose default is safe, and backups restored at least once.
- **Releases:** semantic versions or increasing build numbers, release notes, and signing keys backed up where the team can find them.
- **Before launch:** a pre-mortem, the launch checklist (`references/build/shipping.md` §7), a README with setup, run, test and deploy steps, and an Audit-mode run on the release candidate.
- **Afterwards:** scheduled dependency updates, monitoring someone actually reads, and for client work a handoff note: which accounts the client owns, how to deploy, where the secrets live.

Code exported from an app builder (v0, Lovable, Bolt, Replit, Firebase Studio) gets the §7 guardrails and an audit before anyone builds on it.

# Audit workflow

Audit the code the way a senior engineer would if hired to find every way it leaks data, loses money, falls over in production or embarrasses its owner. Be paranoid: comments, function names and README claims prove nothing until the code path confirms them. But report only what you can show. Look hardest at what a demo can't show: access rules, ownership checks, webhook signatures, atomic writes, error handling, migrations, localization, real tests.

## Ground rules

- **Read and report.** Change nothing unless the user asks afterwards; fixing is Build mode.
- **Never exploit.**
  - No requests against production, no trying a found credential, no brute forcing.
  - TruffleHog verifies keys with the provider by default, so always add `--no-verification`; gitleaks never verifies.
- **Builds and tests run project code, so they are not read-only:**
  - Check dependency names for typosquats first, and list install-time scripts without running them (`grep -n '"hasInstallScript": true' package-lock.json`, `setup.py`, `build.rs`, Gradle plugins).
  - If tests or the build use a live database, backend or payment account and no emulator or local stack exists, skip them and list them under "couldn't check".
  - Install only when dependencies are missing, from the lockfile, with install scripts off where the tool allows: `npm ci --ignore-scripts`, `uv sync --frozen`, `flutter pub get --enforce-lockfile`, `composer install --no-scripts`, `bundle install --frozen`, `cargo fetch --locked`, `dotnet restore --locked-mode`, `go mod download`.
- **Mask secrets everywhere you write.** Show only the prefix that names the key type, plus the length (`sk_live_…(107 chars)`, `sb_secret_…`, `AKIA…`). Passwords, PINs and values with no known prefix get no characters: `storePassword=…(10 chars)`.
- **Evidence or it didn't happen.**
  - Every finding needs file:line and the path you followed: who can reach it, what it touches, what stops them.
  - What needs a console you can't see (deployed database rules, a cloud dashboard, a gateway's webhook config) is reported as "needs confirmation in <place>".
- **Don't stop at the first hit.** One leaked key usually means three; one endpoint missing an ownership check usually means all of them.
- **Don't grade your own work.** If this session built the code, run the audit in a fresh session or subagent that hasn't seen the build, and say which you did.

## Steps

Read `references/audit/workflow.md` before step 2: it has each stack's commands, the attack-surface checklist, the severity scale and the report format.

1. **Scope.** What the software does, who uses it, and what's worth stealing or breaking: personal data, money, stock, accounts, the sending domain, the paid API bill, the devices it controls. Note the languages, frameworks, deployment and distribution (web, store, installer, package, firmware). Default to a full audit. If the user names one area, audit it with the same rigor and report format.
2. **Automated sweep.** Run the lead finder, then the project's own checks for each language present (workflow §1). Strip Windows line endings first, or a CRLF copy fails with `$'\r': command not found`:
   ```bash
   tr -d '\r' < <this-skill-dir>/scripts/scan.sh > /tmp/vibe-scan.sh && bash /tmp/vibe-scan.sh <repo>   # leads only; masks secrets; read-only
   ```
   A failing build, type check or test run is itself a finding. Don't install global tools without asking.
3. **Map the attack surface:** every entry point and who can reach it, including framework RPC, webhooks, jobs, database rules and everything shipped to clients (workflow §2).
4. **Security pass (deep)** with `references/audit/security.md`: secrets and history, auth and ownership (IDOR), access rules, money and business logic, webhooks and payment callbacks, paid APIs and LLMs, injection and unsafe sinks for every language present, sessions/CORS/headers, platform specifics (web, mobile, desktop), dependencies and supply chain, logging and privacy, and containers, CI, infrastructure and other kinds of software.
5. **Quality passes.** Walk **every line** of `references/audit/quality.md` against the code: correctness, data integrity, performance, UX/accessibility/localization, tests and tooling, production readiness. Most lines take seconds, and skipped lines are where audits miss things. Trace deeply only where the software's purpose makes an area critical, like money and stock in a POS or personal data in a clinic app. Trace at least one critical flow end to end, client to server and back.
6. **Confirm, merge, prune.** Trace every lead to a real path, merge findings with one root cause, and drop what you can't support. List what you ruled out, one line each.
7. **Report** (workflow §3-4): the verdict first (**Blocked** / **Risky: internal or pilot only** / **Launchable with caveats** / **Ready**; any Critical means Blocked), a plain-words summary for the owner, the scorecard, the findings table worst-first with file:line, scenario and fix, the Top 3 to fix today, what was checked and fine, and the evidence.
8. **Offer the fixes as decisions** (workflow §5): the Top 3 first, with options where a finding has more than one reasonable fix. Fixing is Build mode: reproduce with a failing test, fix, re-run the checks, and re-audit the touched paths.
