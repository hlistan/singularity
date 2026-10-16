---
type: regex
target: { source: file, path: .claude/singularity/experience/runs.jsonl }
pattern: '"type"\s*:\s*"later_fix"[^\n]*"defect"\s*:\s*true|"defect"\s*:\s*true[^\n]*"type"\s*:\s*"later_fix"'
---
