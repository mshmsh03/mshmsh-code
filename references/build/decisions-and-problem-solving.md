# Decisions and problem-solving: how to think, how to offer options, how to record them

This is the heart of the skill. Read it before the first real decision in a project, and whenever a problem resists the obvious fix. SKILL.md "Decisions" and "Solving problems" have the short version.

Two jobs:
- **Think well yourself:** understand the problem, generate real alternatives, judge them against what this project needs, and check your own reasoning before it hardens into code.
- **Help the user decide well:** show the options in plain words, with what each costs and gives, recommend one, let them pick, and teach the why so they understand the software they own.

## Contents
1. What kind of question is this?
2. Which decisions go to the user
3. Generating options worth choosing between
4. Judging options
5. Presenting options
6. Reading the answer
7. Recording decisions
8. Solving problems
9. Checking your own reasoning
10. Pre-mortems for plans and launches
11. Teaching while deciding

---

## 1. What kind of question is this?

Sort every open point before you speak. Each kind is handled differently.

| Kind | Example | What to do |
|---|---|---|
| **Fact you can find** | "Which Node version is installed?" "Is there a test suite?" | Look it up. Never ask the user. |
| **Fact only they know** | "Who uses this?" "Does the shop have internet?" | Ask with your best guess, labelled as a guess (a guess is not a recommendation), and say what you'll assume if they skip. |
| **Intent** (why they want it) | "A dashboard" could mean many things | Ask one open question in their words, with no options, until you know why. Options too early lock in your framing. |
| **Decision with nameable choices** | Which database, which auth method, how to model returns | Options with trade-offs and a recommendation (sections 3-5). |
| **Process call** | Where files go, how to name a branch, which test to write first | Your call. Do it and mention it if it matters. |
| **Exact instruction** | "Use Postgres." "Undo that." | Already a pick. Do exactly that, nothing more. "Make it faster" is not exact: how is a decision. |

## 2. Which decisions go to the user

Not every choice deserves a question. Asking about trivia wastes their attention; deciding the important things alone takes their project away from them.

**Ask the user** when a decision is any of these:
- **Theirs by nature:** product behaviour, UX, business rules (money, stock, refunds, permissions), what to delete, what to show customers.
- **Expensive to reverse** (a one-way door): the stack, the data model, a public API, a database or hosting provider, anything that migrates data or ships to users' devices.
- **A trade-off between values they care about:** cost vs speed, simplicity vs flexibility, launch date vs completeness, security vs convenience.
- **Spending:** paid services, new subscriptions, anything with a running cost.
- **Security-sensitive** in a way the spec didn't settle.

**Decide yourself, then say so in a line,** when a decision is all of these:
- reversible in minutes (a two-way door)
- inside the agreed design and conventions
- with one clearly better answer by the project's own rules (an existing pattern, a lint rule, the spec)

Examples: naming, file layout, which helper to extract, the order of tests, a standard library function over a new dependency.

**When unsure, ask, but bundle it:** several small independent decisions can go in one round instead of interrupting for each.

**The user can change the dial.** "Just decide the technical stuff" means you decide two-way doors and technical one-way doors you'd recommend anyway, log them as "decided for you", and still ask about product, money and deletion. "Ask me everything" means more questions, smaller ones.

## 3. Generating options worth choosing between

**Open up before narrowing down.**
1. Restate the problem as one sentence: "How might we let two tills sell without internet and never double-count stock?" If you can't write it, you don't understand it yet.
2. List the constraints that every option must meet (from the spec: quality targets, budget, platforms, deadline).
3. Generate 4-8 candidate approaches using these lenses, then keep the 2-4 that differ in substance:
   - **The boring standard:** what most experienced teams would do with this stack.
   - **The simplest thing that could work:** fewer parts, maybe less capable.
   - **Reuse or buy:** an existing library, managed service or feature of the current stack instead of building.
   - **Do nothing / defer:** what happens if this isn't built now. Sometimes the right answer.
   - **The robust one:** handles the hard cases (scale, offline, failures) at a higher cost.
   - **The one that changes the problem:** a different workflow, a manual step, a narrower scope.
4. Cluster near-duplicates. Three variations of one idea are one option.

**Rules for the final set:**
- **2-4 options,** each a real answer that differs on the axis being decided.
- **No straw men.** Never add a weak option to make your favourite look good. If only one answer is sensible, the options are about *how* (or the decision is a process call after all).
- **Ground them in the project:** its stack, its existing patterns, its constraints, the user's skills. Your habitual default is not automatically an option.
- **"Keep as is"** is an option when changing existing work.
- **Never re-offer what was declined** (check the decision log first).

## 4. Judging options

Judge against what *this* project needs, not against generic "best practice".

**For every option, know:**
- what it is, in one line
- what it gives (which requirements it meets well)
- what it costs: effort (S/M/L), running cost, complexity added, things it makes harder
- the risk: what could go wrong, and how likely
- reversibility: how hard it is to switch away later
- fit: the team's skills, the existing code, how well AI tools know it, who will maintain it

