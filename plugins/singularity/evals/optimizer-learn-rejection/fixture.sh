#!/usr/bin/env bash
# The user rejected an agent's edit and typed what to do instead: requests go through apiClient in
# src/lib/api.js, never fetch. The hook queued it with trigger "rejection" and the rejected call. No
# guideline covers it. The learn job must turn it into a guideline, record the correction with its
# trigger and without the typed text, and clear the queue.
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src/lib .claude/singularity/guidelines .claude/singularity/experience .agentic/work/corrections
cat > src/lib/api.js <<'JS'
export const apiClient = { get: path => fetch('/api' + path, { credentials: 'include' }).then(r => r.json()) }
JS
cat > src/users.js <<'JS'
import { apiClient } from './lib/api.js'
export const loadUsers = () => apiClient.get('/users')
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
  type: none
code_host:
  type: none
```
CFG
cat > CLAUDE.md <<'MD'
# Admin console

@.claude/singularity.md
@.claude/singularity/guidelines/project.md
MD
printf '# Project guidelines\n' > .claude/singularity/guidelines/project.md
printf '# Implementation guidelines\n' > .claude/singularity/guidelines/implement.md
: > .claude/singularity/experience/runs.jsonl
printf '# Workflow optimizations\n' > .claude/singularity/experience/optimizations.md
printf '.agentic/\n' > .gitignore
git add -A && git commit -q -m "feat: users"
printf '*\n' > .agentic/work/corrections/.gitignore
cat > .agentic/work/corrections/C-20261015T111500Z-5151-1.txt <<'REC'
captured: 2026-10-15T11:15:00Z
session: 9a1b3c
trigger: rejection

## Feedback typed when rejecting a tool call (transcript)

no, we never call fetch directly here: every request goes through apiClient in src/lib/api.js

## The rejected tool call (transcript)

{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_01","name":"Write","input":{"file_path":"src/orders.js","content":"export const loadOrders = () => fetch('/api/orders').then(r => r.json())\n"}}]}}

## The agent's last message before it (Stop hook input)

{"session_id":"9a1b3c","hook_event_name":"Stop","last_assistant_message":"I'll add loadOrders in src/orders.js."}
REC
