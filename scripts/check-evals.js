#!/usr/bin/env node
// Validates the plugin eval suite structurally, without running any model calls.
// Checks what `claude plugin eval` would reject at load time plus the mistakes we've made before.
const fs = require('fs'), path = require('path');
const root = path.join(__dirname, '..', 'plugins', 'singularity', 'evals');
const PROMPT_KEYS = new Set(['schema_version','name','description','tags','plugins','runs','expected_outcome','model','max_turns','timeout_seconds','allowed_tools','append_system_prompt','env']);
const GRADER_TYPES = new Set(['regex','tool_used','tool_order','file_exists','llm','baseline']);
const GATED_TOOLS = ['Bash','Write','Edit','WebFetch','WebSearch'];
let errors = 0;
const err = (f, m) => { console.log(`::error file=${path.relative(process.cwd(), f)}::${m}`); errors++; };
const frontmatter = f => {
  const s = fs.readFileSync(f, 'utf8');
  const m = s.match(/^---\n([\s\S]*?)\n---/);
  if (!m) return null;
  const o = {};
  for (const line of m[1].split('\n')) { const k = line.match(/^([A-Za-z_]+):\s*(.*)$/); if (k) o[k[1]] = k[2]; }
  return o;
};
const cases = fs.readdirSync(root, { withFileTypes: true }).filter(d => d.isDirectory() && !['mocks','results'].includes(d.name));
if (!cases.length) err(root, 'no eval cases found');
for (const c of cases) {
  const dir = path.join(root, c.name);
  const prompt = path.join(dir, 'prompt.md'), caseYaml = path.join(dir, 'case.yaml');
  if (!fs.existsSync(prompt) && !fs.existsSync(caseYaml)) { err(dir, 'case needs prompt.md or case.yaml'); continue; }
  let allowed = '';
  if (fs.existsSync(prompt)) {
    const fm = frontmatter(prompt);
    if (!fm) err(prompt, 'missing frontmatter');
    else { for (const k of Object.keys(fm)) if (!PROMPT_KEYS.has(k)) err(prompt, `unknown prompt.md field "${k}"`); allowed = fm.allowed_tools || ''; }
    if (!fs.readFileSync(prompt, 'utf8').replace(/^---[\s\S]*?---/, '').trim()) err(prompt, 'empty prompt body');
  }
  if (fs.existsSync(caseYaml)) {
    const y = fs.readFileSync(caseYaml, 'utf8');
    if (!/schema_version:\s*"1\.1"/.test(y)) err(caseYaml, 'schema_version "1.1" required');
    if (!/^name:/m.test(y)) err(caseYaml, 'name required');
    const sc = y.match(/scaffold_script:\s*(\S+)/);
    if (sc) { const p = path.join(dir, sc[1]); if (!fs.existsSync(p)) err(caseYaml, `scaffold_script ${sc[1]} not found`); else if (!(fs.statSync(p).mode & 0o111)) err(p, 'scaffold script is not executable'); }
  }
  const gdir = path.join(dir, 'graders');
  const graders = fs.existsSync(gdir) ? fs.readdirSync(gdir).filter(f => f.endsWith('.md')) : [];
  if (!graders.length && !(fs.existsSync(caseYaml) && /^graders:/m.test(fs.readFileSync(caseYaml, 'utf8')))) err(dir, 'case has no graders');
  for (const g of graders) {
    const gf = path.join(gdir, g), fm = frontmatter(gf);
    if (!fm || !fm.type) { err(gf, 'grader needs a type'); continue; }
    if (!GRADER_TYPES.has(fm.type)) err(gf, `unknown grader type "${fm.type}"`);
    if (fm.type === 'llm' && !fs.readFileSync(gf, 'utf8').replace(/^---[\s\S]*?---/, '').trim()) err(gf, 'llm grader needs a rubric body');
    if (fm.type === 'tool_used' && GATED_TOOLS.includes(fm.tool) && fm.min !== '0' && !allowed.includes(fm.tool)) err(gf, `grader needs ${fm.tool} but prompt.md allowed_tools does not list it`);
    if (fm.type === 'regex' && !fm.pattern) err(gf, 'regex grader needs a pattern');
  }
}
console.log(errors ? `check-evals: ${errors} error(s)` : `check-evals: ${cases.length} case(s) ok`);
process.exit(errors ? 1 : 0);
