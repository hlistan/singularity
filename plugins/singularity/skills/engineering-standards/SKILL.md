---
name: engineering-standards
description: The team's shared definition of done, architecture and testing standards that apply to every project. Use when planning, implementing, reviewing or verifying code changes.
---

# Engineering standards (all projects)

These apply everywhere. A project's `CLAUDE.md` or `.claude/singularity.md` may add rules or tighten these; where they conflict, the project wins. Quality-engineering standards come first: a change is not done until its tests prove it.

## Definition of done

- Every acceptance criterion has at least one automated test that fails without the change.
- Build, lint, typecheck and tests pass using the project's own commands.
- No new warnings in changed files.
- No secrets, credentials or personal data in code, tests, fixtures or logs.
- Public behaviour changes are reflected in docs/changelog where the project keeps them.
- Migrations are reversible, or the plan says why not.
- Zero debt left behind: dead code, obsolete workaround patches, flaky tests, redundant assertions and unmaintained fixtures touched by the change are removed, not left for later.

## Architecture and code

- **No hardcoding.** Thresholds, endpoints, feature flags, mock data and business rules live in configuration, environment variables, fixtures or strategy modules, not inline in logic.
- **Built for testability.** Dependencies are injected (constructor or parameter injection, inversion of control) so that external interfaces can be replaced by test doubles without patching internals.
- Clean code: single responsibility, no duplication (DRY), strong typing, explicit error handling. Never swallow exceptions silently; validate input at trust boundaries.
- Follow existing patterns before introducing new ones. Changes stay within the approved plan; a refactor is planned, not a drive-by.
- **Breaking changes** follow the project's `conventions.breaking_changes` setting: `allowed` means backward compatibility with legacy code or deprecated schemas is not required when the refactor improves maintainability, testability or scalability, provided client contracts are covered by tests; `forbidden` means public contracts and schemas stay compatible unless the spec says otherwise. If unset, treat it as `forbidden`.
- Prefer clear names over comments; comment the *why*, not the *what*.

## Tests

- **Red-green-refactor.** A bugfix starts with a minimal failing test that reproduces the exact defect; a feature starts with the test for its acceptance criterion. Make it fail for the right reason, make it pass, then refactor.
- **Test pyramid.** Unit tests cover domain logic in isolation with test doubles for external interfaces. Integration tests cover data boundaries: database state changes, queues, third-party API contracts. Contract or end-to-end checks prove that API schema migrations and breaking refactors don't violate client contracts.
- **Boundary and failure-mode coverage.** Every fix or feature explicitly covers: the happy path; boundary conditions; malformed, empty and null inputs; timeout and retry paths; and each explicit exception state.
- **Deterministic.** No hardcoded sleeps, no real time or randomness without a mocked clock or seed, no real network. Independent, order-insensitive tests.
- **Semantic assertions.** Assert the specific expected value or state, not a broad boolean. Test behaviour, not implementation details.
- Tests made obsolete by a refactor are updated or replaced in the same change, never deleted to get green.

## Verification summary

Every implemented change ends with a short **Test Coverage and Verification Summary**: per acceptance criterion or defect, the tests covering the happy path, boundary cases and failure modes, the commands run, and their results.

## Git

- Never rewrite shared history, force-push to protected branches or bypass hooks (`--no-verify`).
- Commit messages follow the project's convention (default: Conventional Commits).
