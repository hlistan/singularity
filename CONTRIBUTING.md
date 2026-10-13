# Contributing

Thanks for helping improve Project Singularity. The project is early: it has been validated structurally but not yet exercised against real projects at scale, so experience reports are as valuable as code.

## Ground rules

- Be respectful; see `CODE_OF_CONDUCT.md`.
- Open an issue before a large change so the design can be discussed first. Workflow changes should come with evidence (what failed, how often) rather than preference, in the spirit of `docs/self-optimization.md`.
- Never commit secrets, personal data, internal hostnames or private repository names. CI blocks them, and so do the local hooks below.

## Setup

```bash
git clone https://github.com/hlistan/singularity.git
cd singularity
pip install pre-commit && pre-commit install --hook-type pre-commit --hook-type pre-push
npm install -g @anthropic-ai/claude-code
claude plugin validate --strict .
```

To try your changes in a project: `claude --plugin-dir /path/to/singularity/plugins/singularity`.

## What goes where

| Change | Location | Notes |
|---|---|---|
| Shared agent behaviour | `plugins/singularity/agents/*.md` | Keep each definition under ~120 lines; prefer config and checks over prose |
| Pipelines and commands | `plugins/singularity/skills/*/SKILL.md` | |
| Orchestration | `plugins/singularity/workflows/*.js` | Plain JavaScript; see the `/workflow-authoring` skill in Claude Code |
| Guardrails | `plugins/singularity/hooks/`, `scripts/` | Needs a maintainer review (CODEOWNERS) |
| Regression cases | `plugins/singularity/evals/` | Only add cases; never weaken graders |
| Per-project templates | `plugins/singularity/templates/project/` | |
| Design notes | `docs/` | |
| Release notes | `CHANGELOG.md`, under `## [Unreleased]` | One line per change, written for the people running projects |

## Before you open a pull request

1. `claude plugin validate --strict .` passes.
2. `pre-commit run --all-files` passes (lint, shellcheck, markdownlint, gitleaks, sensitive-info check, version check).
3. `node scripts/check-evals.js` passes (CI runs it too).
4. If you changed anything under `plugins/singularity/` other than eval cases, add a line under `## [Unreleased]` in `CHANGELOG.md`, starting with **Breaking:** if projects must change something. Leave the version alone: it changes only in release PRs. `node scripts/version.js check --base origin/main` runs the same check as CI.
5. For agent, skill or workflow changes: run the eval suite once (`plugins/singularity/evals/README.md`) and paste the summary table in the PR. It costs real model calls; use `--case` and `--runs 1` while iterating.
6. Describe the change as a contract where it affects behaviour: what it should fix, what it might break, how you checked.

Commits follow Conventional Commits (`feat:`, `fix:`, `docs:`, `ci:`…).

## Releasing

Maintainers release by running `node scripts/version.js bump <patch|minor|major>` on a branch and merging the resulting `chore(release): singularity <version>` PR. The Release workflow then tags `singularity--v<version>`, moves the `stable` branch that projects follow, and publishes the GitHub release. Which bump to choose, and what projects see, is in [Versions and releases](README.md#versions-and-releases).
