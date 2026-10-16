---
type: regex
target: { source: file, path: .claude/singularity/experience/runs.jsonl }
pattern: "never call fetch directly|every request goes through"
match: not_contains
---
