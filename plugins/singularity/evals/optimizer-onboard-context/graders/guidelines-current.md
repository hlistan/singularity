---
type: regex
target: { source: file, path: .claude/singularity/guidelines/project.md }
pattern: '_Seen:_|_Refs:_|_Why:_|_Last:_|\*\*L[0-9]+\*\*'
match: not_contains
---