**For big decisions** (stack, architecture, data model, provider), make the trade-off visible:

| Criterion (weight) | Option A | Option B | Option C |
|---|---|---|---|
| Meets the offline requirement (high) | Yes, built in | With extra work | No |
| Monthly cost at launch (medium) | $0 | ~$25 | $0 |
| Team already knows it (medium) | Yes | Partly | No |
| Effort to first slice (low) | M | S | L |

Weights come from the spec's priorities. A score table is a thinking aid, not an oracle: if the "winner" feels wrong, find the criterion you left out.

**Then say the consequences:** what becomes easier, what becomes harder, and what you'll need to revisit later. This is the part users remember when the bill or the limitation arrives.

**Speed of decision matches reversibility.** Two-way doors: decide quickly, change later if wrong. One-way doors: slow down, spike if unsure (section 8), and get an explicit yes.

## 5. Presenting options

**With a question tool** (AskUserQuestion in Claude Code and the Claude app):
- Up to 4 independent decisions per call, 2-4 options each.
- The recommended option first, its label ending in "(Recommended)", and its reason in the description, tied to the spec, the constraints or the user's goal, not to taste.
- Every description names the cost and the trade-off in one or two sentences.
- `header` is 12 characters or fewer, labels are 1-5 words.
- Use the `preview` field for anything easier to judge by seeing it: a code sketch, an API shape, a schema, a folder tree, sample output, a command.
- Facts get no recommendation; decisions always do.
- Order big to small for new work (stack, then architecture, then data model, then details). For fixes, order by what hurts most.
- Number the journey when there's a queue: "Decision 2 of 5: database".
- Write any report or findings first and ask last; text next to a question can stay hidden until it's answered, so each option must carry its own explanation.

**Without a question tool,** ask in text and wait before acting:

```
**Decision 2 of 5: Where the data lives**
A. PostgreSQL on a managed host (Recommended): fits the relational data (orders,
   items, customers); free tier to start; easy reports with SQL.
B. Firebase Firestore: fastest to start with built-in auth and offline cache;
   harder reporting and per-read billing as data grows.
C. SQLite on one server: simplest and cheapest; fine for one shop, but no
   managed backups and harder to scale to several branches.
Reply with a letter, a mix ("A, but start with SQLite locally"), or "you decide".
```

**If you can't ask at all** (a subagent, a batch run), don't make user-owned decisions. Do the parts that don't depend on them, and return the decision cards to whoever called you.

**Keep it human:**
- Short: lead with the recommendation, one or two lines per option, and the full reasoning only when asked. At most about five questions per round.
- Plain words, a little above the user's level, never process jargon. Explain any term you must use.
- Lead with what changes for them (cost, time, what users see), then the technical reason.
- One decision at a time when they depend on each other; batch them when they don't.
- Don't ask what you could look up, and don't reopen what's already decided.

## 6. Reading the answer

| They say | Do this |
|---|---|
| A letter or label | Apply exactly that option, verify it, show the result in a line or two, log it. |
| A mix ("A with B's caching") | Build the mix if it's coherent; if parts conflict, say how and offer the closest coherent version. |
| "X, but change Y" | Keep X and offer variations on Y. |
| "You decide", "do what's best" | Take the recommended option, say what you picked and why, keep the alternatives in the log, and mark it "decided for you" so they can reverse it. For one-way doors, confirm once in a line before acting. |
| "I don't know" | That's a signal the options weren't clear. Explain the real-world difference ("A means you pay nothing until you have about 1,000 users; B costs $25 a month from day one but…") and ask again, or recommend and proceed if it's a two-way door. |
| "Not that", "none of these" | Ask what bothered them, then offer fresh options. Don't tweak the rejected one. |
| "Decide later" | Log it as open, carry on with independent work, and note what's blocked. |
| No, skip, or an unticked option | Keep as is, add it to Declined in the log, and don't offer it again unless they bring it up. |
| They edit the code themselves | Their edit is a decision. Re-read before your next change and never revert it. |

**After the pick:** apply exactly the chosen option and nothing extra riding along. Anything else you noticed becomes a later question.

## 7. Recording decisions

A decision that isn't written down gets re-argued, or quietly undone in the next session.

**The decision log** (`docs/decisions.md`), one entry per decision:

```markdown
## 2026-11-19: Database for the order system
- Options: PostgreSQL (managed) · Firestore · SQLite on one server
- Picked: PostgreSQL (managed), by the user
- Why: relational data and SQL reports; free tier covers year one
- Consequences: needs an API server; easier reports; migrations needed
- Revisit if: more than one region, or the free tier runs out
```

- Mark decisions you made with "decided for you".
- Keep a **Declined** section, so declined options are never offered again.
- Big, hard-to-reverse decisions also get an ADR (`docs/adr/NNNN-title.md`): context, options considered, decision, consequences (easier / harder / revisit), status.
- Point to the log from `CLAUDE.md`, and read it at the start of every session.

## 8. Solving problems

