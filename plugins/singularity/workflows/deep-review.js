export const meta = {
  name: 'deep-review',
  description: 'Multi-lens review of the current change on the strongest reviewer model, with every finding independently challenged before it is reported',
  whenToUse: 'Reviewing a branch, or the review stage of /singularity:feature',
  phases: [
    { title: 'Setup', detail: 'read the project review config' },
    { title: 'Review', detail: 'one reviewer per lens and per project reviewer agent' },
    { title: 'Challenge', detail: 'each finding independently confirmed or disproved' },
  ],
}

// args (all optional): { base, spec, lenses: [{name, description}], extraReviewers: [agentName], reviewer: {agent, model, effort} }
const A = args || {}

const FINDINGS = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['severity', 'location', 'problem', 'evidence', 'fix'],
        properties: {
          severity: { type: 'string', enum: ['blocking', 'should-fix', 'nit'] },
          location: { type: 'string' },
          problem: { type: 'string' },
          evidence: { type: 'string' },
          fix: { type: 'string' },
        },
      },
    },
  },
}

const VERDICT = {
  type: 'object',
  required: ['confirmed', 'severity', 'reason'],
  properties: {
    confirmed: { type: 'boolean' },
    severity: { type: 'string', enum: ['blocking', 'should-fix', 'nit'] },
    reason: { type: 'string' },
  },
}

const CONFIG = {
  type: 'object',
  required: ['lenses', 'extraReviewers'],
  properties: {
    lenses: {
      type: 'array',
      items: {
        type: 'object',
        required: ['name', 'description'],
        properties: { name: { type: 'string' }, description: { type: 'string' } },
      },
    },
    extraReviewers: { type: 'array', items: { type: 'string' } },
    reviewer: {
      type: 'object',
      properties: { agent: { type: 'string' }, model: { type: 'string' }, effort: { type: 'string' } },
    },
  },
}

let cfg = A
if (!A.lenses) {
  cfg = await agent(
    `Read .claude/singularity.md in the project root and return its review configuration:
- lenses: review.lenses (default: correctness, security, maintainability, testability) followed by review.extra_lenses. Give each a one-line description; for the four defaults use "logic, edge cases, error handling, test quality" / "injection, authz, secrets, unsafe input, sensitive data" / "consistency with existing patterns, naming, duplication, complexity" / "hardcoded values, non-injectable dependencies, non-deterministic or broad-assertion tests, obsolete tests left behind, missing boundary and failure-mode tests, untested contract changes".
- extraReviewers: review.extra_reviewers (agent names), or [].
- reviewer: roles.review with only the fields that are set (agent, model, effort), or omit it.
If the file is missing, return the four default lenses and an empty extraReviewers.`,
    { label: 'read review config', phase: 'Setup', schema: CONFIG, model: 'haiku', effort: 'low' },
  )
  cfg = { ...A, ...(cfg || {}) }
}

const binding = cfg.reviewer || {}
const reviewerOpts = extra => {
  const o = { agentType: binding.agent || 'singularity:reviewer', ...extra }
  if (binding.model) o.model = binding.model
  if (binding.effort) o.effort = binding.effort
  return o
}

const base = A.base || 'the merge-base of HEAD with the default branch named in the project config'
const specNote = A.spec ? `The spec is at ${A.spec}.` : 'If a spec for this branch exists under the work_dir from the project config, check the change against it.'

const tasks = [
  ...(cfg.lenses || []).map(l => ({ kind: 'lens', name: l.name, description: l.description })),
  ...(cfg.extraReviewers || []).map(name => ({ kind: 'agent', name })),
]

const failed = []
const reviewStage = t =>
  (t.kind === 'lens'
    ? agent(
        `Task A: review through the "${t.name}" lens (${t.description}). Base: ${base}. ${specNote}`,
        reviewerOpts({ label: `review:${t.name}`, phase: 'Review', schema: FINDINGS }),
      )
    : agent(
        `Review the current change (base: ${base}) according to your instructions. ${specNote} Report only findings you can support with evidence.`,
        { agentType: t.name, label: `review:${t.name}`, phase: 'Review', schema: FINDINGS },
      )
  ).then(r => {
    if (!r) failed.push(t.name)
    return r
  })

const challengeStage = (review, t) =>
  parallel(
    ((review && review.findings) || []).map(f => () =>
      agent(
        `Task B: challenge this finding from the "${t.name}" reviewer. Base: ${base}.
Location: ${f.location}
Severity claimed: ${f.severity}
Problem: ${f.problem}
Evidence: ${f.evidence}
Proposed fix: ${f.fix}`,
        reviewerOpts({ label: `challenge:${f.location}`, phase: 'Challenge', schema: VERDICT }),
      ).then(v => ({ ...f, source: t.name, verdict: v })),
    ),
  )

const results = await pipeline(tasks, reviewStage, challengeStage)
const all = results.filter(Boolean).flat().filter(Boolean)

const order = { blocking: 0, 'should-fix': 1, nit: 2 }
const confirmed = all
  .filter(f => f.verdict && f.verdict.confirmed)
  .map(f => ({ ...f, severity: f.verdict.severity }))
  .sort((a, b) => order[a.severity] - order[b.severity])
const rejected = all.filter(f => f.verdict && !f.verdict.confirmed)
const unverified = all.filter(f => !f.verdict)

if (failed.length) log(`Reviewers that failed (re-run before trusting this review): ${failed.join(', ')}`)
log(`${confirmed.length} confirmed (${confirmed.filter(f => f.severity === 'blocking').length} blocking), ${rejected.length} rejected, ${unverified.length} unverified`)
return { reviewed: tasks.map(t => t.name).filter(n => !failed.includes(n)), failed, confirmed, rejected, unverified }
