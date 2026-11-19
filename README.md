# vibe-code

A Claude skill that makes an AI coding agent work like a senior engineer, in any language and for any kind of software: web, backends and APIs, mobile, desktop, CLIs and scripts, data and AI, games, embedded, browser extensions and libraries.

It does three things:

- **Decides well, with you.** Every decision that shapes your software (the stack, the data model, a paid service, how a business rule works, deleting anything) comes to you as 2-4 real options with their trade-offs, costs and a recommendation. You pick; it builds exactly that, explains why in plain words, and writes the decision down so it isn't re-argued or quietly undone later.
- **Solves problems at the root.** It figures out what kind of problem it's facing, finds the root cause before fixing anything, tests ideas with small experiments, and doubts its own confident answers before they become code.
- **Builds and checks like a professional.** Questions and a spec before code, guardrails on day one, test-first slices, evidence before "done", and a read-only audit before launch.

It's tuned for real client work, including Kurdish and Arabic right-to-left, IQD money, offline shops and local payment gateways, but nothing in it is tied to one stack.

## Install

**Claude Code (recommended: the full version, with the guard hook)**

```bash
npx skills add mshmsh03/vibe-code
```

Or by hand: download this repo and put the folder at

- Windows: `C:\Users\<you>\.claude\skills\vibe-code`
- macOS / Linux: `~/.claude/skills/vibe-code`

Restart Claude Code, then type `/vibe-code`, or just describe what you want ("build me an app for my friend's pharmacy", "which database should I use?", "this bug keeps coming back", "is my app safe to launch?").

**Claude app:** zip the folder and upload it in the app's skills settings. Hooks and slash commands only exist in Claude Code.

## What you need

- Git, plus Git Bash on Windows, for `scripts/scan.sh`.
- Node.js for the guard hook, `scripts/guard-commands.mjs`.
- Optional: gitleaks. When it's installed, the scanner uses it for a deeper secret scan of the git history.

## How it works

**Decisions.** It sorts every open question first: facts it can look up (it looks them up), facts only you know (it asks, with its best guess), your intent (one open question), and real choices (options). You decide anything that's yours by nature or hard to undo; it decides small, reversible things inside the agreed design and tells you. Options come through Claude's question tool where available (with the recommended one first and a preview of code or schemas), or as lettered options in text. Decisions are logged in `docs/decisions.md`, with an ADR for the big ones.

**Problem-solving.** Clear problems get the standard answer; complicated ones get analysis and options; unknowable ones get a small time-boxed experiment; emergencies get stabilized first. After three failed attempts at one approach it stops and rethinks instead of patching on.

**Build mode** ("build", "add", "fix", "which stack should I use")

1. **Discovery sized to the task:** two or three lines of approach for a small change; for a project, questions about users, flows, quality needs, constraints and your dev setup, played back for your yes.
2. **The stack as options:** 2-3 stacks with trade-offs, running costs and a recommendation, recorded in an ADR, then the dev environment checked and pinned.
3. **Design and plan** written down and approved before code, with a pre-mortem for big plans.
4. **Guardrails on day one:** git, strict types, lint, tests, pre-commit hooks, CI, a release cooldown for new dependencies, and secret-safe agent settings.
5. **Small test-first slices,** each committed when its tests pass, with evidence before anything is called done.
6. **Security, data and platform rules** for every language, plus references for each kind of software and for localization, money and offline sync.

**Audit mode** ("audit", "is it safe", "ready to launch", "did I leak keys")

1. **Read-only:** it changes nothing, never exploits anything, and masks every secret it quotes.
2. **A first-pass scan** (`scripts/scan.sh`) for leaked keys in the files and the whole git history, open database rules, unverified webhooks, injection in many languages, container and CI mistakes, and common AI-code bugs.
3. **Security first,** then correctness, data, performance, UX, tests and launch readiness.
4. **A verdict and a ranked report:** every finding has its file and line and a one-line fix, with the Top 3 first, and the fixes offered to you as choices.

## What is in this folder

| Path | What it is |
| --- | --- |
| `SKILL.md` | The core: how a senior engineer thinks, decisions and options, problem-solving, rules for every change, and both workflows |
| `references/build/decisions-and-problem-solving.md` | Who decides what, making and judging options, asking, reading answers, the decision log, problem shapes, doubt reviews, pre-mortems, teaching |
| `references/build/discovery-and-specs.md` | Questions, intent, vague ideas, quality targets, the spec, the dev environment, accounts and costs |
| `references/build/choosing-a-stack.md` | Stack candidates by kind of software, languages, databases, hosting, buy vs build, red flags, presenting the options |
| `references/build/planning.md` | Design doc, prototypes, slicing, plan format, executing a plan, subagents, ADRs |
| `references/build/architecture-and-data.md` | Modules, API shape, errors, idempotency, data modelling, queries and transactions |
| `references/build/git-and-tooling.md` | Setup per language, commits, the guard hook and secret deny rules, pre-commit, CI, dependency bots |
| `references/build/testing.md` | TDD, test levels and commands per language, mocks, flaky tests, E2E |
| `references/build/debugging.md` | A method for bugs that resist the first fix, and the debug report |
| `references/build/security.md` | Secrets (including keeping them out of the agent's context), auth, access rules, input handling, payments, uploads, rate limits, LLM features, supply chain |
| `references/build/shipping.md` | Environments, deploys, store and desktop releases, flags, monitoring, migrations, launch checklists |
| `references/platforms/*.md` | Web, backends and APIs, mobile, desktop, CLIs and automation, data and AI, games/embedded/extensions/libraries |
| `references/concerns/*.md` | Localization and right-to-left, money and business rules, offline-first and sync |
| `references/audit/*.md` | The audit workflow and report format, security checks for every stack, quality checks and the launch verdict |
| `scripts/scan.sh` | The audit's read-only lead finder |
| `scripts/guard-commands.mjs` | A Claude Code hook that blocks destructive commands and asks before deploys, publishes, infrastructure and database changes, and printing secrets |
| `scripts/tests/` | Tests for both scripts |
| `evals/` | Test cases for the skill itself, in the format `claude plugin eval` reads |

## Tested

- **The guard hook:** `node scripts/tests/guard.test.mjs` runs 242 checks: destructive commands blocked, risky ones asked about, everyday commands left alone, and malformed input failing closed.
- **The scanner:** `bash scripts/tests/scan.test.sh` builds a throwaway repo with planted issues in JavaScript, Python, C#, Go, Dart, Docker, GitHub Actions, Electron and Firestore rules, then checks all 30 expected results, including that no planted secret is ever printed in full.
- **The skill itself:** four cases in `evals/`: a new project that must ask and offer stack options, a bug fixed test-first, a database question answered as options, and an audit that must find seven planted issues without changing a file. Run them from this folder with Claude Code: `claude plugin eval . --allow-tools Write,Edit,Bash --scaffold`.

## Licence

MIT. See [LICENSE](LICENSE).
