---
type: regex
target: { source: file, path: .claude/singularity/experience/runs.jsonl }
pattern: '"type"\s*:\s*"correction"[^\n]*"trigger"\s*:\s*"rejection"|"trigger"\s*:\s*"rejection"[^\n]*"type"\s*:\s*"correction"'
---
