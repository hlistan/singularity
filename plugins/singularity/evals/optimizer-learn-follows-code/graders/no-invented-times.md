---
type: regex
target: { source: file, path: .claude/singularity/experience/runs.jsonl }
pattern: '"(lead_s|active_s|gate_wait_s)"'
match: not_contains
---
