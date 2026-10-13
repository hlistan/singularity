#!/usr/bin/env node
// Plugin versioning: one version, in plugin.json; release notes in CHANGELOG.md; tags named <plugin>--v<version>.
//
//   node scripts/version.js check [--base <git-ref>]   consistency checks (CI, pre-commit); with --base, also the PR rules
//   node scripts/version.js bump <patch|minor|major|X.Y.Z> [--date YYYY-MM-DD]
//                                                      move [Unreleased] into a new release and set the version
//   node scripts/version.js notes [<version>]          print a release's changelog section (GitHub release body)
//   node scripts/version.js current | tag              print the version, or its git tag
//
// Rules and rationale: README.md, "Versions and releases".
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const PLUGIN_DIR = 'plugins/singularity';
const PLUGIN_JSON = `${PLUGIN_DIR}/.claude-plugin/plugin.json`;
const MARKETPLACE_JSON = '.claude-plugin/marketplace.json';
const CHANGELOG = 'CHANGELOG.md';
// Paths that change what projects receive. Eval cases are the plugin's own tests, so they don't need a changelog line.
const SHIPPED = f => f.startsWith(`${PLUGIN_DIR}/`) && !f.startsWith(`${PLUGIN_DIR}/evals/`);
const SEMVER = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;
const DATE = /^\d{4}-\d{2}-\d{2}$/;

let errors = 0;
const error = (file, msg) => { console.log(`::error file=${file}::${msg}`); errors++; };
const warn = (file, msg) => console.log(`::warning file=${file}::${msg}`);
const die = msg => { console.error(`version: ${msg}`); process.exit(1); };
const read = f => fs.readFileSync(path.join(ROOT, f), 'utf8');
const git = (...a) => execFileSync('git', a, { cwd: ROOT, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });

const parse = v => { const m = SEMVER.exec(v || ''); return m && m.slice(1).map(Number); };
const compare = (a, b) => { const x = parse(a), y = parse(b); for (let i = 0; i < 3; i++) if (x[i] !== y[i]) return x[i] - y[i]; return 0; };
const next = (v, level) => {
  const [ma, mi, pa] = parse(v);
  if (level === 'major') return `${ma + 1}.0.0`;
  if (level === 'minor') return `${ma}.${mi + 1}.0`;
  if (level === 'patch') return `${ma}.${mi}.${pa + 1}`;
  if (parse(level)) return level;
  die(`unknown bump "${level}": use patch, minor, major or an explicit X.Y.Z`);
};

const manifest = (src = read(PLUGIN_JSON)) => JSON.parse(src);
const tagFor = (m, v) => `${m.name}--v${v}`;
const repoUrl = m => String(m.repository || m.homepage || '').replace(/\.git$/, '').replace(/\/$/, '');

// CHANGELOG.md as sections ("## [name] - date") and link definitions ("[name]: url").
function changelog(src) {
  const lines = src.split('\n'), sections = [], links = new Map();
  lines.forEach((line, i) => {
    const h = /^## \[([^\]]+)\](?:\s+-\s+(\S+))?\s*$/.exec(line);
    if (h) { if (sections.length) sections[sections.length - 1].end = i; sections.push({ name: h[1], date: h[2], start: i, end: lines.length }); }
    const l = /^\[([^\]]+)\]:\s+(\S+)\s*$/.exec(line);
    if (l) { links.set(l[1], { url: l[2], line: i }); if (sections.length && sections[sections.length - 1].end === lines.length) sections[sections.length - 1].end = i; }
  });
  for (const s of sections) s.body = lines.slice(s.start + 1, s.end).filter(l => !/^\[[^\]]+\]:\s/.test(l)).join('\n').trim();
  return { lines, sections, links, find: n => sections.find(s => s.name === n) };
}

