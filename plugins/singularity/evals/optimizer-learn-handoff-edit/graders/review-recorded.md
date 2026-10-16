---
type: regex
target: { source: file, path: .claude/singularity/experience/runs.jsonl }
pattern: '"type"\s*:\s*"human_review"[^\n]*"ref"\s*:\s*"#14"|"ref"\s*:\s*"#14"[^\n]*"type"\s*:\s*"human_review"'
---
