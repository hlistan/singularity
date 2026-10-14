# Changelog

All notable changes to the singularity plugin are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) as described in [Versions and releases](README.md#versions-and-releases).

Add a line under `[Unreleased]` with every change to the plugin. `scripts/release.sh <level>` turns those lines into a release.

## [Unreleased]

### Added

- `optimization.every_runs: 0` stops `/singularity:feature` offering an optimizer run.
- README: a "How to use" guide covering getting started, usage scenarios, customizing and turning off agents, and creating project agents, pipeline stages and workflows, and a table of contents.
- The optimizer **onboards** the agents to a project: it surveys the repository, its history and recent reviews, fills the project sections of `CLAUDE.md` and the experience files, checks the commands, and proposes the review lenses, stages and role settings that fit, as canaries. `/singularity:init-project` starts it when the setup is done; `/singularity:feature` suggests it for projects that were never onboarded.
- **Upstream reports.** The optimizer never edits the plugin. When a failure's cause is in a shared agent, skill, workflow, standard, template or default, it writes a report in `.claude/singularity/upstream/` (new; `init-project` creates it) with the problem, the evidence, the proposed fix and a contract, written to leave out anything that identifies the project, plus a local workaround if the project needs one. Once the team approves a report, the optimizer offers to file it as an issue in the singularity repository, and follows it up until the fix is released. `CONTRIBUTING.md` describes how maintainers adopt reports.
- Learning from human reviews is part of `/singularity:feature`: every run looks up the PRs/MRs of earlier runs by branch, and once one is merged or closed, the learner turns its review comments into lessons and eval cases. Run digests record `branch` and `change` for this.
- Tracker operations `find_change(branch)`, the PR/MR for a branch with its state and commits, and `list_changes(state, limit)`.
- `optimize-scan` audits the project context (template TODOs, stale lessons, commands that no longer match), and its failure taxonomy and practice scan say whether each fix belongs to the project or the plugin.

### Changed

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
