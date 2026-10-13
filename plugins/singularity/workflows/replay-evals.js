export const meta = {
  name: 'replay-evals',
  description: 'Replay the project eval cases (real escaped defects and known false positives) through the reviewer, for one or more config variants, and score recall and precision',
  whenToUse: 'Validating review-related changes in /singularity:optimize, or checking reviewer quality after a model change',
  phases: [
    { title: 'Replay', detail: 'reviewer on each case change, per variant, in an isolated worktree' },
    { title: 'Judge', detail: 'did the reviewer catch the expected defect / avoid the known false positive' },
  ],
}

// args: {
//   cases: [{ id, kind: 'recall' | 'precision', base, patch (absolute path), lens, expect, location, holdout }],
//   variants: [{ name, lenses: [{ name, description }], reviewer: { agent, model, effort } }]
// }
const A = args || {}
const cases = A.cases || []
const variants = A.variants && A.variants.length ? A.variants : [{ name: 'current' }]

const FINDINGS = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['severity', 'location', 'problem'],
        properties: { severity: { type: 'string' }, location: { type: 'string' }, problem: { type: 'string' } },
      },
    },
  },
}
const VERDICT = {
  type: 'object',
  required: ['hit', 'reason'],
  properties: { hit: { type: 'boolean' }, reason: { type: 'string' } },
}

const DEFAULT_LENS = { correctness: 'logic, edge cases, error handling, test quality' }
const tasks = []
for (const v of variants) {
  for (const c of cases) {
    const lenses = v.lenses && v.lenses.length
      ? v.lenses
      : [{ name: c.lens || 'correctness', description: DEFAULT_LENS[c.lens || 'correctness'] || `the ${c.lens} lens` }]
    for (const l of lenses) tasks.push({ v, c, l })
  }
}

const review = t => {
  const b = t.v.reviewer || {}
  const opts = {
    agentType: b.agent || 'singularity:reviewer',
    isolation: 'worktree',
    label: `${t.v.name}:${t.c.id}:${t.l.name}`,
    phase: 'Replay',
    schema: FINDINGS,
  }
  if (b.model) opts.model = b.model
  if (b.effort) opts.effort = b.effort
  return agent(
    `Setup, in your working directory only: run \`git checkout --detach ${t.c.base}\` then \`git apply ${t.c.patch}\`. Do not commit.
Then do Task A: review through the "${t.l.name}" lens (${t.l.description}). The change under review is the uncommitted working-tree diff (\`git diff\`). Report findings with severity, file:line and the problem.`,
    opts,
  )
}

const judge = (findings, t) =>
  !findings
    ? { variant: t.v.name, id: t.c.id, kind: t.c.kind, holdout: !!t.c.holdout, lens: t.l.name, ran: false, verdict: null }
    : agent(
    `${t.c.kind === 'precision'
      ? `Known FALSE POSITIVE for this change: "${t.c.expect}"${t.c.location ? ` at ${t.c.location}` : ''}. hit = true if any finding below flags this non-issue as a problem.`
      : `Expected DEFECT in this change: "${t.c.expect}"${t.c.location ? ` at ${t.c.location}` : ''}. hit = true if a finding below identifies the same root cause (the exact line may differ).`}
Findings: ${JSON.stringify((findings && findings.findings) || [])}`,
    { label: `judge:${t.v.name}:${t.c.id}:${t.l.name}`, phase: 'Judge', schema: VERDICT, model: 'sonnet', effort: 'low' },
  ).then(verdict => ({ variant: t.v.name, id: t.c.id, kind: t.c.kind, holdout: !!t.c.holdout, lens: t.l.name, ran: !!findings, verdict }))

const rows = (await pipeline(tasks, review, judge)).filter(Boolean)

// A case counts as caught if any lens caught it (recall), or flagged if any lens flagged the false positive (precision).
const summary = variants.map(v => {
  const score = holdout => {
    const mine = cases.filter(c => !!c.holdout === holdout)
    const res = mine.map(c => {
      const r = rows.filter(x => x.variant === v.name && x.id === c.id)
      const ran = r.some(x => x.ran && x.verdict)
      const hit = r.some(x => x.verdict && x.verdict.hit)
      return { id: c.id, kind: c.kind, ran, ok: ran && (c.kind === 'precision' ? !hit : hit) }
    })
    const recall = res.filter(x => x.kind !== 'precision')
    const precision = res.filter(x => x.kind === 'precision')
    return {
      recall: `${recall.filter(x => x.ok).length}/${recall.length}`,
      precision: `${precision.filter(x => x.ok).length}/${precision.length}`,
      failed: res.filter(x => !x.ok).map(x => x.id),
      notRun: res.filter(x => !x.ran).map(x => x.id),
    }
  }
  return { variant: v.name, main: score(false), holdout: score(true) }
})

summary.forEach(s => log(`${s.variant}: recall ${s.main.recall}, precision ${s.main.precision} | holdout recall ${s.holdout.recall}, precision ${s.holdout.precision}`))
return { summary, rows }
