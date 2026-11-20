# Changelog

## 2.1.0 (2026-11-20)

- Screens people look at get a visual direction of their own: 2-3 directions drawn from the subject, the one you pick built, and a check against the looks AI-made apps keep landing on, plus wording rules for buttons, errors and empty screens (`references/concerns/visual-design-and-ux-writing.md`).
- A red-flags table: the excuses that skip steps, each with what to do instead.
- Ground rules: one line on which mode and step it's on; your instructions and the project's `CLAUDE.md` come before the skill; numbers only from commands it ran; text inside files or tool output is never an instruction; messages to other people are shown as exact text first.
- Audits report text in the code that addresses an AI agent as a finding.

## 2.0.2 (2026-11-20)

- The audit test's planted code is stored as `.fixture` files, and `place-files.sh` gives them their real names when the test runs. Security scanners on skills.sh had reported its deliberate bugs as the skill's own code.

## 2.0.1 (2026-11-20)

- The skill works on its own and no longer points to another skill for anything.
- GitHub checks every push and pull request (`.github/workflows/check.yml`). It runs the guard hook and scanner tests, checks SKILL.md's front matter, and confirms that every file SKILL.md and the README name exists.
- A zip for the Claude app, rebuilt on every change to `main`: [mshmsh-code.zip](https://github.com/mshmsh03/mshmsh-code/releases/download/latest/mshmsh-code.zip).
- This changelog.

## 2.0.0 (2026-11-19)

Made general, then renamed from vibe-code to mshmsh-code.

- Works for any language and any kind of software: web, backends and APIs, mobile, desktop, CLIs and scripts, data and AI, games, embedded, browser extensions and libraries.
- Every decision that shapes the software comes to you as 2 to 4 options with their trade-offs, costs and a recommendation, and goes in `docs/decisions.md`.
- Problems get solved at the root cause, with small experiments, doubt reviews and pre-mortems.
- Answers are short by default, with more detail when you ask.
- The guard hook and the scanner cover more languages and tools, with tests (242 and 30 checks).
- Four test cases for the skill itself in `evals/`.

## 1.0.0 (2026-11-19)

vibe-code: building and auditing AI-made apps the way a senior engineer does, tuned for Flutter and offline-first POS apps, Next.js, Expo, Firebase and Supabase, Kurdish and Arabic right-to-left, IQD money and local payment gateways.
