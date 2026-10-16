#!/usr/bin/env bash
# An earlier pipeline run (t1-order-total, squash-merged as PR #12) summed order prices without tax. A
# person later fixed it on main: prices are stored net, and every total a customer sees includes each
# item's tax. No guideline says so. The learn job must find the fix (outcomes.sh later-fixes), count it
# as that run's defect, add a guideline, and record a later_fix line and a regression eval case.
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
ago() { printf '@%s +0000' "$(( $(date +%s) - $1 * 86400 ))"; }
mkdir -p src .claude/singularity/guidelines .claude/singularity/experience .claude/singularity/evals
cat > .claude/singularity.md <<'CFG'
# singularity project config

```yaml
commands:
  test: node --test
conventions:
  default_branch: main
  work_dir: .agentic/work
tracker:
  type: none
code_host:
  type: none
```
CFG
cat > CLAUDE.md <<'MD'
# Shop

@.claude/singularity.md
@.claude/singularity/guidelines/project.md
MD
printf '# Project guidelines\n' > .claude/singularity/guidelines/project.md
printf '# Implementation guidelines\n' > .claude/singularity/guidelines/implement.md
printf '# Review guidelines\n' > .claude/singularity/guidelines/review.md
printf '# Workflow optimizations\n' > .claude/singularity/experience/optimizations.md
: > .claude/singularity/experience/runs.jsonl
printf "export const formatPrice = cents => (cents / 100).toFixed(2)\n" > src/money.js
printf '.agentic/\n' > .gitignore
git add -A
GIT_AUTHOR_DATE="$(ago 20)" GIT_COMMITTER_DATE="$(ago 20)" git commit -q -m "chore: shop"
cat > src/orders.js <<'JS'
// Order items: price in net cents, qty, tax as a rate (0.2 = 20%).
export const orderTotal = order => order.items.reduce((sum, i) => sum + i.price * i.qty, 0)
JS
printf '{"type":"run","date":"2026-10-01","ticket":"T1","slug":"t1-order-total","pipeline":"feature","plugin_version":"0.6.0","branch":"feature/T1-order-total","change":"#12","kind":"feature","goal":"checkout","review_rounds":1,"verify_first_pass":true,"findings":[],"defects":[],"guidelines":{}}\n' \
  >> .claude/singularity/experience/runs.jsonl
git add -A
GIT_AUTHOR_DATE="$(ago 15)" GIT_COMMITTER_DATE="$(ago 15)" git commit -q -m "feat: order total (#12)"
cat > src/orders.js <<'JS'
// Order items: price in net cents, qty, tax as a rate (0.2 = 20%).
export const orderTotal = order => order.items.reduce((sum, i) => sum + Math.round(i.price * i.qty * (1 + i.tax)), 0)
JS
GIT_AUTHOR_DATE="$(ago 3)" GIT_COMMITTER_DATE="$(ago 3)" git commit -q -am "fix: order totals include each item's tax" \
  -m "Prices are stored net; every total a customer sees is gross."
