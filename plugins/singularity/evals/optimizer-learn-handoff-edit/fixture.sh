#!/usr/bin/env bash
# A person edited an earlier run's change before merging its PR (#14): the agent logged with console.log,
# and the reviewer switched it to the logger in src/lib/log.js, the project's convention. No review
# comment, no guideline. The pipeline handed the learn job the finished review: no comments, the edits
# in human-edits.diff. The learn job must record the edit as a correction, add a guideline, and append
# a human_review line that says the change was modified.
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src/lib .claude/singularity/guidelines .claude/singularity/experience
cat > src/lib/log.js <<'JS'
export const log = { info: (msg, fields = {}) => process.stdout.write(JSON.stringify({ level: 'info', msg, ...fields }) + '\n') }
JS
cat > .claude/singularity.md <<'CFG'
# singularity project config

```yaml
commands:
  test: node --test
conventions:
  default_branch: main
  work_dir: .agentic/work
tracker:
  type: github
  github: { repo: example/reports }
code_host:
  type: github
learning:
  pr_reviews: true
```
CFG
cat > CLAUDE.md <<'MD'
# Reports service

@.claude/singularity.md
@.claude/singularity/guidelines/project.md
MD
printf '# Project guidelines\n' > .claude/singularity/guidelines/project.md
printf '# Implementation guidelines\n' > .claude/singularity/guidelines/implement.md
printf '# Workflow optimizations\n' > .claude/singularity/experience/optimizations.md
printf '{"type":"run","date":"2026-10-10","ticket":"#9","slug":"9-csv-export","pipeline":"feature","plugin_version":"0.6.0","branch":"feature/9-csv-export","change":"#14","kind":"feature","goal":"self-service reports","review_rounds":1,"verify_first_pass":true,"findings":[],"defects":[],"guidelines":{}}\n' \
  > .claude/singularity/experience/runs.jsonl
printf '.agentic/\n' > .gitignore
git add -A && git commit -q -m "chore: reports service"
git tag base-9
git checkout -q -b feature/9-csv-export
cat > src/export.js <<'JS'
export const exportCsv = rows => {
  console.log('exporting ' + rows.length + ' rows')
  return rows.map(r => [r.id, r.total].join(',')).join('\n')
}
JS
git add -A && git commit -q -m "feat: CSV export" -m "Singularity-Run: 9-csv-export"
handoff=$(git rev-parse HEAD)
cat > src/export.js <<'JS'
import { log } from './lib/log.js'
export const exportCsv = rows => {
  log.info('export', { rows: rows.length })
  return rows.map(r => [r.id, r.total].join(',')).join('\n')
}
JS
git commit -q -am "use the logger"
git tag reviewed-9
git checkout -q main
w=.agentic/work/9-csv-export
mkdir -p "$w"
printf '# Human review of #14\n\nNo review comments.\n' > "$w/human-review.md"
git diff "$handoff" reviewed-9 -- src/export.js > "$w/human-edits.diff"
printf '# Review\n\nNo findings.\n' > "$w/review.md"
