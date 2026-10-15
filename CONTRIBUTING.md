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
| The optimizer's procedures | `plugins/singularity/optimizer/*.md` | Playbooks the optimizer agent reads per job; a maintainer reviews them (CODEOWNERS) |
| Pipelines and commands | `plugins/singularity/skills/*/SKILL.md` | |
| Orchestration | `plugins/singularity/workflows/*.js` | Plain JavaScript; see the `/workflow-authoring` skill in Claude Code |
| Guardrails | `plugins/singularity/hooks/`, `scripts/` | Needs a maintainer review (CODEOWNERS) |
| Regression cases | `plugins/singularity/evals/` | Only add cases; never weaken graders |
| Per-project templates | `plugins/singularity/templates/project/` | |
| Design notes | `docs/` | |
| Release notes | `CHANGELOG.md`, under `## [Unreleased]` | One line per change, written for the people running projects |

## Adopting upstream reports

Each project's optimizer writes up what it finds wrong in the shared plugin as an **upstream report**: the problem, the evidence as counts and categories, the exact fix it proposes, and a contract. Reports arrive as issues titled `[upstream] …`, or pasted into a Workflow improvement issue. Each comes from one project's evidence, so treat it as a hypothesis:

1. **Triage.** Confirm the cause in the plugin's files at the version the report names, and look for other reports of the same problem: several projects reporting it is the strongest evidence. If the fix would only suit the reporting project, decline with the reason; that project's optimizer records it and keeps its local workaround only while it still pays off.
2. **Reproduce.** Add a plugin eval case that fails for the reported reason (`plugins/singularity/evals/`, see its README). Build it from a generic example, never from a project's code.
3. **Fix.** Make the smallest change that does it, the report's proposed fix or a better one. Run the suite on your branch and on `main` (`git worktree add ../baseline main`), and compare case by case: adopt the change only if the new case passes and nothing regresses.
4. **Record.** Add a line under `## [Unreleased]` in `CHANGELOG.md` that names the issue, and describe the change as a contract in the PR. Don't close the issue from the PR: "Fixes #…" closes it at merge, before projects can get it. Close it once the release is out, with a comment naming the version, so the reporting projects' optimizers can check the fix and propose removing their workarounds.

## Before you open a pull request

1. `claude plugin validate --strict .` passes.
2. `pre-commit run --all-files` passes (lint, shellcheck, markdownlint, gitleaks, sensitive-info check, version check).
3. `node scripts/check-evals.js` passes (CI runs it too). If you changed a script under `plugins/singularity/scripts/` or `skills/tracker/scripts/`, or the init-project git-ignore procedure, every `tests/*.test.sh` passes; on macOS, run them with `/bin/bash` too, since CI tests bash 3.2 there, and bash 5 with `mawk` as `awk` on Linux. Keep awk code POSIX. Template Markdown must pass markdownlint's defaults, including the 80-column limit: `plugins/singularity/templates/.markdownlint-cli2.yaml` sets them, and CI checks it.
4. If you changed anything under `plugins/singularity/` other than eval cases, add a line under `## [Unreleased]` in `CHANGELOG.md`, starting with **Breaking:** if projects must change something. Leave the version alone: it changes only in release PRs. `node scripts/version.js check --base origin/main` runs the same check as CI.
5. For agent, skill or workflow changes: run the eval suite once (`plugins/singularity/evals/README.md`) and paste the summary table in the PR. It costs real model calls; use `--case` and `--runs 1` while iterating.
6. Describe the change as a contract where it affects behaviour: what it should fix, what it might break, how you checked.

Commits follow Conventional Commits (`feat:`, `fix:`, `docs:`, `ci:`…).

## Releasing

Maintainers release with `scripts/release.sh <patch|minor|major>` from an up-to-date `main`. It bumps the version on a release branch, opens and merges the `chore(release): singularity <version>` PR, and follows the Release workflow, which tags `singularity--v<version>`, moves the `stable` branch that projects follow, and publishes the GitHub release. Which bump to choose, and what projects see, is in [Versions and releases](README.md#versions-and-releases).
