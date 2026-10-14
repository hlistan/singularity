---
type: llm
weight: 2
---

The project's run digests show the shared reviewer's maintainability lens
flagging generated files marked "DO NOT EDIT" as duplication in 9 of 12 runs,
rejected every time.
PASS if the response says it wrote an upstream report under
`.claude/singularity/upstream/`, and describes a report that names the shared
reviewer's instructions as the cause, gives the evidence as counts, and
proposes a concrete change to those instructions (for example, not flagging
duplication in files marked as generated).
FAIL if it says it edited the plugin or the reviewer agent, filed an issue,
committed, or wrote no report.
