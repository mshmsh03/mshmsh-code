# Planning: from idea to an approved design and an executable plan

Read this when starting anything bigger than a quick fix. SKILL.md "Understand", "Design" and "Plan" have the short version.

## Contents
1. Size the work first
2. Questions that get real answers
3. Turning a vague idea into a direction
4. The design doc and the approval gate
5. Prototypes and spikes
6. MVP and slicing
7. Plan format
8. Executing a plan, subagents and handoffs
9. Docs that earn their place: ADRs, glossary, out-of-scope

---

## 1. Size the work first

Say the size out loud and handle it accordingly:
- **Quick task.** The request already contains everything that matters (a bug fix, a one-file change). Do it, then say what you did and what you assumed.
- **Small change.** State the approach and your assumptions in 2-3 lines, then build. Ask first only when the choice is the user's: data model, money or stock rules, UX, deleting anything.
- **Project** (a new app, work across several modules or sessions, or anything touching auth, payments between systems, or sync). Questions, then a written design, approval, a plan file, then the build. A single module with clear requirements is a small change, even when it contains money logic: test it hard, but skip the design-doc ceremony.

If a task grows mid-way (a "small change" turns out to touch auth, sync or the schema), stop and step up a size. If the request is really several independent projects, agree an order and design them one at a time.

## 2. Questions that get real answers

