# Changelog

All notable changes to the singularity plugin are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) as described in [Versions and releases](README.md#versions-and-releases).

Add a line under `[Unreleased]` with every change to the plugin. `scripts/release.sh <level>` turns those lines into a release.

## [Unreleased]

### Added

- `optimization.every_runs: 0` stops `/singularity:feature` offering an optimizer run.
- README: a "How to use" guide covering getting started, usage scenarios, customizing and turning off agents, and creating project agents, pipeline stages and workflows, and a table of contents.
- The optimizer **onboards** the agents to a project: it surveys the repository, its history and recent reviews, fills the project sections of `CLAUDE.md`, writes the first guidelines, checks the commands, and proposes the review lenses, stages and role settings that fit, as canaries. `/singularity:init-project` starts it when the setup is done; `/singularity:feature` suggests it for projects that were never onboarded.
- **Upstream reports.** The optimizer never edits the plugin. When a failure's cause is in a shared agent, skill, workflow, standard, template or default, it writes a report in `.claude/singularity/upstream/` (new; `init-project` creates it) with the problem, the evidence, the proposed fix and a contract, written to leave out anything that identifies the project, plus a local workaround if the project needs one. Once the team approves a report, the optimizer offers to file it as an issue in the singularity repository, and follows it up until the fix is released. `CONTRIBUTING.md` describes how maintainers adopt reports.
- Learning from human reviews is part of `/singularity:feature`: every run looks up the PRs/MRs of earlier runs by branch, and once one is merged or closed, the learn job turns its review comments into guidelines and eval cases. Run digests record `branch` and `change` for this.
- `scripts/check-guidelines.sh`: reports paths that guidelines name but that don't exist (relative to the root or any directory; git-ignored paths count), rules without `paths`, unquoted or unmatched `paths` patterns (with Claude Code's glob rules and brace expansion), guideline ids used twice, and wording left from the lesson log. Spans listed in `.claude/singularity/guidelines/check-ignore.txt` aren't treated as paths. The learn job runs it before it finishes, and onboarding and the context audit use it.
- `optimize-scan` audits the guidelines: history written in place of guidance, duplicates and contradictions, guidelines that belong in a path-scoped rule, and guidelines a lint rule, test or hook could enforce. The failure taxonomy says whether a failure recurred after the guideline meant to prevent it.
- Tracker operations `find_change(branch)`, the PR/MR for a branch with its state and commits, and `list_changes(state, limit)`.
- `optimize-scan` audits the project context (template TODOs, guidelines about code that is gone, commands that don't match the scripts), and its failure taxonomy and practice scan say whether each fix belongs to the project or the plugin.

### Changed

- **Breaking:** the learner and the optimizer are one agent, `singularity:optimizer`, which leads the harness towards operational perfection for the project. The learner's work is its **learn** job, which `/singularity:feature` runs as its learn step at opus · high (`roles.learn` sets the job's model and effort; `roles.learn.agent` no longer applies, and the optimizer's binding, `roles.optimize.agent`, covers both). The learn job changes only guidelines, the record and eval cases, and records larger changes as `proposals` for the next optimization. `agents/learner.md` is gone; its procedure is `optimizer/learn.md`.
- The optimizer optimizes towards what the project is for. `.claude/singularity/goals.md` (new; `init-project` creates it) holds the users, the value they get, the goals now, the trade-offs and the constraints. The optimizer drafts it at onboarding for the team to confirm, and after that only proposes changes (tier 3). The spec names the goal the work serves, the planner follows the trade-off order, and every proposal names its goal and is ranked by harm to the goals and their users.
- Safeguards for the merged agent: the learn job does no web research and starts no subagents; contracts are judged on what the pipeline records mechanically, and keep verdicts go to the challenger; unattended optimizations implement a behaviour change only with a passing replay (canaries wait for a person); removing a review lens, extra reviewer or project stage is tier 3. `goals.md` carries `Status: draft` until the team confirms it, and the spec writer and planner use it only once confirmed. The learn step now runs before the hand-off commit, so its changes go into the same commit and PR/MR, and after an early stop, so stopped runs reach the record.
- Flow, not just quality: the run record keeps gate wait times, the kind of work, its goal and why a run stopped; the digest adds `lead_s`, `active_s`, `gate_wait_s`, `fix_rounds`, `stopped` and `fixes` (a later run fixing a pipeline change); `human_review` lines add `outcome` and `review_s`; and `find_change` returns when a PR/MR was opened and merged. `optimize-scan` reports lead time, flow efficiency, waiting, rework and the change-failure rate, and a new `value` stream reports how the effort splits across the goals and where quality problems hit what users rely on.
- **Breaking:** learning keeps **guidelines**, not a log of lessons. A guideline states the current right way to work in the project, in the present tense, names the files it depends on, and changes in the same run as the code it describes: the learn job corrects or removes guidelines that a run's change makes wrong, and never keeps "no longer" notes. Their history (`_Why:_`, `_Seen:_`, `_Last:_`, `_Refs:_`) moves out of the agents' context into the record: the run digest's `guidelines` field (added, changed, removed) replaces `lessons_added` and `lessons_reinforced`, and `human_review` lines carry it too; a finding or escaped defect records the `guideline` written for it and the guideline that should have prevented it (`covered_by`); `proposed_checks` and `full` replace notes in the learn job's report; and the optimizer appends `curation` lines for the guidelines it writes. Ids are never reused. A guideline that a check could enforce is kept until the check exists. The research behind this is in `docs/self-optimization.md`.
- **Breaking:** the files the agents read move to `.claude/singularity/guidelines/` (`project.md`, which `CLAUDE.md` now imports, and one file per role). Guidelines for one part of the code go in path-scoped rules, `.claude/rules/singularity/<area>.md`, which Claude Code loads only when an agent works on matching files; the `init-project` git-ignore exceptions now keep `.claude/rules/`. `.claude/singularity/experience/` keeps only the record (`runs.jsonl`, `optimizations.md`, `upstream.md`). For projects that still have lesson files, `/singularity:feature` has the optimizer migrate them first, in its checkout, as part of the run's change (an attended run can stop instead): it checks each lesson against the code, rewrites the ones that hold as guidelines, drops the rest, converts `upstream.md`, repoints project agents, adds `!/.claude/rules/` to a 0.4.0 `.gitignore` block, and records a lesson-to-guideline map in `optimizations.md`. Asked for directly, the optimizer migrates on its own branch and opens a draft PR/MR.
- Onboarding writes only what agents can't find out quickly for themselves (exact commands and tools, non-obvious conventions, risks, what not to touch) and no repository overview, following research that LLM-written context files and overviews don't help coding agents. The `CLAUDE.md` template asks for a sentence or two on the project, and architecture facts the code doesn't make obvious.
- **Breaking:** the optimizer is an agent, not a command. Ask for `@agent-singularity:optimizer` in a session, or run `claude --agent singularity:optimizer`; `/singularity:feature` offers it when it is due. Its procedures are playbooks in `plugins/singularity/optimizer/`. As a subagent it stops at each decision with a **Decision needed** block for the session to show you. Scheduled runs ask for it by name, for example `claude -p "Use the singularity:optimizer agent: optimize, unattended"`.
- **Breaking:** `/singularity:feature` runs the review stage itself: one reviewer agent per lens and per project reviewer, then a challenger per finding, as the removed `deep-review` workflow did. To review a branch outside the pipeline, ask for `@agent-singularity:reviewer`.
- The reviewer's Task C also challenges upstream reports: is the cause really in the plugin, would the fix suit other projects, and does the report identify the project?
- `optimize-scan` no longer takes a `scope` argument.
- The optimizer's change tiers, for a project: adding a "Do not touch" entry is curation (tier 1) and removing one is oversight (tier 3); adding a check to the project's `verify.sh` or `post-edit.sh` is a behaviour change (tier 2) and removing or weakening one is tier 3; the optimize role's own binding, model and effort are tier 3. The optimizer makes its changes in a worktree of its own, so a pipeline run's uncommitted work is never mixed in.
- `/singularity:feature` keeps a finding whose challenger failed twice, marked unverified, instead of dropping it.

### Removed

- **Breaking:** `/singularity:optimize`, with its `shared` scope and `optimizer/projects.example.yaml`. Maintainers learn from projects through their upstream reports instead.
- **Breaking:** `/singularity:deep-review` (the `deep-review` workflow) and `/singularity:learn`. Review and learning, including learning from human PR/MR reviews, are stages of `/singularity:feature`.

### Fixed

- `/singularity:feature` said what to do only when an `after_plan` stage agent reported a blocking problem. Every project stage now works the same way: the pipeline shows the problem and asks whether to fix it and re-run the agent, continue anyway, or stop. Unattended runs stop, as they do on remaining review blockers.
- `/singularity:feature` passes the four shared review lenses when the config lists only `review.extra_lenses`, instead of reviewing through the extra lenses alone. It also gives the verifier the spec path, and says what an unattended run is: a scheduled or headless run where nobody can answer. `no-gates` on its own only skips the gates.
- The `review-domain` agent template said `/singularity:feature` picks it up because its name starts with `review-`. Only agents listed in `review.extra_reviewers` run, and the template now says so.

## [0.4.0] - 2026-10-14

### Fixed

- Files tracker: the documented `statuses: { in_review: PROGRESS }` was rejected with "status prefix PROGRESS used twice", so a project that copied it had no working tracker. States other than `todo` can now share a prefix; moving a task to a state that shares its current prefix keeps the file name. `todo` still needs a prefix of its own, because claiming a task relies on renaming it out of the queue. The tests now run every `statuses` and `extra_statuses` example in the docs.
- Files tracker: an empty `--from` value matched as a status, so the move went ahead unchecked.
- `/singularity:init-project` checks that the files the team shares (`CLAUDE.md`, `.claude/singularity.md`, `.claude/settings.json`, experience, evals, project agents) aren't git-ignored. When `.claude` is ignored, it proposes the `.gitignore` exceptions in `templates/project/gitignore-claude.txt`, which keep personal files such as `settings.local.json` local.
- Template Markdown passes markdownlint's default rules, including the 80-column line length, so projects that lint Markdown still pass after setup. The learner and optimizer wrap what they write to experience files and eval cases at 80 columns, and a wrapped lesson counts once toward `learning.max_lines_per_file`, so a project's lesson capacity doesn't change.

### Added

- Resuming: `/singularity:feature <ticket>` on a ticket already in progress, blocked or in review asks whether to resume it, then continues in its existing work dir from the first unfinished stage. `next` never resumes. The run record is now written to `run.json` in the work dir after every stage and gate, so a crashed run can be resumed and still learned from.
- `tasks.sh move --from` accepts several states (`--from in_progress,blocked,in_review`), so a resume is still a checked move rather than a hand rename.
- README: how to switch a running session to a new release (`/plugin marketplace update singularity`, then `/reload-plugins`).

## [0.3.0] - 2026-10-14

### Added

- File-based task tracker (`tracker.type: files`). Each task is a file named `STATUS-ID-slug` in a git-ignored folder (default `.tasks/`), with the statuses `TODO`, `PROGRESS`, `REVIEW`, `BLOCKED` and `DONE`. A project can rename them, and declare any other statuses it uses (such as `QA` or `ON_HOLD`) in `tracker.files.extra_statuses`. `skills/tracker/scripts/tasks.sh` does the parsing, renames, log entries and new IDs, and refuses to work in a folder that isn't git-ignored.
- `/singularity:feature next` takes the first `TODO` task by priority, then ID, and claims it with an atomic rename, so parallel sessions never take the same task.
- Tracker operation `next()`, and the logical states `todo` and `blocked`. When the pipeline stops on remaining blockers or failed verification, it moves the ticket to `blocked`, on trackers that map that state.
- `code_host.type: none`, for projects without a GitHub or GitLab remote.

## [0.2.0] - 2026-10-14

### Changed

- The verify role runs at `medium` effort (was `low`). Lower effort makes fewer tool calls, and the coverage summary needs judgment. Shipped as a canary: see `docs/models-and-effort.md`.
- `/singularity:feature` runs implement fix rounds (blocking review findings, failed verification) at `high` effort, unless the project sets `roles.implement.effort`. Per-call effort needs Claude Code v2.1.292 or later.
- The `review-domain` agent template sets `effort: high`. Without it the agent ran at Opus 5.5's default, `medium`.
- The config template suggests `{ model: opus, effort: high }` for review when Fable isn't available (was `xhigh`).

### Added

- `docs/models-and-effort.md`: the evidence behind each role's model and effort, open trials, and how to choose model and effort for a project's own agents.

## [0.1.0] - 2026-10-13

### Added

- Plugin with six roles (spec, plan, implement, review, verify, learn) plus the workflow optimizer.
- `/singularity:feature`, `/singularity:deep-review`, `/singularity:learn`, `/singularity:optimize`, `/singularity:init-project`.
- Tracker adapters for Jira, GitHub and GitLab.
- Per-project experience, eval cases and optimization archive.
- Shared engineering standards preloaded into every code-facing role.
- CI: lint, manifest validation, eval-case smoke check, gitleaks and internal-information checks.
- Versioned releases: the version lives in `plugin.json`, `scripts/version.js` checks it and prepares releases, and merging a version bump tags `singularity--v<version>`, moves the `stable` branch and publishes a GitHub release.
- Projects follow the `stable` branch (`ref: stable` in the `init-project` settings template), so they only receive released versions.
- Run digests record the `plugin_version` each run used, so the optimizer can compare releases.

[Unreleased]: https://github.com/hlistan/singularity/compare/singularity--v0.4.0...HEAD
[0.4.0]: https://github.com/hlistan/singularity/compare/singularity--v0.3.0...singularity--v0.4.0
[0.3.0]: https://github.com/hlistan/singularity/compare/singularity--v0.2.0...singularity--v0.3.0
[0.2.0]: https://github.com/hlistan/singularity/compare/singularity--v0.1.0...singularity--v0.2.0
[0.1.0]: https://github.com/hlistan/singularity/releases/tag/singularity--v0.1.0
