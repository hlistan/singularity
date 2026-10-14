# Onboard: form the project context

The optimizer's playbook for onboarding the agents to a project and to what it is for. The goal: an agent that has never seen this repository can spec, plan, implement, review and verify a change in it the way the team would, towards what the project's users need. `/singularity:init-project` creates the config and the empty guideline files; onboarding fills them with what the agents need to know, and fits the setup to the project.

If `.claude/singularity.md` doesn't exist, stop and tell the user to run `/singularity:init-project` first. It starts the onboarding when it's done.

## 1. Survey (read only)

Answer these questions from the repository, its docs, its history and its code host. On a large repository, give each question to its own read-only subagent (Explore), in parallel, and ask for file paths with every answer.

| Question | Where to look |
|---|---|
| **Value**: who the users are and what they rely on the project for; what the team is working towards now and how it will know; what wins when speed, quality, cost and scope pull apart; the constraints the work must respect | README, product docs, the roadmap or milestones, the tracker's open epics and recent tickets (`get`, read-only), release notes, incident and support notes |
| **Purpose**: what the project does, its main components | README, docs, package metadata, entry points |
| **Architecture**: the modules and how they talk, where the business logic lives, data stores, external services, generated and vendored code | directory layout, entry points, dependency manifests, infrastructure files |
| **Build and test**: the real commands; test layout, frameworks, fixtures and factories; how to run one test; services a test run needs; slow or flaky suites; what CI checks | package scripts, Makefile, CI config, test directories, compose files |
| **Conventions** that differ from or add to the shared standards (`<plugin root>/skills/engineering-standards/SKILL.md`): layering, errors, dependency injection, naming, migrations, feature flags, API versioning | the code, linter config, CONTRIBUTING, ADRs |
| **Risk map**: where a defect costs most (authorization, money, personal data, concurrency, migrations, public APIs and client contracts), and the domain rules a reviewer must know | the code, ADRs, incident and postmortem notes |
| **What the team corrects**: recurring review comments and rework | the last 20 merged PRs/MRs (tracker skill `list_changes(merged, 20)`, then `review_comments` for each; both read-only); `git log` for fix and revert commits |

Write down only what the repository shows, with the paths it rests on. Anything you can't establish is an **open question** for the gate, not a guess. Save the findings, with their refs, and the open questions to `onboarding.md` in the run directory as you go, so that a later invocation can carry on from them.

Write the context and make the changes below in your own worktree, on a `singularity/onboard-<YYYY-MM-DD>` branch ("Your own worktree" in the agent definition). If the setup isn't committed on the default branch yet, as when `/singularity:init-project` starts you, work in the user's checkout instead.

## 2. Write the context (tier 1)

**Goals first.** If `goals.md` says `Status: confirmed`, the team has decided them: don't redraft them; propose any change as a diff at the gate. Otherwise draft `.claude/singularity/goals.md`, in its template's sections and under about 40 lines, from the Value answers, and keep `Status: draft`. Every statement rests on something the team wrote (the README, the roadmap, tickets, release notes): cite it in `onboarding.md`. What you can't find stays a `TODO` and becomes a question at the gate. The goals are the team's: they decide what every later optimization works towards, so the gate is where the team corrects and confirms them, and you only propose changes after that. Write the rest of the context to serve them: rank the risk map by harm to the users and goals.

Write only what an agent can't find out quickly from the code, or would get wrong without being told: the exact commands and tools, conventions that differ from what the code suggests, domain rules and risks, what not to touch. Don't write repository overviews or directory tours. In a study of coding agents, context files written by an LLM lowered task success in most settings and raised cost by about a fifth; overviews didn't help agents find their way, while naming the tools to use did (Gloaguen et al., 2026, cited in `docs/self-optimization.md`). Everything you write is a draft that the team reviews.

Put each fact in the one place the agent that needs it reads, and nowhere else:

