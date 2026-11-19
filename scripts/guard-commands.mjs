#!/usr/bin/env node
// Claude Code PreToolUse hook. Blocks destructive git and delete commands, and asks
// before production deploys, publishes, infrastructure and database changes, and
// commands that print secrets into the session. Wire it with matcher "Bash|PowerShell"
// (see references/build/git-and-tooling.md §3). Tests: node scripts/tests/guard.test.mjs
// Fails closed: if the hook input can't be read, the command is blocked.
// Regex guards prevent accidents; they are not a security boundary.

// A command that reads a secret file and prints it: .env files (not .env.example,
// .env.sample or .env.template), private keys, keystores, signing and credential files.
const SECRET_FILE =
  String.raw`(?:\.env(?!\.(?:example|sample|template|dist|defaults)\b)(?:\.[\w-]+)?|\.envrc|[\w.-]*\.(?:pem|p12|pfx|jks|keystore|key)|key\.properties|id_(?:rsa|dsa|ecdsa|ed25519)|[\w.-]*(?:service[-_]?account|adminsdk)[\w.-]*\.json|credentials\.json|\.npmrc|\.pypirc|\.netrc|\.git-credentials)`;
const READERS = String.raw`(?:cat|type|Get-Content|gc|head|tail|less|more|bat|nl|xxd|od|strings|base64|grep|egrep|fgrep|rg|ag|sed|awk|Select-String|sls|jq|yq)`;
const SECRET_FILE_READ = new RegExp(
  String.raw`(?:^|[\s;&|(])` + READERS + String.raw`\b[^|;&]*[\s"'=/\\]` + SECRET_FILE + String.raw`(?=["'\s)]|$)`,
  "i"
);

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
  [/\brails\b[^|;&]*\bdb:(drop|reset|schema:load)\b|\brake\b[^|;&]*\bdb:(drop|reset)\b|\bartisan\b[^|;&]*\b(migrate:(fresh|reset|refresh)|db:wipe)\b|\bmanage\.py\b[^|;&]*\b(flush|reset_db)\b|\bdotnet\s+ef\b[^|;&]*\bdatabase\s+drop\b|\balembic\b[^|;&]*\bdowngrade\s+base\b/, "drops or resets whatever database the app is configured for"],
  [/\b(dropdb|dropuser)\b|\b(psql|mysql|mariadb|sqlite3|sqlcmd|mongosh|mongo|duckdb)\b[^|;&]*\b(drop\s+(database|schema|table|collection)\b|truncate\s+table\b|dropDatabase\s*\()|\bredis-cli\b[^|;&]*\bflush(all|db)\b/i, "drops or empties a database"],
  // publishing in other ecosystems
  [/\bcargo\b[^|;&]*\bpublish\b(?![^|;&]*--dry-run)/, "publishes a crate to crates.io"],
  [/\b(twine\s+upload|uv\s+publish|poetry\s+publish|flit\s+publish|hatch\s+publish)\b/, "publishes a package to PyPI"],
  [/\bgem\s+push\b/, "publishes a gem to RubyGems"],
  [/\b(dotnet\s+nuget|nuget)\s+push\b/, "publishes a package to NuGet"],
  [/\bmvn\b[^|;&]*\s(deploy|release:perform)\b|\bgradlew?\b[^|;&]*\s(publish(?!ToMavenLocal\b)\w*)\b/, "publishes artifacts to a Maven repository"],
  [/\b(bun|deno|jsr)\b[^|;&]*\bpublish\b(?![^|;&]*--dry-run)|\b(vsce|ovsx)\s+publish\b|\bpod\s+trunk\s+push\b/, "publishes a package or extension"],
  [/\b(docker|podman)\b[^|;&]*\s(push|buildx\b[^|;&]*--push)\b/, "pushes an image to a registry"],
  // infrastructure and hosting
  [/\b(terraform|tofu)\b[^|;&]*\s(apply|destroy)\b|\bpulumi\b[^|;&]*\s(up|destroy)\b/, "changes real infrastructure"],
  [/\b(fly|flyctl)\b[^|;&]*\s(deploy|destroy)\b|\brailway\b[^|;&]*\s(up|down)\b|\bwrangler\b[^|;&]*\s(deploy|publish|delete)\b/, "deploys to or deletes a live app"],
  [/\bgcloud\b[^|;&]*\s(deploy|delete)\b|\baz\b[^|;&]*\s(deploy|delete)\b|\bazd\b[^|;&]*\s(up|deploy|down)\b/, "deploys to or deletes cloud resources"],
  [/\baws\b[^|;&]*\s(deploy|delete-\w+|terminate-instances|rb|rm\b[^|;&]*--recursive)\b|\bsam\b[^|;&]*\sdeploy\b|\bcdk\b[^|;&]*\s(deploy|destroy)\b|\b(serverless|sls)\b[^|;&]*\s(deploy|remove)\b/, "deploys to or deletes AWS resources"],
  [/\bkubectl\b[^|;&]*\s(apply|delete|replace|patch|scale|rollout\s+(undo|restart))\b|\bhelm\b[^|;&]*\s(install|upgrade|uninstall|rollback|delete)\b/, "changes a Kubernetes cluster"],
  [/\bheroku\b[^|;&]*\s(releases:rollback|apps:destroy|pg:reset)\b|\bgit\b[^|;&]*\bpush\b[^|;&]*\bheroku\b/, "changes a live Heroku app"],
  // secrets printed into the session (and so into logs and transcripts)
  [SECRET_FILE_READ, "prints a secret file (.env, private key, keystore, credentials) into the session; read .env.example for variable names instead"],
  [/\bgh\s+auth\s+token\b|\bheroku\s+config(?!:(set|unset|add|remove))\b|\bvercel\s+env\s+pull\b|\bnetlify\s+env:(list|get)\b|\bfirebase\b[^|;&]*\bfunctions:config:get\b|\baws\b[^|;&]*\b(secretsmanager\s+get-secret-value|ssm\s+get-parameters?\b[^|;&]*--with-decryption)|\bgcloud\b[^|;&]*\bsecrets\s+versions\s+access\b|\baz\s+keyvault\s+secret\s+show\b|\bkubectl\b[^|;&]*\bget\s+secrets?\b[^|;&]*\s-o\s*=?\s*(yaml|json|jsonpath|go-template)|\bop\s+(read|item\s+get)\b|\bdoppler\s+secrets\b/, "prints secrets from a secret store into the session"],
  [/(?:^|[;&|(]\s*)(printenv|env)(?=\s*($|[|;&)]))|\b(Get-ChildItem|gci|dir|ls)\s+env:/i, "prints every environment variable, including secrets"],
  [/\b(echo|printf|Write-Output|Write-Host)\b[^|;&]*\$(env:)?\{?\w*(KEY|TOKEN|SECRET|PASSWORD|PASSWD)\w*/i, "prints a secret from an environment variable"],
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
