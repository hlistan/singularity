---
type: regex
target: { source: file, path: .claude/singularity/experience/runs.jsonl }
pattern: '"type"\s*:\s*"correction"[^\n]*"cause"\s*:\s*"guideline-missing"|"cause"\s*:\s*"guideline-missing"[^\n]*"type"\s*:\s*"correction"'
---
