# Onboard: form the project context

Done when an agent new to this repository can spec, plan, implement, review and verify a change as the team would, towards what its users need. `/singularity:init-project` creates the config and empty guideline files; onboarding fills them and fits the setup.

No `.claude/singularity.md` -> stop; tell the user to run `/singularity:init-project` (it starts onboarding when done).

## 1. Survey (read only)

Answer each question below. Large repository -> one read-only Explore subagent per question, in parallel; answers cite file paths.

| Question | Where to look |
|---|---|
| **Value**: the users and what they rely on; the team's current aim and how it will know; what wins when speed, quality, cost and scope conflict; constraints on the work | README, product docs, roadmap, milestones, the tracker's open epics and recent tickets (`get`, read-only), release notes, incident and support notes |
| **Purpose**: what the project does, main components | README, docs, package metadata, entry points |
| **Architecture**: modules and their interactions, where business logic lives, data stores, external services, generated and vendored code | directory layout, entry points, dependency manifests, infrastructure files |
| **Build and test**: real commands; test layout, frameworks, fixtures, factories; running one test; services tests need; slow or flaky suites; what CI checks | package scripts, Makefile, CI config, test directories, compose files |
| **Conventions** differing from or adding to the shared standards (`<plugin root>/skills/engineering-standards/SKILL.md`): layering, errors, dependency injection, naming, migrations, feature flags, API versioning | the code, linter config, CONTRIBUTING, ADRs |
| **Risk map**: costliest defect spots (authorization, money, personal data, concurrency, migrations, public APIs, client contracts); domain rules a reviewer must know | the code, ADRs, incident and postmortem notes |
| **What the team corrects**: recurring review comments and rework | the last 20 merged PRs/MRs (tracker skill `list_changes(merged, 20)`, then `review_comments` for each; read-only); `git log` fix and revert commits |

Record only what the repository shows, with its paths; anything unestablished is an **open question** for the gate, not a guess. Save findings (with refs) and open questions to `onboarding.md` in the run directory as you go, for resuming.

Work in your own worktree on a `singularity/onboard-<YYYY-MM-DD>` branch ("Your own worktree" in the agent definition); setup not yet committed on the default branch (as when `/singularity:init-project` starts you) -> work in the user's checkout.

## 2. Write the context (tier 1)

**Goals first.** `goals.md` says `Status: confirmed` -> don't redraft; propose changes as a gate diff. Otherwise draft `.claude/singularity/goals.md` from the Value answers: template sections, under about 40 lines, `Status: draft`. Each statement cites (in `onboarding.md`) something the team wrote (README, roadmap, tickets); gaps stay `TODO` and become gate questions. The rest of the context serves them: rank the risk map by harm to users and goals.

Write only what an agent can't quickly learn from the code or would get wrong untold: exact commands and tools, conventions that differ from what the code suggests, domain rules and risks, what not to touch. No repository overviews or directory tours: they didn't help agents navigate, and LLM-written context files lowered task success and raised cost about a fifth (Gloaguen et al., 2026, in `docs/self-optimization.md`).

One home per fact: where its agent reads.

| Fact | Goes to |
|---|---|
| purpose (a sentence or two); architecture facts the code doesn't make obvious (e.g. which service owns which data); conventions differing from the shared standards | `CLAUDE.md` project sections, replacing the template's `TODO`s |
| facts and rules every role needs anywhere | `guidelines/project.md` |
| one part of the code (e.g. migrations) | a rule in `.claude/rules/singularity/<area>.md`, with its `paths` |
| where requirements, ADRs and the domain glossary live; what a spec here must cover | `guidelines/spec.md` |
| module boundaries, where each kind of new code goes, migration and feature-flag patterns | `guidelines/plan.md` |
| running one test, fixtures, code generation, local services | `guidelines/implement.md` |
| risk map, domain rules, intended things that look wrong | `guidelines/review.md` |
| slow or flaky checks, what a run needs, CI checks beyond `commands` | `guidelines/verify.md` |
| generated code, vendored libraries, released migrations | "Do not touch" in `.claude/singularity.md` |

Rules:

- `CLAUDE.md` and `guidelines/project.md` load into every session: `CLAUDE.md` project sections under about 60 lines, `project.md` within its 40 guidelines; point to files, don't copy them.
- Guidelines follow `learn.md`'s format and curation rules: current right way, present tense, wrapped at 80 columns (markdownlint).
- Enforceable by a check (lint rule, test, hook) -> write the guideline and propose the check, whose change removes the guideline.
- Number guidelines from one above the highest id in guideline files, rules and `runs.jsonl`; record them in one `runs.jsonl` curation line: `{"type":"curation","date":"<date>","by":"optimizer","ref":"O-<date>-onboard","guidelines":{"added":["G1","G2"]}}`.
- Don't repeat the shared engineering standards. Never record secrets, credentials, personal or customer data.
- The team's text stays: correct a wrong guideline by editing it; propose `CLAUDE.md` changes as a gate diff, not a rewrite.

## 3. Fit the setup

