// Tests for scripts/guard-commands.mjs. Run: node scripts/tests/guard.test.mjs
// Each case feeds the hook a shell command the way Claude Code does and checks the
// verdict: deny (exit 2), ask (permissionDecision "ask" on stdout) or allow (silent exit 0).
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const hook = fileURLToPath(new URL("../guard-commands.mjs", import.meta.url));

const cases = [
  // --- destructive git: deny ---
  ["git push --force", "deny"], ["git push -f origin main", "deny"], ["git push -uf origin main", "deny"],
  ["git push origin +main", "deny"], ["git push --mirror", "deny"], ["git reset --hard HEAD~1", "deny"],
  ["git clean -fdx", "deny"], ["git checkout .", "deny"], ["git checkout -- .", "deny"], ["git checkout HEAD -- .", "deny"],
  ["git switch --discard-changes main", "deny"], ["git restore .", "deny"], ["git restore -SW .", "deny"],
  ["git branch -D feat", "deny"], ["git stash drop", "deny"], ["git worktree remove --force .worktrees/x", "deny"],
  ['git commit --no-verify -m "x"', "deny"], ['git commit -n -m "x"', "deny"], ['HUSKY=0 git commit -m "x"', "deny"],
  ["git -c core.hooksPath=/dev/null commit -m x", "deny"], ["$env:HUSKY=0; git commit -m 'x'", "deny"],
  ['git commit -m "fix: handle \\"quoted\\" names" && git reset --hard', "deny"],
  // --- recursive deletes of precious folders: deny ---
  ["rm -rf ~/", "deny"], ["rm -rf ~", "deny"], ["rm -rf /", "deny"], ["rm -rf /*", "deny"], ["rm -rf $HOME", "deny"],
  ["rm -rf .git", "deny"], ["rm -rf ./.git", "deny"], ["rm -rf .", "deny"], ["rm -rf *", "deny"], ["rm -fr ..", "deny"],
  ["rm --recursive --force ~", "deny"], ["rm -r -f .git/", "deny"], ['rm -rf "$HOME"', "deny"],
  ["Remove-Item -Recurse -Force .git", "deny"], ["Remove-Item .git -Recurse -Force", "deny"], ["Remove-Item -Path ~ -Recurse", "deny"],
  ["Remove-Item -Recurse -Force C:\\", "deny"], ["remove-item -recurse $env:USERPROFILE", "deny"],
  ["echo 'rm -rf ~' > notes.txt", "deny"], // text-based guard: documents the trade-off
  // --- history, deploys, publishing (JS, Dart, Firebase, Supabase, Vercel, Netlify, Expo, GitHub): ask ---
  ["git push --force-with-lease", "ask"], ["git push origin --delete old", "ask"], ["git push origin :old", "ask"],
  ["git filter-repo --path secrets.json --invert-paths", "ask"], ["git reflog expire --expire=now --all", "ask"],
  ["git gc --prune=now --aggressive", "ask"],
  ["firebase deploy", "ask"], ["firebase deploy --only hosting", "ask"], ["npx firebase-tools deploy --only firestore:rules", "ask"],
  ["firebase hosting:clone app:preview app:live", "ask"], ["firebase firestore:delete --all-collections", "ask"],
  ["supabase db push", "ask"], ["supabase db reset --linked", "ask"], ["netlify deploy --prod", "ask"],
  ["vercel --prod", "ask"], ["vercel deploy --prod", "ask"], ["eas submit -p android", "ask"],
  ["eas build -p android --profile production --auto-submit", "ask"],
  ['eas update --branch production --message "fix"', "ask"], ["eas update --channel=production", "ask"],
  ["npm publish", "ask"], ["flutter pub publish", "ask"], ["gh pr merge 12 --admin", "ask"], ["gh repo delete me/x --yes", "ask"],
  ["gh repo edit --visibility public --accept-visibility-change-consequences", "ask"], ["gh repo edit me/x --visibility=public", "ask"],
  ["npx prisma migrate reset --force", "ask"], ["npx prisma db push --accept-data-loss", "ask"], ["npx prisma db push --force-reset", "ask"],
  ["npx drizzle-kit push --force", "ask"],
  // --- publishing in other ecosystems: ask ---
  ["cargo publish", "ask"], ["twine upload dist/*", "ask"], ["uv publish", "ask"], ["poetry publish --build", "ask"],
  ["gem push mylib-1.0.gem", "ask"], ["dotnet nuget push pkg.nupkg --source nuget.org", "ask"], ["mvn deploy", "ask"],
  ["./gradlew publish", "ask"], ["bun publish", "ask"], ["npx jsr publish", "ask"], ["vsce publish", "ask"],
  ["docker push org/app:1.0", "ask"], ["docker buildx build --push -t org/app .", "ask"],
  // --- infrastructure and hosting: ask ---
  ["terraform apply", "ask"], ["terraform destroy -auto-approve", "ask"], ["tofu apply", "ask"], ["pulumi up --yes", "ask"],
  ["fly deploy", "ask"], ["flyctl apps destroy shop-api", "ask"], ["railway up", "ask"], ["wrangler deploy", "ask"],
  ["gcloud run deploy api --source .", "ask"], ["gcloud app deploy", "ask"], ["az webapp deploy --src-path app.zip", "ask"],
  ["azd up", "ask"], ["aws s3 rm s3://bucket --recursive", "ask"], ["aws cloudformation deploy --template-file t.yml", "ask"],
  ["aws ec2 terminate-instances --instance-ids i-1", "ask"], ["sam deploy", "ask"], ["cdk deploy", "ask"],
  ["serverless deploy", "ask"], ["kubectl apply -f k8s/", "ask"], ["kubectl delete pod web-1", "ask"],
  ["helm upgrade --install app ./chart", "ask"], ["git push heroku main", "ask"], ["heroku pg:reset DATABASE", "ask"],
  // --- databases: ask ---
  ["rails db:drop", "ask"], ["bin/rails db:reset", "ask"], ["php artisan migrate:fresh --seed", "ask"],
  ["python manage.py flush --no-input", "ask"], ["dotnet ef database drop -f", "ask"], ["alembic downgrade base", "ask"],
  ["dropdb shop", "ask"], ['psql -c "DROP TABLE sales"', "ask"], ['mongosh --eval "db.dropDatabase()"', "ask"],
  ["redis-cli FLUSHALL", "ask"],
  // --- secrets printed into the session: ask ---
  ["cat .env", "ask"], ["cat .env.local", "ask"], ["cat apps/api/.env.production", "ask"], ["type .env", "ask"],
  ["Get-Content .env", "ask"], ["head -n 5 .env", "ask"], ["grep API_KEY .env", "ask"], ["cat .envrc", "ask"],
  ["Select-String -Path .env -Pattern KEY", "ask"], ["cat server.key", "ask"], ["cat certs/private.pem", "ask"],
  ["base64 -i upload-keystore.jks", "ask"], ["cat android/key.properties", "ask"], ["cat ~/.ssh/id_ed25519", "ask"],
  ["cat shop-firebase-adminsdk-ab12c.json", "ask"], ["cat service-account.json", "ask"], ["cat ~/.npmrc", "ask"],
  ["jq . credentials.json", "ask"], ["cat .env | grep STRIPE", "ask"],
  ["gh auth token", "ask"], ["heroku config", "ask"], ["heroku config:get DATABASE_URL", "ask"], ["vercel env pull", "ask"],
  ["netlify env:list", "ask"], ["firebase functions:config:get", "ask"],
  ["aws secretsmanager get-secret-value --secret-id prod/db", "ask"], ["gcloud secrets versions access latest --secret=api", "ask"],
  ["az keyvault secret show --name db --vault-name v", "ask"], ["kubectl get secret db -o yaml", "ask"],
  ["op read op://vault/item/field", "ask"], ["doppler secrets download", "ask"],
  ["env", "ask"], ["printenv", "ask"], ["env | sort", "ask"], ["Get-ChildItem env:", "ask"], ["gci env:", "ask"],
  ["echo $OPENAI_API_KEY", "ask"], ['echo "token: $GH_TOKEN"', "ask"], ["Write-Host $env:STRIPE_SECRET_KEY", "ask"],

  // --- must stay allowed (false-positive checks) ---
  ["git push", "allow"], ["git push -u origin feat/x", "allow"], ["git push --follow-tags", "allow"], ["git push origin fix-flags", "allow"],
  ['git commit -m "docs: never run git reset --hard or --no-verify"', "allow"], ["git commit --amend --no-edit", "allow"],
  ['git commit -m "docs: never cat .env or run terraform apply"', "allow"],
  ["git restore --staged .", "allow"], ["git restore -S .", "allow"], ["git clean -n", "allow"], ["git branch -d merged", "allow"],
  ["git stash pop", "allow"], ["git checkout -b feat/x", "allow"], ["git checkout ./src/a.ts", "allow"],
  ["git config core.hooksPath .githooks", "allow"], ["git gc", "allow"], ["git reflog", "allow"],
  ["firebase hosting:channel:deploy pr-12 --expires 3d", "allow"], ["supabase db reset", "allow"], ["npm publish --dry-run", "allow"],
  ["vercel", "allow"], ["git log --oneline -n 5 && git status", "allow"], ["npm run build", "allow"],
  ["git commit -m \"$(cat <<'EOF'\nfix(sync): upsert sales\n\nCo-Authored-By: x\nEOF\n)\"", "allow"],
  ["rm -rf node_modules", "allow"], ["rm -rf build dist .next", "allow"], ["rm -rf ./dist", "allow"], ["rm -rf /tmp/scan-123", "allow"],
  ["rm -rf ~/projects/old-demo", "allow"], ["rm -rf .dart_tool", "allow"], ["rm -rf .github/old", "allow"], ["rm -rf .gitignore.bak", "allow"],
  ["rm file.txt", "allow"], ["rm -f .env.local.bak", "allow"], ["rm -rf ./build/*", "allow"], ["rm -r src/old", "allow"],
  ["Remove-Item -Recurse -Force node_modules", "allow"], ["Remove-Item -Recurse -Force .\\build", "allow"], ["Remove-Item .\\tmp.txt", "allow"],
  ["gh repo edit --visibility private", "allow"], ["gh repo view", "allow"],
  ["npx prisma migrate dev", "allow"], ["npx prisma db push", "allow"], ["npx drizzle-kit push", "allow"],
  ["cargo publish --dry-run", "allow"], ["cargo build --release", "allow"], ["./gradlew publishToMavenLocal", "allow"],
  ["deno publish --dry-run", "allow"], ["docker build -t app .", "allow"], ["docker compose up -d", "allow"],
  ["terraform plan", "allow"], ["pulumi preview", "allow"], ["wrangler dev", "allow"], ["gcloud config list", "allow"],
  ["aws s3 ls", "allow"], ["cdk synth", "allow"], ["kubectl get pods", "allow"], ["kubectl get secrets", "allow"],
  ["helm template .", "allow"], ["heroku config:set FOO=1", "allow"], ["php artisan migrate", "allow"],
  ["python manage.py migrate", "allow"], ["dotnet ef database update", "allow"], ["alembic upgrade head", "allow"],
  ['psql -c "select 1"', "allow"], ['grep -rn "DROP TABLE" migrations', "allow"],
  ["cat .env.example", "allow"], ["cat .env.sample", "allow"], ["cp .env.example .env", "allow"], ['echo "X=1" >> .env', "allow"],
  ["cat ~/.ssh/id_ed25519.pub", "allow"], ["cat package.json", "allow"], ["cat google-services.json", "allow"],
  ["cat src/api.key.ts", "allow"], ["grep -rn TODO src", "allow"], ["ls -la .env", "allow"],
  ["env FOO=1 node app.js", "allow"], ["printenv HOME", "allow"], ["python -m venv env", "allow"], ["npm run env", "allow"],
  ["echo $HOME", "allow"], ["echo $PWD", "allow"], ["source env/bin/activate", "allow"], ["conda env list", "allow"],
];

function verdict(command) {
  const r = spawnSync(process.execPath, [hook], { input: JSON.stringify({ tool_input: { command } }), encoding: "utf8" });
  if (r.status === 2) return "deny";
  if (r.status !== 0) return `error(${r.status})`;
  return r.stdout.includes('"ask"') ? "ask" : "allow";
}

let failures = 0;
for (const [command, want] of cases) {
  const got = verdict(command);
  if (got !== want) {
    failures++;
    console.log(`FAIL want=${want} got=${got} ${JSON.stringify(command)}`);
  }
}

// Malformed input must fail closed; a non-shell tool call must pass.
const malformed = spawnSync(process.execPath, [hook], { input: "not json", encoding: "utf8" });
if (malformed.status !== 2) { failures++; console.log(`FAIL malformed input exited ${malformed.status}, want 2`); }
const noCommand = spawnSync(process.execPath, [hook], { input: JSON.stringify({ tool_input: { file_path: "a.ts" } }), encoding: "utf8" });
if (noCommand.status !== 0) { failures++; console.log(`FAIL non-shell input exited ${noCommand.status}, want 0`); }

console.log(`${cases.length + 2} checks, ${failures} failed`);
process.exit(failures ? 1 : 0);
