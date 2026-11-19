# Command-line tools, scripts, scheduled jobs, bots and scrapers

Read this when building something that runs in a terminal, on a schedule or in response to events without a UI of its own: CLIs, one-off and recurring scripts, cron jobs, chat bots, integrations between services, and scrapers. Even a 50-line script gets verification; "it ran once on my machine" isn't evidence.

## Contents
1. Size it honestly
2. Designing a CLI
3. Scripts that don't bite
4. Files, encodings and paths
5. Scheduled jobs
6. Bots, webhooks and integrations
7. Scrapers
8. Distribution
9. Testing

---

## 1. Size it honestly

- **A throwaway script** (one-time data fix, a quick conversion): keep it simple, but run it on a copy or with a dry run first, and check the output.
- **A script someone will run again:** arguments instead of edited constants, a `--help`, clear errors, and a README line on how to run it.
- **A tool other people install:** everything in this file, plus tests and releases.
- Ask the user which it is when it isn't obvious; the difference is hours of work.
- **Shell or a real language?** Shell is fine for under ~50 lines of glue with no logic worth testing. Anything with branching, data structures, error handling or reuse goes in Python, Go, Node or the project's language.

## 2. Designing a CLI

Follow the conventions users already know (the Command Line Interface Guidelines at clig.dev are a good reference):
- **Help:** `-h`/`--help` with a usage line, a short description and examples; `--version`.
- **Output:** data to stdout, messages and errors to stderr, so output can be piped. Offer `--json` (or another machine-readable format) for anything a script might consume.
- **Exit codes:** 0 for success, non-zero for failure (and distinct codes when callers need to tell failures apart).
- **Color and progress** only when stdout is a terminal; respect `NO_COLOR`; no spinners in CI logs.
- **Destructive actions:** confirm interactively, `--yes`/`--force` to skip in scripts, and `--dry-run` to show what would happen.
- **Configuration precedence:** flags override environment variables, which override a config file, which overrides defaults. Say where the config file lives.
- **Secrets** come from environment variables, a secrets manager or a prompt, never flags (they show in shell history and process lists).
- **Errors** say what went wrong and what to do: "config.yaml not found in ~/.mytool; run `mytool init`", not a stack trace. Show the stack trace with `--verbose` or `--debug`.
- **Use a proper argument parser** (argparse, Typer or Click; Cobra; clap; commander or yargs; System.CommandLine; picocli) rather than reading `argv` by hand.

## 3. Scripts that don't bite

- **Bash:** start with `set -euo pipefail`, quote every variable (`"$file"`), use `"$@"` not `$*`, prefer `[[ ]]`, and run `shellcheck`. Use `mktemp` for temporary files and `trap` to clean up.
- **PowerShell:** `$ErrorActionPreference = 'Stop'` and `Set-StrictMode -Version Latest`; mind the execution policy on users' machines.
- **Python:** a `main()` behind `if __name__ == "__main__":`, type hints, `pathlib` for paths, and dependencies declared (a `pyproject.toml`, or inline script metadata run with `uv run`).
- **Idempotent by design:** running it twice does no harm. Check before creating, upsert instead of insert, skip what's already done, and keep a record of what was processed.
- **Safe on real data:** default to a dry run for anything that changes or deletes data, process a small sample first, and back up before bulk changes.
- **Fail loudly:** no `|| true` or bare `except: pass` to make an error go away; a partial failure says what succeeded and what didn't.
- **Never build shell commands from strings with user input;** pass argument lists (`subprocess.run([...])`, `execFile`, `exec.Command`).

## 4. Files, encodings and paths

- **Write atomically:** write to a temporary file in the same directory, then rename it over the target, so a crash never leaves a half-written file.
- **Encodings:** read and write UTF-8 explicitly (`open(path, encoding='utf-8')`); CSV for Excel users needs UTF-8 with a byte-order mark to show Arabic-script text correctly; handle Windows line endings in input.
- **Large files:** stream them line by line or in chunks; don't load gigabytes into memory.
- **Cross-platform paths:** build paths with the language's path API, handle spaces and non-Latin characters, and don't hard-code `/tmp` or `C:\`.
- **Never trust file names from input** as paths without normalizing them and checking they stay inside the intended folder.

## 5. Scheduled jobs

- **Where it runs:** cron or systemd timers on a server, Task Scheduler on Windows, CI schedules (GitHub Actions `schedule`), or a cloud scheduler calling a function. Choose by where the data and secrets already are.
- **Schedules are in UTC** unless the tool says otherwise; write the intended local time in a comment.
- **No overlapping runs:** a lock (`flock`, a database advisory lock, the platform's concurrency setting) so a slow run and the next one don't collide.
- **Catch-up:** decide what happens after downtime: run once, run every missed slot, or skip.
- **Observability:** log each run's start, outcome and counts; alert on failure **and** on silence (a heartbeat or dead-man's-switch check), because a job that stopped running fails quietly.
- **Idempotent and resumable:** process in batches, record progress, and make a rerun pick up where it stopped.

## 6. Bots, webhooks and integrations

- **Verify every incoming webhook** (the provider's signature, a shared secret, or fetching the event back from the provider's API) before acting, and reject old timestamps to stop replays.
- **Respond fast, work later:** acknowledge the webhook within the provider's timeout and queue the work; providers retry slow endpoints, which causes duplicates.
- **Deduplicate** by the event ID with a unique constraint; deliveries are at least once.
- **Respect rate limits** of the APIs you call: back off on 429 with `Retry-After`, batch requests, cache responses.
- **Tokens:** least-privilege scopes, stored in a secrets manager or the platform's secret store, rotated, never logged.
- **Chat bots:** check who is allowed to run each command; a bot that executes commands for anyone in a group chat is a remote shell.

## 7. Scrapers

- **Prefer an official API or data export.** Scraping is the fallback, and its legality depends on the site's terms, the data (personal data is protected in many places) and the country. Raise this with the user before building.
- **Be polite:** honour `robots.txt`, rate-limit (seconds between requests, not milliseconds), identify the client honestly in the User-Agent, and cache pages so reruns don't refetch.
- **Expect breakage:** selectors change without notice. Isolate parsing in one module with tests on saved sample pages, and alert when a run extracts nothing.
- **Headless browsers** (Playwright) only when the content needs JavaScript; plain HTTP plus an HTML parser is faster and lighter.
- **Never bypass logins, paywalls, CAPTCHAs or bot protection.**

## 8. Distribution

- **Single binaries** (Go, Rust, .NET single-file, Deno or Bun compile) are easiest for non-developers.
- **Python:** `pipx install` or `uv tool install` for CLIs; publish to PyPI with trusted publishing.
- **Node:** an npm package with a `bin` entry, runnable with `npx`; publish with provenance or trusted publishing.
- **Package managers:** Homebrew, winget, Scoop, apt repositories for wider audiences.
- **Version every release** (semantic versions), print it with `--version`, and keep a changelog.
- **Sign and checksum** release binaries, especially when users download them directly.

## 9. Testing

- **Keep logic in functions** that take arguments and return values; the CLI layer only parses arguments and prints. Test the functions directly.
- **Golden-file or snapshot tests** for output formats, with fixed time zones, locales and seeds.
- **Run the real binary** in a few integration tests against temporary directories and fixture files: success, bad input, missing file, and the exit codes.
- **Test idempotency:** run twice, assert the same end state.
- **Scheduled jobs** get a "run once now" command, so they can be tested and triggered by hand.
