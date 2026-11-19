# vibe-code

A Claude skill for building and auditing AI-made software the way a senior engineer does. You describe what you want. It asks the right questions first, plans before writing code, builds in small test-first steps, and doesn't say "done" without proof. When the app is ready, audit mode checks it the way an attacker would, before launch or handoff.

It is built for the work that comes up in Kurdistan and Iraq: Flutter and offline-first POS apps on SQLite, Next.js and Expo, Firebase and Supabase, Kurdish and Arabic right-to-left, IQD money, and local payment gateways like FIB and ZainCash.

## Install

**Claude Code (recommended, full version with the guard hook)**

```bash
npx skills add mshmsh03/vibe-code
```

Or by hand: download this repo and put the folder at

- Windows: `C:\Users\<you>\.claude\skills\vibe-code`
- macOS / Linux: `~/.claude/skills/vibe-code`

Restart Claude Code, then type `/vibe-code`, or just describe what you want built or checked ("build me a POS for a sweets shop", "add offline sync", "is my app safe to launch?").

**Claude app:** zip the folder and upload it in the app's skills settings. The guard hook and slash commands only exist in Claude Code.

## What you need

- Git, plus Git Bash on Windows, for `scripts/scan.sh`.
- Node.js for the guard hook, `scripts/guard-commands.mjs`.
- Optional: gitleaks. When it's installed, the scanner uses it for a deeper secret scan of the git history.

## How it works

**Build mode** ("build", "add", "fix", "vibe code this")

1. **Questions and a plan before code,** sized to the task: two or three lines of approach for a small change, a written design and plan for a new project.
2. **Guardrails on day one:** git, strict types, lint, hooks and CI, set up before the first feature.
3. **Small test-first slices,** each committed when its tests pass.
4. **Evidence before "done":** the test run, the build output or a screenshot, never just a claim.
5. **Secure patterns** for auth, Firebase rules, Supabase RLS, secrets, payments and LLM features, plus stack rules for React/Next.js, Flutter, Expo, POS and right-to-left.

**Audit mode** ("check", "audit", "is it safe", "ready to launch", "did I leak keys")

1. **Read-only:** it changes nothing, never exploits anything, and masks every secret it quotes.
2. **A first-pass scan** (`scripts/scan.sh`) for leaked keys in the files and the whole git history, open database rules, unverified webhooks and common AI-code mistakes.
3. **Security first,** then correctness, data, performance, UX and right-to-left, tests and launch readiness.
4. **A verdict and a ranked report:** every finding has its file and line and a one-line fix, with the top 3 to fix first.

## What is in this folder

| Path | What it is |
| --- | --- |
| `SKILL.md` | The two modes, the rules for every change, and both workflows |
| `references/build/planning.md` | Anything bigger than a quick fix: questions, design doc, prototypes, slicing, plan format, executing a plan, subagents, ADRs |
| `references/build/architecture-and-data.md` | Stack choice, modules, API shape, errors, idempotency, schema, indexes |
| `references/build/git-and-tooling.md` | Project setup, commits, the guard hook, pre-commit, CI, merge conflicts |
| `references/build/testing.md` | TDD, good tests, mocks, flaky tests, E2E, RTL tests |
| `references/build/debugging.md` | Something's broken and the first obvious fix didn't work |
| `references/build/security.md` | Building auth, Firebase rules, Supabase RLS, secrets, payments, uploads, rate limits, LLM features |
| `references/build/web-frontend.md` | Any web UI: RTL, forms, the four states, accessibility, Core Web Vitals, React/Next.js |
| `references/build/mobile-and-offline.md` | Flutter, Expo/React Native, Windows tills, offline POS, SQLite, IQD, printing, Kurdish RTL |
| `references/build/shipping.md` | Environments, deploys, signing and store release, flags, monitoring, launch checklist |
| `references/audit/security.md` | Audit: per-stack security checks, detection commands, severity calls |
| `references/audit/quality.md` | Audit: correctness, data, performance, UX/RTL, tests, readiness, and the launch verdict |
| `scripts/scan.sh` | The audit's read-only lead finder: masks secrets and scans the whole git history |
| `scripts/guard-commands.mjs` | A Claude Code hook that blocks destructive git commands and risky deletes, and asks before production deploys |
