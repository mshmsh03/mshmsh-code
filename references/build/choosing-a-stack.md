# Choosing a stack: ask, then recommend

Read this before picking languages, frameworks, databases or hosting for a new project, or for a new part of an existing one (a mobile app beside a web app, a new service, a data pipeline). SKILL.md Build §3 has the short version; `decisions-and-problem-solving.md` has the general options method this file applies.

The stack is usually the most expensive decision to reverse, so it goes to the user as options, never as a silent default.

## Contents
1. Existing projects keep their stack
2. Inputs: what the choice depends on
3. What pushes the choice which way
4. Candidates by kind of software
5. Languages
6. Databases
7. Hosting and backend services
8. Buy, don't build
9. Red flags
10. Presenting the options
11. Recording the decision and setting up

---

## 1. Existing projects keep their stack

- Use the project's language, framework, libraries and conventions. Read the manifests and a few representative files before adding anything.
- Don't add a second way of doing what the project already does (a second HTTP client, state library, ORM, test runner or CSS approach).
- A new dependency is a decision: say what it's for, why the existing code can't do it, and check it's real, maintained and licensed for the use. Small things are often a few lines of your own code instead.
- Replacing a stack is a project of its own, with its own options and an explicit yes. "This would be nicer in X" is not a reason.

## 2. Inputs: what the choice depends on

Collect these during discovery (`discovery-and-specs.md`) before recommending anything:
- **Platforms:** web, iOS, Android, Windows, macOS, Linux, a server, a device. Which are required at launch and which come later?
- **Quality needs that change the architecture:** offline use, real-time updates, heavy computation, large data, strict latency, SEO and link previews, device hardware (camera, Bluetooth, NFC, printers, scanners), background work.
- **People:** what the user and their team already know, who maintains it after launch, and what local developers and freelancers know if it's handed over.
- **Money:** the monthly running cost the owner accepts at launch and at 10x the users; store and developer account fees.
- **Time:** the deadline and how much of it can go to learning something new.
- **Rules:** where data may live, regulated data (health, payments, children), on-premises requirements, licences.
- **Existing systems:** databases, identity providers, accounting or ERP systems, payment gateways the business already uses.

## 3. What pushes the choice which way

| If the project needs... | Lean towards | Avoid |
|---|---|---|
| To work without internet | A local database (SQLite) as the source of truth, with sync; a native or cross-platform app | A web app that only works online (a PWA can cover light offline use) |
| App-store presence or deep device access | Native or cross-platform mobile (Flutter, React Native/Expo, Swift/Kotlin) | A web wrapper that fights the platform |
| Search engines and link previews | Server-rendered or static web pages | A client-only SPA for public content |
| Real-time collaboration | A managed real-time service or a WebSocket server | Polling every few seconds |
| Heavy computation or low latency | Go, Rust, Java/Kotlin, C#; Python only with native numeric libraries | Interpreted hot loops |
| One small team on many platforms | One cross-platform codebase (Flutter, React Native, Tauri/Electron, a PWA) | Separate native apps per platform |
| A tiny budget | Static hosting, free tiers of managed services, or SQLite on one small server | Several always-on services and managed clusters |
| On-premises or no cloud | Self-hostable parts (Postgres, containers, plain servers) | Backend-as-a-service lock-in |
| A long life and unknown future maintainers | The most popular, best-documented option in that space | Niche frameworks and one-person libraries |
| To ship in days | What the user already knows, plus managed auth and database | Anything new to them |

When two needs pull in opposite directions (offline vs real-time, budget vs scale), that tension is the decision: put it to the user in those words.

## 4. Candidates by kind of software

These are starting candidates, not answers. Offer the 2-3 that fit the inputs, with the trade-offs for this project. Check current versions, prices and limits before quoting them.

