---
name: engineering-standards
description: The team's shared definition of done, architecture and testing standards that apply to every project. Use when planning, implementing, reviewing or verifying code changes.
---

# Engineering standards (all projects)

A project's `CLAUDE.md` or `.claude/singularity.md` may add or tighten rules and wins on conflict.

## Definition of done

- Every acceptance criterion has an automated test that fails without the change.
- Build, lint, typecheck and tests pass (the project's own commands).
- No new warnings in changed files.
- No secrets, credentials or personal data in code, tests, fixtures or logs.
- Public behaviour changes are in docs/changelog, where kept.
- Migrations reversible, or the plan says why not.
- Zero debt: remove the dead code, obsolete workaround patches, flaky tests, redundant assertions and unmaintained fixtures the change touches.

## Architecture and code

- **No hardcoding.** Thresholds, endpoints, feature flags, mock data and business rules go in configuration, environment variables, fixtures or strategy modules.
- **Built for testability.** Inject dependencies (constructor or parameter injection, inversion of control) so test doubles replace external interfaces without patching internals.
- Single responsibility, no duplication (DRY), strong typing, explicit error handling. Never swallow exceptions; validate input at trust boundaries.
- Existing patterns first; stay within the approved plan (no drive-by refactors).
- **Breaking changes** per `conventions.breaking_changes`. `allowed`: a refactor improving maintainability, testability or scalability may drop compatibility with legacy code or deprecated schemas if tests cover client contracts. `forbidden` (also when unset): public contracts and schemas stay compatible unless the spec says otherwise.
- Clear names over comments; comments say *why*, not *what*.

## Tests

- **Red-green-refactor.** Start with a failing test (bugfix: minimal, reproducing the exact defect; feature: for its acceptance criterion). Fail for the right reason, pass, refactor.
- **Test pyramid.** Unit: domain logic in isolation, test doubles for external interfaces. Integration: data boundaries (database state changes, queues, third-party API contracts). Contract or e2e: API schema migrations and breaking refactors keep client contracts.
- **Boundary and failure-mode coverage.** Cover the happy path; boundary conditions; malformed, empty and null inputs; timeout and retry paths; each explicit exception state.
- **Deterministic.** No hardcoded sleeps, unmocked clock, unseeded randomness or real network; independent, order-insensitive tests.
- **Semantic assertions.** The specific expected value or state, not a broad boolean; behaviour, not implementation details.
- Tests a refactor obsoletes: update or replace in the same change, never delete to get green.

## Verification summary

Every implemented change ends with a short **Test Coverage and Verification Summary**: per acceptance criterion or defect, its happy-path, boundary and failure-mode tests, the commands run, results.

## Git

- Never rewrite shared history, force-push to protected branches or bypass hooks (`--no-verify`).
- Commit messages: the project's convention (default: Conventional Commits).
