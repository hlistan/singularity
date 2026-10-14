#!/usr/bin/env bash
# A finished run moved the retry helper from src/retry.js to src/lib/retry.js. The implement guideline G2
# still points at the old path; the optimizer's learn job must rewrite it to the new one.
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src/api .claude/singularity/guidelines .claude/singularity/experience
printf 'export const withRetry = (fn, tries = 3) => fn()\n' > src/retry.js
printf "import { withRetry } from '../retry.js'\nexport const get = url => withRetry(() => fetch(url))\n" > src/api/client.js
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
# Fetcher

@.claude/singularity.md
@.claude/singularity/guidelines/project.md
EOF
printf '# Project guidelines\n' > .claude/singularity/guidelines/project.md
cat > .claude/singularity/guidelines/implement.md <<'EOF'
# Implementation guidelines

## HTTP

- **G2** Wrap every outbound HTTP call in `withRetry` from `src/retry.js`.
EOF
: > .claude/singularity/experience/runs.jsonl
printf '# Workflow optimizations\n' > .claude/singularity/experience/optimizations.md
printf '.agentic/\n' > .gitignore
git add -A && git commit -q -m "feat: fetcher"
base=$(git rev-parse HEAD)
git checkout -q -b feature/T1-move-retry
mkdir -p src/lib
git mv src/retry.js src/lib/retry.js
printf "import { withRetry } from '../lib/retry.js'\nexport const get = url => withRetry(() => fetch(url))\n" > src/api/client.js
git add -A && git commit -q -m "refactor: move the retry helper to src/lib"
w=.agentic/work/t1-move-retry
mkdir -p "$w"
printf '# Spec\n\n1. The retry helper lives in `src/lib/retry.js`.\n' > "$w/spec.md"
cp "$w/spec.md" "$w/spec.draft.md"
printf '# Plan\n\n- [x] 1. Move `src/retry.js` to `src/lib/retry.js` and update imports.\n' > "$w/plan.md"
cp "$w/plan.md" "$w/plan.draft.md"
printf '# Review\n\nNo findings.\n' > "$w/review.md"
printf '# Summary\n\nMoved the retry helper to `src/lib/retry.js`. Verification: PASS.\n' > "$w/summary.md"
cat > "$w/run.json" <<EOF
{"ticket":"T1","slug":"t1-move-retry","pipeline":"feature","kind":"refactoring","plugin_version":"0.5.0","branch":"feature/T1-move-retry","base":"$base",
 "stages":{"spec":{"done":true},"plan":{"done":true},"implement":{"done":true},"review":{"done":true},"verify":{"done":true},"handoff":{"done":true}},
 "gates":{"spec":"approved","plan":"approved"},"gate_edits":{"spec":false,"plan":false},
 "review_rounds":0,"findings":[],"verify_first_pass":true}
EOF
