# Debugging: a method, not guesses

Read this when something is broken and the first obvious fix didn't work. SKILL.md "Debugging" has the short version.

## The rule

**No fix without a reproduction, and no theory without a feedback loop.** Guessing works on the first easy bug and then burns hours. If the user says "stop guessing", "is that not happening?" or "we're stuck", you skipped gathering evidence; go back to step 1.

**Stop the line:** no new feature work while the suite is red or the build is broken. Save the evidence (exact error text, stack trace, logs, the input that triggered it) before it scrolls away.

## Steps

### 1. Build the feedback loop first
The loop is one command, already run, that turns red on the user's exact symptom, gives the same verdict every run, and takes seconds. Options, best first:
- a failing test
- a `curl` script against the local server
- a CLI run on a fixture, diffed against the expected output
- a headless browser script
- replaying a captured payload saved to disk (webhook body, sync batch)
- a throwaway harness that calls the function directly
- a fuzz loop over many generated inputs
- a `git bisect run` harness
- comparing an old build against the new one
- last resort: a script that walks a human through the steps

**Tighten it:**
- *Faster:* skip unrelated setup.
- *Sharper:* assert the exact symptom, not "something failed".
- *Deterministic:* fixed time, seeded randomness, isolated files, no real network.

A slow, flaky loop is nearly worthless. A 2-second deterministic one finds the bug.

**Intermittent bugs:** raise the hit rate before theorising. Run the repro 100 times, in parallel or under load, or widen race windows with an injected delay. 50% reproducible is workable; 1% isn't. Classify the cause: timing, environment, state or truly random.

**No loop possible?** Say so, list what you tried, and ask for one of these:
- access to the environment
- a redacted artifact (HAR file, `adb logcat` output, a Crashlytics or Sentry trace, the failing request)
- permission for temporary logging

Redact secrets in everything you show.

### 2. Read the error properly
Read the whole message and stack trace, including the first frame in *your* code and any "caused by" lines. Ask for raw error text rather than paraphrases. Check the obvious: is it the build you think it is, the environment you think it is, the latest code?

### 3. Check what changed
`git diff`, `git log --oneline -15`, and any new dependency versions, config changes or env vars since it last worked. Gotchas:
- `NEXT_PUBLIC_`, `VITE_` and `EXPO_PUBLIC_` values are baked in at **build** time, so changing them on Netlify or Vercel needs a rebuild.
- Netlify's build-time and function-runtime environment scopes differ.
- A Flutter hot reload doesn't re-run `main()` or initState; hot restart or a full rebuild might "fix" a bug that isn't fixed.

### 4. Shrink the reproduction
Remove one input, step or config item at a time until every remaining part is needed. That minimal case becomes the regression test.

### 5. Compare with code that works
Find similar code in the same codebase that works and list *every* difference. Read a reference implementation fully before copying its pattern.

### 6. Hypotheses, ranked, one variable at a time
Write 3-5 hypotheses, most likely first, each with a prediction: "if X is the cause, changing Y makes the bug disappear." Show the list to the user; they can often re-rank it instantly ("oh, that only happens on the Windows till"). Test one variable at a time and revert probes that didn't confirm anything.

### 7. Instrument instead of guessing
- Use a debugger first. Otherwise add targeted logs at the boundaries that tell your hypotheses apart; never "log everything".
- Tag temporary logs (`[DEBUG-a4f2]`) so they can be found and removed (`grep -rn "\[DEBUG-"`).
- For multi-step paths (app → Cloud Function → Firestore; CI → build → deploy), log what goes into and comes out of each step once to find the broken one.
- To find where a bad value comes from, log the inputs plus a stack trace (`new Error().stack`, `StackTrace.current`) right before the risky call, then climb to the **first** place the value goes wrong.
- For UI bugs, drive the real app (browser automation, a device) and look, rather than reasoning about it.
- For performance problems, measure a baseline first, then bisect.

### 8. Find the breaking commit when the code used to work
```bash
git bisect start
git bisect bad
git bisect good <last-known-good-sha>
git bisect run flutter test test/sale_test.dart   # or: npm test -- path; exit 125 = skip commit
git bisect reset
```

### 9. Fix at the source, then add layers of defence
- Fix where the bad value is *created*, not where it explodes. **Symptom patches are findings, not fixes:**
  - de-duplicating rows in the UI instead of fixing the query that duplicates them
  - wrapping a crash in `try/catch` that hides it
  - raising a timeout
  - adding a retry
- After the root fix, add the cheap layers that stop it coming back:
  - validation at the entry point
  - a check in the business logic
  - an environment guard (tests refuse to run against the production Firebase project)
  - enough logged context to diagnose it next time

### 10. Lock it in and clean up
- Add the regression test where it reproduces the real call pattern. If no test seam can reproduce it, report that as an architecture problem.
- Re-run the original repro and the full suite.
- Delete the tagged logs and throwaway scripts.
- Put the confirmed cause in the commit message ("fix: stock went negative when two tills synced the same sale; sync now upserts by sale UUID").
- Explain to the user, in plain words, what actually went wrong, not just what you changed.
- "No root cause" usually means the investigation isn't finished. If the cause really is external (a provider outage, an OS bug), document it and add handling and monitoring.

## When to stop and question the design

If the **third** fix fails, or each fix uncovers new shared state or coupling, or the fix needs a big refactor, stop patching. Summarize what was tried and what it revealed, then discuss the design with the user before a fourth attempt. This is separate from the context-hygiene rule (SKILL.md "Context hygiene and subagents"), which says when to start a fresh session. Resist pressure here: "just add a retry" and "that's how it's supposed to work" aren't evidence.

## Excuses to reject
- "Quick fix now, investigate later."
- "Just try X."
- "One more fix" (after two failures).
- "I see the problem." (Prove it with the loop.)
- "Works on my machine."
- "The failing test is probably wrong."