function check(base) {
  let m;
  try { m = manifest(); } catch (e) { error(PLUGIN_JSON, `not valid JSON: ${e.message}`); return; }
  const v = m.version;
  if (!v) error(PLUGIN_JSON, 'no "version": set it here (and only here)');
  else if (!parse(v)) error(PLUGIN_JSON, `version "${v}" is not MAJOR.MINOR.PATCH (no "v" prefix, no pre-release suffix)`);

  const entry = (JSON.parse(read(MARKETPLACE_JSON)).plugins || []).find(p => p.name === m.name);
  if (!entry) error(MARKETPLACE_JSON, `no entry for plugin "${m.name}"`);
  else if ('version' in entry) error(MARKETPLACE_JSON, `remove "version" from the "${m.name}" entry: plugin.json is the only place the version lives, and it wins anyway`);

  const cl = changelog(read(CHANGELOG));
  const [first, second] = cl.sections;
  if (!first || first.name !== 'Unreleased') error(CHANGELOG, 'the first section must be "## [Unreleased]"');
  const released = cl.sections.filter(s => s.name !== 'Unreleased');
  for (const s of released) {
    if (!parse(s.name)) error(CHANGELOG, `section "${s.name}" is not a MAJOR.MINOR.PATCH version`);
    if (!DATE.test(s.date || '')) error(CHANGELOG, `section "${s.name}" needs a date: "## [${s.name}] - YYYY-MM-DD"`);
    if (!s.body) error(CHANGELOG, `section "${s.name}" is empty`);
    if (!cl.links.has(s.name)) error(CHANGELOG, `no link definition for "[${s.name}]"`);
  }
  for (let i = 1; i < released.length; i++)
    if (parse(released[i - 1].name) && parse(released[i].name) && compare(released[i - 1].name, released[i].name) <= 0)
      error(CHANGELOG, `releases must be newest first and unique: "${released[i - 1].name}" comes before "${released[i].name}"`);
  if (v && parse(v)) {
    if (!second || second.name !== v) error(CHANGELOG, `plugin.json says ${v}, but the newest release in the changelog is "${second ? second.name : 'none'}": run "node scripts/version.js bump" instead of editing the version by hand`);
    const u = cl.links.get('Unreleased');
    if (!u || !u.url.endsWith(`${tagFor(m, v)}...HEAD`)) error(CHANGELOG, `"[Unreleased]:" should compare ${tagFor(m, v)}...HEAD`);
  }
  if (base) checkAgainst(base, m, cl);
}

// PR rules: the version never goes backwards, and a change to what projects receive carries a changelog line.
function checkAgainst(base, m, cl) {
  let mergeBase;
  try { mergeBase = git('merge-base', base, 'HEAD').trim(); } catch (e) { die(`can't find a merge base with "${base}" (fetch it, or use fetch-depth: 0): ${e.stderr || e.message}`); }
  const changed = git('diff', '--name-only', `${mergeBase}...HEAD`).split('\n').filter(Boolean);
  let before;
  try { before = manifest(git('show', `${mergeBase}:${PLUGIN_JSON}`)).version; } catch { before = undefined; }
  const now = m.version;
  if (!parse(now)) return;
  const bumped = before !== now;
  if (bumped && parse(before) && compare(now, before) <= 0) error(PLUGIN_JSON, `version went from ${before} to ${now}: it may only increase`);
  const shipped = changed.filter(SHIPPED);
  if (!shipped.length) return;
  if (bumped) {
    if (cl.find('Unreleased') && cl.find('Unreleased').body) warn(CHANGELOG, `entries are still under [Unreleased]; they won't be in the ${now} release notes`);
    return;
  }
  let beforeUnreleased = '';
  try { const old = changelog(git('show', `${mergeBase}:${CHANGELOG}`)).find('Unreleased'); beforeUnreleased = old ? old.body : ''; } catch { /* no changelog at base */ }
  const nowUnreleased = cl.find('Unreleased') ? cl.find('Unreleased').body : '';
  if (nowUnreleased === beforeUnreleased)
    error(CHANGELOG, `this change touches the plugin (${shipped.slice(0, 3).join(', ')}${shipped.length > 3 ? ', …' : ''}) but adds nothing under "## [Unreleased]". Add a line saying what changes for projects`);
}

