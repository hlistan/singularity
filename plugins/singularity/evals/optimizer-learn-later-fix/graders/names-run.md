---
type: regex
target: { source: file, path: .claude/singularity/experience/runs.jsonl }
pattern: '"type"\s*:\s*"later_fix"[^\n]*"t1-order-total"|"t1-order-total"[^\n]*"type"\s*:\s*"later_fix"'
---
