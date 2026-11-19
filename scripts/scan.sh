#!/usr/bin/env bash
# First-pass lead finder for the vibe-code skill's Audit mode.
#
# Prints places worth reading. A hit is a lead, not a finding: open the file,
# follow the code path, and only report what you confirm. A clean section does
# not mean the area is safe either; grep can't see logic bugs.
#
# Read-only: no file changes, no network, no installs. Secret values are masked.
# Usage (Git Bash on Windows; from PowerShell, plain `bash` may start WSL instead):
#   bash scan.sh [repo-dir]          SCAN_MAX=50 bash scan.sh .   shows more hits per check

set -u
ROOT="${1:-.}"
cd "$ROOT" 2>/dev/null || { echo "scan.sh: no such directory: $ROOT" >&2; exit 1; }
MAX="${SCAN_MAX:-12}"

# Never worth scanning. Secret checks use only these, so .vscode/.idea/.claude are covered.
EXCL_BASE=(--exclude-dir=.git --exclude-dir=node_modules --exclude-dir=build --exclude-dir=dist
  --exclude-dir=out --exclude-dir=.next --exclude-dir=.nuxt --exclude-dir=.expo --exclude-dir=.dart_tool
  --exclude-dir=.gradle --exclude-dir=Pods --exclude-dir=DerivedData --exclude-dir=coverage
  --exclude-dir=vendor --exclude-dir=.venv --exclude-dir=venv --exclude-dir=__pycache__
  --exclude-dir=.turbo --exclude-dir=.vercel --exclude-dir=.netlify --exclude-dir=.firebase
  "--exclude=*.lock" --exclude=package-lock.json --exclude=pnpm-lock.yaml "--exclude=*.min.js"
  "--exclude=*.map" "--exclude=*.log")
# Code-smell leads also skip editor/agent folders, SVGs and generated Dart.
EXCL=("${EXCL_BASE[@]}" --exclude-dir=.idea --exclude-dir=.vscode --exclude-dir=.claude
  "--exclude=*.svg" "--exclude=*.g.dart" "--exclude=*.freezed.dart")
SRC=("--include=*.js" "--include=*.jsx" "--include=*.ts" "--include=*.tsx" "--include=*.mjs"
  "--include=*.cjs" "--include=*.vue" "--include=*.svelte" "--include=*.dart" "--include=*.py"
  "--include=*.php" "--include=*.rb" "--include=*.go" "--include=*.java" "--include=*.kt"
  "--include=*.swift" "--include=*.sql" "--include=*.html" "--include=*.cs" "--include=*.cshtml"
  "--include=*.razor" "--include=*.rs" "--include=*.kts" "--include=*.erb" "--include=*.jinja"
  "--include=*.j2" "--include=*.twig" "--include=*.scala" "--include=*.ex" "--include=*.exs")

hdr() { printf '\n## %s\n' "$1"; }
note() { printf '    %s\n' "$1"; }
any() { for f in "$@"; do [ -e "$f" ] && return 0; done; return 1; }

# Mask secret-shaped values in any line we print.
mask() {
  sed -E \
    -e 's#(://[^:/@ ]+:)[^@ ]+@#\1***@#g' \
    -e 's/((Password|Pwd|PASSWORD|password|pwd)=)[^;"'"'"' ]+/\1***/g' \
    -e 's/\b((sk|rk|pk)_(live|test)_|sb_secret_|sbp_|whsec_|github_pat_|gh[pousr]_|xox[abprs]-|gsk_|hf_|xai-|GOCSPX-)[A-Za-z0-9_-]{6,}/\1***/g' \
    -e 's/\bre_[A-Za-z0-9]{6,}_[A-Za-z0-9]{16,}/re_***/g' \
    -e 's/\b([0-9]{8,10}:)AA[A-Za-z0-9_-]{30,}/\1AA***/g' \
    -e 's/\bsk-(proj-|ant-|svcacct-|admin-)?[A-Za-z0-9_-]{16,}/sk-\1***/g' \
    -e 's/\b(AKIA|ASIA)[0-9A-Z]{12,}/\1***/g' \
    -e 's/\bAIza[0-9A-Za-z_-]{20,}/AIza***/g' \
    -e 's/\beyJ[A-Za-z0-9_-]{10,}(\.[A-Za-z0-9_-]+)*/eyJ***/g' \
    -e 's/\bSG\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/SG.***/g' \
    -e 's/(([Kk]ey|KEY|[Ss]ecret|SECRET|[Tt]oken|TOKEN|[Pp]assw(or)?d|PASSW(OR)?D|[Pp]wd)[A-Za-z_]*["'"'"']?\]?[[:space:]]*(:|=|==|===|!=|!==)[[:space:]]*["'"'"'])[^"'"'"']{6,}/\1***/g' \
    -e 's/(([Kk]ey|KEY|[Ss]ecret|SECRET|[Tt]oken|TOKEN|[Pp]assw(or)?d|PASSW(OR)?D|[Pp]wd|PWD)[A-Za-z0-9_]*[[:space:]]*(:|=)[[:space:]]*)[A-Za-z0-9_+/=-]{6,}([[:space:]"'"'"';,]|$)/\1***\6/g' \
    -e 's/(["'"'"'])[A-Za-z0-9_-]{24,}(["'"'"'])/\1***\2/g'
}

# print_hits NAME : reads grep -n output on stdin, prints up to MAX masked lines
print_hits() {
  local name="$1" out n
  out=$(head -n $((MAX + 1)))
  [ -z "$out" ] && return 0
  n=$(printf '%s\n' "$out" | wc -l)
  printf -- '- %s\n' "$name"
  printf '%s\n' "$out" | head -n "$MAX" | mask | cut -c1-220 | sed 's|^\./|    |'
  [ "$n" -gt "$MAX" ] && note "... more (rerun with SCAN_MAX=50)"
  return 0
}

