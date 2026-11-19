#!/usr/bin/env bash
# Tests for scripts/scan.sh. Run: bash scripts/tests/scan.test.sh
# Builds a throwaway git repo with planted issues in several languages, runs the
# scanner on it, and checks that each issue is reported and no secret leaks in full.
# Fake secrets are generated at run time so none are ever committed to this repo.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
tr -d '\r' < "$HERE/../scan.sh" > "$TMP/scan.sh"

rand() { LC_ALL=C tr -dc "${2:-A-Za-z0-9}" </dev/urandom 2>/dev/null | head -c "$1"; }
STRIPE="sk_live_$(rand 40)"
AWS="AKIA$(rand 16 'A-Z0-9')"
OPENAI="sk-proj-$(rand 48)"
PEMBODY="$(rand 64)"
DBPASS="$(rand 14)"
APPTOKEN="$(rand 32)"
ADMINKEY="$(rand 24)"

R="$TMP/repo"
mkdir -p "$R" && cd "$R" || exit 1
git init -q && git config user.email test@example.com && git config user.name test && git config commit.gpgsign false

# 1. A committed .env with a live payment key
printf 'STRIPE_SECRET_KEY=%s\nNODE_ENV=production\n' "$STRIPE" > .env
# 2-3. Express handler with an unscoped lookup and a webhook without signature checks
mkdir -p src
cat > src/server.js <<'EOF'
const express = require("express");
const app = express();
app.get("/orders/:id", async (req, res) => {
  const order = await Order.findById(req.params.id);
  res.json(order);
});
app.post("/webhook", express.json(), async (req, res) => {
  await markPaid(req.body.data.object.id);
  res.sendStatus(200);
});
EOF
printf 'const OPENAI_KEY = "%s";\n' "$OPENAI" > src/ai.js
# 2b. A router-style handler protected by a shared static admin key
mkdir -p routes
cat > routes/admin.js <<EOF
const ADMIN_KEY = "$ADMINKEY";
adminRouter.delete("/products/:id", async (req, res) => {
  if (req.headers["x-admin-key"] === ADMIN_KEY) return res.sendStatus(204);
  res.sendStatus(403);
});
EOF
# 4-5. Python: SQL from an f-string and pickle on request data
mkdir -p app
cat > app/views.py <<'EOF'
import pickle
def order(request, user_id):
    cursor.execute(f"SELECT * FROM orders WHERE user_id = {user_id}")
    prefs = pickle.loads(request.body)
    return prefs
EOF
# 6. ASP.NET endpoint with auth switched off, plus a connection string with a password
cat > Program.cs <<'EOF'
[AllowAnonymous]
[HttpPost("/admin/reset")]
public IActionResult Reset() => Ok();
EOF
printf '{ "ConnectionStrings": { "Db": "Server=db;Database=shop;User Id=app;Password=%s;" } }\n' "$DBPASS" > appsettings.json
# 7. Go: SQL built with Sprintf
cat > main.go <<'EOF'
package main
func get(id string) { db.Query(fmt.Sprintf("SELECT * FROM orders WHERE id = %s", id)) }
EOF
# 8. Dockerfile running as root with a secret in ENV and an unpinned base image
printf 'FROM node\nENV API_TOKEN=%s\nCOPY . .\nCMD ["node","src/server.js"]\n' "$APPTOKEN" > Dockerfile
# 9. CI running PR code with secrets
mkdir -p .github/workflows
cat > .github/workflows/ci.yml <<'EOF'
on: pull_request_target
jobs:
  t:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - run: echo "${{ github.event.pull_request.title }}"
