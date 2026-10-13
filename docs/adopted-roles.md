# Adopted role prompts and where they live now

Role prompts the team adopted before singularity, and where each clause landed. Keeping the mapping lets us check nothing was lost and lets the optimizer trace a rule back to its origin.

## Principal Software Engineer / Technical Architect / Principal Quality Engineer (adopted 2026-10)

Purpose: design, implement and verify production-ready fixes, refactorings and test suites from QA issues, defect reports and architectural recommendations.

| Clause | Where it lives |
|---|---|
| Breaking changes and refactorings allowed; backward compatibility not required when the refactor improves maintainability, testability or scalability | `conventions.breaking_changes: allowed \| forbidden` in each project's `.claude/singularity.md` (default `forbidden`); rule text in `engineering-standards` |
| All code changes come with automated test updates | `engineering-standards` → Definition of done, Tests |
| Zero hardcoding (config, env, fixtures, strategy modules) | `engineering-standards` → Architecture and code; `testability` review lens |
| Clean architecture: SOLID, DRY, strong typing, explicit errors, DI / IoC | `engineering-standards` → Architecture and code; `testability` lens |
| Shift-left QA: reproduce the defect with a failing test first (red-green-refactor) | `engineering-standards` → Tests; spec-writer defect spec; implementer step 1 |
| Zero technical and test debt (dead code, workaround patches, flaky tests, redundant assertions, stale fixtures) | `engineering-standards` → Definition of done; implementer step 4; planner step contents |
| Test pyramid: unit / integration / contract and E2E | `engineering-standards` → Tests; optional `commands.test_unit / test_integration / test_e2e` |
| Boundary and failure-mode rigour | `engineering-standards` → Tests; verifier coverage summary; spec-writer acceptance criteria |
| Deterministic, semantic assertions | `engineering-standards` → Tests; `testability` lens |
| Execution steps 1–4 (reproduce → fix → update tests → coverage summary) | spec-writer (reproduction + root cause) → planner (failing test first, obsolete tests to replace) → implementer (red-green-refactor, debt removal) → verifier (Test Coverage and Verification Summary) |

How the standards are enforced: every code-facing agent preloads the `engineering-standards` skill through its `skills:` frontmatter, the reviewer runs a `testability` lens by default, and the verifier reports coverage gaps per acceptance criterion.

The role itself is not one agent: the architect part is the **planner**, the engineer part the **implementer**, the quality-engineer part the **verifier** plus the reviewer's **testability** lens. Keeping them separate keeps the "fresh context" guarantee for review and lets a project swap any one of them.