# lead NAME REGEX [include args...] : matching lines (code smells), masked
lead() {
  local name="$1" re="$2"; shift 2
  grep -rnIE "$@" "${EXCL[@]}" -e "$re" . 2>/dev/null | print_hits "$name"
}

# names NAME REGEX [include args...] : file:line plus the matched text only (regex must stop before any value)
names() {
  local name="$1" re="$2"; shift 2
  grep -rnoIE "$@" "${EXCL[@]}" -e "$re" . 2>/dev/null | sort -u | print_hits "$name"
}

IS_GIT=0; git rev-parse --is-inside-work-tree >/dev/null 2>&1 && IS_GIT=1

# secret NAME REGEX : file:line, a short masked prefix and length, and whether git tracks the file
secret() {
  local name="$1" re="$2" out
  out=$(grep -rnoIE "${EXCL_BASE[@]}" -e "$re" . 2>/dev/null | head -n "$MAX")
  [ -z "$out" ] && return 0
  printf -- '- %s\n' "$name"
  printf '%s\n' "$out" | while IFS= read -r l; do
    local file="${l%%:*}" rest="${l#*:}"
    local line="${rest%%:*}" m="${rest#*:}" st=""
    if [ "$IS_GIT" = 1 ]; then
      if git ls-files --error-unmatch -- "$file" >/dev/null 2>&1; then st=" [TRACKED]"
      else st=" [untracked: a leak only if bundled or shared]"; fi
    fi
    printf '    %s:%s  %s...(%d chars)%s\n' "${file#./}" "$line" "${m:0:7}" "${#m}" "$st"
  done
}

echo "# scan.sh leads for: $(pwd)"
echo "Every line is a lead to confirm by reading the code. Masked values are deliberate."

# ---------------------------------------------------------------------------
hdr "Stack and surfaces"
find . \( -name node_modules -o -name .git -o -name build -o -name .dart_tool -o -name Pods \) -prune -o \
  \( -name package.json -o -name pubspec.yaml -o -name firebase.json -o -name '*.rules' \
     -o -name database.rules.json -o -name config.toml -path '*supabase*' -o -name 'next.config.*' \
     -o -name 'vite.config.*' -o -name app.json -o -name 'app.config.*' -o -name eas.json \
     -o -name netlify.toml -o -name vercel.json -o -name _headers -o -name Dockerfile \
     -o -name requirements.txt -o -name pyproject.toml -o -name AndroidManifest.xml \
     -o -name Info.plist -o -name schema.prisma -o -name go.mod -o -name Cargo.toml -o -name pom.xml \
     -o -name 'build.gradle*' -o -name '*.csproj' -o -name composer.json -o -name Gemfile -o -name manage.py \
     -o -name tauri.conf.json -o -name '*.tf' -o -name Pulumi.yaml -o -name 'docker-compose*.y*ml' \
     -o -name Package.swift -o -name CMakeLists.txt -o -name platformio.ini \) -print 2>/dev/null \
  | sed 's|^\./|    |' | head -n 40
[ -d .github/workflows ] && note ".github/workflows/ (CI present)"
lead "Next.js version (read the exact version from the lockfile; compare with the newest security release on nextjs.org/blog: 13.x/14.x get no fixes)" '"next"[[:space:]]*:[[:space:]]*"[^"]+"' "--include=package.json"

# ---------------------------------------------------------------------------
hdr "Committed files that usually hold secrets"
SENSITIVE='(^|/)(\.env(\.[^/]*)?|\.envrc|[^/]*\.pem|[^/]*\.key|[^/]*\.p12|[^/]*\.pfx|[^/]*\.jks|[^/]*\.keystore|key\.properties|[^/]*service[-_]?account[^/]*\.json|[^/]*firebase-adminsdk[^/]*\.json|credentials\.json|id_rsa|id_ed25519|\.npmrc|\.pypirc|\.netrc|\.git-credentials|master\.key|terraform\.tfstate(\.backup)?|[^/]*\.tfvars)$'
if [ "$IS_GIT" = 1 ]; then
  [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = true ] \
    && note "SHALLOW CLONE: history is incomplete, so secrets in older commits can't be seen"
  git ls-files | grep -iE "$SENSITIVE" | grep -viE '\.env\.(example|sample|template|dist)$' | sed 's/^/    tracked now: /'
  git log --all --name-only --format= 2>/dev/null | sort -u | grep -iE "$SENSITIVE" \
    | grep -viE '\.env\.(example|sample|template|dist)$' | while IFS= read -r f; do
      git ls-files --error-unmatch -- ":/$f" >/dev/null 2>&1 || note "in history only (deleted, still leaked): $f"
    done
  probe=(.env .env.local .env.production node_modules/x)
  [ -d android ] && probe+=(android/key.properties android/app/upload-keystore.jks)
  for p in "${probe[@]}"; do
    git check-ignore -q "$p" 2>/dev/null || note "not covered by .gitignore: $p"
  done
else
  note "not a git repo: history checks skipped"
  find . -path ./node_modules -prune -o -type f -print | grep -iE "$SENSITIVE" | sed 's/^/    present: /'
fi

