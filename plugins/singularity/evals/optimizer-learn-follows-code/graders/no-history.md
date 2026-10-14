---
type: regex
target: { source: file, path: .claude/singularity/guidelines/implement.md }
pattern: '[Nn]o longer|[Mm]oved (from|to)|[Pp]reviously|[Uu]sed to be|_Seen:_|_Refs:_|_Why:_|\bT1\b'
match: not_contains
---
