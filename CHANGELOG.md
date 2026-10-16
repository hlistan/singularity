# Changelog

All notable changes to the singularity plugin are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) as described in [Versions and releases](README.md#versions-and-releases).

Add a line under `[Unreleased]` with every change to the plugin. `scripts/release.sh <level>` turns those lines into a release.

## [Unreleased]

### Added

- **User corrections drive the guidelines.** Two plugin hooks capture prompts in which the user corrects an agent: `UserPromptSubmit` queues a prompt that starts with `correction:` or `defect:`, or matches a phrase in `scripts/correction-patterns.txt` (a project adds its own, in any language, in `.claude/singularity/correction-patterns.txt`), paired with the agent's last message, which the `Stop` hook keeps. The queue is `<work_dir>/corrections/`, and it keeps itself out of git, since prompts can hold secrets. The learn job turns the corrections into guidelines and clears the queue. `/singularity:feature` hands it the queue at every run; outside the pipeline, a new session says when corrections are waiting, and the optimizer picks the learn job when nothing more urgent is due. `learning.corrections: false` turns the capture off. `scripts/corrections.sh` manages the queue.
- **Root cause before any guideline changes.** The learn job gives every defect and correction a cause: `guideline-missing`, `guideline-wrong` or `guideline-unclear` changes a guideline; `guideline-ignored` gets a proposed check, or a move to a rule scoped to its code, instead of more text; `not-guideline` (a slip, a flaky environment, an ambiguous ticket, a request for this task only, a cause in the plugin) changes nothing. What a person or a tool confirmed (a correction, a gate edit, a failed verification, a later fix) counts at once; what only a model confirmed (a review finding) is `pending` until it recurs. Only what the user typed counts as a correction, and no correction can loosen a check, a guardrail or a permission.
- Run digests record each finding's `cause` and `action`, a `defects` list for verification failures and for defects of earlier runs that a run fixes (`source: later-fix`), and `confirms` for the pending entries a recurrence confirms. A new `correction` line records each correction kept, with its role, scope, cause and action, never the prompt's text. The run record keeps each failed verification check, and whether a finding was confirmed only by the challenger.
- Regression eval cases also come from later fixes and from corrections about code the review passed, not only from human reviews.
- `replay-evals` runs each variant several times on every case (`trials`, default 3) and reports which cases are right in most trials, which are right in every trial, and which flip (`flaky`). The optimizer treats a difference of one or two cases, or of flaky cases, as noise (`insufficient evidence`), and judges a canary on whether the defects and corrections it targets stopped.
- Plugin eval cases `optimizer-learn-correction`, `optimizer-learn-drops-non-correction` and `optimizer-learn-ignored-guideline`; `tests/corrections.test.sh` runs in CI on bash 5 and 3.2.
- **Mechanical checks before judgement.** `scripts/run-checks.sh` runs the project's `commands` named in `checks.run` (default build, lint, typecheck, test) and the project's verify hook, with CI=true and no input; pass and fail are exit codes, success prints one line, and each failure prints its command, exit status and output tail. A new **Checks** stage in `/singularity:feature` runs it after implement and before review, with up to 2 fix rounds, and the verifier uses it for its table.
- **Stop gate.** A `SubagentStop` hook (`scripts/subagent-stop.sh`) keeps the implementer, or the project agent bound to the implement role, working while the checks fail, for at most `checks.stop_retries` attempts (default 3). Off with `checks.implement_gate: false`.
- **A baseline of failing checks.** Before implementing, the pipeline records which checks already fail (`run-checks.sh --save-failures`). The stop gate, the checks stage and the verifier report those as failing before the change (`--known-failures`), without sending the implementer after them, and `summary.md` lists them.
- **Test integrity.** The implementer freezes each test once it fails for the right reason (`scripts/test-guard.sh freeze`); a `PreToolUse` hook on `Edit|Write|NotebookEdit` blocks edits to frozen tests, and `test-guard.sh check` reports frozen tests changed or deleted afterwards and existing tests changed or deleted without the plan naming them. Those become blocking findings, which a challenger confirms unless the spec requires the change. The implementer stops and reports when a frozen test is wrong. `checks.test_pattern` sets the paths that count as tests.
- **Sized pipeline.** `/singularity:feature` sizes each change as `small`, `standard` or `large` (or takes `small` / `full` from the request). A small change, one sentence and a few files away from the risk list, gets a short spec, one gate, no plan stage and a correctness review (plus security near the risk list); a large one gets a second, independent correctness pass.
- **One run per checkout.** A run takes a lock in `<work_dir>/.state/active-run`, refuses to start next to another run or on uncommitted work that isn't its own, and points to `claude --worktree` for parallel runs. In a worktree, the files tracker claims tasks in the main checkout's task folder, so claims stay atomic.
- Fix rounds reproduce each blocking finding with a failing test before fixing it; a finding no test can show where a test should be possible is recorded as rejected, by a test. The challenger may answer `uncertain`.
- `scripts/change-diff.sh` prints the whole change against a base, new untracked files included. The pipeline writes it to `change.diff` and `change.stat` for every reviewer.
- `docs/pipeline-design.md`: the research behind the checks, the test guard, the review split, sizing, the run lock and the command guard. Plugin eval case `review-recall-new-file`; `tests/guard-bash.test.sh`, `run-checks.test.sh`, `test-guard.test.sh` and `change-diff.test.sh` run in CI.
- **More correction sources.** Besides prompts that read like a correction, the hooks queue what the user types after interrupting a turn (prompt ids: the turn never reached `Stop`) and after rejecting a tool call (feedback typed in the dialog, or the next prompt, with the rejected call), read from the session transcript on a best-effort basis, since Claude Code doesn't document its format. Pasted content, notifications and other agents' messages are cut before matching; "continue" and "yes" are never queued, and phrases match only once the agent has answered in the session, so a first prompt's "don't commit" isn't queued. Records and `correction` lines carry a `trigger` (`phrase`, `interrupt`, `rejection`); a `StopFailure` hook marks turns that ended on an API error. A correction that only rephrases the request is implicit and changes a guideline when it recurs.
- **Later fixes and reverts.** `scripts/outcomes.sh later-fixes` finds commits on the default branch, from the last 90 days, that fix or revert lines a pipeline run wrote: `git blame -w -M -C` at the fix's parent, attributed through the `Singularity-Run: <slug>` trailer the pipeline now adds when it commits, the run's squash-merged PR/MR or merged branch, or its hand-off snapshot. Every learn job reads up to three, counts a person's fix of the run's defect at once, a revert only for a bug or a wrong approach, and records each in a `later_fix` line. `learning.later_fixes: false` turns it off.
- **People's edits before merge.** At hand-off the pipeline keeps the change as the local ref `refs/singularity/handoff/<slug>` (`outcomes.sh snapshot`, index and working tree untouched). With `learning.pr_reviews`, `outcomes.sh edits` gives the learn job what people changed before merge: edits fixing a defect become escaped defects and eval cases, edits applying a project convention become corrections. `human_review` lines gain `unmodified`, `corrections` and `addressed` (open findings the merged code changed, per lens). Guidelines from a run whose PR/MR closed unmerged are added again when they don't depend on its change.
- **Guideline citations and lifecycle.** Reviewers cite the guideline a finding breaks; the planner and implementer report the guidelines that decided a choice (`cites`, `applied` in the run digest). Citations point the root cause at a guideline and never add one. `optimize-scan` reports each guideline's lifecycle; the optimizer corrects guidelines that work still failed under, moves always-loaded guidelines nobody used to path-scoped rules, replays review guidelines added by learn jobs with and without them, narrows lenses whose findings people rarely address, and proposes a mutation check when weak-test defects recur.
- The stop gate logs each block to `<work_dir>/.state/stop-gate.log`; the run digest records blocks as `stop-gate` defects and checks-stage failures as `checks` defects. The optimizer's dashboard adds stop-gate blocks, changes merged unedited, changes later fixed or reverted, and findings people addressed.
- Plugin eval cases `optimizer-learn-later-fix`, `optimizer-learn-rejection` and `optimizer-learn-handoff-edit`; `tests/outcomes.test.sh` runs in CI.
- `docs/agentic-flow.html`: an interactive schema of the `/singularity:feature` pipeline and the learning loop. Each stage, gate, hook and script opens its contract, rules and limits, and 17 usage scenarios play step by step on the schema.

### Changed

- **Breaking:** singularity has no human review of its own, so learning from human PR/MR review comments is off unless a project sets `learning.pr_reviews: true`. Projects that relied on it must add the setting.
- **Review: correctness and security block, the rest advise.** Only `review.blocking_lenses` (default correctness, security) and `review.extra_reviewers` can block. Other lenses report at most should-fix, run on `review.advisory` (default sonnet · high) and aren't challenged; only blocking findings get a challenger.
- **The command guard reads commands the way a shell splits them**: quotes, escapes, here-documents, `;`, `&&`, `|`, subshells, `bash -c` and `eval`. It now catches `"main"` quoted, `+main` refspecs, `--force-with-lease`, `--mirror`, `--all` with force, deleting a protected branch, `git commit -n`, `core.hooksPath`, `HUSKY=0`, `rm -r -f /`, `rm -rf ~/` and `$HOME` forms, and the project's `conventions.default_branch`; and it no longer blocks a branch named like `fix-format-main` or commands that only mention these in quotes, commit messages or here-documents. The README says what it is: a seatbelt, with branch protection and the sandbox for enforcement.
- The reviewer reads the whole change from `change.diff`, or builds it with `change-diff.sh`, instead of `git diff`. The verifier takes pass and fail from `run-checks.sh` exit codes and confirms the tests are intact.
- The post-edit project hook also runs for `NotebookEdit`.
- Agent definitions, skills, optimizer playbooks, templates, README and docs are rewritten as terse declarative rules, about a quarter fewer words, with every path, command, config key, limit and output contract kept. Agents load less prose per run; behaviour is meant to stay the same.
- Guidelines change only for defects whose root cause is a weak guideline and for user corrections, besides onboarding's first context and keeping guidelines true to the code. An optimization no longer adds a missing guideline on its own judgement, replaces a guideline that keeps being ignored with a check, and acts on `pending` categories that recurred. The optimizer ranks user corrections right after escaped defects, and `optimize-scan` counts corrections, causes, pending categories and ignored guidelines.

### Fixed

- `replay-evals` applied a case's patch without staging it and asked the reviewer for `git diff`, which leaves out every file the patch adds. It now applies the patch with `--index` and reviews `git diff HEAD`.
- The pipeline's reviewers missed every new file: the implementer doesn't commit unless `auto_commit` is on, and `git diff` leaves out untracked files. They now read `change.diff`.
- The command guard missed force-pushes with a quoted branch, `+refspec`s and split `rm` flags, and blocked harmless commands whose text mentioned the patterns.
- The README said teammates get the plugin through the committed settings; Claude Code enables it but doesn't install it, so each teammate runs `claude plugin install singularity@singularity --scope project`.
- Headless runs couldn't save what they learned: Claude Code asks before every write under `.claude/`, where guidelines, the record and eval cases live, and refuses it when nobody can answer. The README and `docs/self-optimization.md` run unattended pipelines and optimizations with `--permission-mode auto`. A learn job whose write is refused now stops without clearing the correction queue (it used to clear it, losing the correction) and returns its changes; the optimizer never retries a refused write through the shell.
- The correction hook queued a session's first prompt when it set the task with "don't commit" or "use X instead". Phrases now match only once the agent has answered in the session; `correction:` and `defect:` still match anywhere.
- The plugin eval command in `evals/README.md` didn't grant `Write` and `Edit`, and even with them `claude plugin eval` runs in `dontAsk` mode, which refuses every write under `.claude/`, so the optimizer cases could never pass. `scripts/eval-auto.js` runs them in auto mode with only the checkout's plugin loaded and applies the same graders. Two graders wanted a guideline in one file where the playbooks put it in another: `optimizer-learn-ignored-guideline` now accepts G1 moved where the reviewer also reads it, `optimizer-onboard-context` looks for project-wide facts in `project.md`.
- `optimize.md` named the run directory `optimizer-<date>/`; the agent definition's `optimizer-<date>-optimize/` is the one used.
- `scripts/check-sensitive.sh` without arguments failed on macOS's bash 3.2 (`mapfile`).
- `docs/models-and-effort.md`: the Factory benchmark's most expensive model, not its second most expensive, ranked near the bottom; the SWE-bench Pro figures come from Anthropic's *Optimizing for cost and intelligence* page, and that subset isn't comparable with the public leaderboard; Ambig-SWE's gain applies to underspecified tasks; Sonnet 5.5's lower score at max was partly a harness effect. `docs/self-optimization.md` describes the Cemri et al. failure split as the paper does.

## [0.5.0] - 2026-10-14

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

[Unreleased]: https://github.com/hlistan/singularity/compare/singularity--v0.5.0...HEAD
[0.5.0]: https://github.com/hlistan/singularity/compare/singularity--v0.4.0...singularity--v0.5.0
[0.4.0]: https://github.com/hlistan/singularity/compare/singularity--v0.3.0...singularity--v0.4.0
[0.3.0]: https://github.com/hlistan/singularity/compare/singularity--v0.2.0...singularity--v0.3.0
[0.2.0]: https://github.com/hlistan/singularity/compare/singularity--v0.1.0...singularity--v0.2.0
[0.1.0]: https://github.com/hlistan/singularity/releases/tag/singularity--v0.1.0