# ---------------------------------------------------------------------------
hdr "Secret-shaped strings in the working tree"
secret "Stripe live secret/restricted key" '(sk|rk)_live_[0-9A-Za-z]{10,}'
secret "Stripe test key (lower risk, still rotate if public)" 'sk_test_[0-9A-Za-z]{10,}'
secret "Stripe webhook signing secret" 'whsec_[A-Za-z0-9]{20,}'
secret "Supabase secret key (bypasses all RLS)" 'sb_secret_[A-Za-z0-9_-]{20,}'
secret "OpenAI/Anthropic/OpenRouter-style key" 'sk-(proj-|ant-|svcacct-|admin-)?[A-Za-z0-9_-]{20,}'
secret "Groq / xAI / Hugging Face key" '(gsk_[A-Za-z0-9]{40,}|xai-[A-Za-z0-9]{40,}|hf_[A-Za-z0-9]{34,})'
secret "Supabase personal access token (full account access)" 'sbp_[A-Za-z0-9_]{32,}'
secret "Google OAuth client secret" 'GOCSPX-[A-Za-z0-9_-]{20,}'
secret "Telegram bot token" '[0-9]{8,10}:AA[A-Za-z0-9_-]{30,}'
secret "Resend API key" 're_[A-Za-z0-9]{6,}_[A-Za-z0-9]{16,}'
secret "AWS access key id" '(AKIA|ASIA)[0-9A-Z]{16}'
secret "GitHub token" '(gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,})'
secret "Slack token" 'xox[abprs]-[A-Za-z0-9-]{10,}'
secret "SendGrid key" 'SG\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}'
secret "Private key block" '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----'
secret "Service-account JSON content" '"type"[[:space:]]*:[[:space:]]*"service_account"'
secret "Connection string with an inline password" '(Password|Pwd|PASSWORD|password|pwd)=[^;"'"'"' <>{}$]{4,};'
secret "DB URL with password" '(postgres(ql)?|mysql|mongodb(\+srv)?|redis|amqp)://[^:/ "]+:[^@/ "]+@'
secret "JWT (legacy Supabase anon/service_role keys are JWTs: decode the payload; role service_role = critical)" 'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
secret "Google API key (Firebase config keys are public by design; Gemini/Maps server keys are not)" 'AIza[0-9A-Za-z_-]{35}'
secret "Hardcoded credential assignment" '([Aa][Pp][Ii][_-]?[Kk][Ee][Yy]|([Aa][Dd][Mm][Ii][Nn]|[Mm][Aa][Ss][Tt][Ee][Rr]|[Ss][Ii][Gg][Nn][Ii][Nn][Gg])[_-]?[Kk][Ee][Yy]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Pp][Aa][Ss][Ss][Ww]([Oo][Rr])?[Dd]|[Tt][Oo][Kk][Ee][Nn])[A-Za-z0-9_]*["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"' ]{8,}["'"'"']'
names "Static key in a header compared in code (a shared secret instead of real auth)" \
  '(headers\[[^]]*|headers\.get\([^)]*|req\.get\([^)]*|header\([^)]*)([Kk]ey|[Tt]oken|[Ss]ecret|[Aa]uth)[^])]*[])][[:space:]]*[!=]==?' "${SRC[@]}"
names "Secrets compiled into a mobile binary (--dart-define values are extractable)" \
  'String\.fromEnvironment\(["'"'"'][A-Z_]*(KEY|SECRET|TOKEN|PASSWORD)[A-Z_]*["'"'"']' "--include=*.dart"
lead "A .env file bundled as a Flutter asset (ships in plain text)" '^[[:space:]]*-[[:space:]]*\.env' "--include=pubspec.yaml"
names "Secret-looking names behind a client-exposed prefix (bundled into the app)" \
  '(NEXT_PUBLIC|VITE|REACT_APP|EXPO_PUBLIC|NUXT_PUBLIC|PUBLIC)_[A-Z0-9_]*(SECRET|SERVICE_ROLE|PRIVATE|OPENAI|ANTHROPIC|GEMINI|GROQ|STRIPE_SECRET|ADMIN|PASSWORD|DATABASE_URL|RESEND|SENDGRID|TWILIO)[A-Z0-9_]*'

# ---------------------------------------------------------------------------
hdr "Secrets in git history (all branches; prints commits, not values)"
if [ "$IS_GIT" != 1 ]; then
  note "skipped: not a git repo"
elif command -v gitleaks >/dev/null 2>&1; then
  out=$(gitleaks git -v --redact --no-banner --exit-code 0 . 2>&1) \
    || out=$(gitleaks detect -v --redact --no-banner --exit-code 0 --source . 2>&1)
  printf '%s\n' "$out" | head -n 80
else
  note "gitleaks not installed; using git pickaxe (slower, fewer rules). Never use a scanner's live-verify mode."
  hnames=("Stripe live key" "Stripe webhook secret" "Supabase secret key" "OpenAI/Anthropic key" "AWS key id"
          "Private key block" "Service-account JSON" "DB URL with password" "GitHub token"
          "Groq/xAI/Hugging Face key" "Supabase access token" "Google OAuth secret" "Telegram bot token")
  hres=('(sk|rk)_live_[0-9A-Za-z]{10,}' 'whsec_[A-Za-z0-9]{20,}' 'sb_secret_[A-Za-z0-9_-]{20,}'
        'sk-(proj-|ant-)?[A-Za-z0-9_-]{20,}' '(AKIA|ASIA)[0-9A-Z]{16}' 'BEGIN ([A-Z]+ )?PRIVATE KEY'
        '"type": "service_account"' '(postgres(ql)?|mysql|mongodb(\+srv)?)://[^:/ ]+:[^@/ ]+@' 'gh[pousr]_[A-Za-z0-9]{36,}'
        '(gsk_[A-Za-z0-9]{40,}|xai-[A-Za-z0-9]{40,}|hf_[A-Za-z0-9]{34,})' 'sbp_[A-Za-z0-9_]{32,}' 'GOCSPX-[A-Za-z0-9_-]{20,}'
        '[0-9]{8,10}:AA[A-Za-z0-9_-]{30,}')
  for i in "${!hnames[@]}"; do
    hits=$(git log --all -E -G"${hres[$i]}" --format='%h %ad %s' --date=short 2>/dev/null | head -n "$MAX")
    [ -n "$hits" ] && { printf -- '- %s added or removed in:\n' "${hnames[$i]}"; printf '%s\n' "$hits" | sed 's/^/    /'; }
  done
