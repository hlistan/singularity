# Project Singularity

[![CI](https://github.com/hlistan/singularity/actions/workflows/ci.yml/badge.svg)](https://github.com/hlistan/singularity/actions/workflows/ci.yml) [![Sensitive information checks](https://github.com/hlistan/singularity/actions/workflows/sensitive-info.yml/badge.svg)](https://github.com/hlistan/singularity/actions/workflows/sensitive-info.yml) [![Release](https://img.shields.io/github/v/release/hlistan/singularity?display_name=release&label=release)](https://github.com/hlistan/singularity/releases/latest) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A self-improving harness for autonomous software delivery with [Claude Code](https://code.claude.com), packaged as **one plugin**. Shared behaviour (agents, pipelines, guardrails, standards) lives here; project repos hold only their config, own agents and workflows, experience and eval cases. A release here reaches every project.

> **Status:** early: the structure validates and workflows pass dry runs; pipelines are not yet exercised at scale on real projects. Feedback and experience reports: [CONTRIBUTING.md](CONTRIBUTING.md).

Loaded from this git repository via `marketplace.json`; no registry. Projects follow [versioned releases](#versions-and-releases). Start: [Getting started](#getting-started).

## Contents

- [The pipeline](#the-pipeline)
- [How to use](#how-to-use)
  - [Getting started](#getting-started)
  - [Usage scenarios](#usage-scenarios)
    - [Implement a feature from a tracker ticket](#implement-a-feature-from-a-tracker-ticket)
    - [Implement a feature from a prompt](#implement-a-feature-from-a-prompt)
    - [Work through a queue of task files](#work-through-a-queue-of-task-files)
    - [Fix a defect or apply a refactoring](#fix-a-defect-or-apply-a-refactoring)
    - [Run without the approval gates](#run-without-the-approval-gates)
    - [Resume an interrupted run](#resume-an-interrupted-run)
    - [Teach the agents by correcting them](#teach-the-agents-by-correcting-them)
    - [Learning from human reviews](#learning-from-human-reviews)
    - [Review a branch without the pipeline](#review-a-branch-without-the-pipeline)
    - [The optimizer: onboard, optimize, report upstream](#the-optimizer-onboard-optimize-report-upstream)
  - [Customizing agents and turning them off](#customizing-agents-and-turning-them-off)
    - [Change a role's model or effort](#change-a-roles-model-or-effort)
    - [Give the agents project knowledge](#give-the-agents-project-knowledge)
    - [Tune the review](#tune-the-review)
    - [Hooks](#hooks)
    - [Turn things off](#turn-things-off)
  - [Creating custom roles and agents](#creating-custom-roles-and-agents)
    - [Write the agent](#write-the-agent)
    - [Replace a role's agent](#replace-a-roles-agent)
    - [Add a reviewer](#add-a-reviewer)
    - [Add a pipeline step](#add-a-pipeline-step)
    - [Add a workflow or a command](#add-a-workflow-or-a-command)
    - [Let custom agents learn](#let-custom-agents-learn)
- [Roles and models](#roles-and-models)
- [Trackers](#trackers)
- [Guidelines and self-optimization](#guidelines-and-self-optimization)
- [Layout](#layout)
- [Changing the shared setup](#changing-the-shared-setup)
- [Versions and releases](#versions-and-releases)
  - [What the version means](#what-the-version-means)
  - [Release](#release)
  - [Pin a project to a release](#pin-a-project-to-a-release)
- [Security and contributing](#security-and-contributing)
- [License](#license)

## The pipeline

```text
/singularity:feature <ticket>

 tracker.get ─▶ size ─▶ spec ─▶ [gate] ─▶ plan† ─▶ [gate]† ─▶ after_plan* ─▶ implement ─▶ after_implement*
                                                                  (stop hook: can't finish while checks fail)
                                                                                         │
 learn ◀─ hand-off ◀─ before_handoff* ◀─ verify ◀─ fix blockers (≤2) ◀─ review ◀─ checks (exit codes)
   │                                                   (blocking lenses challenged, advisory lenses advise)
   └─▶ guidelines from defects and your corrections (fast loop)     every ~10 runs ─▶ optimizer agent (slow loop)
                                          * = project-defined stages   † = not for small changes
```

| Command | What it does |
|---|---|
| `/singularity:feature <ticket \| defect \| refactoring> [small \| full]` | The whole delivery, sized to the change: gated spec and plan (small changes skip the plan), implementation with frozen tests, checks, a review where correctness and security can block, verification, hand-off, learning |
| `/singularity:init-project` | Sets up a project repo, then has the optimizer onboard the agents to it |

Everything else is agents, run by the pipeline or called by name (`@agent-singularity:<name>`); you call the [optimizer](#the-optimizer-onboard-optimize-report-upstream) yourself. `/singularity:` also lists `optimize-scan` and `replay-evals`: internal optimizer workflows (Claude Code lists every plugin workflow); ask for the optimizer instead.

Every stage, gate, hook and script, with playable usage scenarios: open [`docs/agentic-flow.html`](docs/agentic-flow.html) in a browser.

## How to use

Run everything below in a Claude Code session started from the project root; project choices live in one committed file, `.claude/singularity.md`.

### Getting started

**Before you start**, you need:

- Claude Code v2.1.292 or later, local (terminal, IDE or desktop app): cloud sessions don't load plugins from repository settings.
- The project in a git repository.
- Tracker access: Jira via the Atlassian MCP server (added by `init-project`; each person signs in once with `/mcp`); GitHub via a signed-in `gh` CLI; GitLab via a signed-in `glab` CLI; task files: nothing.
- Fable for review and optimize; otherwise Claude Code falls back ([Roles and models](#roles-and-models)), or [choose a model](#change-a-roles-model-or-effort).

**1. Install the plugin, once per machine.**

```bash
claude plugin marketplace add hlistan/singularity#stable
claude plugin install singularity@singularity
```

Teammates on a set-up project: step 4.

**2. Set up the project.** In the project root: `/singularity:init-project`. It creates these files (never overwrites; asks before adding):

| File | What it holds |
|---|---|
| `.claude/singularity.md` | Project config: commands, conventions, tracker, overrides |
| `.claude/settings.json` | Marketplace and enabled plugin, for the whole team |
| `CLAUDE.md` | Imports the config and project guidelines into every session |
| `.claude/singularity/goals.md` | What the project is for |
| `.claude/singularity/guidelines/` | Agent guidelines: one file every session loads, one per role |
| `.claude/singularity/experience/` | Learning record: run digests, the optimizer's archive |
| `.claude/singularity/evals/` | Regression cases (real escaped defects, known false positives) the optimizer validates against |
| `.claude/singularity/upstream/` | Upstream reports on singularity itself, with proposed fixes |
| `.mcp.json` | Jira only: the Atlassian MCP server |
| `.tasks/` | Task files only: the task folder, git-ignored |

It also test-runs each project command, confirms the tracker with you, offers optional hook scripts and example agents, has the optimizer **onboard the agents** ([details](#the-optimizer-onboard-optimize-report-upstream)), and checks git-ignore: shared files tracked; work dir, task folder, `.claude/settings.local.json` ignored.

**3. Check what onboarding wrote, and fill in the gaps.** Confirm `goals.md` once it matches the team's aims; pick the optimizer's proposals; fix errors in `CLAUDE.md` and `.claude/singularity/guidelines/project.md`, which every agent reads. Answer open questions; replace each listed `TODO`, above all in `commands` in `.claude/singularity.md`: the verifier runs them, the implementer uses `test_one` for targeted tests, so a wrong command costs every run.

Leave `roles`, `stages` and `review.extra_*` empty unless changing something: omitted keys follow shared defaults, which new releases keep improving.

**4. Commit the files**, ideally via a PR for team review. The committed `.claude/settings.json` enables singularity for everyone who clones and trusts the folder but doesn't download it: each teammate runs `claude plugin install singularity@singularity --scope project` once (until then, `/plugin`'s Errors tab shows it enabled but not installed).

**5. Check it.** New session:

- `claude plugin list` (terminal): `singularity@singularity` and its version;
- `/singularity:` lists the commands; `@agent-singularity:` the shared agents.

Then try a small ticket, gates on (first scenario).

**Updates:** [Release](#release); to hold one release, [Pin a project to a release](#pin-a-project-to-a-release).

### Usage scenarios

Each `/singularity:feature` run keeps its files in `<work_dir>/<slug>/` (`conventions.work_dir`, default `.agentic/work/`, git-ignored): `spec.md`, `plan.md`, `review.md`, `summary.md`, first spec and plan drafts, `run.json` (crash-resume record).

#### Implement a feature from a tracker ticket

```text
/singularity:feature ABC-123
/singularity:feature https://github.com/org/repo/issues/42
```

1. **Ticket.** Read, moved to in progress, sized `small` (one-sentence change, few files, away from risky areas: authorization, payments, migrations, public APIs), `standard` or `large`; `small` or `full` in the command overrides.
2. **Spec, then a gate.** `spec.md`: acceptance criteria, open questions. Answer, request changes or edit it, then approve; the learn job diffs your final spec against the first draft, so edits teach the next run.
3. **Plan, then a gate.** Same for `plan.md` (approach, steps, risks). Small changes skip it: the acceptance criteria are the plan.
4. **Implement.** On the `conventions.branch` branch, plan step by step, test first. A test freezes once it fails for the right reason; the plugin then blocks edits to it. On "done", a hook runs the checks, sending the implementer back while they fail.
5. **Checks.** The pipeline runs build, lint, type check and tests (`checks.run`); exit code = pass/fail. Pre-run failures (recorded first) are listed in the summary, not counted against the change. Also reported: tests changed after freezing; existing tests changed or deleted without the plan naming them. Failures return to the implementer before review.
6. **Review.** One reviewer per lens and per project reviewer, on the whole change incl. new files. A second reviewer challenges each blocking finding; the implementer reproduces it with a failing test, then fixes; at most two rounds. Blocking lenses: [Tune the review](#tune-the-review).
7. **Verify.** Checks rerun, each acceptance criterion mapped to a passing test, tests confirmed intact. Failure -> one fix round.
8. **Hand-off.** `summary.md` and a short report. Commit only if `conventions.auto_commit` is true; draft PR/MR only if `conventions.auto_pr` is true or you ask; ticket -> in review, with the link. Task files go to review regardless.
9. **Learn.** The learn job updates the guidelines and lists each one added, changed or removed, with its cause ([Teach the agents by correcting them](#teach-the-agents-by-correcting-them)).

Blockers left after the fix rounds, or failing checks or verification -> the run stops, comments reason and work dir on the ticket, moves it to blocked (task files always; Jira, GitHub, GitLab if `tracker.states` maps `blocked`). Fix, resume.

One run per checkout: a second `/singularity:feature` stops, naming the holder. Parallel tickets -> a worktree per session, `claude --worktree <name>` (or `-w`): own checkout and work dir; the files tracker still claims from the main checkout's task folder.

#### Implement a feature from a prompt

```text
/singularity:feature Add CSV export to the orders page. Admins only, same filters as the table, at most 10,000 rows.
```

The text is the ticket: same pipeline, no tracker reads or updates, work dir named after the request (e.g. `.agentic/work/orders-csv-export/`). Write it like a ticket (audience, expected behaviour, constraints, done criteria); gaps return as open questions at the spec gate.

#### Work through a queue of task files

With `tracker.type: files`, a task is a file in the task folder prefixed with its status, e.g. `.tasks/TODO-T12-orders-csv-export.md`:

```markdown
---
priority: 1
---
# Add CSV export to the orders page

Admins only, same filters as the table, at most 10,000 rows.
```

Create it, or ask Claude to. Then:

```text
/singularity:feature next      # the first TODO task: lowest priority number, then ID
/singularity:feature T12       # a task you name
```

Claiming and statuses: [Trackers](#trackers). Other trackers have no queue: `next` asks which ticket to take.

#### Fix a defect or apply a refactoring

```text
/singularity:feature ABC-456
/singularity:feature Defect: saving a draft with an empty title returns 500 instead of 400
/singularity:feature Refactoring: replace the hand-written retry loops in api/ with RetryPolicy
```

Same pipeline, adapted: a defect spec starts with the reproduction; the plan's first step is a failing test reproducing it. Refactoring: `conventions.breaking_changes` says whether backward compatibility may be dropped; client contracts are tested either way.

#### Run without the approval gates

```text
/singularity:feature ABC-123 no-gates
```

Small, well-specified tickets; scheduled or headless runs (`claude -p --permission-mode auto "/singularity:feature ABC-123 no-gates"`: Claude Code asks before every write under `.claude/`, where guidelines and the record live, and headless outside auto mode nobody can answer, so the learn step saves nothing). Review, verification and their stop rules still apply; commits and PRs/MRs follow `conventions`. Scheduled or headless runs never resume a ticket in progress, blocked or in review, and leave finished task files in review.

#### Resume an interrupted run

Session died or run stopped on blockers -> rerun the command:

```text
/singularity:feature ABC-123
```

Shows the ticket's status and last log or comment lines, and asks before resuming (another session may hold it). Yes -> continues in the existing work dir from the first stage `run.json` doesn't mark done, re-showing unapproved gates. `next` never resumes a task.

The work dir is found by ticket ID: tickets and task files resume, prompt-started runs don't. Start multi-session work from a ticket or task file.

#### Teach the agents by correcting them

Correct an agent in the session:

```text
No, we don't use moment here: dates go through formatDate in src/lib/dates.js.
```

Hooks queue, with the agent's preceding message, in `<work_dir>/corrections/` (never committed):

- prompts that read like a correction ("that's wrong", "don't use", "you broke") once the agent has answered in the session, and anything starting `correction:`;
- what you type after interrupting the agent (Esc), except "continue" and the like;
- what you type when rejecting a tool call ("No, and tell Claude what to do differently"), or in your next prompt, with the rejected call. Read from the session transcript, whose format Claude Code doesn't document: best effort.

Pasted text, notifications and other agents' messages never count. Implicit corrections (after an interrupt you only rephrase the request) change a guideline only when they recur. The next `/singularity:feature` run passes the queue to the learn job; outside the pipeline a new session reminds you; `@agent-singularity:optimizer learn from corrections` runs it now. Dropped: non-corrections (new request, question, change of mind), task-only instructions ("make this one blue"). Project rules ("we never mock the database") go through the [fast loop](#guidelines-and-self-optimization)'s root-cause step.

Hooks match English phrases; add yours (any language) as extended regular expressions in `.claude/singularity/correction-patterns.txt`. `learning.corrections: false` stops capture. Claude Code's auto memory also saves corrections, per machine, outside the guidelines; `"autoMemoryEnabled": false` in `.claude/settings.json` keeps learning in the shared guidelines only.

#### Learning from human reviews

`learning.pr_reviews: true` counts what your PR/MR reviewers catch that agents missed as defects: each `/singularity:feature` run looks up up to three earlier runs' PRs/MRs by branch (hand-opened too). Merged or closed -> the learn job root-causes each review comment, and each edit people made after hand-off (from the hand-off snapshot, a local git ref, to the reviewed commit): a fixed defect becomes a regression eval case for validating review changes, an applied project convention a correction. It also counts which open findings people addressed, the reviewers' precision. Open -> waits. Needs a readable code host (`code_host.type` other than `none`).

#### Learning from later fixes and reverts

Every learn job looks for commits on the default branch, from the last 90 days, that fix or revert lines a pipeline run wrote (`scripts/outcomes.sh later-fixes`: `git blame` at the fix's parent). A line belongs to a run through the commit trailer `Singularity-Run: <slug>` (the pipeline adds it when it commits; keep it when you commit yourself), the run's squash-merged PR/MR or merged branch, or, on the machine that ran it, its hand-off snapshot. The learn job reads each commit: a fix of that run's defect counts as a defect found by a person, at once. `learning.later_fixes: false` stops it.

#### Review a branch without the pipeline

Review is a `/singularity:feature` stage, not a command. For a branch the pipeline didn't build:

```text
@agent-singularity:reviewer review this branch against main through the security lens
```

One lens, fresh context; findings with severity, location, evidence, fix. The pipeline adds other lenses, project reviewers and a challenge of every finding.

#### The optimizer: onboard, optimize, report upstream

An agent, not a command: ask in a session, or run a whole session as it:

```text
@agent-singularity:optimizer onboard
@agent-singularity:optimizer optimize, focus on review false positives
@agent-singularity:optimizer the reviewer keeps flagging our generated clients; report it upstream
claude --agent singularity:optimizer
```

No instruction -> it works out which job is due:

- **Learn: after every run, and when you have corrected an agent.** `/singularity:feature`'s learn step: fixes guidelines behind defects and corrections, writes a run digest and eval cases, proposes larger changes for the next optimization.
- **Onboard: once, and when the project or its goals change.** Started by `init-project`. Drafts `.claude/singularity/goals.md` for you to correct and confirm; surveys code, history, recent reviews; writes as guidelines only what agents can't quickly find out (exact commands, non-obvious conventions, risks, what not to touch), each where its reader looks (`CLAUDE.md`, guideline files, path-scoped rules, the "Do not touch" list), and no repository overview (overviews don't help agents; LLM-written context files can hurt: [research](docs/self-optimization.md#onboarding-context-before-optimization)); checks commands; proposes lenses, stages, role settings.
- **Optimize: every ~10 runs, or when you ask.** Offered by `/singularity:feature` every `optimization.every_runs` runs (default 10); words after `optimize` set a focus. Runs the slow-loop cycle on past-run evidence; delivers validated changes as a draft PR/MR on a `singularity/optimize-<date>` branch.
- **Report upstream: when a failure's cause is in the shared plugin** (agent instructions, a default, a standard). A fix for one project can break another, so it never changes the plugin: it writes a report in `.claude/singularity/upstream/` (problem, evidence as counts and categories, exact fix and its validation, plus a local workaround if needed now; nothing project-identifying). After team approval in the PR/MR it offers to file an issue in the singularity repository, filing only on your yes. Projects send these reports, not experience; maintainers adopt them per [Adopting upstream reports](CONTRIBUTING.md#adopting-upstream-reports), reproducing each as a case in `plugins/singularity/evals/`.

Choices (proposals to implement, reports to file) arrive as a **Decision needed** block; Claude shows it to you and relays your answer. A `claude --agent singularity:optimizer` session is the optimizer throughout: asks you directly, runs singularity's evidence and replay workflows itself.

Scheduled: request it unattended in auto mode, e.g. `claude -p --permission-mode auto "Use the singularity:optimizer agent: optimize, unattended"` (outside auto mode, headless writes under `.claude/` are refused). Skips gates; implements context and curation changes, and behaviour changes whose replay passes within `optimization.max_eval_cost_usd`; leaves canary choice, goal confirmation and upstream filing to people. Nothing merges without a human. See [Guidelines and self-optimization](#guidelines-and-self-optimization).

### Customizing agents and turning them off

Mostly `.claude/singularity.md` keys, read at session start: restart the session after changes.

| To | Set, in the project |
|---|---|
| Change a role's model or effort | `roles.<role>.model`, `roles.<role>.effort` |
| Give the agents project knowledge | `CLAUDE.md`, `.claude/singularity/guidelines/*.md`, `.claude/rules/singularity/*.md` |
| Keep agents away from some paths | the "Do not touch" section of `.claude/singularity.md` |
| Add or drop review lenses | `review.lenses`, `review.extra_lenses` |
| Format edits, guard commands, add checks | `.claude/singularity/hooks/{post-edit,pre-bash,verify}.sh` |
| Replace a role's agent | `.claude/agents/<name>.md` and `roles.<role>.agent` (see [Creating custom roles and agents](#creating-custom-roles-and-agents)) |
| Add a reviewer, a pipeline step, a workflow or a command | see [Creating custom roles and agents](#creating-custom-roles-and-agents) |

#### Change a role's model or effort

```yaml
roles:
  review:    { model: opus, effort: high }   # e.g. if Fable isn't enabled for the org
  optimize:  { model: opus, effort: xhigh }  # the same, for the optimizer
  implement: { model: opus }                 # effort stays medium, fix rounds high
```

Omitted roles keep their defaults ([Roles and models](#roles-and-models)); implement fix rounds run at high effort unless `roles.implement.effort` is set.

#### Give the agents project knowledge

Most project specifics need no new agent; put them where the shared agents look:

- `CLAUDE.md`: what the project is, architecture, conventions differing from the shared engineering standards; every agent reads it.
- `.claude/singularity/guidelines/project.md` (every session) and `spec.md`, `plan.md`, `implement.md`, `review.md`, `verify.md` beside it (each by its role).
- `.claude/rules/singularity/<area>.md`: one code area's guidelines, with `paths` frontmatter (e.g. `paths: ["api/**"]`); loaded only when an agent works on matching files.
- The "Do not touch" section at the end of `.claude/singularity.md`: generated code, vendored libraries, released migrations.

The optimizer keeps guidelines current, each file within `learning.max_lines_per_file` guidelines (40 for `project.md`). Your edits: the current right way, present tense, naming the files depended on (the guideline check flags them once gone).

#### Tune the review

```yaml
review:
  lenses: [correctness, security, maintainability, testability]
  extra_lenses:
    - { name: performance, description: "N+1 queries, missing pagination" }
    - { name: accessibility, description: "labels, focus order, contrast" }
```

Each lens adds a reviewer, cost and time to every run. Only `review.blocking_lenses` (default: correctness, security) and `review.extra_reviewers` block; blocking lenses use the review model, and each blocking finding gets a challenger. Others advise: at most `should-fix`, unchallenged, on `review.advisory` (default `{ model: sonnet, effort: high }`); blocking style and design remarks breed false positives and rework ([evidence](docs/pipeline-design.md#review-correctness-and-security-block-the-rest-advise)). Drop a shared lens only with a reason beside it. Small changes: correctness, plus security near risky areas; large: a second independent correctness pass.

#### Hooks

`init-project` can add three scripts in `.claude/singularity/hooks/`:

- `post-edit.sh`: after each file edit (e.g. formatting); exit 2 + stderr message -> feedback to Claude.
- `pre-bash.sh`: before each shell command, alongside the shared guard; exit 2 + stderr message -> command blocked.
- `verify.sh`: run by the verifier for checks the commands miss (contract tests, a smoke test).

`post-edit.sh` and `pre-bash.sh` run only while executable.

Plugin hooks:

- command guard: blocks force-pushes to protected branches (main, master, develop, trunk, production, release branches, `conventions.default_branch`), skipping git hooks (`--no-verify`, `git commit -n`, `core.hooksPath`, `HUSKY=0`), and recursive deletes of `/` or home. Shell-style parsing: quoting doesn't evade it; commit messages naming these commands don't trip it. A seatbelt, not a security boundary (Claude Code's docs call argument-constraining Bash rules fragile): protect the default branch on your code host; enforce with the sandbox (`/sandbox`);
- the stop gate (`checks.implement_gate`, `checks.stop_retries`) and frozen-test guard ([step 4](#implement-a-feature-from-a-tracker-ticket));
- three correction-capture hooks, on `UserPromptSubmit`, `Stop` and `StopFailure` ([Teach the agents by correcting them](#teach-the-agents-by-correcting-them)).

#### Turn things off

| To turn off | Do this |
|---|---|
| The approval gates, for one run | Add `no-gates` to the command |
| Learning after each run | `learning.enabled: false`. This also stops capturing corrections, learning from human reviews, and the run digests that optimizations and their reminder work from |
| Capturing your corrections from prompts, interrupts and rejected tool calls | `learning.corrections: false` |
| Tracing later fixes and reverts of pipeline changes | `learning.later_fixes: false` |
| The stop gate that keeps the implementer working while checks fail | `checks.implement_gate: false` |
| A frozen test, when it really is wrong | Ask the user to decide; `bash <plugin root>/scripts/test-guard.sh reset` unfreezes all |
| Blocking by a review lens | Leave it out of `review.blocking_lenses`: it then advises |
| Tracker comments and status changes | `tracker.updates: false`. Tickets are still read |
| Commits and PRs/MRs | Nothing to do: `conventions.auto_commit` and `auto_pr` are off by default |
| A shared review lens | Remove it from `review.lenses` |
| A project reviewer or stage | Remove it from `review.extra_reviewers` or from its `stages` list |
| The optimizer | Nothing to do: it runs only when someone asks for it. `optimization.every_runs: 0` also stops the pipeline offering it |
| The optimizer's web research | `optimization.web_scan: false` |
| A project hook | Delete the script |
| singularity, for yourself in one project | `claude plugin disable singularity@singularity --scope local`, which writes to your git-ignored `.claude/settings.local.json`. Pass `--scope local`: without it, the change can land in the committed `.claude/settings.json` |
| singularity, for the whole project | Set `"singularity@singularity": false` under `enabledPlugins` in `.claude/settings.json`, and commit |

Spec, plan, implement, checks, review, verify are the pipeline: not individually switchable (small changes skip the plan). Cheaper stage -> smaller model, lower effort or own agent for its role. Different sequence -> own workflow (next section). The shared command guard stays on with the plugin.

### Creating custom roles and agents

Roles are fixed: spec, plan, implement, review, verify, optimize (its learn job is the pipeline's learn step). Projects add their own agents (Markdown in `.claude/agents/`) at four points:

| Point | Config | When it runs | Example |
|---|---|---|---|
| Replace a role | `roles.<role>.agent` | instead of the shared agent | `custom-implementer.md.example` |
| Add a reviewer | `review.extra_reviewers` | in the review stage, next to the lenses | `review-domain.md.example` |
| Add a pipeline step | `stages.after_plan`, `after_implement`, `before_handoff` | at that point in `/singularity:feature` | |
| Add a workflow or command | `.claude/workflows/*.js`, `.claude/skills/<name>/SKILL.md` | when someone runs it | `dependency-upgrade.js.example` |

Examples: [`plugins/singularity/templates/project/.claude/`](plugins/singularity/templates/project/.claude/); `init-project` copies them on request.

#### Write the agent

```markdown
---
name: migration-checker
description: Checks that database migrations in the current change are reversible and safe on a live database. Runs as a singularity pipeline stage (after_implement).
tools: Read, Grep, Glob, Bash
model: opus
effort: high
skills:
  - singularity:engineering-standards
---

# Migration checker

Read `.claude/singularity/guidelines/project.md` first.

Check every migration this branch adds, compared with
`conventions.default_branch`:

- it has a working down migration;
- it doesn't lock a large table, such as an index built without
  CONCURRENTLY.

Report each problem with file:line, evidence and a fix. Call a problem
blocking only if running the migration could lose data or cause downtime.
```

- `name`: the config's reference; plain, unique, no `singularity:`, no `:`.
- `description`: what it does, where it runs; Claude delegates by it: flag pipeline-only agents.
- `tools`: the minimum; reviewers and checkers get no `Write` or `Edit`.
- `model`, `effort`: [Choosing model and effort for a custom agent](docs/models-and-effort.md#choosing-model-and-effort-for-a-custom-agent); for a role-bound agent, `roles.<role>.model` and `.effort` override them.
- `skills: [singularity:engineering-standards]` preloads the shared standards, like the shared agents.
- Body: the guidelines file to read, exactly what to report, when a problem blocks; report only what it can prove.

Commit it (`git check-ignore .claude/agents/<name>.md` should print nothing). Try it alone first: ask Claude to "use the migration-checker agent on this branch".

#### Replace a role's agent

```yaml
roles:
  implement: { agent: android-implementer }
```

For instructions or tools the shared agent can't get from `CLAUDE.md` and the guidelines (e.g. a platform's build commands). Stages hand off through files; keep the role's contract:

| Role | Gets | Must deliver |
|---|---|---|
| spec | the ticket, its kind (feature, defect or refactoring), an output path | a spec there, with numbered acceptance criteria and open questions |
| plan | the spec path, an output path | a plan there, steps as checkboxes (`- [ ] 1. …`), which resuming relies on |
| implement | spec and plan paths; in fix rounds, the findings or failures | code and tests on the current branch; finished steps ticked in the plan |
| review | a lens, the base and the spec (task A), or one finding to challenge (task B) | findings with severity, location, problem, evidence and fix; or a verdict: confirmed, severity, reason |
| verify | the spec path | a checks table with evidence, the Test Coverage and Verification Summary, then PASS or FAIL |
| optimize, learn job | the work dir, the run record, human review comments on earlier runs' PRs/MRs | updated guidelines, a run digest; per PR/MR, a `human_review` digest and an eval case per escaped defect |

`roles.optimize.agent` rebinds optimize, learn job included, but that contract is the longest and its playbooks in [`plugins/singularity/optimizer/`](plugins/singularity/optimizer/) resolve via the plugin's own path, which project agents lack. Prefer an upstream report to forking the optimizer.

Start from a renamed copy of [`plugins/singularity/agents/<agent>.md`](plugins/singularity/agents/) plus project specifics. A replacement is a fork: shared-agent improvements stop reaching that role. Keep replacements few; on upgrade, check the [changelog](CHANGELOG.md) for them. Project review rules -> add a reviewer, not a review-role replacement.

#### Add a reviewer

```yaml
review:
  extra_reviewers: [review-domain]
```

Runs only when listed. Gets the change's base and the spec; own model and effort; reports findings with severity (`blocking`, `should-fix` or `nit`), location, problem, evidence, fix. The review role challenges each: confirmed = lens finding (blocking -> fix round); rejected -> `review.md`, for the learn job. Starting point for rules like "money amounts use the Money type": `review-domain.md.example`.

#### Add a pipeline step

```yaml
stages:
  after_plan: [threat-modeler]           # read-only checks of the plan
  after_implement: [migration-checker]   # runs before review, so its changes get reviewed
  before_handoff: [release-notes-writer] # after review and verification
```

Agents run in list order; each gets the work dir path (spec, plan, later `review.md`). Blocking problem -> you choose: fix and rerun the agent, continue anyway, or stop. Scheduled or headless: stop, as on remaining review blockers. `before_handoff` runs after review and verification, so its changes go unreviewed: notes and documents only, or read-only.

#### Add a workflow or a command

For a stage sequence `/singularity:feature` doesn't fit:

- **Workflow:** `.claude/workflows/<name>.js`, run as `/<name>`, orchestrating agents in code via `agent(prompt, { agentType, model, effort, isolation, schema, label, phase })`, `pipeline`, `parallel`; `agentType` is a shared agent (`'singularity:implementer'`) or yours. `dependency-upgrade.js.example` upgrades each listed package in its own worktree with the shared implementer, then verifies each with the shared verifier (rename to `.js`).
- **Skill:** `.claude/skills/<name>/SKILL.md`: a command (`/<name>`) or knowledge Claude loads when relevant; can use the `tracker` skill for tickets and shared agents such as `singularity:reviewer` for a one-lens review.

#### Let custom agents learn

Tell each custom agent its guidelines file: the replaced role's, or `project.md`. Extra reviewers' findings count like any: confirmed -> implement or plan guidelines; rejected -> review guidelines. The optimizer may propose evidence-backed changes to project agents too.

## Roles and models

Every code-facing role preloads the `engineering-standards` skill (definition of done, no hardcoding, dependency injection, red-green-refactor, test pyramid, boundary/failure-mode coverage, deterministic assertions, zero debt): one file, `skills/engineering-standards/SKILL.md`, enforced per stage; `docs/adopted-roles.md` maps each adopted guideline to its enforcement point.

Pipelines name **roles**, not agents.

| Role | Default agent | Model · effort | Why |
|---|---|---|---|
| spec | `singularity:spec-writer` | opus · high | ambiguity costs the most when caught late |
| plan | `singularity:planner` | opus · high | a precise plan lets a fast model implement it |
| implement | `singularity:implementer` | **sonnet · medium**, fix rounds high | fast; targeted tests per step, full suite once at the end; a high-effort retry of a failure costs less than a higher baseline |
| review | `singularity:reviewer` | **fable · high** for the blocking lenses; sonnet · high for advisory ones | read-only, fresh context; correctness and security block, maintainability and testability advise; blocking findings challenged. First trial to replay: Opus 5.5 · high |
| verify | `singularity:verifier` | sonnet · medium | checks via `run-checks.sh` (exit codes), acceptance criteria mapped to tests, tests confirmed intact; lower effort makes fewer tool calls |
| optimize | `singularity:optimizer` | **fable · xhigh**; its learn job **opus · high** | onboarding and optimization: rare, high-leverage workflow changes; the learn job runs every run, and curation needs a strong model, not that budget (`roles.learn` sets its model and effort) |

Defaults live only in `plugins/singularity/agents/*.md` frontmatter; override in `.claude/singularity.md` ([Change a role's model or effort](#change-a-roles-model-or-effort), [Replace a role's agent](#replace-a-roles-agent)). Evidence, and choosing model and effort for project agents: [docs/models-and-effort.md](docs/models-and-effort.md).

Allowlist blocks a model -> newest allowed version of the family, else the session model. On Amazon Bedrock, Google Cloud and Microsoft Foundry some aliases resolve to older models (e.g. `sonnet` to Sonnet 4.5): check `/model`. Per-call `effort` overrides need Claude Code v2.1.292 or later.

## Trackers

One `tracker` skill: the same operations everywhere (`get`, `next`, `comment`, `move`, `link`, `open_change`, `find_change`, `review_comments`), loading only the project's adapter:

| Project config | Adapter | Access |
|---|---|---|
| `tracker.type: jira` | `skills/tracker/jira.md` | Atlassian MCP server (`templates/mcp/jira.mcp.json`) |
| `tracker.type` / `code_host.type: github` | `skills/tracker/github.md` | `gh` CLI |
| `tracker.type` / `code_host.type: gitlab` | `skills/tracker/gitlab.md` | `glab` CLI |
| `tracker.type: files` | `skills/tracker/files.md` | Task files in a git-ignored folder, through `skills/tracker/scripts/tasks.sh` |

Tracker and code host are independent (Jira with GitLab MRs works); `tracker.states` maps logical states to Jira statuses or labels.

**Task files.** Git-ignored folder (default `.tasks/`); name prefix = status: `TODO-T7-fix-login.md`, `PROGRESS-T3-add-search.md`, `DONE-T1-setup-ci.md`. Statuses `TODO`, `PROGRESS`, `REVIEW`, `BLOCKED`, `DONE`; rename via `tracker.files.statuses`, add others (`QA`, `ON_HOLD`) via `tracker.files.extra_statuses`. `/singularity:feature next` takes the first `TODO` (lowest `priority` in front matter, then lowest ID) and claims it by atomic rename to `PROGRESS`, so no two sessions share a task. Hand-off -> `REVIEW`; `DONE` once you confirm.

## Guidelines and self-optimization

The [optimizer](#the-optimizer-onboard-optimize-report-upstream) drives self-improvement ([design and sources](docs/self-optimization.md)) towards `.claude/singularity/goals.md`. Working agents follow **guidelines** (how to work in the project now; [where they live](#give-the-agents-project-knowledge)). Also committed:

- `.claude/singularity/goals.md`: users, their value, current goals, trade-offs, constraints. Team-owned: the optimizer drafts it (`Status: draft`); once the team sets `Status: confirmed`, the optimizer only proposes changes and agents rely on it. Read by the optimizer, spec writer and planner.
- `.claude/singularity/experience/`: the record; working agents don't read it.
  - `runs.jsonl`: a digest line per run and per human review, incl. guidelines added, changed or removed;
  - `optimizations.md`: the optimizer's archive;
  - `upstream.md`: guidelines that may apply to every project, with evidence.
- `.claude/singularity/evals/`, `.claude/singularity/upstream/`: see the [file table](#getting-started).

**Why guidelines, not a log of lessons.** Agents copy retrieved experience, mistakes included; a note about deleted code misleads every later run ([research](docs/self-optimization.md#guidelines-not-a-log-of-lessons)). So a guideline states only the current right way, names the files it depends on, and changes in the same PR/MR as that code.

**Fast loop (the optimizer's learn job, every run, and whenever corrections are waiting).** Guidelines change on two signals only:

- **defects whose root cause is a weak guideline:** confirmed review findings, rejected findings (reviewer false positives), failed checks and stop-gate blocks, verification failures, later commits fixing or reverting a run's lines, and, if enabled, human reviewers' comments and edits that fix a defect. Each defect that escaped review also becomes an eval case;
- **your corrections:** hook-captured prompts saying an agent was wrong, what you type after an interrupt or a rejected tool call, your edits at the approval gates, and, if enabled, your edits before merge that apply a project convention.

Reviewers cite the guideline a finding breaks, and the planner and implementer the guidelines that decided a choice. Citations point the root cause at a guideline; they never add one.

Root cause first: guideline missing, wrong or unclear -> add or fix it, in the narrowest place the agent reads; guideline ignored -> propose a check (lint rule, test, hook), not more text; else (one-off slip, flaky environment, task-only request) -> no change. Person- or tool-confirmed (explicit correction, failed verification, later fix): counts at once; model-only or implicit (review finding, a rephrased request after an interrupt): on recurrence. `runs.jsonl` logs each correction and defect with its cause, never your prompt text. Guidelines about code the run renamed, moved or removed: fixed or removed in the same run.

Before finishing, the guideline check (`scripts/check-guidelines.sh` in the plugin) reports named paths that don't exist, rules loading everywhere or nowhere, duplicate ids, leftover lesson-log wording. Reported non-path spans -> `.claude/singularity/guidelines/check-ignore.txt`. A change adding a check for a guideline removes it.

**Slow loop (optimizer, every ~10 runs or on a schedule).** Fixed cycle:

1. **Evidence:** quality and flow trends (lead time and its working/waiting split, rework, changes merged unedited, changes later fixed or reverted, findings people addressed, cost per run, costly stages catching little); effort across goals; failure taxonomy (fix in project or plugin); corrections by source; guideline audit (history instead of guidance, duplicates, check-enforceable guidelines, each guideline's use and failures); context audit (guidelines about vanished code); due contracts; eval coverage; web scan for new Claude Code features, models, research.
2. **Propose:** up to five changes to models, lenses, stages, project agents, guidelines, ranked by harm to the goals and their users; each a falsifiable contract (goal served, what it fixes, by how much, what it might break).
3. **Challenge:** a reviewer tries to refute each.
4. **Gate:** you choose what to implement.
5. **Implement:** one commit per change.
6. **Validate:** replayed eval cases or a canary; adopted only with no regressions, held-out cases included. Review guidelines the learn jobs added are replayed with and without them, and rewritten or removed if they don't help.
7. **Deliver:** archive entry and draft PR/MR.

**What the optimizer can never change:** confirmed goals, approval gates, guardrails, permissions, existing eval cases, metric definitions, the plugin (its own definition included); it only proposes these, the plugin via [upstream reports](#the-optimizer-onboard-optimize-report-upstream). Goals, eval cases and the challenging reviewer measure it, so it doesn't grade itself.

**Upgrading from 0.4.0.** The learner agent is now the optimizer's learn job (`roles.learn` still sets its model and effort; `roles.learn.agent` no longer applies). A lesson log from before 0.5.0 in `.claude/singularity/experience/`, which the roles no longer read, is migrated by the optimizer before the next `/singularity:feature` run (attended runs may stop instead): lessons still true in the code become guidelines, the rest are dropped with reasons (draft PR/MR).

## Layout

```text
.claude-plugin/marketplace.json
plugins/singularity/
  .claude-plugin/plugin.json
  agents/          spec-writer, planner, implementer, reviewer, verifier, optimizer
  optimizer/       the optimizer's playbooks: learn, onboard, optimize, upstream
  skills/          feature, init-project, tracker (+ jira/github/gitlab/files), engineering-standards
  workflows/       optimize-scan.js, replay-evals.js: the optimizer's evidence and replays
  evals/           regression suite for the shared plugin (claude plugin eval)
  hooks/ scripts/  guardrails, project hook extension points, correction capture, the guideline check, outcomes after hand-off
  templates/       project files for init-project, Jira MCP config
docs/                     design notes, adopted role prompts and where each clause lives
scripts/                  release.sh and version.js (versions and releases), check-evals.js, check-sensitive.sh
CHANGELOG.md              what changed in each release
```

## Changing the shared setup

1. Edit here (often adopting an upstream report). Test with `claude --plugin-dir ./plugins/singularity` in any project; run `claude plugin validate --strict .` and the eval suite (`plugins/singularity/evals/README.md`).
2. Add a line under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md) on what changes for projects; merge to the default branch.
3. Release when projects should get it (next section): merging alone reaches no project.

## Versions and releases

The version lives only in `version` in `plugins/singularity/.claude-plugin/plugin.json`; Claude Code installs and updates by version, so projects get new files only when it changes. Projects track the `stable` branch, which moves only on a published release (a version always means the same files); `main` holds merged, unreleased changes.

### What the version means

Versions follow [Semantic Versioning](https://semver.org). Public interface = what projects depend on: `/singularity:*` commands and arguments, role and agent names, workflow names and arguments, `.claude/singularity.md` keys, project hook extension points, guideline file and rule locations and formats, `runs.jsonl` and eval-case formats.

| Bump | When | Examples |
|---|---|---|
| Major | A project must change something to keep working | rename a config key or command, change the `runs.jsonl` or eval-case format, remove a role |
| Minor | New capability, or behaviour projects get without doing anything | a new command, config key or review lens; an agent's model, effort or instructions change |
| Patch | Fixes that keep the intended behaviour | a bug in a workflow or hook, clearer wording, docs |

Under 0.x the interface isn't stable: a breaking change bumps minor, and its changelog line starts with **Breaking:**. No pre-releases (a marketplace serves one version at a time); try unreleased changes with `claude --plugin-dir`.

### Release

GitHub publishes releases in [hlistan/singularity](https://github.com/hlistan/singularity), never a local checkout. A release = a PR to `main` changing the version; merging starts the [Release workflow](https://github.com/hlistan/singularity/actions/workflows/release.yml), which:

- creates the [tag](https://github.com/hlistan/singularity/tags) `singularity--v<version>` (the tag `claude plugin tag` creates);
- moves the [`stable`](https://github.com/hlistan/singularity/tree/stable) branch to the tagged commit;
- publishes a [GitHub release](https://github.com/hlistan/singularity/releases) with that version's changelog section as notes.

From an up-to-date `main`:

```bash
scripts/release.sh minor
```

Level: `patch`, `minor`, `major` ([table above](#what-the-version-means)) or `X.Y.Z`. Options:

- `--dry-run`: check everything, show the plan, stop; only fast-forwards `main` if GitHub's is ahead.
- `--yes`: skip confirmation.
- `--date YYYY-MM-DD`: changelog date (default: today, UTC).
- `--admin`: maintainers on the ruleset's bypass list with no other approver (GitHub bars approving your own PR): once all PR checks pass, merge with the bypass (`gh pr merge --admin`).

Needs `git`, Node.js, and `gh` signed in to github.com with write access. Stops at the first problem:

1. **Checks** the GitHub repository named by `repository` in `plugin.json` and its git remote, whatever the name (https or ssh); then:
   - write access;
   - clean `main` at GitHub's commit (fast-forwards if GitHub is ahead; refuses on commits GitHub lacks);
   - last CI run on that commit passed; `node scripts/version.js check` passes;
   - something waits under `## [Unreleased]`;
   - no **Breaking:** line released as a patch, or as a minor from 1.0 on;
   - release branch and tag don't exist yet.
2. **Shows the plan** (versions, tag, release notes); asks to confirm.
3. **Bumps the version** on `release/<version>` (`node scripts/version.js bump`), verifies only `CHANGELOG.md` and `plugin.json` changed, commits `chore(release): singularity <version>`, pushes.
4. **Opens the release pull request** (notes as description); waits for checks.
5. **Squash-merges it.** `main` needs an approving review -> with `--admin`, merges with your bypass; otherwise enables auto-merge for another approver, explains the bypass merge on GitHub, waits.
6. **Follows the Release workflow** run for the merge commit to the end.
7. **Checks the result:** release published; tag and `stable` on one commit.
8. **Updates your `main`**, fetches the tag, deletes the release branch locally and on GitHub.

On failure it prints where it stopped and exact commands to continue or undo. A part-failed Release workflow can be re-run once the cause is fixed on `main`; it skips completed work:

```bash
gh workflow run release.yml --repo hlistan/singularity --ref main
```

Auto-update (the `init-project` template default): sessions download a release in the background at start; `/reload-plugins` or the next start loads it. Running sessions keep the old version (`/reload-plugins` downloads nothing): run `/plugin marketplace update singularity`, then `/reload-plugins`. Without auto-update: `claude plugin update singularity@singularity`. `claude plugin list` shows the installed version; run digests record it as `plugin_version` (`+dev` for `--plugin-dir`): the optimizer compares releases, not commits.

CI enforces this via `node scripts/version.js check`: one valid version, only in `plugin.json`; a changelog section for it; on PRs, a version that only goes up and a changelog line per change to `plugins/singularity/` (eval cases excepted).

### Pin a project to a release

Set `ref` in the marketplace source in the project's `.claude/settings.json` to the release tag; change it to upgrade:

```json
"source": { "source": "git", "url": "https://github.com/hlistan/singularity.git", "ref": "singularity--v0.1.0" }
```

Marketplaces are per user, not per project: the pin covers every project on the machine; projects sharing machines should agree on `ref`.

## Security and contributing

[SECURITY.md](SECURITY.md): what the plugin runs on your machine; reporting vulnerabilities. [CONTRIBUTING.md](CONTRIBUTING.md): development setup and checks. [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## License

[MIT](LICENSE).