function bump(level, date) {
  if (!level) die('usage: node scripts/version.js bump <patch|minor|major|X.Y.Z> [--date YYYY-MM-DD]');
  const m = manifest(), cur = m.version;
  if (!parse(cur)) die(`plugin.json version "${cur}" is not MAJOR.MINOR.PATCH`);
  const nv = next(cur, level);
  if (compare(nv, cur) <= 0) die(`${nv} is not newer than ${cur}`);
  date = date || new Date().toISOString().slice(0, 10);
  if (!DATE.test(date)) die(`--date must be YYYY-MM-DD, got "${date}"`);
  const cl = changelog(read(CHANGELOG)), u = cl.find('Unreleased');
  if (!u) die('CHANGELOG.md has no "## [Unreleased]" section');
  if (!u.body) die('nothing under "## [Unreleased]" to release: add the changes there first');
  const repo = repoUrl(m);
  if (!repo) die('plugin.json has no "repository" URL to build changelog links from');

  const out = cl.lines.slice(0, u.start).concat(['## [Unreleased]', '', `## [${nv}] - ${date}`, '', ...u.body.split('\n'), ''], cl.lines.slice(u.end));
  const links = out.map((l, i) => ({ l, i })).filter(x => /^\[[^\]]+\]:\s/.test(x.l));
  const uLink = links.find(x => x.l.startsWith('[Unreleased]:'));
  const unreleasedLine = `[Unreleased]: ${repo}/compare/${tagFor(m, nv)}...HEAD`;
  const releaseLine = `[${nv}]: ${repo}/compare/${tagFor(m, cur)}...${tagFor(m, nv)}`;
  if (uLink) out.splice(uLink.i, 1, unreleasedLine, releaseLine);
  else { while (out.length && out[out.length - 1] === '') out.pop(); out.push('', unreleasedLine, releaseLine, ''); }

  m.version = nv;
  fs.writeFileSync(path.join(ROOT, PLUGIN_JSON), JSON.stringify(m, null, 2) + '\n');
  fs.writeFileSync(path.join(ROOT, CHANGELOG), out.join('\n'));
  console.log(`${m.name} ${cur} → ${nv}

Next:
  1. Review CHANGELOG.md (mark breaking changes with **Breaking:**).
  2. Commit on a branch: git commit -am "chore(release): ${m.name} ${nv}", and open a PR.
  3. Merging it tags ${tagFor(m, nv)} and publishes the GitHub release (.github/workflows/release.yml).`);
}

function notes(version) {
  const m = manifest(), v = version || m.version, cl = changelog(read(CHANGELOG)), s = cl.find(v);
  if (!s || !s.body) die(`no changelog section for ${v}`);
  const link = cl.links.get(v);
  process.stdout.write(`${s.body}\n${link && link.url.includes('/compare/') ? `\n**Full changelog:** ${link.url}\n` : ''}`);
}

const [cmd, ...rest] = process.argv.slice(2);
const opt = name => { const i = rest.indexOf(name); return i >= 0 ? rest.splice(i, 2)[1] : undefined; };
switch (cmd) {
  case 'check': {
    const base = opt('--base');
    check(base);
    console.log(errors ? `version: ${errors} error(s)` : `version: ${manifest().version} ok${base ? ` (against ${base})` : ''}`);
    process.exit(errors ? 1 : 0);
    break;
  }
  case 'bump': { const date = opt('--date'); bump(rest[0], date); break; }
  case 'notes': notes(rest[0]); break;
  case 'current': console.log(manifest().version); break;
  case 'tag': { const m = manifest(); console.log(tagFor(m, m.version)); break; }
  default: die('usage: node scripts/version.js <check [--base ref] | bump <level> [--date d] | notes [version] | current | tag>');
}