fi

# ---------------------------------------------------------------------------
hdr "Firebase rules"
rules=$(find . \( -name node_modules -o -name .git \) -prune -o \( -name '*.rules' -o -name database.rules.json \) -print 2>/dev/null)
if [ -n "$rules" ]; then
  printf '%s\n' "$rules" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -nE 'if[[:space:]]+true|allow[[:space:]]+[a-z, ]+;|request\.time[[:space:]]*<|request\.auth(\.uid)?[[:space:]]*!=[[:space:]]*null[[:space:]]*;|"\.(read|write)"[[:space:]]*:[[:space:]]*(true|"true"|"auth[[:space:]]*!==?[[:space:]]*null"|"now[[:space:]]*<)|match[[:space:]]+/\{[a-zA-Z_]+=\*\*\}' "$f" 2>/dev/null \
      | sed "s|^|    ${f#./}:|"
  done
fi
if grep -rqIE "${EXCL[@]}" -e 'cloud_firestore|firebase/firestore|@react-native-firebase/(firestore|storage|database)|firebase_storage|firebase_database' . 2>/dev/null \
   && [ -z "$rules" ]; then
  note "Firebase data APIs used but no rules files in the repo: the rules live only in the console, ask the user to paste them"
fi
lead "Firebase Hosting publishing the project folder (source and secrets go live)" '"public"[[:space:]]*:[[:space:]]*"\.?/?"' "--include=firebase.json"

# ---------------------------------------------------------------------------
if [ -d supabase ] || grep -rqIE "${EXCL[@]}" -e '@supabase/|supabase_flutter' . 2>/dev/null; then
hdr "Supabase"
if [ -d supabase/migrations ]; then
  t=$(grep -riE 'create table' supabase/migrations 2>/dev/null | wc -l)
  r=$(grep -riE 'enable row level security' supabase/migrations 2>/dev/null | wc -l)
  note "CREATE TABLE: $t   ENABLE ROW LEVEL SECURITY: $r   (fewer RLS lines than tables = check each table)"
fi
lead "security definer functions (bypass RLS; need set search_path and an auth check; trigger functions aren't RPC-callable)" '[Ss][Ee][Cc][Uu][Rr][Ii][Tt][Yy] [Dd][Ee][Ff][Ii][Nn][Ee][Rr]' "--include=*.sql"
lead "user_metadata used in authorization (users can edit it themselves)" 'user_metadata|raw_user_meta_data' "--include=*.sql" "--include=*.ts" "--include=*.js"
lead "service_role / secret key referenced (must be server-only)" 'service_role|SERVICE_ROLE|sb_secret_' "${SRC[@]}"
lead "Edge Function with JWT verification off (must check the caller itself)" 'verify_jwt[[:space:]]*=[[:space:]]*false|--no-verify-jwt' "--include=*.toml" "--include=*.json" "--include=*.yml" "--include=*.yaml"
fi

# ---------------------------------------------------------------------------
hdr "Endpoints to check for auth, ownership and validation"
lead "HTTP handlers and callable functions" \
  '([A-Za-z_]*[Aa]pp|[A-Za-z_]*[Rr]outer|[Ss]erver|fastify)\.(get|post|put|patch|delete|all)\(|export (async )?function (GET|POST|PUT|PATCH|DELETE)\b|\bon(Request|Call)\(|["'"'"']use server["'"'"']|Deno\.serve\(|@app\.(get|post|put|delete|route)\(' "${SRC[@]}"
lead "Handlers in other frameworks (Django/DRF, Flask/FastAPI, Rails, Laravel, Spring, ASP.NET, Go, Rust)" \
  '@api_view|\((APIView|ViewSet|ModelViewSet|GenericAPIView)\)|@(app|router|bp|blueprint)\.(route|get|post|put|patch|delete)\(|Route::(get|post|put|patch|delete|any|resource)\(|@(Get|Post|Put|Patch|Delete|Request)Mapping|\[Http(Get|Post|Put|Patch|Delete)|\.Map(Get|Post|Put|Patch|Delete)\(|http\.HandleFunc\(|\.(GET|POST|PUT|PATCH|DELETE)\("/|\.route\("/' "${SRC[@]}"
lead "Auth or CSRF protection switched off (confirm each one is intended)" \
  'AllowAny|permitAll\(\)|\[AllowAnonymous\]|skip_before_action[[:space:]]+:authenticate|csrf_exempt|skip_forgery_protection|csrf\(\)\.disable|csrf\([^)]*disable|IgnoreAntiforgeryToken|withoutMiddleware\(' "${SRC[@]}" "--include=*.py"
lead "Lookups by client-supplied ID (confirm an ownership check)" \
  'doc\([[:space:]]*req\.params|\.(query|execute)\([^;]*req\.(params|query|body)\.[A-Za-z_]*[iI]d\b|findUnique\(\{[^}]*params|where\([^)]*req\.params|\.eq\(["'"'"']id["'"'"'],[[:space:]]*(req\.)?(params|query)|findById\([[:space:]]*req\.' "${SRC[@]}"
lead "Price/amount taken from the client (recompute from the DB on the server)" \
  '\{[^}]*\b(total|price|amount|subtotal|discount)\b[^}]*\}[[:space:]]*=[[:space:]]*(req\.body|await req\.json\(\)|body)|req\.body\.(total|price|amount|subtotal|discount)' "${SRC[@]}"