- Look things up before asking. Repo, docs, recent commits, existing data: anything the code can answer is your job. Only **decisions** go to the human.
- **Non-technical clients:** in Claude Code you're talking to the developer, so draft client questions for them to forward. Use one question per message, tied to a real moment ("walk me through the last time a customer returned something"). Don't attach a menu of answers, because options steer. Offer a menu only if they're stuck. A concrete guess they can correct often beats an open question.
- **Technical owners (including the user, when they're the developer):** go in rounds. Ask every question whose prerequisites are settled, numbered, each with a recommended answer worded so "yes" accepts it. Questions that depend on unanswered ones wait for the next round.
- Ground to cover (a territory, not a script): what's special about this, why now, what success looks like, goals / non-goals / **anti-goals** (ways it could technically work and still fail), prior art they love or hate, what exists and what was tried, which choices they want to make vs hand to you, and what assets they already have (logo, product list, old database, printer model).
- **Say every default out loud.** A default the user never heard is one they couldn't reject. Label guesses as guesses.
- If they say "you decide", propose something concrete and log it as your call, not as agreed.
- Play your understanding back in short chunks (a few hundred words) and let them correct you before you move on.
- Don't be a yes-machine. If the idea is weak, or the stated approach fights the stated goal, say so with the reason.

## 3. Turning a vague idea into a direction

For "I want an app for X" with no shape yet:
1. Restate it as "How might we…" and ask at most 3-5 sharpening questions: who exactly, what success is, constraints, what's been tried, why now.
2. Generate 5-8 variations through different lenses (invert it, remove a constraint, a different audience, 10x simpler, combine it with something they already use), then cluster them into 2-3 directions.
3. Score each direction:
   - **User value:** painkiller or vitamin? Can you name three real people with the problem? Their current workaround (a notebook, WhatsApp, Excel) is the real competitor.
   - **Feasibility:** the hardest part, and what depends on outsiders (payment provider approval, printer SDKs, store review).
   - **Differentiation.**
4. Sort assumptions into must-be-true (validate before building), should-be-true and might-be-true (ignore until the core is proven). Name what would kill the idea.
5. Write a one-pager: problem, chosen direction, assumptions each with a test, MVP scope, a **Not Doing** list with reasons, open questions. Save it (e.g. `docs/ideas/<name>.md`) only once they confirm.

## 4. The design doc and the approval gate

**For projects, nothing is scaffolded, installed or coded until a written design is approved.** Small changes only need their approach stated (§1). "Sounds good" to an idea in conversation is not approval of a design that was never written down.

A design doc covers: intent and why; goals, non-goals, anti-goals; constraints (devices, offline needs, languages, budget, deadline); the decisions the owner made; the decisions left to you; data model sketch; risky parts and how you'll de-risk them; and the Not Doing list. Use a dated path like `docs/specs/YYYY-MM-DD-<topic>-design.md` and commit it.

**Builder check before approval (for projects):** give the doc to a fresh subagent playing a capable builder who can't contact the author. Ask it for ranked questions where a wrong guess would change what gets built. Sort the answers into three piles:
- already answered: write the answer into the doc
- minor: decide it yourself and mark it "my call"
- owner-only: send one batched message, most important first

Do one round, not a loop.

After approval the next step is the plan, not code.

**Client work:** keep approvals in writing (the doc, an email, a message). When scope creeps later, the Not Doing list and the approved doc are what you point to. A client-facing brief can use simplified technical English, which helps clients who aren't native English speakers.

## 5. Prototypes and spikes

- A spike answers one question and is thrown away. Call it a prototype in its name, skip tests and review, and don't build on it. Keeping its code is a new request that goes back through the design gate. "The spike works, so I'll just build on it" is the excuse to reject.
- **Logic prototype** ("does this rule feel right?"): one HTML file that opens with a double-click. It holds a pure reducer or state machine with no DOM access (so it can be lifted into real code later), a state panel that re-renders after every click, free-play buttons, and scenario tabs (happy path, awkward edge, illegal move) that reset to a known state. Use business language in the labels. This is ideal for sale, return, debt, discount, stock and offline-sync rules: send it to the shop owner to click through before writing the real thing.
- **UI prototype** ("what should it look like?"): build 3 variants (5 at most) that differ in *structure* (layout, hierarchy, primary action), not just colour. Use real content, not lorem ipsum. Make them switchable inside the real page (`?variant=` on web; a debug-only toggle under `kDebugMode` in Flutter) and strip that out of production builds.
- Keep prototype state in memory. If persistence is the question, use a scratch database named so it's obviously safe to wipe.
- Afterwards, rewrite the winner properly, park the prototype on a throwaway branch, and write down the verdict and the question it answered.

## 6. MVP and slicing

- An MVP is **one user job done well**, aimed at the riskiest assumption. Time-box it rather than listing features. For an internal MVP, if v1 doesn't feel slightly embarrassing, it was over-built. For paid client work, keep v1 small but polish what ships.
- **Slice vertically.** "Cashier can record a cash sale" (table + logic + screen + test) beats "all tables, then all APIs, then all screens". Every slice leaves the app working and demoable.
- **The first slice is a tracer bullet:** the thinnest path through every layer (SQLite migration → repository → state → screen → test, or DB → API → UI). It proves the architecture before you invest in breadth.
- Pick the slicing strategy deliberately:
  - **Vertical** (default).
  - **Contract-first:** freeze the API, Firestore document or sync payload shape first, then build both sides against it, with the UI on mock data.
  - **Risk-first:** prove the scariest piece first. Offline sync, Arabic-script receipt printing and payment callbacks are typical.
- **Prefactor before features:** make the change easy, then make the easy change.
- **Wide renames and schema changes use expand → migrate → contract:**
  1. Add the new field or column beside the old one.
  2. Move callers in batches.
  3. Remove the old one last.

  On mobile, the remove step waits until old installed app versions are gone, because you can't force-update every device.
- Unfinished features merge behind a flag that defaults off (`--dart-define`, an env var, remote config).

## 7. Plan format

For projects, write the plan to a file (e.g. `docs/plans/YYYY-MM-DD-<feature>.md`) so it survives context resets and another session can pick it up. Never overwrite a plan that still has unchecked tasks for different work; another session may be mid-build.

**Header:**
- **Goal** (1 sentence)
- **Architecture** (2-3 sentences)
- **Stack**
- **Spec path**
- **Global constraints** copied verbatim from the spec: version floors, platforms, languages and RTL, naming and copy rules, "no new dependencies without asking". These apply to every task.
- **Review focus:** the ~5 inputs or failure modes the spec implies but no task tests yet, most likely first. Each one then gets a test in the task that owns that code. POS examples:
  - Eastern Arabic digits (٠-٩) typed into quantity or price fields (in JS, `Number('٣')` is `NaN`)
  - Product names mixing Arabic script and Latin
  - Zero or negative quantities
  - The app killed mid-sale
  - Two offline tills selling the last unit

**File map:** before the tasks, list the files to create or modify, each with one responsibility. Split by responsibility, not by layer. Follow existing patterns; only split an unwieldy file you're already touching.

**Each task contains:**
- **Files:** create / modify / test, with exact paths.
- **Interfaces:** what it consumes from earlier tasks and what it produces, with exact names and signatures.
- **Steps**, each one action with a checkable result:
  1. Write the failing test, using the spec's literal values.
  2. Run it: the exact command and the expected FAIL.
  3. Implement the named signature.
  4. Run it again: the exact command and the expected PASS.
  5. Commit, with the message.

A step is ready when only one reasonable implementation follows from it. Steps that decide nothing are banned: "handle edge cases", "add validation", "add error handling", "TBD". Name *which* edge cases and *which* validation. Write out a function body only for an algorithm that the signature and tests don't already pin down. A plan longer than the code it describes has stopped being a plan.

**Sizing:** XS = 1 file, S = 1-2, M = 3-5, L = 5-8 (split it), XL = 8+ (must split). Also split when a task has more than 3 acceptance bullets, spans two independent subsystems, has "and" in its title, or would take more than ~2 hours. Schedule high-risk tasks early, and put a checkpoint every 2-3 tasks: tests pass, build clean, the core flow works end to end, and a human looks at it.

**Parallel vs sequential:** independent slices, tests for finished features and docs can run in parallel. Migrations and shared state are sequential. Anything sharing a contract needs the contract defined first.

**Self-review the plan before handing it over** (fix inline):
- Every spec requirement maps to a task.
- No filler steps and no transcribed code.
- Names and types match across tasks (`clearLayers()` in one task and `clearAllLayers()` in another is a bug you're planting).
- Review focus is filled in.
- The length is proportionate to the spec.

**Specs and briefs that will sit for a while** (tickets, client briefs) leave out file paths and line numbers, which go stale. They describe behaviour: the problem, the solution from the user's view, numbered user stories ("As a cashier, I want…, so that…"), implementation decisions (modules, interfaces, schema), testing decisions (which behaviour, at which seam) and what's out of scope. Plans you'll execute now do include exact paths.

## 8. Executing a plan, subagents and handoffs

- Work on a branch (or a worktree). Never on `main` without explicit consent. Read the spec as well as the plan; where the plan contradicts itself, the spec wins.
- **Pre-flight:** for every task that consumes another's output, check that the names and types match before starting task 1.
- Re-read each task's text when you start it; memory keeps a summary but the plan has the exact values. Compare every expected output with the real one. If the code is wrong, find the cause; never massage the output or the test to match.
- **A new test that's green before you've written the code is lying.** Find out why.
- **Keep a ledger.** Use `progress.md` (or the plan's checkboxes), with one line per finished task: commit range, test command, result. After a context reset, trust the ledger and `git log` over memory and never redo a logged task.
- **Rulings:** settle small ambiguities yourself and log each one as `Ruling: <what> | <why> | <cost if wrong>`. Stop and ask only for:
  - destructive or irreversible operations
  - security-sensitive changes the plan didn't spell out
  - effects outside the branch (push, merge, publish, deploy, sending messages)
  - a plan so broken that every path is a guess

  During design, ask; during execution of an approved plan, decide, log and report. Don't ask "should I continue?" between tasks.
- Run the relevant tests after every ~100 new lines and keep the build green after each increment. Make one logical change per commit. Run targeted tests while working and the full suite before committing.
- **Scope discipline:** no tidying of neighbouring code, reshuffled imports or modernised files you only read. Note them under "Noticed, not touching" and offer them as separate tasks.
- **End of plan:** a fresh reviewer (strongest model available) reviews the whole branch.
  - Grade each finding by its effect on a real user.
  - Fix Critical and Important ones, each with a test seen red then green, then run the full suite.
  - List Minor ones as "Deferred" for the owner, unfixed unless asked.
- **Excuses to reject:**
  - "I remember the task."
  - "No need to watch it fail."
  - "The full suite at the end is enough."
  - "I'll update the ledger later."
  - "My own read of the diff replaces the review."
  - "It's trivial, it'll pass."
  - "I'll fix the minors too."

### Subagents

- **Write the brief; never pass your session history.** A good dispatch has:
  - one line on where the task fits
  - the task text with exact values (or the path to a brief file)
  - the interfaces and decisions from earlier tasks
  - your ruling on any ambiguity
  - the reply format
- **Reply format:** a status (DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT) and a short report, including the red and green test commands with their output.
- **On BLOCKED, change something before redispatching:** more context, a smaller task, a stronger model, or a corrected plan. Never resend the same brief.
- **Review risky work** with a separate reviewer subagent. Give it the brief, the implementer's report, the diff written to a file (`git diff <sha-before>..HEAD`, recorded before dispatch, not `HEAD~1`) and the constraints. Tell it to assume the report may be optimistic. It returns a spec verdict (missing / extra / misunderstood) and a quality verdict, with file:line.
- **Parallel subagents only for independent problems** (three failing tests with unrelated causes, separate research questions). Never put two implementers in one working tree; give each its own worktree and branch, and merge them one at a time. Afterwards, check for overlapping edits and run the full suite.
- **Models:**
  - the cheapest tier for fully specified one- or two-file tasks
  - the standard tier for multi-file work
  - the strongest for design and the final review
- **Workers don't spawn their own helpers,** and their self-approval doesn't count as review.

### Handoffs and context resets

- **Reset at boundaries,** never mid-implementation:
  - after research, once the plan is saved
  - after a failed approach
  - when switching to an unrelated task
- **Before ending or compacting, write a handoff:**
  - accepted scope and decisions
  - task status and the next task
  - files changed and the working-tree state
  - the exact verification commands and their results
  - open questions and pending approvals

  Link the spec, plan and ADRs by path instead of copying them, and redact keys and personal data.
- **A new session reads the handoff,** the context file, the plan and the real `git status`, then re-verifies anything stale. It treats an approval as given only if a file records it.

## 9. Docs that earn their place: ADRs, glossary, out-of-scope

- **ADR** (`docs/adr/0001-<slug>.md`), only when all three hold: the decision is costly to reverse, a future reader would be puzzled without context, and there was a real trade-off. Keep it to one to three sentences of context, decision and why, plus optional Status (proposed / accepted / superseded by ADR-NNNN), Alternatives and Consequences. Supersede old ADRs; don't delete them. Typical candidates:
  - SQLite as the offline source of truth vs a Firestore cache
  - the sync conflict policy
  - Flutter vs Expo for this client
  - the state-management choice
  - the auth provider
  - any deliberate deviation from the obvious approach (this stops the next agent from "fixing" it)
- **Glossary** (`GLOSSARY.md`): one canonical term per concept, with synonyms listed under *Avoid*, and one- or two-sentence definitions. Add the Sorani and Arabic UI label next to each term so translations stay consistent across screens. The `domain-modeling` skill covers this in depth.
- **Out-of-scope records** (`.out-of-scope/<concept>.md`): one per rejected feature request, holding the decision, a lasting reason (not "busy right now") and the list of times it was requested. Check it before re-arguing a request. It's the cleanest defence against client scope creep.
- **Comments explain why.** They never restate the code. Delete commented-out code. Leave no TODO for work you could do now. Docs describe the present state, not the history of changes.
