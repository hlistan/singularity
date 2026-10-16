# Adopted role prompts and where they live now

Pre-singularity role prompts mapped clause by clause to their current home, so nothing is lost and the optimizer can trace a rule to its origin.

## Principal Software Engineer / Technical Architect / Principal Quality Engineer (adopted 2026-10)

Purpose: design, implement and verify production-ready fixes, refactorings and test suites from QA issues, defect reports and architectural recommendations.

| Clause | `engineering-standards` section | Also |
|---|---|---|
| Breaking changes and refactorings allowed (backward compatibility not required) when they improve maintainability, testability or scalability | rule text | `conventions.breaking_changes: allowed \| forbidden` in each project's `.claude/singularity.md` (default `forbidden`) |
| Every code change updates automated tests | Definition of done, Tests | |
| Zero hardcoding (config, env, fixtures, strategy modules) | Architecture and code | `testability` review lens |
| Clean architecture: SOLID, DRY, strong typing, explicit errors, DI / IoC | Architecture and code | `testability` lens |
| Shift-left QA: a failing test reproduces the defect first (red-green-refactor) | Tests | spec-writer defect spec; implementer step 1 |
| Zero technical and test debt (dead code, workaround patches, flaky tests, redundant assertions, stale fixtures) | Definition of done | implementer step 4; planner step contents |
| Test pyramid: unit / integration / contract and E2E | Tests | optional `commands.test_unit / test_integration / test_e2e` |
| Boundary and failure-mode rigour | Tests | verifier coverage summary; spec-writer acceptance criteria |
| Deterministic, semantic assertions | Tests | `testability` lens |
| Execution steps 1–4 (reproduce → fix → update tests → coverage summary) | | spec-writer (reproduction + root cause) → planner (failing test first, obsolete tests to replace) → implementer (red-green-refactor, debt removal) → verifier (Test Coverage and Verification Summary) |

Enforcement: every code-facing agent preloads the `engineering-standards` skill (`skills:` frontmatter); the reviewer runs the `testability` lens by default; the verifier reports coverage gaps per acceptance criterion.

The role is split across agents: architect → **planner**, engineer → **implementer**, quality engineer → **verifier** plus the reviewer's **testability** lens. Separate agents keep review's "fresh context" guarantee and let a project swap any one of them.
