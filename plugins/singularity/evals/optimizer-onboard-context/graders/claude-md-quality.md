---
type: llm
weight: 2
focus: { source: file, path: CLAUDE.md }
---

This is CLAUDE.md after the agents were onboarded to a small service: order
intake for a chain of bakeries, with order totals in `src/orders.js` (integer
cents), a generated API client in `src/gen/`, SQL migrations in
`db/migrations/` and tests run with `node --test`.
PASS if the file still imports `.claude/singularity.md` and
`.claude/singularity/guidelines/project.md`, its template TODOs are replaced,
it says in a sentence or two what the project is for, and it adds only facts
the code doesn't make obvious, such as money in integer cents or `src/gen/`
being generated.
FAIL if TODOs remain, the imports are gone, it walks through the directory
layout, or it states things the repository doesn't support (for example a
framework, database or service the code doesn't use).
