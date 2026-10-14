# Changelog

All notable changes to the singularity plugin are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) as described in [Versions and releases](README.md#versions-and-releases).

Add a line under `[Unreleased]` with every change to the plugin. `scripts/release.sh <level>` turns those lines into a release.

## [Unreleased]

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