- **Commands** (tier 1): run every command `init-project` marked failing or left `TODO`, plus `test_one` on a real test file; fix them.
- **Review** (tier 2): `review.extra_lenses` for risks the four shared lenses don't name (e.g. performance for data-heavy code); `review.extra_reviewers` only for domain rules too long for a lens description (start from `review-domain.md.example` in `<plugin root>/templates/project/.claude/agents/`).
- **Stages** (tier 2): a project agent for a check no command covers, e.g. a migration checker `after_implement` if there are migrations.
- **Roles** (tier 2): a model or effort override only with a reason, e.g. Fable not allowed, or a provider alias resolving to an older model (check with `/model`).
- **Hooks** (tier 2): `post-edit.sh` with the project's formatter; `verify.sh` for checks the commands don't cover (e.g. contract tests).

Project agents' model and effort: `docs/models-and-effort.md` in the singularity repository. Each tier-2 change is a proposal with a contract, shipped as a **canary** (no runs yet): name the metric it should move, note there's no baseline yet, check it after 10 runs.

## 4. Baseline eval cases (optional)

Review changes validate only against eval cases; a new project has none. Survey found merged PRs/MRs where a human reviewer caught a real defect -> offer at the gate to turn up to 10 into eval cases, as the feature pipeline does ("Learning from human reviews" in `<plugin root>/skills/feature/SKILL.md`; case format in `learn.md`): the change as first reviewed, its base, the defect to catch. Every 5th case is `holdout: true`.

## 5. Gate

First run `bash "<plugin root>/scripts/check-guidelines.sh"` and fix each finding; a reported non-path span -> `.claude/singularity/guidelines/check-ignore.txt`. Then show the user:

- the draft goals, to correct and confirm;
- the context written: each file, guidelines added, `CLAUDE.md` sections filled, the guideline check's report;
- the open questions;
- the tier-2 proposals as a table: id, change, why (survey evidence), what it should move, check after;
- the eval-case offer, if any.

Add the proposals to `onboarding.md` first, then ask the user to answer the questions, correct and confirm the goals, and choose proposals. Apply the answers and record them in `onboarding.md`; goals confirmed -> set `Status: confirmed <date>`; implement the chosen proposals.

Unattended: tier-1 context and command fixes only. The goals draft goes to `goals.md` with `Status: draft` (nobody can confirm it) and into the PR/MR; the next attended run offers confirmation. Open questions and proposals stay in the run directory.

## 6. Record and deliver

- `optimizations.md`: one entry `O-<date>-onboard · Onboard the agents · tier 1 · adopted`, listing files written and open questions left; one per applied proposal, with its contract and status `canary`.
- Shared-plugin misfits (a standard conflicting with the stack, a gap every project will hit) -> an upstream report (`upstream.md`).
- Setup not yet committed (as when `/singularity:init-project` starts you) -> leave changes uncommitted for the team's setup commit. Otherwise commit on the onboarding branch and deliver as an optimization does (`optimize.md`, step 8).

## Confirming the goals

Due alone when `goals.md` isn't confirmed but the project is otherwise onboarded. Show the draft and each statement's sources (no draft -> re-survey the Value question), take corrections; on confirmation set `Status: confirmed <date>` and record `O-<date>-goals · Goals confirmed · tier 1 · adopted` in `optimizations.md`. Unattended: do nothing; only a person can confirm the goals.

## Refreshing the context

For drift the learn job can't see (it fixes only what a run's own change breaks). The evidence pack's context audit (`optimize.md`, step 1), the guideline check or a request shows drift (guidelines citing gone files, a new module, a stack migration) -> repeat steps 1 to 3 for the changed parts: correct wrong guidelines, remove those whose code is gone; a guideline warning agents off something removed stays only while they still reach for it. Record changes in a curation line.

## Migrating lessons from before 0.5.0

Before 0.5.0 a learner agent kept lessons in `learning.dir` (default `.claude/singularity/experience/`): `project.md` plus one file per role, each lesson with its history (`_Why:_`, `_Seen:_`, `_Last:_`, `_Refs:_`). Requested by `/singularity:feature` -> work in its checkout, leave the result uncommitted; otherwise your own worktree.

1. Check each lesson against the current code (as in step 1); drop those about gone code or contradicted by it.
2. Rewrite each survivor as a guideline without its history: current right way, in its home (step 2's table), numbered from one above any id in use. Merge duplicates. Enforceable by a check -> guideline plus proposed check.
3. Convert `upstream.md` likewise: each candidate becomes its proposed guideline plus an `Evidence:` line (counts and refs from its history). Add `README.md` to `learning.dir` from `<plugin root>/templates/project/.claude/singularity/experience/README.md`.
4. `git rm` the old lesson files; point the `CLAUDE.md` import at `@.claude/singularity/guidelines/project.md`. Keep `runs.jsonl`, `optimizations.md`, `upstream.md` (the record).
5. Find leftover pointers: `grep -rn "singularity/experience/" CLAUDE.md .claude/agents .claude/skills .claude/workflows`; repoint project agents and skills to their guideline file.
6. Check the new files will be committed: `git check-ignore -- .claude/singularity/guidelines/project.md`, and the same per rule written. A `.gitignore` with the 0.4.0 exceptions for `.claude` lacks `!/.claude/rules/` -> add it (as `/singularity:init-project` does).
7. Run the guideline check; fix what it reports.
8. Record the old files' history: one `optimizations.md` entry, `O-<date>-migrate · Lessons to guidelines · tier 1 · adopted`, with a table: lesson id -> guideline id (or `dropped`, with the reason), old _Seen_ and _Refs_; one curation line in `runs.jsonl` with the guidelines added. Deliver as an optimization does (`optimize.md`, step 8), unless you worked in the pipeline's checkout.