lead "Webhook/callback handlers (confirm signature or JWT check on the RAW body + replay window)" '[Ww]ebhook|[Cc]allback.*(payment|zaincash|fib|fastpay)' "${SRC[@]}"
{ grep -rlIE "${SRC[@]}" "${EXCL[@]}" -e '[Ww]ebhook|checkout\.session\.completed|payment_intent\.succeeded' . 2>/dev/null
  find . \( -name node_modules -o -name .git -o -name .next -o -name dist -o -name build \) -prune -o -type f \
    \( -ipath '*webhook*' -o -ipath '*callback*' \) -print 2>/dev/null | grep -E '\.(js|jsx|ts|tsx|mjs|cjs|py|php|rb|go|dart)$'
} | sort -u | head -n "$MAX" | while IFS= read -r f; do
  grep -qE 'constructEvent|verifyHeader|validateWebhook|verifyWebhook|svix|createHmac|timingSafeEqual|verifySignature|hmac\.|Hmac\(|jwt\.verify|jwtVerify|jose' "$f" \
    || note "webhook/callback code with no signature/JWT verification call: ${f#./}"
done
lead "User input concatenated into an LLM prompt (prompt injection)" \
  '(content|prompt|system|instructions)["'"'"']?[[:space:]]*:[[:space:]]*[^,]*(\+[[:space:]]*(req|body|input|user|query)|\$\{[^}]*(req|body|input|user|query))' "${SRC[@]}"
lead "Firebase AI Logic in the client (no key ships; confirm App Check with limited-use tokens, sign-in required, per-user limits, budget alert)" \
  'from ["'"'"']firebase/(ai|vertexai)["'"'"']|package:firebase_(ai|vertexai)/' "${SRC[@]}"
lead "LLM call sites (check auth, rate limit, max tokens, prompt built from user input)" \
  'chat\.completions|messages\.create\(|generateContent\(|api\.openai\.com|api\.anthropic\.com|generativelanguage\.googleapis' "${SRC[@]}"

# ---------------------------------------------------------------------------
hdr "Injection, XSS and unsafe sinks"
lead "HTML injection sinks (XSS if the value is user/DB controlled)" \
  'dangerouslySetInnerHTML|\.innerHTML[[:space:]]*=|v-html|insertAdjacentHTML|document\.write\(|bypassSecurityTrust|\{@html' "${SRC[@]}"
lead "SQL built from strings" \
  '(raw(Query|Insert|Update|Delete)|execute|query|unsafe|\$queryRawUnsafe)\([^)]*(\$\{|\$[a-zA-Z_]|["'"'"'`][[:space:]]*\+)|execute\([[:space:]]*f["'"'"']' "${SRC[@]}"
lead "SQL built from strings (Python, Java, C#, Go, PHP, Ruby)" \
  '\.raw\([[:space:]]*f["'"'"']|cursor\.execute\([^)]*%[[:space:]]*\(|execute(Query|Update)?\([[:space:]]*"[^"]*"[[:space:]]*\+|createStatement\(\)|FromSqlRaw\([[:space:]]*\$"|ExecuteSqlRaw\([[:space:]]*\$"|new SqlCommand\([[:space:]]*(\$"|"[^"]*"[[:space:]]*\+)|Sprintf\([[:space:]]*"(SELECT|INSERT|UPDATE|DELETE)|mysqli_query\([^)]*\$_(GET|POST|REQUEST)|\.where\([[:space:]]*"[^"]*#\{' "${SRC[@]}"
lead "Code/command execution" '\beval\(|new Function\(|child_process|execSync\(|os\.system\(|shell=True|Runtime\.getRuntime\(\)\.exec\(|exec\.Command\("(sh|bash|cmd)"|\b(shell_exec|passthru|proc_open)\(|\b(exec|system)\([[:space:]]*\$' "${SRC[@]}"
lead "Unsafe deserialization (never on untrusted data)" \
  'pickle\.loads?\(|torch\.load\(|ObjectInputStream|BinaryFormatter|TypeNameHandling\.(All|Auto|Objects)|\bunserialize\(|Marshal\.load|YAML\.load\(' "${SRC[@]}"
grep -rnIE "${SRC[@]}" "${EXCL[@]}" -e 'yaml\.load\(' . 2>/dev/null | grep -vE 'SafeLoader|safe_load|CSafeLoader' \
  | print_hits "yaml.load without SafeLoader (runs arbitrary constructors)"
lead "Server-template escaping turned off or user input rendered as a template" \
  'mark_safe\(|\|[[:space:]]*safe\b|autoescape[[:space:]]+off|\.html_safe\b|<%==|\{!!|Html\.Raw\(|template\.HTML\(|render_template_string\(' "${SRC[@]}"
lead "Electron security settings switched off" 'nodeIntegration:[[:space:]]*true|contextIsolation:[[:space:]]*false|webSecurity:[[:space:]]*false|sandbox:[[:space:]]*false|allowRunningInsecureContent:[[:space:]]*true' "${SRC[@]}"
lead "Request data flowing into fetch/redirect/file paths (SSRF, open redirect, traversal)" \
  '(fetch|axios\.(get|post)|got|request)\([[:space:]]*(req|request)\.(body|query|params)|redirect\([^)]*(req\.(query|body|params)|searchParams)|(readFile|createReadStream|sendFile|download)\([^)]*req\.(params|query|body)' "${SRC[@]}"
