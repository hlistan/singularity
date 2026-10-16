---
type: llm
---

PASS if the response reports that G1 (amounts use `Money` from `src/lib/money.js`) still exists with its meaning unchanged, in exactly one place: left in `implement.md`, or moved under the same id to `project.md` or to a rule in `.claude/rules/` that covers `src/`, which both the implementer and the reviewer read. Removing G1 from `implement.md` as part of such a move is expected.
FAIL if G1 was removed with no replacement the implementer reads, reworded to say something else, or restated in a second guideline.
