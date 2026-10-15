export const meta = {
  name: 'replay-evals',
  description: 'Internal, run by the singularity optimizer agent. Replays the project eval cases (real escaped defects and known false positives) through the reviewer, for one or more config variants and several trials, and scores recall and precision per case',
  whenToUse: 'Validating review-related changes in an optimizer run (singularity:optimizer), or checking reviewer quality after a model change',
  phases: [
    { title: 'Replay', detail: 'reviewer on each case change, per variant and trial, in an isolated worktree' },
    { title: 'Judge', detail: 'did the reviewer catch the expected defect / avoid the known false positive' },
  ],
}

// args: {
//   cases: [{ id, kind: 'recall' | 'precision', base, patch (absolute path), lens, expect, location, holdout }],
//   variants: [{ name, lenses: [{ name, description }], reviewer: { agent, model, effort } }],
//   trials: 3   // runs of each variant on each case: the reviewer isn't deterministic
// }
const A = args || {}
const cases = A.cases || []
const variants = A.variants && A.variants.length ? A.variants : [{ name: 'current' }]
const trials = Math.max(1, Math.floor(Number(A.trials) || 3))

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
    for (let k = 1; k <= trials; k++) for (const l of lenses) tasks.push({ v, c, l, k })
  }
}

const review = t => {
  const b = t.v.reviewer || {}
  const opts = {
    agentType: b.agent || 'singularity:reviewer',
    isolation: 'worktree',
    label: `${t.v.name}:${t.c.id}:${t.l.name}#${t.k}`,
    phase: 'Replay',
    schema: FINDINGS,
  }
  if (b.model) opts.model = b.model
  if (b.effort) opts.effort = b.effort
  return agent(
    `Setup, in your working directory only: run \`git checkout --detach ${t.c.base}\` then \`git apply --index ${t.c.patch}\`. Do not commit.
Then do Task A: review through the "${t.l.name}" lens (${t.l.description}). The change under review is everything the patch staged: \`git diff HEAD\`, which includes the files it adds. Report findings with severity, file:line and the problem.`,
    opts,
  )
}

const row = (t, findings, verdict) =>
  ({ variant: t.v.name, id: t.c.id, kind: t.c.kind, holdout: !!t.c.holdout, lens: t.l.name, trial: t.k, ran: !!findings && !!verdict, verdict })

const judge = (findings, t) =>
  !findings
    ? row(t, null, null)
    : agent(
    `${t.c.kind === 'precision'
      ? `Known FALSE POSITIVE for this change: "${t.c.expect}"${t.c.location ? ` at ${t.c.location}` : ''}. hit = true if any finding below flags this non-issue as a problem.`
      : `Expected DEFECT in this change: "${t.c.expect}"${t.c.location ? ` at ${t.c.location}` : ''}. hit = true if a finding below identifies the same root cause (the exact line may differ).`}
Findings: ${JSON.stringify((findings && findings.findings) || [])}`,
    { label: `judge:${t.v.name}:${t.c.id}:${t.l.name}#${t.k}`, phase: 'Judge', schema: VERDICT, model: 'sonnet', effort: 'low' },
  ).then(verdict => row(t, findings, verdict))

const rows = (await pipeline(tasks, review, judge)).filter(Boolean)

// One trial of a case: caught if any lens caught it (recall), or flagged if any lens flagged the false positive (precision).
// A case is right when it is right in most of the trials that ran; it is flaky when its trials disagree.
const caseResult = (v, c) => {
  let run = 0
  let ok = 0
  for (let k = 1; k <= trials; k++) {
    const r = rows.filter(x => x.variant === v.name && x.id === c.id && x.trial === k)
    if (!r.some(x => x.ran)) continue
    run++
    const hit = r.some(x => x.verdict && x.verdict.hit)
    if (c.kind === 'precision' ? !hit : hit) ok++
  }
  return { id: c.id, kind: c.kind, holdout: !!c.holdout, run, ok, right: run > 0 && ok * 2 > run, flaky: ok > 0 && ok < run }
}

const perCase = variants.map(v => ({ variant: v.name, cases: cases.map(c => caseResult(v, c)) }))

const summary = perCase.map(({ variant, cases: res }) => {
  const score = holdout => {
    const mine = res.filter(x => x.holdout === holdout)
    const recall = mine.filter(x => x.kind !== 'precision')
    const precision = mine.filter(x => x.kind === 'precision')
    const always = xs => xs.filter(x => x.run === trials && x.ok === trials).length
    return {
      recall: `${recall.filter(x => x.right).length}/${recall.length}`,
      recallEveryTrial: `${always(recall)}/${recall.length}`,
      precision: `${precision.filter(x => x.right).length}/${precision.length}`,
      precisionEveryTrial: `${always(precision)}/${precision.length}`,
      failed: mine.filter(x => x.run > 0 && !x.right).map(x => x.id),
      flaky: mine.filter(x => x.flaky).map(x => x.id),
      notRun: mine.filter(x => x.run === 0).map(x => x.id),
    }
  }
  return { variant, trials, main: score(false), holdout: score(true) }
})

summary.forEach(s => log(`${s.variant} (${trials} trials): recall ${s.main.recall} (every trial ${s.main.recallEveryTrial}), precision ${s.main.precision} | holdout recall ${s.holdout.recall}, precision ${s.holdout.precision} | flaky: ${s.main.flaky.concat(s.holdout.flaky).join(', ') || 'none'}`))
return { summary, perCase, rows }