EOF
# 10. Electron with Node in the renderer
mkdir -p electron
printf 'new BrowserWindow({ webPreferences: { nodeIntegration: true, contextIsolation: false } });\n' > electron/main.js
# 11. Money as a double in Dart
mkdir -p lib
printf 'class Item { final double price; Item(this.price); }\n' > lib/item.dart
# 12. Open Firestore rules
printf "rules_version = '2';\nservice cloud.firestore {\n  match /databases/{db}/documents {\n    match /{document=**} { allow read, write: if true; }\n  }\n}\n" > firestore.rules
# 13. package.json with no lockfile and no release cooldown
printf '{ "name": "shop", "dependencies": { "express": "^5.0.0" } }\n' > package.json
git add -A && git commit -qm "initial"
# 14. A service-account key committed, then deleted (still in history)
mkdir -p config
printf '{ "type": "service_account", "private_key": "-----BEGIN PRIVATE KEY-----\\n%s\\n-----END PRIVATE KEY-----\\n" }\n' "$PEMBODY" > config/service-account.json
git add -A && git commit -qm "add credentials"
git rm -q config/service-account.json && git commit -qm "remove credentials"

OUT="$TMP/out.txt"
bash "$TMP/scan.sh" "$R" > "$OUT" 2>"$TMP/err.txt"
STATUS=$?

fail=0
expect() { # expect LABEL FIXED-STRING
  if grep -qF -- "$2" "$OUT"; then :; else echo "FAIL $1: expected output to contain: $2"; fail=$((fail + 1)); fi
}
expect "exit status" "Next: run the project's checks"
[ "$STATUS" -eq 0 ] || { echo "FAIL scanner exited $STATUS"; fail=$((fail + 1)); }
[ -s "$TMP/err.txt" ] && { echo "FAIL scanner wrote to stderr:"; head -5 "$TMP/err.txt"; fail=$((fail + 1)); }
expect ".env tracked" "tracked now: .env"
expect "Stripe live key" "Stripe live secret/restricted key"
expect "OpenAI-style key" "OpenAI/Anthropic/OpenRouter-style key"
expect "connection string" "Connection string with an inline password"
expect "unscoped lookup" "Lookups by client-supplied ID"
expect "router-style handler" "routes/admin.js:2:adminRouter.delete("
expect "hardcoded admin key" "Hardcoded credential assignment"
expect "static header key" "Static key in a header compared in code"
expect "webhook without verification" "webhook/callback code with no signature/JWT verification call: src/server.js"
expect "python SQL" "SQL built from strings (Python, Java, C#, Go, PHP, Ruby)"
expect "go SQL" "main.go"
expect "pickle" "Unsafe deserialization"
expect "auth off" "Auth or CSRF protection switched off"
expect "other frameworks" "Handlers in other frameworks"
expect "docker root" "container runs as root (no USER line): Dockerfile"
expect "docker unpinned" "unpinned base image (latest or no tag): Dockerfile"
expect "dockerignore" "no .dockerignore"
expect "CI prt" "CI running untrusted PR code with secrets"
expect "CI injection" "CI interpolating event text into shell steps"
expect "unpinned action" "Third-party actions not pinned to a commit SHA"
expect "electron" "Electron security settings switched off"
expect "money float" "Money in floating point"
expect "firestore rules" "firestore.rules"
expect "no lockfile" "no lockfile next to package.json"
expect "no cooldown" "no dependency release cooldown for JS packages"
expect "history-only file" "in history only (deleted, still leaked): config/service-account.json"
expect "history pickaxe or gitleaks" "config"

# No secret may appear in full: check every 10-character window past each key's prefix.
leaks=0
for s in "${STRIPE#sk_live_}" "${AWS#AKIA}" "${OPENAI#sk-proj-}" "$PEMBODY" "$DBPASS" "$APPTOKEN" "$ADMINKEY"; do
  n=${#s}
  for ((i = 0; i + 10 <= n; i += 5)); do
    if grep -qF -- "${s:i:10}" "$OUT"; then leaks=$((leaks + 1)); echo "FAIL secret fragment printed: ${s:0:3}…"; break; fi
  done
done
fail=$((fail + leaks))

checks=30
echo "$checks checks, $fail failed"
[ "$fail" -eq 0 ]
