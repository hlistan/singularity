---
type: llm
weight: 2
---

PASS if the response reports a new guideline saying that dates are formatted with `formatDate` from `src/lib/dates.js` (rather than with moment), placed in a guideline file or path-scoped rule that the implementing agent reads.
FAIL if no such guideline was added, if the guideline records history (what went wrong, when, or in which session) instead of the current rule, or if the response says it only fixed the code.
