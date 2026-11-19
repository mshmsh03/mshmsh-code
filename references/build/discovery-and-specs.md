# Discovery and specs: what to ask, what to write down, what to set up

Read this before building anything bigger than a quick fix. SKILL.md Build §2 has the short version. The goal is a short written spec and a working dev environment before the first line of product code, so the stack choice (`choosing-a-stack.md`) and the design rest on facts instead of guesses.

## Contents
1. How to ask
2. When the idea is still vague
3. The core questions
4. Extra questions by project type
5. Turning quality words into numbers
6. The spec file
7. The dev environment
8. Accounts, keys and running costs
9. When discovery is done

---

## 1. How to ask

**Size the work first,** out loud:
- **Quick task:** the request already holds everything that matters (a bug fix, a one-file change). Do it, then say what you did and assumed.
- **Small change:** state the approach and assumptions in 2-3 lines, then build. A single module with clear requirements is a small change even when it holds money logic: test it hard, skip the design-doc ceremony.
- **Project:** discovery, stack, design, plan, then build. If a task grows mid-way (a "small change" touches auth, sync or the schema), stop and step up a size. If the request is really several independent projects, agree an order and do them one at a time.

**Look first, ask second.** Read the repo, manifests and lockfiles, existing docs, data samples and git history, and check which tools are installed (`node -v`, `python --version`, `go version`, `dotnet --list-sdks`, `java -version`, `flutter --version`). Only decisions and facts you can't find go to the user.

**Intent before details.** People ask for the conventional thing ("a dashboard", "make it faster") rather than what they need.
- Before asking anything, write down privately your one-sentence guess of what they want and an honest confidence number. Below about 70%, note what's missing: who it's for, why now, what success looks like, the binding constraint.
- Until you know why they want it, ask open questions in their own terms, one at a time, with no menu of answers: your options would steer them.
- Listen for "should want" answers: buzzwords as goals ("scalable", "modern", "clean architecture"), deference to convention ("the way most apps do it"), "I think I'm supposed to…". Ask what they would want if they didn't have to justify it to anyone.

**Then the details, in numbered rounds.** Ask every question whose prerequisites are already settled, each with your best guess (for facts) or recommended default (for choices), worded so "yes" accepts it: "3. Offline: the app keeps taking orders without internet and syncs later. Recommended: yes, since the shop's connection drops daily." Questions that depend on unanswered ones wait for the next round. If they'd rather go one question at a time, switch.

**Ground to cover** (a territory, not a script): what's special about this and why now; goals, non-goals and **anti-goals** (ways it could technically work and still fail); prior art they love or hate; what exists already and what was tried; the assets they have (logo, product list, old database, printer model); and **which decisions they want to make themselves and which they'd hand to you**. That last answer sets the dial in SKILL.md "Decisions".

**Ask about moments, not abstractions.** "Walk me through the last time a customer returned something" gets real requirements; "do you need returns?" gets "yes".

**Clients get questions in plain words,** drafted for the user to forward: one per message where possible, most important first, no jargon, no menu of answers unless they're stuck. Technical owners can take the detailed rounds.

**Scale it to the work.** A script needs three questions (input, output, where it runs). A product needs all of section 3. Never interview someone for longer than the work will take.

**Say defaults out loud and label guesses** ("Assuming 1-3 staff users; tell me if it's more"). A default the user never heard is one they couldn't reject. If they say "you decide", propose something concrete and log it as your call, not as agreed.

**Play it back before building:**

```
Here's what I think you want:
- Outcome:      <one line>
- Users:        <who benefits>
- Why now:      <what changed>
- Success:      <how we'll know it worked>
- Constraint:   <the binding limit>
- Out of scope: <what we're not doing>
Yes, no, or what should change?
```

"Out of scope" is not optional: half of all misunderstandings are silent disagreements about what isn't being built. The gate is an explicit yes. "Whatever you think is best" is delegation, not agreement: offer two concrete options instead.

**Don't be a yes-machine.** If the idea is weak, or the stated approach fights the stated goal, say so with the reason and a better alternative.

## 2. When the idea is still vague

