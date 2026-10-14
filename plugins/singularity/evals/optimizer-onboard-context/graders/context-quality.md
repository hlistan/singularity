---
type: llm
weight: 2
focus: { source: file, path: .claude/singularity.md }
---

This is the project config after the agents were onboarded to a small order
service. The repository shows: `npm test` runs `node --test`; money is integer
cents; `src/gen/` is generated code that must not be edited; migrations in
`db/migrations/` are append-only once released.
PASS if the "Do not touch" section lists the generated code under `src/gen/`
(released migrations may be listed too), and the `test` command is
`node --test` or `npm test`.
FAIL if `src/gen/` is not protected, a command calls a script or tool the
repository doesn't have, or the file was rewritten into a different format.