| Fact | Goes to |
|---|---|
| what the project is for, in a sentence or two; architecture facts the code doesn't make obvious, such as where the business rules live or which service owns which data; conventions that differ from the shared standards | the project sections of `CLAUDE.md`, replacing the template's `TODO`s |
| how to work anywhere in the codebase: facts and rules every role needs | `guidelines/project.md` |
| how to work in one part of the code (an API layer, the UI, migrations) | a rule in `.claude/rules/singularity/<area>.md`, with the `paths` it applies to |
| where requirements, ADRs and the domain glossary live; what a spec here must cover | `guidelines/spec.md` |
| module boundaries, where new code of each kind goes, migration and feature-flag patterns | `guidelines/plan.md` |
| running one test, fixtures, code generation, local services | `guidelines/implement.md` |
| the risk map, domain rules, things that look wrong but are intended | `guidelines/review.md` |
| slow or flaky checks, what a run needs, what CI checks beyond `commands` | `guidelines/verify.md` |
| generated code, vendored libraries, released migrations | "Do not touch" in `.claude/singularity.md` |

Rules:

- `CLAUDE.md` and `guidelines/project.md` load into every session. Keep the project sections of `CLAUDE.md` under about 60 lines and `project.md` within its 40 guidelines, put what matters for one part of the code in rules, and point to files rather than copying them.
- Guidelines follow the format and curation rules in `learn.md`: the current right way, in the present tense, grounded in the files it names. Wrap at 80 columns: projects lint these files with markdownlint.
- Where a check could enforce a guideline (a lint rule, a test, a hook), write the guideline and also propose the check; the change that adds the check removes the guideline.
- Number guidelines from one above the highest id in the guideline files, the rules and `runs.jsonl`, and record what you wrote in one curation line in `runs.jsonl`: `{"type":"curation","date":"<date>","by":"optimizer","ref":"O-<date>-onboard","guidelines":{"added":["G1","G2"]}}`.
- Don't repeat the shared engineering standards. Never record secrets, credentials, personal or customer data.
- What the team already wrote stays. Correct a wrong guideline by editing it. Propose changes to text the team wrote in `CLAUDE.md` as a diff at the gate instead of rewriting it.

## 3. Fit the setup

From the survey, work out what would make the pipeline fit this project:

- **Commands** (tier 1): run every command `init-project` marked as failing or left as `TODO`, and `test_one` on a real test file, and fix them.
- **Review** (tier 2): `review.extra_lenses` for risks the four shared lenses don't name, such as performance for data-heavy code or accessibility for UI; `review.extra_reviewers` only for domain rules too long for a lens description (start from `review-domain.md.example` in `<plugin root>/templates/project/.claude/agents/`).
- **Stages** (tier 2): a project agent for a check that no command covers, such as a migration checker `after_implement` when the repository has migrations.
- **Roles** (tier 2): a model or effort override only with a reason, such as Fable not being allowed for the organization, or a provider where an alias resolves to an older model (check with `/model`).
- **Hooks** (tier 2): `post-edit.sh` with the project's formatter; `verify.sh` for checks the commands don't cover, such as contract tests.

Choose the model and effort of any project agent with `docs/models-and-effort.md` in the singularity repository. Each tier-2 change is a proposal with a contract. Onboarding has no runs to measure yet, so each ships as a **canary**: name the metric it should move, record that there is no baseline yet, and check it after 10 runs.

## 4. Baseline eval cases (optional)

You can only validate review changes against eval cases, and a new project has none. If the survey found merged PRs/MRs where a human reviewer caught a real defect, offer at the gate to turn up to 10 of them into eval cases, the way the feature pipeline learns from a human review ("Learning from human reviews" in `<plugin root>/skills/feature/SKILL.md`, and the case format in `learn.md`): the change as it was first reviewed, its base, and the defect it should have been caught for. Every 5th case is `holdout: true`.

## 5. Gate

First run `bash "<plugin root>/scripts/check-guidelines.sh"` and fix each finding; a span it reports that isn't a path goes into `.claude/singularity/guidelines/check-ignore.txt`. Then show the user:

- the draft goals, for the team to correct and confirm;
- the context written: each file, the guidelines added and the `CLAUDE.md` sections filled, and what the guideline check reports;
- the open questions;
- the tier-2 proposals, as a table: id, change, why (the survey evidence), what it should move, check after;
- the eval-case offer, if any.

Add the proposals to `onboarding.md` first. Then ask the user to answer the questions, to correct and confirm the goals, and to choose the proposals to apply. Apply the answers to the goals and the context; when the user confirms the goals, set `Status: confirmed <date>`. Implement the chosen proposals.

