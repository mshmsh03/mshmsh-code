// Checks the skill before it reaches anyone: SKILL.md's front matter, and that
// every script, reference and eval path SKILL.md and README.md name in `code`
// exists. Run from the repo root: node .github/check-skill.mjs

import { existsSync, readFileSync } from "node:fs";

const problems = [];
const read = (path) => readFileSync(path, "utf8").replace(/\r\n/g, "\n");

// A front-matter value, with YAML double or single quotes undone.
const value = (front, key) => {
  const raw = front.match(new RegExp(`^${key}:\\s*(.+)$`, "m"))?.[1]?.trim();
  if (!raw) return undefined;
  if (raw.startsWith('"')) return JSON.parse(raw);
  if (raw.startsWith("'")) return raw.slice(1, -1).replace(/''/g, "'");
  return raw;
};

const front = read("SKILL.md").match(/^---\n([\s\S]*?)\n---\n/)?.[1];
if (!front) problems.push("SKILL.md: no front matter");
else {
  const name = value(front, "name");
  const description = value(front, "description");
  if (name !== "mshmsh-code") problems.push(`SKILL.md: name is "${name}", expected "mshmsh-code"`);
  if (!description) problems.push("SKILL.md: no description");
  else {
    if (description.length > 1024) problems.push(`SKILL.md: the description is ${description.length} characters (the limit is 1024)`);
    if (/[<>]/.test(description)) problems.push("SKILL.md: the description has < or >, which skill loaders reject");
  }
}

// Only SKILL.md and README.md: the reference files name paths in the project
// being built or audited, not in this repo.
for (const doc of ["SKILL.md", "README.md"]) {
  for (const [, span] of read(doc).matchAll(/`([^`\n]+)`/g)) {
    for (const [, path] of span.matchAll(/(?:^|[\s(])((?:scripts|references|evals)\/[\w./-]*)/g)) {
      const clean = path.replace(/[.,:;]+$/, "");
      if (!existsSync(clean)) problems.push(`${doc}: names ${clean}, which doesn't exist`);
    }
  }
}

if (problems.length) {
  for (const problem of new Set(problems)) console.log(`::error::${problem}`);
  process.exit(1);
}
console.log("SKILL.md is valid and every file SKILL.md and README.md name exists.");
