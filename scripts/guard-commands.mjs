#!/usr/bin/env node
// Claude Code PreToolUse hook: blocks destructive git commands and asks before
// risky deploys. Wire it with matcher "Bash|PowerShell" (see references/build/git-and-tooling.md).
// Fails closed: if the hook input can't be read, the command is blocked.
// Regex guards prevent accidents; they are not a security boundary.

const DENY = [
  [/\bgit\b[^|;&]*\bpush\b[^|;&]*(\s--force(?=[\s"')]|$)|\s-[a-zA-Z]*f[a-zA-Z]*(?=[\s"')]|$)|\s["']?\+[^\s"']|\s--mirror\b)/, "force-push rewrites remote history"],
  [/\bgit\b[^|;&]*\breset\b[^|;&]*--hard\b/, "reset --hard discards uncommitted work"],
  [/\bgit\b[^|;&]*\bclean\b[^|;&]*(\s-[a-zA-Z]*f|\s--force\b)/, "clean -f deletes untracked files permanently"],
  [/\bgit\b[^|;&]*\b(checkout|switch)\b[^|;&]*(\s-f\b|\s--force\b|\s--discard-changes\b)/, "checkout/switch --force discards working-tree changes"],
  [/\bgit\b[^|;&]*\bcheckout\b[^|;&]*\s(--\s+)?\.(\s|$)/, "checkout . discards working-tree changes"],
  [/\bgit\b[^|;&]*\brestore\b(?![^|;&]*(--staged|\s-S\b))[^|;&]*\s\.(\s|$)/, "restore . discards working-tree changes"],
  [/\bgit\b[^|;&]*\brestore\b(?=[^|;&]*(--worktree|\s-W\b))[^|;&]*\s\.(\s|$)/, "restore --worktree . discards working-tree changes"],
  [/\bgit\b[^|;&]*\bbranch\b[^|;&]*(\s-D\b|\s-df\b|\s-fd\b|\s-d\s+-f\b|\s-f\s+-d\b|--delete\s+--force|--force\s+--delete)/, "branch -D deletes unmerged work"],
  [/\bgit\b[^|;&]*\bstash\b\s+(drop|clear)\b/, "stash drop/clear loses stashed work"],
  [/\bgit\b[^|;&]*\bworktree\s+remove\b[^|;&]*(--force|\s-f\b)/, "worktree remove --force deletes files that exist nowhere else"],
  [/--no-verify\b|\bgit\b[^|;&]*\bcommit\b[^|;&]*\s-[a-zA-Z]*n[a-zA-Z]*(?=[\s"')]|$)|core\.hooksPath=|\bHUSKY=0\b|\$env:HUSKY\s*=\s*["']?0/, "skipping git hooks"],
  [/\brm\b(?=[^|;&]*\s-(?:[a-zA-Z]*[rR]|-recursive\b))[^|;&]*\s["']?(?:\/\*?|~\/?\*?|\$\{?HOME\}?\/?\*?|\.{1,2}\/?|\*|(?:\.\/)?\.git\/?)["']?(?=\s|$)/, "recursive delete of the home folder, the drive root, the whole folder or .git"],
  [/\bRemove-Item\b(?=[^|;&]*\s-Recurse\b)[^|;&]*\s["']?(?:~|\$HOME|\$env:USERPROFILE|[A-Za-z]:\\?|\.{1,2}|\*|(?:\.\\)?\.git)["']?(?=\s|$)/i, "recursive delete of the home folder, a drive root, the whole folder or .git"],
];

const ASK = [
  [/\bgit\b[^|;&]*\bpush\b[^|;&]*--force-with-lease\b/, "force-push (with lease) rewrites remote history"],
  [/\bgit\b[^|;&]*\bpush\b[^|;&]*(\s--delete\b|\s-d\b|\s:[^\s:])/, "deletes a remote branch or tag"],
  [/\bgit\b[^|;&]*\b(filter-branch|filter-repo)\b/, "rewrites repository history"],
  [/\bfirebase\b[^|;&]*\sdeploy\b(?![^|;&]*--only)/, "firebase deploy without --only also pushes rules, functions and indexes to the live project"],
  [/\bfirebase\b[^|;&]*\sdeploy\b[^|;&]*--only/, "deploys to the live Firebase project"],
  [/\bfirebase\b[^|;&]*\shosting:clone\b[^|;&]*:live\b/, "promotes a build to the live site"],
  [/\bfirebase\b[^|;&]*\s(firestore:delete|firestore:databases:delete|database:remove|functions:delete|hosting:disable)\b/, "deletes live Firebase data or resources"],
  [/\bsupabase\b[^|;&]*\bdb\s+push\b/, "applies migrations to the linked remote database"],
  [/\bsupabase\b[^|;&]*\bdb\s+reset\b[^|;&]*(--linked|--db-url)/, "drops every user-created object in the remote database"],
  [/\bnetlify\b[^|;&]*\bdeploy\b[^|;&]*--prod/, "deploys to the production site"],
  [/\bvercel\b[^|;&]*(--prod\b|\spromote\b|\srollback\b)/, "changes the production deployment"],
  [/\beas\b[^|;&]*\bsubmit\b/, "submits a build to the app stores"],
  [/\beas\b[^|;&]*\bupdate\b[^|;&]*(--channel|--branch)[\s=]+production\b/, "pushes an OTA update to production users"],
  [/\b(npm|pnpm|yarn)\b[^|;&]*\bpublish\b(?![^|;&]*--dry-run)|\b(dart|flutter)\s+pub\s+publish\b(?![^|;&]*--dry-run)/, "publishes a package to the registry"],
  [/\bgh\b[^|;&]*\b(pr\s+merge\b[^|;&]*--admin|repo\s+delete)\b/, "bypasses branch protection or deletes a repository"],
  [/\bgh\b[^|;&]*\brepo\s+edit\b[^|;&]*--visibility[\s=]+public\b/, "makes the repository public, including every secret ever committed to its history"],
  [/\bgit\b[^|;&]*\b(reflog\s+expire\b|gc\b[^|;&]*--prune=now)/, "destroys the reflog, the last way to recover lost commits"],
  [/\bprisma\b[^|;&]*\b(migrate\s+reset\b|db\s+push\b[^|;&]*(--force-reset|--accept-data-loss))|\bdrizzle-kit\b[^|;&]*\bpush\b[^|;&]*--force\b/, "can drop tables and data in whatever database DATABASE_URL points to"],
];

function decide(command) {
  // Ignore commit-message text (quotes, bash heredocs inside quotes, PowerShell
  // here-strings) so "docs: never run git reset --hard" isn't blocked.
  const cmd = command
    .replace(/(\s-[a-zA-Z]*m|\s--message)(=|\s+)(@'[\s\S]*?'@|@"[\s\S]*?"@|"[^"]*"|'[^']*')/g, "$1 MSG")
    .replace(/\\\r?\n/g, " ") // line continuations
    .replace(/\r?\n/g, " ; ") // separate lines are separate commands
    .replace(/\s+/g, " ");
  for (const [re, why] of DENY) if (re.test(cmd)) return ["deny", why];
  for (const [re, why] of ASK) if (re.test(cmd)) return ["ask", why];
  return null;
}

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (c) => (raw += c));
process.stdin.on("end", () => {
  let command;
  try {
    command = JSON.parse(raw)?.tool_input?.command;
  } catch {
    process.stderr.write("guard-commands: could not parse hook input; blocking to be safe.\n");
    process.exit(2);
  }
  if (typeof command !== "string") process.exit(0); // not a shell call

  const verdict = decide(command);
  if (!verdict) process.exit(0);
  const [decision, why] = verdict;

  if (decision === "deny") {
    process.stderr.write(
      `Blocked by guard-commands: ${why}.\n` +
        "If the user explicitly asked for this, tell them what it will change and let them run it themselves.\n"
    );
    process.exit(2);
  }
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "ask",
        permissionDecisionReason: `guard-commands: ${why}. Confirm before running.`,
      },
    })
  );
  process.exit(0);
});