Unattended: write the tier-1 context and fix the commands only. Nobody can confirm the goals, so write your draft to `goals.md` with `Status: draft`: it goes into the PR/MR with everything else, and the next attended run offers it for confirmation. Leave the open questions and the proposals in the run directory too.

## 6. Record and deliver

- In the run directory, `onboarding.md` holds the survey findings with their refs, the open questions and the proposals, with the user's answers.
- In `optimizations.md`: one entry `O-<date>-onboard · Onboard the agents · tier 1 · adopted`, listing the files written and the open questions left; and one entry per applied proposal, with its contract and status `canary`.
- Anything in the shared plugin that didn't fit this project, such as a standard that conflicts with its stack or a gap every project will hit, becomes an upstream report (`upstream.md`).
- Before the setup is committed, as when `/singularity:init-project` starts you: leave the changes uncommitted, so the team commits them with the rest of the setup. Otherwise commit them on the onboarding branch and deliver as an optimization does (`optimize.md`, step 8).

## Confirming the goals

When `goals.md` isn't confirmed but the project is otherwise onboarded, only this is due. Show the user the draft and the sources behind each statement (survey the Value question again if there is no draft), take their corrections, and when they confirm, set `Status: confirmed <date>`. Record it in `optimizations.md` as `O-<date>-goals · Goals confirmed · tier 1 · adopted`. Unattended, do nothing: only a person can confirm the goals.

## Refreshing the context

The project changes, and its context has to follow. The learn job corrects guidelines that a run's own change makes wrong; this is for the drift it can't see. When the evidence pack's context audit (`optimize.md`, step 1), the guideline check or a request shows that the context has drifted, such as guidelines citing files that are gone, a new module or a stack migration, repeat steps 1 to 3 for the parts that changed: correct the guidelines that are wrong, and remove those whose code is gone, keeping a guideline that tells agents not to reach for something removed only while they still do. Record the changes in a curation line.

## Migrating lessons from before 0.5.0

Until 0.5.0 a separate learner agent kept a log of lessons in `learning.dir` (default `.claude/singularity/experience/`): `project.md` and one file per role, each lesson with its history (`_Why:_`, `_Seen:_`, `_Last:_`, `_Refs:_`). The roles now read guidelines instead. When `/singularity:feature` asks for the migration, work in its checkout and leave the result uncommitted; otherwise work in your own worktree.

1. For each lesson, check it against the code as it is now, as in step 1. A lesson about code that is gone, or one the code contradicts, is dropped.
2. Rewrite each one that still holds as a guideline, without its history: the current right way, where it belongs (step 2's table), numbered from one above any id already in use. Merge lessons that say the same thing. If a check could enforce one, write the guideline and propose the check.
3. Convert `upstream.md` the same way: each candidate becomes the guideline it proposes, followed by an `Evidence:` line with the counts and refs from its history. Add `README.md` to `learning.dir` from `<plugin root>/templates/project/.claude/singularity/experience/README.md`.
4. Remove the old lesson files with `git rm`, and change the import in `CLAUDE.md` to `@.claude/singularity/guidelines/project.md`. Keep `runs.jsonl`, `optimizations.md` and `upstream.md`: they are the record.
5. Find what still points at the old files: `grep -rn "singularity/experience/" CLAUDE.md .claude/agents .claude/skills .claude/workflows`. Point project agents and skills at their guideline file instead.
6. Check that the new files will be committed: run `git check-ignore -- .claude/singularity/guidelines/project.md` and the same for any rule you wrote. A `.gitignore` with the 0.4.0 exceptions for `.claude` lacks `!/.claude/rules/`: add it, as `/singularity:init-project` does.
7. Run the guideline check and fix what it reports.
8. Record the history the old files carried: one entry in `optimizations.md`, `O-<date>-migrate · Lessons to guidelines · tier 1 · adopted`, with a table from each lesson id to its guideline id (or `dropped`, with the reason), and its old _Seen_ and _Refs_; and one curation line in `runs.jsonl` with the guidelines added. Deliver as an optimization does (`optimize.md`, step 8), unless you worked in the pipeline's checkout.
