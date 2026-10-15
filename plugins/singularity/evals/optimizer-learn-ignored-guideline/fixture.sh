#!/usr/bin/env bash
# A run's first verification failed because the implementer summed money as floats, although guideline
# G1 in implement.md, which the implementer reads, says to use Money. The cause is guideline-ignored:
# the learn job must propose a check, and add no second guideline that says the same thing.
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src/lib src/billing .claude/singularity/guidelines .claude/singularity/experience
cat > src/lib/money.js <<'EOF'
export class Money {
  constructor(cents) { this.cents = cents }
  static of(amount) { return new Money(Math.round(amount * 100)) }
  plus(other) { return new Money(this.cents + other.cents) }
  toString() { return (this.cents / 100).toFixed(2) }
}
EOF
cat > .claude/singularity.md <<'EOF'
# singularity project config

```yaml
commands:
  test: node --test
conventions:
  default_branch: main
  branch: "feature/{ticket}-{slug}"
  work_dir: .agentic/work
tracker:
  type: files
code_host:
  type: none
```
EOF
cat > CLAUDE.md <<'EOF'
# Billing

@.claude/singularity.md
@.claude/singularity/guidelines/project.md
EOF
printf '# Project guidelines\n' > .claude/singularity/guidelines/project.md
cat > .claude/singularity/guidelines/implement.md <<'EOF'
# Implementation guidelines

## Money

- **G1** Do all arithmetic on amounts with `Money` from `src/lib/money.js`;
  never add or multiply amounts as floats.
EOF
printf '{"type":"curation","date":"2026-10-01","by":"optimizer","ref":"O-2026-10-01-onboard","guidelines":{"added":["G1"]}}\n' > .claude/singularity/experience/runs.jsonl
printf '# Workflow optimizations\n' > .claude/singularity/experience/optimizations.md
printf '.agentic/\n' > .gitignore
git add -A && git commit -q -m "feat: money"
base=$(git rev-parse HEAD)
git checkout -q -b feature/T4-invoice-total
cat > src/billing/invoice.js <<'EOF'
import { Money } from '../lib/money.js'
export const invoiceTotal = lines => lines.reduce((sum, l) => sum.plus(Money.of(l.amount)), Money.of(0))
EOF
git add -A && git commit -q -m "feat: invoice total"
w=.agentic/work/t4-invoice-total
mkdir -p "$w"
printf '# Spec\n\n1. The invoice total is the exact sum of its line amounts, to the cent.\n' > "$w/spec.md"
cp "$w/spec.md" "$w/spec.draft.md"
printf '# Plan\n\n- [x] 1. Add `invoiceTotal` in `src/billing/invoice.js`, test first.\n' > "$w/plan.md"
cp "$w/plan.md" "$w/plan.draft.md"
printf '# Review\n\nNo findings.\n' > "$w/review.md"
printf '# Summary\n\nAdded invoiceTotal. Verification: PASS after one fix round.\n' > "$w/summary.md"
cat > "$w/run.json" <<EOF
{"ticket":"T4","slug":"t4-invoice-total","pipeline":"feature","kind":"feature","plugin_version":"0.6.0","branch":"feature/T4-invoice-total","base":"$base",
 "stages":{"spec":{"done":true},"plan":{"done":true},"implement":{"done":true},"review":{"done":true},"verify":{"done":true},"handoff":{"done":true}},
 "gates":{"spec":"approved","plan":"approved"},"gate_edits":{"spec":false,"plan":false},
 "review_rounds":1,"findings":[],"fix_rounds":1,"verify_first_pass":false,
 "verify_failures":[{"command":"node --test","output":"invoice total: expected '10.10', got '10.099999999999998' (src/billing/invoice.js summed l.amount as floats)"}],
 "fix_round_reasons":["verification failure: float arithmetic on amounts in src/billing/invoice.js, fixed by using Money"]}
EOF