| Kind | Candidates | When each wins |
|---|---|---|
| **Content site** (company site, menu, portfolio, docs) | Astro or another static generator · a hosted site builder · a small CMS with a static front end | Static: fast, cheap, nothing to hack. Builder: the owner edits everything alone. CMS: frequent edits by non-developers |
| **Web app** (SaaS, dashboard, internal tool) | Next.js, SvelteKit, Nuxt or Remix/React Router · Django, Rails or Laravel · a Vite SPA with an API | JS full-stack: one language, rich UI. Batteries-included server frameworks: forms, admin, auth and ORM built in, least code for CRUD. SPA + API: the API also serves mobile apps |
| **API or backend service** | Node/TypeScript (Fastify, Hono, NestJS) · Python (FastAPI, Django) · Go · Java/Kotlin (Spring Boot, Ktor) · C# (ASP.NET Core) | The language the team knows wins. Go: simple deploys and concurrency. Java/C#: big ecosystems and enterprise integration. Python: data and AI work nearby |
| **Backend-as-a-service** | Supabase (Postgres) · Firebase (Firestore) · your own API | BaaS: auth, database and storage in days, with access rules as the security layer. Own API: complex business logic, on-premises needs, no lock-in |
| **Mobile app** | Flutter · React Native/Expo · native Swift and Kotlin · Kotlin Multiplatform | Flutter: one codebase including desktop, consistent UI. Expo: JS/React skills, over-the-air updates. Native: best platform feel and newest APIs, two codebases. KMP: shared logic, native UI |
| **Offline-first business app** (POS, field data, clinics) | Flutter or React Native with SQLite, syncing to an API or Firestore · a native app with a local database · a PWA with IndexedDB | Local database as the ledger, sync as a separate concern (`../concerns/offline-first-and-sync.md`). PWA only when offline needs are light and no special hardware is involved |
| **Desktop app** | Tauri · Electron · Flutter desktop · .NET (WPF, WinUI, Avalonia) · Qt · native SwiftUI | Tauri: small installers, web UI, Rust core. Electron: the most mature, large installers. .NET: Windows-first business apps. Qt: native performance across platforms |
| **CLI tool, script, automation, bot** | Python · Go · Node/TypeScript · Rust · shell for short glue | Python: fastest to write, rich libraries. Go/Rust: one binary to distribute. Node: the project is already JS. Shell: under ~50 lines with no logic worth testing |
| **Data pipeline or analytics** | Python with pandas or Polars · SQL with dbt · DuckDB · an orchestrator (Dagster, Prefect, Airflow) | SQL-first when the data lives in a warehouse. DuckDB for local analytics on files. An orchestrator only once there are several scheduled steps with dependencies |
| **Machine learning** | Python with scikit-learn, PyTorch, or managed APIs | Classic tabular problems: scikit-learn or gradient boosting first. Deep learning: PyTorch. A hosted model or API when training isn't the point |
| **LLM-powered feature** | A provider API called from the server · a framework only when it earns its place | Plain SDK calls first; keys server-side, outputs validated, spend capped (`../platforms/data-and-ai.md`) |
| **Game** | Godot · Unity · Unreal · Phaser, PixiJS or Three.js for the web | Godot: free, light, good for 2D and small 3D. Unity: largest ecosystem, mobile. Unreal: high-end 3D. Web libraries: browser games |
| **Embedded or IoT** | C/C++ (ESP-IDF, Zephyr, Arduino) · MicroPython · embedded Rust | C/C++: the vendor SDKs. MicroPython: quick prototypes on capable boards. Rust: memory safety on supported chips |
| **Browser extension** | WebExtensions (Manifest V3), optionally a framework such as WXT | One codebase for Chromium browsers and Firefox |
| **Library or package** | The ecosystem's standard layout and tooling | Follow the registry's conventions; minimal dependencies |

## 5. Languages

- **The language the user already knows is the default** unless a hard requirement rules it out. Learning a language while building a product doubles the risk.
- **TypeScript** over plain JavaScript for anything that lives longer than a week.
- **Python** for scripts, automation, data and AI; add type hints and a type checker for anything that grows.
- **Go** for network services and CLIs that must be one simple binary.
- **Rust** where memory safety and performance both matter and the team can absorb the learning curve.
- **Java/Kotlin and C#** for large, long-lived business systems, Android (Kotlin) and Windows (C#).
- **Swift** for Apple platforms; **Dart** with Flutter.
- **PHP and Ruby** remain good choices with Laravel and Rails, especially where hosting or local talent favours them.
- **C/C++** for embedded and performance-critical native code, with sanitizers and warnings as errors.
- Prefer one language across the stack when the team is small, unless a part has a requirement only another language meets.

## 6. Databases

- **PostgreSQL is the default** for server-side data: relational, constraints, transactions, JSON when needed, full-text search, and every host supports it.
- **SQLite** for local and embedded data (mobile, desktop, POS ledgers, CLIs, tests) and for small single-server apps.
- **Document databases** (Firestore, MongoDB, DynamoDB) when the access patterns are known and simple, offline client sync is built in (Firestore), or the platform demands it. They make reporting and changing relationships harder later.
- **A cache or queue** (Redis or Valkey, a managed queue) only when measurements show the need.
- **Search engines, time-series and analytics stores** (Meilisearch, OpenSearch, ClickHouse, DuckDB) when the main database demonstrably can't serve the query.
- **One database until you must have two.** Every extra store adds backups, migrations, monitoring and a consistency problem.

