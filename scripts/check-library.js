#!/usr/bin/env node
// Checks the agent and skill library against its catalog (plugins/singularity/library/README.md), without model calls:
// every catalog row has its file, every library file has a row, names match, skill folders hold Markdown only,
// and every skill an agent preloads (`skills:` frontmatter) exists.
const fs = require('fs'), path = require('path');
const plugin = path.join(__dirname, '..', 'plugins', 'singularity');
const catalogFile = path.join(plugin, 'library', 'README.md');
const librarySkills = path.join(plugin, 'library', 'skills');
const agentsDir = path.join(plugin, 'agents');
// The pipeline's role agents; every other shared agent is a library agent and needs a catalog row.
const ROLE_AGENTS = new Set(['spec-writer', 'planner', 'implementer', 'reviewer', 'verifier', 'optimizer']);
let errors = 0;
const err = (f, m) => { console.log(`::error file=${path.relative(process.cwd(), f)}::${m}`); errors++; };
const frontmatter = f => {
  const m = fs.readFileSync(f, 'utf8').match(/^---\n([\s\S]*?)\n---/);
  if (!m) return null;
  const o = {};
  let list = null;
  for (const line of m[1].split('\n')) {
    const item = line.match(/^\s+-\s+(\S+)/);
    if (item && list) { o[list].push(item[1]); continue; }
    const k = line.match(/^([A-Za-z_-]+):\s*(.*)$/);
    if (!k) continue;
    list = null;
    if (k[2] === '') { o[k[1]] = []; list = k[1]; } else o[k[1]] = k[2];
  }
  return o;
};

const rows = [];
for (const line of fs.readFileSync(catalogFile, 'utf8').split('\n')) {
  const m = line.match(/^\|\s*`([a-z0-9-]+)`\s*\|\s*(agent|skill)\s*\|/);
  if (m) rows.push({ name: m[1], kind: m[2] });
}
if (!rows.length) err(catalogFile, 'no catalog rows found');
const seen = new Set();
for (const { name, kind } of rows) {
  if (seen.has(name)) err(catalogFile, `"${name}" is listed twice`);
  seen.add(name);
  const file = kind === 'agent' ? path.join(agentsDir, `${name}.md`) : path.join(librarySkills, name, 'SKILL.md');
  if (!fs.existsSync(file)) { err(catalogFile, `${kind} "${name}" has no file ${path.relative(plugin, file)}`); continue; }
  const fm = frontmatter(file);
  if (!fm || fm.name !== name) err(file, `frontmatter name must be "${name}"`);
  if (!fm || !fm.description) err(file, 'frontmatter needs a description');
  if (kind === 'agent' && ROLE_AGENTS.has(name)) err(catalogFile, `"${name}" is a role agent, not a library entry`);
}

for (const f of fs.readdirSync(agentsDir).filter(f => f.endsWith('.md'))) {
  const name = f.slice(0, -3);
  if (!ROLE_AGENTS.has(name) && !rows.some(r => r.kind === 'agent' && r.name === name)) err(path.join(agentsDir, f), `library agent "${name}" has no catalog row`);
}
if (fs.existsSync(librarySkills)) {
  for (const d of fs.readdirSync(librarySkills, { withFileTypes: true })) {
    const dir = path.join(librarySkills, d.name);
    if (!d.isDirectory()) { err(dir, 'only skill folders belong in library/skills'); continue; }
    if (!rows.some(r => r.kind === 'skill' && r.name === d.name)) err(dir, `library skill "${d.name}" has no catalog row`);
    const walk = p => fs.readdirSync(p, { withFileTypes: true }).flatMap(e => e.isDirectory() ? walk(path.join(p, e.name)) : [path.join(p, e.name)]);
    for (const f of walk(dir)) if (!f.endsWith('.md')) err(f, 'library skills hold Markdown only (no bundled scripts)');
  }
}

// Skills preloaded by shared agents must exist as registered plugin skills.
for (const f of fs.readdirSync(agentsDir).filter(f => f.endsWith('.md'))) {
  const fm = frontmatter(path.join(agentsDir, f)) || {};
  for (const s of Array.isArray(fm.skills) ? fm.skills : []) {
    const m = s.match(/^singularity:([a-z0-9-]+)$/);
    if (m && !fs.existsSync(path.join(plugin, 'skills', m[1], 'SKILL.md'))) err(path.join(agentsDir, f), `preloads missing skill "${s}"`);
  }
}

console.log(errors ? `check-library: ${errors} error(s)` : `check-library: ${rows.length} entr${rows.length === 1 ? 'y' : 'ies'} ok`);
process.exit(errors ? 1 : 0);
