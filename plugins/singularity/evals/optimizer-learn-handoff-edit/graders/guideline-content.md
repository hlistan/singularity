---
type: llm
weight: 2
---

PASS if the response reports a new guideline saying that code logs through `log` from `src/lib/log.js` (structured fields) rather than `console.log`, placed in a guideline file or path-scoped rule that the implementing agent reads, and treats the reviewer's edit as a correction of the agents' work.
FAIL if no such guideline was added, if the guideline records history (the PR, the review, the edit or a date) instead of the current rule, or if the response ignores the edit because the review had no comments.