lead "CORS wildcard or reflected origin (High only with credentials or cookie auth)" 'origin:[[:space:]]*(["'"'"']\*["'"'"']|true)|Allow-Origin["'"'"']?[[:space:]]*[:,][[:space:]]*["'"'"']\*|\bcors\(\)' "${SRC[@]}" "--include=*.toml" "--include=*.json" "--include=_headers"
lead "Error details sent to clients" 'stack:[[:space:]]*(err|error|e)\.stack|\bres\.(status\([0-9]+\)\.)?(json|send)\(([^)]*\b(err|error|e)\.stack|[[:space:]]*(err|error|e)[[:space:]]*\))' "${SRC[@]}"
grep -rnIiE "${SRC[@]}" "${EXCL[@]}" -e '(console\.(log|info|error)|print|debugPrint|logger\.[a-z]+)\([^)]*(req\.body|password|passwd|token\b|[a-z]token|secret|authorization|cardnumber|session)' . 2>/dev/null \
  | print_hits "Sensitive data in logs"
grep -rnIiE "${SRC[@]}" "${EXCL[@]}" -e '(setString|setItem|localStorage\.setItem|AsyncStorage\.setItem|SharedPreferences)[^;]*(token\b|[a-z]token|password|passwd|secret|jwt|session)' . 2>/dev/null \
  | print_hits "Tokens/passwords in plain local storage (use secure storage)"
grep -rnIE "${SRC[@]}" "--include=*.json" "--include=*.xml" "--include=*.plist" "${EXCL[@]}" -e 'http://[a-zA-Z0-9]' . 2>/dev/null \
  | grep -vE 'xmlns|www\.w3\.org|schemas\.(android|microsoft|openxmlformats)|localhost|127\.0\.0\.1|10\.0\.2\.2|0\.0\.0\.0' \
  | print_hits "Cleartext http:// URLs"
lead "Android/iOS hardening flags" 'usesCleartextTraffic="true"|android:debuggable="true"|NSAllowsArbitraryLoads' "--include=*.xml" "--include=*.plist"
lead "Release build possibly signed with the debug key (check it's under buildTypes.release)" 'signingConfigs\.(debug|getByName\("debug"\))' "--include=*.gradle" "--include=*.kts"
lead "Weak randomness for secrets/IDs/codes" \
  '(Math\.random\(\)|Random\(\)\.next(Int|Double)).{0,60}([Tt]oken|[Oo]tp|[Cc]ode|[Pp]assword|[Ss]ecret|[Ii]d\b)|([Tt]oken|[Oo]tp|[Cc]ode|[Pp]in|[Pp]assword|[Ss]ecret)[A-Za-z]*[[:space:]]*=.{0,60}(Math\.random\(\)|Random\(\)\.next)' "${SRC[@]}"

