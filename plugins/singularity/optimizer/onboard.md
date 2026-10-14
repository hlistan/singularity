# Onboard: form the project context

The optimizer's playbook for onboarding the agents to a project. The goal: an agent that has never seen this repository can spec, plan, implement, review and verify a change in it the way the team would. `/singularity:init-project` creates the config and the empty experience files; onboarding fills them with what the agents need to know, and fits the setup to the project.

If `.claude/singularity.md` doesn't exist, stop and tell the user to run `/singularity:init-project` first. It starts the onboarding when it's done.

## 1. Survey (read only)

Answer these questions from the repository, its docs, its history and its code host. On a large repository, give each question to its own read-only subagent (Explore), in parallel, and ask for file paths with every answer.

| Question | Where to look |
|---|---|
| **Purpose**: what the project does, for whom, its main components | README, docs, package metadata, entry points |
| **Architecture**: the modules and how they talk, where the business logic lives, data stores, external services, generated and vendored code | directory layout, entry points, dependency manifests, infrastructure files |
| **Build and test**: the real commands; test layout, frameworks, fixtures and factories; how to run one test; services a test run needs; slow or flaky suites; what CI checks | package scripts, Makefile, CI config, test directories, compose files |
| **Conventions** that differ from or add to the shared standards (`<plugin root>/skills/engineering-standards/SKILL.md`): layering, errors, dependency injection, naming, migrations, feature flags, API versioning | the code, linter config, CONTRIBUTING, ADRs |
| **Risk map**: where a defect costs most (authorization, money, personal data, concurrency, migrations, public APIs and client contracts), and the domain rules a reviewer must know | the code, ADRs, incident and postmortem notes |
| **What the team corrects**: recurring review comments and rework | the last 20 merged PRs/MRs (tracker skill `list_changes(merged, 20)`, then `review_comments` for each; both read-only); `git log` for fix and revert commits |

Write down only what the repository shows, with the paths it rests on. Anything you can't establish is an **open question** for the gate, not a guess. Save the findings, with their refs, and the open questions to `onboarding.md` in the run directory as you go, so that a later invocation can carry on from them.

Write the context and make the changes below in your own worktree, on a `singularity/onboard-<YYYY-MM-DD>` branch ("Your own worktree" in the agent definition). If the setup isn't committed on the default branch yet, as when `/singularity:init-project` starts you, work in the user's checkout instead.

## 2. Write the context (tier 1)

Put each fact in the one place the agent that needs it reads, and nowhere else:

| Fact | Goes to |
|---|---|
| purpose, users, main components; architecture; conventions that differ from the shared standards | the project sections of `CLAUDE.md`, replacing the template's `TODO`s |
| codebase facts and gotchas every role needs | `experience/project.md` |
| where requirements, ADRs and the domain glossary live; what a spec here must cover | `experience/spec.md` |
| module boundaries, where new code of each kind goes, migration and feature-flag patterns | `experience/plan.md` |
| running one test, fixtures, code generation, local services | `experience/implement.md` |
| the risk map, domain rules, things that look wrong but are intended | `experience/review.md` |
| slow or flaky checks, what a run needs, what CI checks beyond `commands` | `experience/verify.md` |
| generated code, vendored libraries, released migrations | "Do not touch" in `.claude/singularity.md` |

Rules:

- `CLAUDE.md` and `project.md` load into every session. Keep the project sections of `CLAUDE.md` under about 60 lines and `project.md` within its 40 lessons, and point to files rather than copying them.
- Lessons follow the learner's format and curation rules (`<plugin root>/agents/learner.md`), with `_Seen:_ 1`, `_Last:_ <today>` and `_Refs:_ onboarding <date>, <paths>`. Wrap at 80 columns: projects lint these files with markdownlint.
- Don't repeat the shared engineering standards. Never record secrets, credentials, personal or customer data.
- What the team already wrote stays. Correct a wrong lesson by editing it. Propose changes to text the team wrote in `CLAUDE.md` as a diff at the gate instead of rewriting it.

## 3. Fit the setup

From the survey, work out what would make the pipeline fit this project:

- **Commands** (tier 1): run every command `init-project` marked as failing or left as `TODO`, and `test_one` on a real test file, and fix them.
- **Review** (tier 2): `review.extra_lenses` for risks the four shared lenses don't name, such as performance for data-heavy code or accessibility for UI; `review.extra_reviewers` only for domain rules too long for a lens description (start from `review-domain.md.example` in `<plugin root>/templates/project/.claude/agents/`).
- **Stages** (tier 2): a project agent for a check that no command covers, such as a migration checker `after_implement` when the repository has migrations.
- **Roles** (tier 2): a model or effort override only with a reason, such as Fable not being allowed for the organization, or a provider where an alias resolves to an older model (check with `/model`).
- **Hooks** (tier 2): `post-edit.sh` with the project's formatter; `verify.sh` for checks the commands don't cover, such as contract tests.

Choose the model and effort of any project agent with `docs/models-and-effort.md` in the singularity repository. Each tier-2 change is a proposal with a contract. Onboarding has no runs to measure yet, so each ships as a **canary**: name the metric it should move, record that there is no baseline yet, and check it after 10 runs.

## 4. Baseline eval cases (optional)

You can only validate review changes against eval cases, and a new project has none. If the survey found merged PRs/MRs where a human reviewer caught a real defect, offer at the gate to turn up to 10 of them into eval cases, the way the feature pipeline learns from a human review ("Learning from human reviews" in `<plugin root>/skills/feature/SKILL.md`, and the case format in `learner.md`): the change as it was first reviewed, its base, and the defect it should have been caught for. Every 5th case is `holdout: true`.

## 5. Gate

Show the user:

- the context written: each file, the lessons added and the `CLAUDE.md` sections filled;
- the open questions;
- the tier-2 proposals, as a table: id, change, why (the survey evidence), what it should move, check after;
- the eval-case offer, if any.

Add the proposals to `onboarding.md` first. Then ask the user to answer the questions and to choose the proposals to apply. Apply the answers to the context, and implement the chosen proposals.

Unattended: write the tier-1 context and fix the commands only. Leave the open questions and the proposals in the run directory.

## 6. Record and deliver

- In the run directory, `onboarding.md` holds the survey findings with their refs, the open questions and the proposals, with the user's answers.
- In `optimizations.md`: one entry `O-<date>-onboard · Onboard the agents · tier 1 · adopted`, listing the files written and the open questions left; and one entry per applied proposal, with its contract and status `canary`.
- Anything in the shared plugin that didn't fit this project, such as a standard that conflicts with its stack or a gap every project will hit, becomes an upstream report (`upstream.md`).
- Before the setup is committed, as when `/singularity:init-project` starts you: leave the changes uncommitted, so the team commits them with the rest of the setup. Otherwise commit them on the onboarding branch and deliver as an optimization does (`optimize.md`, step 8).

## Refreshing the context

The project changes, and its context has to follow. When the evidence pack's context audit (`optimize.md`, step 1) or a request shows that the context has drifted, such as lessons citing files that no longer exist, a new module or a stack migration, repeat steps 1 to 3 for the parts that changed, and correct stale lessons by editing them.