## 7. Hosting and backend services

| Option | Fits | Watch out for |
|---|---|---|
| Static hosting (Netlify, Cloudflare Pages, GitHub Pages, Vercel) | Content sites, SPAs | Anything secret: there is no server |
| Platform services (Vercel, Netlify, Render, Railway, Fly.io, Heroku-style) | Web apps and APIs with little operations work | Price jumps at scale, region choice, cold starts, vendor-specific features |
| Serverless functions | Spiky or light APIs, webhooks, scheduled jobs | Timeouts, cold starts, no shared memory between instances, per-invocation costs |
| Containers (a managed container service, Kubernetes) | Several services, specific runtimes | Kubernetes is rarely worth it for a team of one or two |
| A plain server (VPS) | Cheap, predictable cost, full control | You own patching, backups, TLS and monitoring |
| Backend-as-a-service (Supabase, Firebase) | Fast starts, auth and real-time included | Access rules are your whole security model; lock-in; per-read or per-user pricing |
| On-premises | Data that can't leave the building, unreliable internet | Backups, updates and hardware are the owner's job |

- Pick a region near the users, and check that the provider is reachable from where they are.
- Write the expected monthly cost at launch and at 10x usage into the options.
- Keep dev and prod as separate projects or accounts from day one.

## 8. Buy, don't build

Use mature services or libraries for anything that isn't the product's core, because they encode years of security fixes:
- **Authentication:** the framework's auth, a library, or a managed provider. Never your own password hashing or session crypto.
- **Payments:** the gateway's hosted page or SDK; card data never touches your server.
- **Email and SMS:** a delivery provider, with domain authentication (SPF, DKIM, DMARC).
- **Maps, search, analytics, error tracking, feature flags:** managed services or established libraries.

Build the parts that make the product different: its business rules, workflows and data.

## 9. Red flags

- Choosing for a scale the project may never reach ("in case we get a million users").
- Microservices, event buses or Kubernetes for a team of one.
- A niche or brand-new framework with thin documentation: both the AI and future maintainers will guess, badly.
- More than one new technology for the user in the same project.
- A stack picked because it was in a tutorial, not because it fits the inputs.
- Several providers where one would do (separate auth, database, storage and functions vendors for a small app).

## 10. Presenting the options

Offer 2-3 stacks through the question tool (SKILL.md "Decisions"), recommended first:

```
header:   "Stack"
question: "Which stack should the shop's order app use? It must work offline on
           Android tablets and a Windows PC, and print receipts."
options:
  - label: "Flutter + SQLite (Recommended)"
    description: "One codebase for tablets and the PC, a local database so sales
      continue offline, and you already know Dart. Cost: desktop printer plugins
      are less mature, so printing gets an early spike."
    preview: "lib/sales/ · lib/sync/ · local SQLite ledger → sync to API"
  - label: "React Native + Expo"
    description: "Strong for phones and tablets, over-the-air updates. Cost: Windows
      support is weaker, so the PC would likely need a separate app."
  - label: "Web app (PWA)"
    description: "No installs, one URL, cheapest to update. Cost: offline is
      limited and direct printer and scanner access is unreliable."
```

Without the tool, use the same content as lettered options in text. In both cases:
- Say why the recommendation fits *these* inputs, in one or two sentences the user can repeat to someone else.
- Name the cost of every option, including the recommended one.
- Mention the monthly running cost when it differs between options.
- If the user picks against your recommendation, build it well; note the risk once in the decision log, not repeatedly in chat.

## 11. Recording the decision and setting up

**ADR** at `docs/adr/0001-stack.md`:

```markdown
# ADR-0001: Stack for the order app
Status: Accepted · Date: 2026-11-19 · Decided by: the user

## Context
Offline sales on 3 Android tablets and 1 Windows PC; receipt printing; owner pays
under $20/month; built and maintained by one developer who knows Dart.

## Options considered
- Flutter + SQLite, syncing to a small API: one codebase, offline-first, known language
- React Native + Expo: strong mobile tooling, weak Windows support
- PWA: cheapest, but offline and printing are unreliable

## Decision
Flutter + SQLite with a small API for sync.

## Consequences
Easier: one codebase, offline by design. Harder: desktop printing needs a spike.
Revisit if: iOS becomes required, or more than ~10 branches need central reporting.
```

Then add a line to `docs/decisions.md`, and set up the environment: install or confirm the toolchain, pin versions in the repo, and run the platform's own check (`discovery-and-specs.md` §7).
