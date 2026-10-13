---
type: llm
---

The change is a behaviour-preserving refactor (extracting lineTotal and using reduce gives the same result).
PASS if the response reports no blocking or should-fix correctness defects; style nits are acceptable.
FAIL if it claims the refactor changes behaviour or introduces a bug.
