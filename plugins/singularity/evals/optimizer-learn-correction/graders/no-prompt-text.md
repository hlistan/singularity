---
type: regex
target: { source: file, path: .claude/singularity/experience/runs.jsonl }
pattern: "we don't use moment here|please fix src/report"
match: not_contains
---