# ---------------------------------------------------------------------------
dockerfiles=$(find . \( -name node_modules -o -name .git -o -name vendor \) -prune -o -type f \( -name Dockerfile -o -name '*.Dockerfile' -o -name 'Dockerfile.*' \) -print 2>/dev/null)
if [ -n "$dockerfiles" ] || [ -d .github/workflows ] || ls ./*.tf >/dev/null 2>&1 || find . -name '*.tf' -not -path '*/.terraform/*' 2>/dev/null | grep -q .; then
hdr "Containers, CI and infrastructure"
printf '%s\n' "$dockerfiles" | while IFS= read -r f; do
  [ -n "$f" ] || continue
  grep -qE '^[[:space:]]*USER[[:space:]]' "$f" || note "container runs as root (no USER line): ${f#./}"
  grep -nE '^[[:space:]]*(ENV|ARG)[[:space:]]+[A-Za-z0-9_]*(SECRET|TOKEN|PASSWORD|PASSWD|API_KEY|PRIVATE)[A-Za-z0-9_]*[[:space:]]*=' "$f" \
    | mask | sed "s|^|    ${f#./}:|" | head -n "$MAX"
  awk 'toupper($1) == "FROM" {
         img = $2; if (img ~ /^--platform/) img = $3
         for (i = 2; i < NF; i++) if (toupper($i) == "AS") stage[$(i + 1)] = 1
         if (!(img in stage) && img != "scratch" && img !~ /\$/ && (img ~ /:latest$/ || img !~ /[:@]/)) bad = 1
       } END { exit !bad }' "$f" && note "unpinned base image (latest or no tag): ${f#./}"
done
if [ -n "$dockerfiles" ] && [ ! -f .dockerignore ]; then note "no .dockerignore: COPY . . can ship .env and .git into the image"; fi
lead "CI running untrusted PR code with secrets (pull_request_target / workflow_run)" 'pull_request_target|workflow_run:' "--include=*.yml" "--include=*.yaml"
lead "CI interpolating event text into shell steps (command injection)" '\$\{\{[[:space:]]*github\.event\.(issue|pull_request|comment|review|head_commit|discussion)\.[a-z_.]*(title|body|name|message|ref|label)' "--include=*.yml" "--include=*.yaml"
lead "Third-party actions not pinned to a commit SHA" 'uses:[[:space:]]*[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@(v?[0-9]+(\.[0-9]+)*|main|master|latest)[[:space:]]*$' "--include=*.yml" "--include=*.yaml"
lead "Infrastructure open to the internet or with wildcard permissions" '0\.0\.0\.0/0|"public-read(-write)?"|acl[[:space:]]*=[[:space:]]*"public|"Action"[[:space:]]*:[[:space:]]*"\*"|publicly_accessible[[:space:]]*=[[:space:]]*true' "--include=*.tf" "--include=*.json" "--include=*.yaml" "--include=*.yml"
fi

# ---------------------------------------------------------------------------
hdr "Correctness and data smells (AI-code tells)"
lead "Swallowed errors" 'catch[[:space:]]*(\([^)]*\))?[[:space:]]*\{[[:space:]]*\}|except[^:]*:[[:space:]]*pass\b|\.catch\(\(\)[[:space:]]*=>[[:space:]]*\{?[[:space:]]*\}?\)|_[[:space:]]*=[[:space:]]*err\b|rescue[[:space:]]*=>[[:space:]]*[a-z_]+[[:space:]]*$|rescue[[:space:]]+nil' "${SRC[@]}"
lead "Money in floating point" \
  '\b(double|float|parseFloat)\b[^;]{0,40}([Pp]rice|[Aa]mount|[Tt]otal|[Cc]ost|[Bb]alance|[Ss]ubtotal)|([Pp]rice|[Aa]mount|[Tt]otal|[Cc]ost|[Bb]alance)[A-Za-z]*[[:space:]]+(REAL|FLOAT|DOUBLE)\b|([Pp]rice|[Aa]mount|[Tt]otal|[Cc]ost|[Bb]alance|[Ss]ubtotal)\)?\.toFixed\(' "${SRC[@]}"
lead "Read-modify-write on stock/balances (race: use a transaction or atomic increment)" \
  '([Ss]tock|[Bb]alance|[Qq]uantity|[Ii]nventory)["'"'"']?[[:space:]]*:[[:space:]]*[A-Za-z_.]+[[:space:]]*[-+][[:space:]]*[A-Za-z0-9_]' "${SRC[@]}"
lead "Async writes fired inside forEach (not awaited)" '\.forEach\([[:space:]]*async|\.forEach\(.*\.ref\.(update|set|delete)\(' "${SRC[@]}"
lead "DB writes without await (a bug for SQL/HTTP; intended for Firestore offline queues, so check which)" \
  '^[[:space:]]*(db|_db|firestore|FirebaseFirestore\.instance|supabase|prisma)[A-Za-z_.()'"'"'"]*\.(update|set|add|delete|insert|upsert)\(' "${SRC[@]}"
lead "Unbounded reads (no where/limit/pagination)" \
  'collection\([^)]*\)\.get\(\)|\.from\(["'"'"'][a-z_]+["'"'"']\)\.select\(["'"'"']\*["'"'"']\)[[:space:]]*;?$|findMany\(\)|SELECT \* FROM [a-z_]+["'"'"']' "${SRC[@]}"
grep -rlIE "--include=*.dart" "${EXCL[@]}" -e 'openDatabase\(' . 2>/dev/null | while IFS= read -r f; do
  grep -qE 'version:[[:space:]]*([2-9]|[1-9][0-9]+)\b' "$f" && ! grep -q 'onUpgrade' "$f" \
    && note "sqflite DB is past version 1 with no onUpgrade (existing installs never migrate): ${f#./}"
done
if grep -rqIE "--include=pubspec.yaml" -e '^[[:space:]]*sqflite:' . 2>/dev/null && [ -d windows ] \
   && ! grep -rqIE "--include=*.dart" "${EXCL[@]}" -e 'sqfliteFfiInit|databaseFactoryFfi' . 2>/dev/null; then
  note "sqflite used in an app with a windows/ target but no sqflite_common_ffi init: the Windows build throws on the first DB call"
fi
lead "FutureBuilder/StreamBuilder future created in build (refetches on every rebuild)" \
  '(future|stream):[[:space:]]*[A-Za-z_][A-Za-z_.]*(\([^)]*\))?\.[A-Za-z_.]*\(' "--include=*.dart"
lead "Device-local time stored as text" 'DateTime\.now\(\)\.toString\(\)|new Date\(\)\.toString\(\)|toLocaleString\(\)|toLocaleDateString\(\)' "${SRC[@]}"
lead "Unfinished or placeholder code" 'TODO|FIXME|HACK|[Nn]ot implemented|[Ll]orem ipsum|mock(Data|Users|Products)' "${SRC[@]}"
lead "Type/lint suppressions" '@ts-ignore|@ts-nocheck|eslint-disable|// ignore:|ignore_for_file|# type: ignore|noqa|//nolint|#\[allow\(|@SuppressWarnings|#pragma warning disable|rubocop:disable|phpstan-ignore' "${SRC[@]}"
lead "Loose any types" '\bas any\b|:[[:space:]]*any\b' "--include=*.ts" "--include=*.tsx"
lead "Focused, skipped or empty tests" '\b(it|test|describe)\.(only|skip)\(|\bx(it|describe)\(|skip:[[:space:]]*true|expect\([[:space:]]*true|assert(True)?\([[:space:]]*[Tt]rue' "${SRC[@]}"

# ---------------------------------------------------------------------------
hdr "UX, accessibility and RTL leads"
lead "LTR or physical left/right (correct around phone numbers, barcodes and amounts; a finding on layouts or the app root)" \
  'TextDirection\.ltr|EdgeInsets\.(only\([^)]*(left|right):|fromLTRB)|Alignment\.(center|top|bottom)(Left|Right)|Positioned\([^)]*(left|right):|TextAlign\.(left|right)|(margin|padding)(Left|Right)[[:space:]]*:' "--include=*.dart" "--include=*.tsx" "--include=*.jsx" "--include=*.js" "--include=*.ts"
lead "Kurdish locale with only the stock Flutter delegates (no built-in ckb: needs fallback delegates or the app renders LTR)" "Locale\([[:space:]]*['\"]ckb['\"]" "--include=*.dart"
lead "CSS physical properties (prefer margin-inline-start etc. for RTL)" '(margin|padding)-(left|right)[[:space:]]*:|text-align:[[:space:]]*(left|right)' "--include=*.css" "--include=*.scss" "--include=*.html"
grep -rnIE "--include=*.jsx" "--include=*.tsx" "--include=*.html" "--include=*.vue" "${EXCL[@]}" -e '<img\b' . 2>/dev/null \
  | grep -v 'alt=' | print_hits "<img> without alt"
lead "Click handlers on non-interactive elements (not keyboard reachable)" '<(div|span|li|img)[^>]*onClick' "--include=*.jsx" "--include=*.tsx" "--include=*.html" "--include=*.vue"
lead "Focus outline removed / zoom disabled" 'outline:[[:space:]]*(none|0)|user-scalable=no|maximum-scale=1' "--include=*.css" "--include=*.scss" "--include=*.html" "--include=*.tsx" "--include=*.jsx"
lead "Hardcoded UI strings in Flutter (i18n)" "Text\([[:space:]]*(const[[:space:]]+)?['\"][A-Za-z]" "--include=*.dart"

# ---------------------------------------------------------------------------
hdr "Tooling and production readiness (missing = ask or flag)"
find . \( -name node_modules -o -name .git \) -prune -o -name package.json -print 2>/dev/null | sort | while IFS= read -r p; do
  d=$(dirname "$p")
  n=$(ls "$d"/package-lock.json "$d"/yarn.lock "$d"/pnpm-lock.yaml "$d"/bun.lock "$d"/bun.lockb 2>/dev/null | wc -l)
  [ "$n" -gt 1 ] && note "$n lockfiles next to ${p#./} (installs depend on which tool runs)"
  [ "$n" -eq 0 ] && note "no lockfile next to ${p#./}"
done | awk -v max="$MAX" '/lockfiles next to/ {print; next} {buf[++n]=$0}
  END {for (i = 1; i <= n && i <= max; i++) print buf[i]; if (n > max) printf "    ... %d more package.json files without a lockfile\n", n - max}'
find . \( -name .git -o -name .dart_tool \) -prune -o -name pubspec.yaml -print 2>/dev/null | while IFS= read -r p; do
  [ -f "$(dirname "$p")/pubspec.lock" ] || note "no pubspec.lock next to ${p#./} (apps should commit it)"
done
for pair in "pyproject.toml:uv.lock poetry.lock pdm.lock requirements.txt Pipfile.lock" "go.mod:go.sum" \
  "Gemfile:Gemfile.lock" "composer.json:composer.lock"; do
  manifest="${pair%%:*}"; locks="${pair#*:}"
  [ -f "$manifest" ] || continue
  found=0; for l in $locks; do [ -f "$l" ] && found=1; done
  [ "$found" = 1 ] || note "no lockfile next to $manifest"
done
[ -f Cargo.toml ] && grep -qE '^\[\[bin\]\]|^\[package\]' Cargo.toml && [ ! -f Cargo.lock ] && [ -f src/main.rs ] \
  && note "no Cargo.lock for a binary crate (apps should commit it)"
if [ -f package.json ]; then
  grep -qsE '^[[:space:]]*min-release-age[[:space:]]*=' .npmrc || grep -qsE 'minimumReleaseAge' pnpm-workspace.yaml .npmrc bunfig.toml \
    || grep -qsE 'npmMinimalAgeGate' .yarnrc.yml || note "no dependency release cooldown for JS packages (references/build/security.md §12)"
fi
if [ -f pyproject.toml ] || [ -f requirements.txt ]; then
  grep -qsE 'exclude-newer|min-release-age|uploaded-prior-to' pyproject.toml uv.toml poetry.toml pip.conf \
    || note "no dependency release cooldown for Python packages (references/build/security.md §12)"
fi
for f in .github/dependabot.yml .github/dependabot.yaml; do
  [ -f "$f" ] && ! grep -q 'cooldown' "$f" && note "Dependabot without a cooldown: $f"
done
for f in renovate.json renovate.json5 .github/renovate.json .renovaterc .renovaterc.json; do
  [ -f "$f" ] && ! grep -q 'minimumReleaseAge' "$f" && note "Renovate without minimumReleaseAge: $f"
done
has() { grep -rqIE "${EXCL[@]}" "$@" . 2>/dev/null; }
any .github/workflows/*.y*ml .gitlab-ci.yml bitbucket-pipelines.yml codemagic.yaml || note "no CI config found"
any .eslintrc* eslint.config.* biome.json* analysis_options.yaml ruff.toml .ruff.toml .flake8 */analysis_options.yaml \
  .golangci.y*ml phpstan.neon* .rubocop.yml .editorconfig detekt.yml .swiftlint.yml .clang-tidy \
  || grep -qsE '^\[tool\.(ruff|mypy|pyright)' pyproject.toml || note "no lint config found"
any .env.example .env.sample .env.template */.env.example || note "no .env.example documenting required variables"
any README* || note "no README"
tests=$(find . \( -name node_modules -o -name .git -o -name vendor \) -prune -o -type f \( -name '*_test.dart' -o -name '*.test.*' -o -name '*.spec.*' \
  -o -name 'test_*.py' -o -name '*_test.py' -o -name '*_test.go' -o -name '*Test.java' -o -name '*Test.kt' -o -name '*Tests.cs' \
  -o -name '*Test.cs' -o -name '*_spec.rb' -o -name '*_test.rb' -o -name '*Test.php' \) -print 2>/dev/null | wc -l)
note "test files found: $tests"
has -e 'sentry|crashlytics|bugsnag|rollbar|datadog|highlight\.run|posthog' || note "no crash/error reporting SDK found"
has -e '[Rr]ate.?[Ll]imit|express-rate-limit|@upstash/ratelimit|[Tt]hrottle|App ?Check' || note "no rate limiting or App Check found"
has -e 'helmet|Content-Security-Policy|Strict-Transport-Security|X-Frame-Options|frame-ancestors' || note "no security headers config found (web)"
echo
echo "Next: run the project's checks with the precautions in SKILL.md, then confirm each lead."