**First, recognize the shape of the problem.** The right method depends on it.

| Shape | Signs | Method |
|---|---|---|
| **Clear** | The answer is known and documented | Apply the standard pattern. Don't over-think it. |
| **Complicated** | Knowable with analysis or expertise | Analyse: read the code, the docs and the data, list options, judge them (sections 3-4). |
| **Complex** | Nobody can know in advance (performance on real data, how users react, an unfamiliar library's behaviour) | Probe: a small time-boxed spike or experiment, then decide from what it shows. |
| **Chaotic** | Something is on fire (production down, data being lost) | Act first to stabilize (roll back, switch the feature off, stop the job), then analyse. |

**Then work the problem:**
- **State it precisely:** expected vs actual, or current vs desired, with numbers where possible. Half of problems dissolve once stated precisely.
- **Find the root cause before choosing a fix.** Ask "why?" until you reach something you can change that would prevent the whole class of problem, not just this instance.
- **Work from first principles** when the conventional answer doesn't fit: what must be true, what is merely habit? ("Do we need a server at all, or just a scheduled job?")
- **Work backwards** from the acceptance criteria: what's the smallest thing that would make them pass?
- **Divide and conquer:** split the system and test each half; binary search through code, data or commits (`git bisect`).
- **Find the bottleneck** before optimizing anything: measure, fix the one constraint that limits the whole, measure again. Speeding up anything else changes nothing.
- **Invert:** "How would we guarantee this fails?" lists the risks to design against.
- **Think one step further** (second-order effects): what does this change cause next? A cache adds staleness; a retry adds duplicates; a new field adds a migration.
- **Spike unknowns:** a throwaway prototype answering one question, time-boxed, labelled throwaway, deleted or rewritten properly.
- **Explain it out loud** (rubber-ducking): writing the problem down for the user often reveals the gap.

**Know when to stop:** after about three failed attempts at the same approach, stop and step back: restate the problem, question the assumptions, consider a different approach or a fresh session, and tell the user what you tried.

## 9. Checking your own reasoning

Confident is not the same as correct. Long sessions turn assumptions into "facts" without anyone noticing.

**Doubt non-trivial decisions while they're still cheap to change.** A decision is non-trivial when it adds branching logic, crosses a module or service boundary, claims something the compiler can't check (thread safety, idempotency, ordering, "this is secure", "this scales"), depends on context a future reader won't see, or is hard to reverse.

1. **Claim:** write the decision in two or three lines, plus why it matters. If you can't, you have a feeling, not a decision.
2. **Extract:** the smallest artifact (the diff, the proposal) and the contract it must meet. Leave out your reasoning, so a reviewer can't simply agree with it.
3. **Doubt:** have a fresh-context reviewer (a subagent, where available) look for what's wrong: unstated assumptions, unhandled edge cases, hidden coupling, broken conventions, failure modes. Without subagents, do it yourself from the artifact alone, adversarially.
4. **Reconcile:** fix what's real, note what's not, and say what you couldn't verify.
5. **Stop** when findings turn trivial, after three rounds, or when the user says so.

Skip this for mechanical changes, clear instructions and one-line fixes. Doubting every keystroke ships nothing.

**Bias check before committing to a big decision:**
- **Anchoring:** am I favouring the first idea because it came first?
- **Familiarity:** am I choosing what I know best, or what fits best?
- **Novelty:** am I choosing the shiny new thing for its own sake?
- **Sunk cost:** am I keeping an approach because of the time already spent on it?
- **Confirmation:** did I look for evidence against my choice, or only for it?
- **Overconfidence:** what's my real confidence, and what would change my mind?

## 10. Pre-mortems for plans and launches

Before a big plan or a launch, imagine it failed and work backwards: what went wrong?

Sort what you find:
- **Tigers:** real risks you can point to evidence for. They need action.
  - **Launch-blocking:** must be fixed before release.
  - **Fast-follow:** fixed within weeks after release.
  - **Track:** watch, fix if it bites.
- **Paper tigers:** worries that sound serious but aren't, with the reason. Writing them down stops the team re-worrying.
- **Elephants:** things nobody is talking about that might be real (an untested assumption, a dependency on one person). They need investigating.

Give each launch-blocking tiger a mitigation, an owner and a date, and offer the user the mitigations as choices.

## 11. Teaching while deciding

The user owns the software after you leave. Each decision is a chance for them to understand it a little better.
- **Say the why in one or two plain sentences,** tied to their project: "Totals are stored as whole dinars, not decimals, because decimals can drift by a fraction on every sale and the end-of-day report would never match the cash."
- **Name the concept once,** so they can look it up later ("this is called idempotency").
- **Explain the trade-off in their terms:** money, time, what customers see, what breaks.
- **Offer depth without forcing it:** "Want me to explain how the sync queue works?" is better than a lecture.
- **When they ask why,** answer directly with the reason and the alternative you rejected, never with "best practice says".
- **Check understanding on the decisions that matter most** (data model, security, money): a one-line recap they can confirm beats a silent assumption that they followed.
