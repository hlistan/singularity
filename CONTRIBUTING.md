# Contributing

Early project: validated structurally, not yet exercised on real projects at scale; experience reports count as much as code.

## Ground rules

- Be respectful (`CODE_OF_CONDUCT.md`).
- Large change: open an issue first. Workflow changes need evidence (what failed, how often), not preference (`docs/self-optimization.md`).
- Never commit secrets, personal data, internal hostnames or private repository names; CI and local hooks block them.

## Setup

```bash
git clone https://github.com/hlistan/singularity.git
cd singularity
pip install pre-commit && pre-commit install --hook-type pre-commit --hook-type pre-push
npm install -g @anthropic-ai/claude-code
claude plugin validate --strict .
```

Test in a project: `claude --plugin-dir /path/to/singularity/plugins/singularity`.

## What goes where

| Change | Location | Notes |
|---|---|---|
| Shared agent behaviour | `plugins/singularity/agents/*.md` | Each definition under ~120 lines; prefer config and checks over prose |
| The optimizer's procedures | `plugins/singularity/optimizer/*.md` | Optimizer playbooks, one per job; maintainer review (CODEOWNERS) |
| Pipelines and commands | `plugins/singularity/skills/*/SKILL.md` | |
| Agent and skill library | `plugins/singularity/agents/` (library agents), `plugins/singularity/library/skills/` | The main place to contribute; rules and catalog in `plugins/singularity/library/README.md`; `node scripts/check-library.js` |
| Orchestration | `plugins/singularity/workflows/*.js` | Plain JavaScript; see Claude Code's `/workflow-authoring` skill |
| Guardrails | `plugins/singularity/hooks/`, `scripts/` | Maintainer review (CODEOWNERS) |
| Regression cases | `plugins/singularity/evals/` | Add cases only; never weaken graders |
| Per-project templates | `plugins/singularity/templates/project/` | |
| Design notes | `docs/` | |
| Release notes | `CHANGELOG.md`, under `## [Unreleased]` | One line per change, for people running projects |

## Adopting upstream reports

A project's optimizer files each problem it finds in the shared plugin as an **upstream report**: problem, evidence (counts, categories), exact proposed fix, contract. Reports arrive as `[upstream] …` issues or pasted into a Workflow improvement issue. One project's evidence: treat it as a hypothesis.

1. **Triage.** Confirm the cause in the plugin at the reported version; seek other reports (several reporting projects: the strongest evidence). Fix suits only the reporting project: decline with the reason; its optimizer records it and keeps its local workaround only while it pays off.
2. **Reproduce.** Add a plugin eval case that fails for the reported reason (`plugins/singularity/evals/`, see its README), built from a generic example, never a project's code.
3. **Fix.** Smallest change that works (the proposed fix or better). Run the suite on your branch and on `main` (`git worktree add ../baseline main`), both runners its README names, compare case by case; adopt only if the new case passes and nothing regresses.
4. **Record.** Line naming the issue under `## [Unreleased]` in `CHANGELOG.md`; a contract in the PR. Don't close the issue from the PR ("Fixes #…" closes it at merge, before projects get the fix); close it after the release, naming the version, so reporting projects' optimizers can check the fix and propose dropping workarounds.

## Before you open a pull request

1. `claude plugin validate --strict .` passes.
2. `pre-commit run --all-files` passes (lint, shellcheck, markdownlint, gitleaks, sensitive-info check, version check).
3. `node scripts/check-evals.js` and `node scripts/check-library.js` pass (CI too). Changed a script under `plugins/singularity/scripts/` or `skills/tracker/scripts/`, or the init-project git-ignore procedure: every `tests/*.test.sh` passes, on macOS also under `/bin/bash` (CI: bash 3.2 on macOS; bash 5 with `mawk` as `awk` on Linux). Awk stays POSIX. Template Markdown passes markdownlint's defaults, 80-column limit included (`plugins/singularity/templates/.markdownlint-cli2.yaml`, CI-checked).
4. Changes under `plugins/singularity/` other than eval cases: a line under `## [Unreleased]` in `CHANGELOG.md`, **Breaking:** first if projects must change something. Version untouched (release PRs only); `node scripts/version.js check --base origin/main` runs CI's check.
5. Agent, skill or workflow changes: one eval-suite run (`plugins/singularity/evals/README.md`), summary table in the PR. Real model calls: iterate with `--case` and `--runs 1`.
6. Behaviour changes: a contract (should fix, might break, how checked).

Commits: Conventional Commits (`feat:`, `fix:`, `docs:`, `ci:`…).

## Releasing

Maintainers run `scripts/release.sh <patch|minor|major>` from an up-to-date `main`. It bumps the version on a release branch, opens and merges the `chore(release): singularity <version>` PR, and follows the Release workflow (tags `singularity--v<version>`, moves the `stable` branch projects follow, publishes the GitHub release). Which bump, and what projects see: [Versions and releases](README.md#versions-and-releases).