For "I want an app for X" with no shape yet:
1. Restate it as "How might we…" and ask at most 3-5 sharpening questions: who exactly, what success is, constraints, what's been tried, why now.
2. Generate 5-8 variations through different lenses (invert it, remove a constraint, a different audience, 10x simpler, combine it with something they already use), then cluster them into 2-3 directions that truly differ.
3. Weigh each direction:
   - **User value:** a painkiller or a vitamin? Can you name three real people with the problem? Their current workaround (a notebook, WhatsApp, a spreadsheet) is the real competitor.
   - **Feasibility:** the hardest part, and what depends on outsiders (a payment provider's approval, a hardware SDK, store review).
   - **Difference:** why this over the workaround.
4. Sort the assumptions into must be true (test before building), should be true, and might be true (ignore until the core is proven). Name what would kill the idea.
5. Offer the directions as options (SKILL.md "Decisions"), then write a one-pager for the chosen one: problem, direction, assumptions each with a test, MVP scope, a **Not Doing** list with reasons, open questions. Save it (for example `docs/ideas/<name>.md`) once they confirm.

## 3. The core questions

**Goal and users**
- Who uses it, how many, how often, on what devices, and how comfortable they are with technology?
- What's the one job it must do well? What happens today without it (paper, Excel, WhatsApp, another app)?
- What does success look like in numbers (orders per day, time saved, errors avoided)?
- Who pays for it, and who decides when it's done?

**Features and flows**
- The 3-7 main flows as short stories: "As a cashier, I scan items and take cash so the sale is recorded even offline." Each gets acceptance criteria you can test.
- Roles and permissions: who can see, create, change and delete what.
- Out of scope: what it will *not* do in the first version. Write the Not Doing list now.

**Data**
- What data exists already, where, in what shape, and does it need importing or migrating?
- What's sensitive (personal data, health, payments, location), who may see it, and how long must it be kept or deleted?
- What must never be lost? How far back must it be possible to restore?

**Quality needs** (section 5 turns these into numbers)
- Speed, scale, uptime, offline use, security and privacy, accessibility.
- Languages, scripts and right-to-left, digits, currency, time zones (`../concerns/localization-and-rtl.md`).

**Constraints**
- Deadline and budget, including monthly running costs the owner will accept.
- Platforms that are required or forbidden; hardware that must work (printers, scanners, cameras, sensors).
- Existing systems to integrate (accounting, payment gateways, ERPs, SMS providers, maps).
- Rules to follow: tax and invoicing, data protection, store policies, industry rules.
- Who maintains it after launch, and how much they know.

**Operations**
- Where will it run, who deploys it, and who gets the alert at 2 a.m.?
- Backups, monitoring, support channel, update policy.

## 4. Extra questions by project type

| Type | Ask about |
|---|---|
| Website or web app | SEO and link previews; who edits content and how; browsers and minimum devices; sign-up or invite-only; payments; email sending |
| API or backend service | Who calls it (own apps, partners, public); auth method; rate limits; versioning; expected request volume; data residency |
| Mobile app | iOS, Android or both; store or sideloaded; offline; push notifications; camera, location, Bluetooth; minimum OS versions; tablet layouts |
| Desktop app | Windows, macOS, Linux; installer and updates; offline; local hardware; multi-user PCs; admin rights at install |
| CLI, script or automation | Input and output formats; how often it runs and who runs it; what a failure should do; dry-run; where it runs (laptop, server, CI); idempotency |
| Data or AI | Data sources and freshness; who consumes results; accuracy needed and how it's measured; cost per query; privacy of training or prompt data |
| Game | Platforms and input methods; 2D or 3D; target frame rate and minimum hardware; online play; monetization; save data |
| Embedded or IoT | Board and sensors; power source and battery life; connectivity; update method in the field; safety limits; environment (heat, dust) |
| Browser extension | Browsers; which sites it touches; permissions it truly needs; data it stores; store review |
| Library or package | Target languages and versions; public API surface; licence; supported platforms; release process |

## 5. Turning quality words into numbers

Vague qualities can't be tested. Agree a number, or say that it doesn't matter yet.

| Quality | Ask | Example target |
|---|---|---|
| Speed | Which action must feel instant? | Search results in under 300 ms at p95; app opens in under 2 s on the cheapest supported phone |
| Scale | Users, records and requests at launch and in a year? | 50 staff, 2,000 sales a day, 1 million rows in year one |
| Availability | What does an hour of downtime cost? | Shop hours only; a planned 10-minute window at night is fine |
| Offline | Which actions must work without internet, and for how long? | Sales and receipts for 7 days offline; reports may wait |
| Data safety | How much recent work can be lost? How fast must it be restorable? | Lose nothing confirmed; restore yesterday's state within an hour |
| Security and privacy | Who are the likely attackers, and what would hurt most? | Ex-employees and curious customers; customer phone numbers must not leak |
| Accessibility | Who might use it with assistive tech or large text? | WCAG 2.2 AA for the public site |
| Cost | Monthly running cost ceiling? | Under $25/month until 1,000 users |
| Maintainability | Who changes it next year? | A junior developer who knows Python |

## 6. The spec file

Write `docs/specs/YYYY-MM-DD-<topic>-spec.md`. Keep it to what decisions need; a page or two for most projects.

```markdown
# <Project> spec

## Problem and users
<who, the one job, what happens today, success in numbers>

## Flows (with acceptance criteria)
1. <role> can <action> so that <outcome>.
   - Given … when … then …

## Roles and permissions
| Role | Can | Can't |

## Data
<entities, sensitive fields, retention, imports>

## Quality targets
<the numbers from section 5>

## Constraints
<deadline, budget, platforms, hardware, integrations, rules>

## Not doing (v1)
- …

## Open questions
| Question | Who answers | By when |

## Assumptions
- <stated defaults, labelled as guesses until confirmed>
```

The spec feeds the stack choice (`choosing-a-stack.md`) and the design doc (`planning.md` §1). Update it when an answer changes; don't let chat history become the spec.

## 7. The dev environment

Before coding, make sure the project can be built and run on the user's machine, and that versions are pinned so it keeps working.

**Check what exists:**
- OS and shell: Windows (PowerShell, Git Bash or WSL), macOS, Linux. Note the CPU (Apple silicon, ARM laptops) when native dependencies or emulators are involved.
- Installed runtimes and their versions, the package manager in use, Git, Docker, and the editor.
- Free disk space and RAM when the stack is heavy: Android Studio with an emulator, Xcode and Unity each need many gigabytes and plenty of memory; a low-RAM laptop may need a physical test device instead of an emulator.

**Hard platform limits to raise early:**
- iOS and macOS apps need a Mac (or a cloud build service) to build, sign and submit.
- Windows desktop installers are best signed on Windows or in CI with a Windows runner.
- Some native toolchains (C/C++, Rust on Windows) need the platform's build tools installed first (Visual Studio Build Tools, Xcode Command Line Tools).

**Pin versions in the repo:**

| Ecosystem | Pin with |
|---|---|
| Node | `.nvmrc` or `.node-version`, `"engines"` and `"packageManager"` in `package.json` |
| Python | `.python-version`, `requires-python` in `pyproject.toml`, a lockfile (`uv.lock`, `poetry.lock`) |
| Go | the `go` and `toolchain` lines in `go.mod` |
| Rust | `rust-toolchain.toml` |
| Java/Kotlin | the Gradle wrapper (`gradlew`) and a toolchain block, or the Maven wrapper |
| .NET | `global.json` |
| Dart/Flutter | the SDK constraint in `pubspec.yaml`; FVM's config if the team uses it |
| Ruby | `.ruby-version` |
| PHP | `"require": { "php": ... }` in `composer.json` |
| Several at once | `.tool-versions` (asdf or mise) |

**Run the platform's own check:** `flutter doctor -v`, `npx expo-doctor`, `dotnet --info`, `go env`, `rustup show`, `java -version` with `./gradlew --version`, `xcode-select -p`.

**Windows gotchas:** line endings (add `.gitattributes`, see `git-and-tooling.md` §1), long paths (`git config --system core.longpaths true`), PowerShell's execution policy blocking scripts, antivirus slowing `node_modules` and build folders, and `bash` meaning WSL rather than Git Bash in some terminals.

**Make it reproducible:** a README "Getting started" that a new machine can follow from zero, and optionally a dev container or `docker compose` file for services (database, cache, mail catcher) so nobody installs Postgres by hand.

## 8. Accounts, keys and running costs

List every account the project needs, who owns it (the client, not the developer, for client work), and what it costs. Prices change, so confirm them at the time; these are snapshots.

| Need | Typical cost | Notes |
|---|---|---|
| Apple Developer Program | 99 USD a year | Needed to ship iOS or notarized macOS apps; enrolment can take days |
| Google Play developer account | 25 USD once | New personal accounts must run a closed test before production (`shipping.md` §3) |
| Domain name | about 10-20 USD a year | Register in the client's name |
| Hosting and database | free tiers to tens of dollars a month | Check limits that bite: sleeping free servers, row and bandwidth caps |
| Email and SMS sending | per message | Needs domain DNS records for deliverability (SPF, DKIM, DMARC) |
| Maps, AI and other paid APIs | per request | Set quotas and budget alerts before launch |
| Code signing | yearly certificate or monthly signing service | Unsigned Windows and macOS apps trigger scary warnings |
| Payment gateway | per transaction | Check it serves the client's country and currency before designing around it |

Note which services accept payment from the client's country, and whether any are blocked or slow there. A design built on a provider the client can't pay for, or that doesn't operate where they are, fails on launch day.

## 9. When discovery is done

Move on to the stack choice and design when:
- the spec exists, with flows, acceptance criteria and a Not Doing list
- the quality targets that matter have numbers
- constraints, integrations and accounts are listed, with owners
- the dev environment builds and runs a hello-world in the likely stack, or the blocker is known
- open questions have an owner and a date, and none of them blocks the first slice
