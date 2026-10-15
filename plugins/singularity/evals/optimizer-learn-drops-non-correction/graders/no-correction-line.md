---
type: regex
target: { source: file, path: .claude/singularity/experience/runs.jsonl }
pattern: '"type"\s*:\s*"correction"'
match: not_contains
---
