#!/usr/bin/env bash
# The word filter queued a prompt that only asks for more work ("No need to hurry ... also add").
# It corrects nothing, so the learn job must drop it: no guideline, no correction line, queue cleared.
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src/lib .claude/singularity/guidelines .claude/singularity/experience .agentic/work/corrections
printf "export const formatDate = d => d.toISOString().slice(0, 10)\n" > src/lib/dates.js
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
git add -A && git commit -q -m "feat: dates"
printf "import { formatDate } from './lib/dates.js'\nexport const reportTitle = r => 'Report ' + formatDate(r.date)\n" > src/report.js
printf '*\n' > .agentic/work/corrections/.gitignore
cat > .agentic/work/corrections/C-20261015T111500Z-4243-7.txt <<'EOF'
captured: 2026-10-15T11:15:00Z
session: 9a4f10

## The prompt (UserPromptSubmit hook input)

{"session_id":"9a4f10","transcript_path":"/home/dev/.claude/projects/x/9a4f10.jsonl","cwd":"/home/dev/billing","hook_event_name":"UserPromptSubmit","prompt":"No need to hurry. Looks good. Also add a CSV export button to the report page, and don't forget the changelog."}

## The agent's last message before it (Stop hook input)

{"session_id":"9a4f10","hook_event_name":"Stop","last_assistant_message":"I added reportTitle to src/report.js using formatDate from src/lib/dates.js. Tests pass."}
EOF
