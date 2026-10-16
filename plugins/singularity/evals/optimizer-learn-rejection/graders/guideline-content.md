---
type: llm
weight: 2
---

PASS if the response reports a new guideline saying that requests go through `apiClient` from `src/lib/api.js` rather than calling `fetch` directly, placed in a guideline file or path-scoped rule that the implementing agent reads.
FAIL if no such guideline was added, if the guideline records history (the rejection, its session or date) instead of the current rule, or if the response drops the record as not a correction.
