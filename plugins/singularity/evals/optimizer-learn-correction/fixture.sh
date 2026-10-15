#!/usr/bin/env bash
# The user corrected the agent in a session: it formatted a date with moment, but dates go through
# formatDate in src/lib/dates.js. The hook queued the correction; no guideline covers dates. The learn
# job must turn it into a guideline, record it without the prompt's text, and clear the queue.
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src/lib .claude/singularity/guidelines .claude/singularity/experience .agentic/work/corrections
printf "import { format } from 'date-fns'\nexport const formatDate = d => format(d, 'yyyy-MM-dd')\n" > src/lib/dates.js
printf "import { formatDate } from './lib/dates.js'\nexport const invoiceLine = i => formatDate(i.date) + ' ' + i.total\n" > src/invoice.js
cat > .claude/singularity.md <<'EOF'
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
EOF
cat > CLAUDE.md <<'EOF'
# Billing reports

@.claude/singularity.md
@.claude/singularity/guidelines/project.md
EOF
printf '# Project guidelines\n' > .claude/singularity/guidelines/project.md
printf '# Implementation guidelines\n' > .claude/singularity/guidelines/implement.md
: > .claude/singularity/experience/runs.jsonl
printf '# Workflow optimizations\n' > .claude/singularity/experience/optimizations.md
printf '.agentic/\n' > .gitignore
git add -A && git commit -q -m "feat: invoices"
# The agent's change that the user corrected, left uncommitted as the session left it.
printf "import moment from 'moment'\nexport const reportTitle = r => 'Report ' + moment(r.date).format('YYYY-MM-DD')\n" > src/report.js
printf '*\n' > .agentic/work/corrections/.gitignore
cat > .agentic/work/corrections/C-20261015T101500Z-4242-1.txt <<'EOF'
captured: 2026-10-15T10:15:00Z
session: 7d1e2c

## The prompt (UserPromptSubmit hook input)

{"session_id":"7d1e2c","transcript_path":"/home/dev/.claude/projects/x/7d1e2c.jsonl","cwd":"/home/dev/billing","hook_event_name":"UserPromptSubmit","prompt":"No, we don't use moment here. Every date we show goes through formatDate in src/lib/dates.js, please fix src/report.js."}

## The agent's last message before it (Stop hook input)

{"session_id":"7d1e2c","hook_event_name":"Stop","last_assistant_message":"I added reportTitle to src/report.js. It formats the report date with moment(r.date).format('YYYY-MM-DD')."}
EOF
