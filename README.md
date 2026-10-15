# Project Singularity

[![CI](https://github.com/hlistan/singularity/actions/workflows/ci.yml/badge.svg)](https://github.com/hlistan/singularity/actions/workflows/ci.yml) [![Sensitive information checks](https://github.com/hlistan/singularity/actions/workflows/sensitive-info.yml/badge.svg)](https://github.com/hlistan/singularity/actions/workflows/sensitive-info.yml) [![Release](https://img.shields.io/github/v/release/hlistan/singularity?display_name=release&label=release)](https://github.com/hlistan/singularity/releases/latest) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A self-improving harness for autonomous software delivery with [Claude Code](https://code.claude.com), packaged as **one plugin**. Shared behaviour (agents, pipelines, guardrails, standards) lives in this repository. Each project repo holds only its config, its own agents and workflows, its accumulated experience and its eval cases. Change something here, release it, and every project picks it up.

> **Status:** early. The structure validates and the workflows pass dry runs, but the pipelines have not yet been exercised at scale on real projects. Feedback and experience reports are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md).

The plugin is loaded straight from this git repository through `marketplace.json`; nothing is published to a registry. Projects follow versioned releases: see [Versions and releases](#versions-and-releases).

To use it in a project, start with [Getting started](#getting-started).

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
| `/singularity:feature <ticket \| defect \| refactoring> [small \| full]` | The whole delivery, sized to the change: spec and plan with approval gates (small changes skip the plan), implementation with frozen tests, the project's checks, a review in which correctness and security can block, verification, hand-off, and learning from defects and your corrections. A defect starts with its reproduction as a failing test |
| `/singularity:init-project` | Sets up a project repo, then has the optimizer onboard the agents to it |

Everything else is done by agents. The pipeline runs them, and you can ask for any of them by name (`@agent-singularity:<name>`). The one you call yourself is the **optimizer**: it forms the project context the agents work from, improves the delivery process from the evidence of past runs, and reports what it finds wrong in singularity itself to the maintainers. See [The optimizer](#the-optimizer-onboard-optimize-report-upstream).

Typing `/singularity:` also lists `optimize-scan` and `replay-evals`. They are the optimizer's internal workflows for gathering evidence and replaying eval cases, and Claude Code shows every plugin workflow as a command. Ask for the optimizer instead of running them.

## How to use

Everything below happens in a project repository, in a Claude Code session started from its root. You drive the plugin with `/singularity:*` commands, and the project's choices live in one committed file, `.claude/singularity.md`.

### Getting started

**Before you start**, you need:

- Claude Code v2.1.292 or later, run locally (terminal, IDE or desktop app). Cloud sessions don't load plugins from a repository's settings.
- The project in a git repository.
- Access to the project's tracker:
  - Jira: the Atlassian MCP server, which `init-project` adds; each person signs in once with `/mcp`;
  - GitHub: the `gh` CLI, signed in;
  - GitLab: the `glab` CLI, signed in;
  - task files: nothing.
- Fable for the review and optimize roles. Without it, Claude Code falls back to another model (see [Roles and models](#roles-and-models)), or you choose one: see [Change a role's model or effort](#change-a-roles-model-or-effort).

**1. Install the plugin, once per machine.**

```bash
claude plugin marketplace add hlistan/singularity#stable
claude plugin install singularity@singularity
```

Teammates joining a project that is already set up run only `claude plugin install singularity@singularity --scope project` in it: see step 4.

**2. Set up the project.** Start Claude Code in the project root and run `/singularity:init-project`. It inspects the repository and creates the files below. It never overwrites a file that exists; it shows what it would add and asks first.

| File | What it holds |
|---|---|
| `.claude/singularity.md` | The project config: commands, conventions, tracker, and any overrides |
| `.claude/settings.json` | The marketplace and the enabled plugin, so the whole team gets singularity |
| `CLAUDE.md` | Imports the config and the project guidelines into every session |
| `.claude/singularity/goals.md` | What the project is for: its users, the value they get, the goals now, the trade-offs. The optimizer drafts it with you at onboarding |
| `.claude/singularity/guidelines/` | The guidelines the agents follow: one file every session loads, and one per role |
| `.claude/singularity/experience/` | The record the learning loop keeps: run digests and the optimizer's archive. The agents doing the work don't read it |
| `.claude/singularity/evals/` | Regression cases the optimizer validates against |
| `.claude/singularity/upstream/` | Upstream reports: problems the optimizer found in singularity itself, with proposed fixes |
| `.mcp.json` | Jira only: the Atlassian MCP server |
| `.tasks/` | Task files only: the task folder, git-ignored |

Along the way it runs each project command once to confirm it works, asks you to confirm the tracker, and offers the optional hook scripts and example agents. Then the optimizer agent **onboards the agents**: it drafts what the project is for in `goals.md` (its users, the value they get, the goals now, the trade-offs) for you to correct and confirm, surveys the code, the history and recent reviews, writes the first guidelines (only what agents can't find out quickly for themselves, such as exact commands, non-obvious conventions, risks and what not to touch), checks the commands, and proposes the review lenses, stages or role settings that fit the project. You answer its open questions and choose the proposals. Last, `init-project` checks that the shared files aren't git-ignored, and that the work dir, the task folder and `.claude/settings.local.json` are.

**3. Check what onboarding wrote, and fill in the gaps.** The goals in `.claude/singularity/goals.md` steer every later optimization, so make sure they say what your team is actually working towards. Every agent reads `CLAUDE.md` and `.claude/singularity/guidelines/project.md`, so correct anything wrong there. Then answer the open questions and replace any `TODO` that `init-project` and the optimizer listed, above all in `commands` in `.claude/singularity.md`: the verifier runs them, and the implementer uses `test_one` for targeted tests, so a wrong command costs every run.

Leave `roles`, `stages` and the `review.extra_*` lists empty unless you mean to change something. What you leave out follows the shared defaults, so improvements in new releases keep reaching the project.

**4. Commit the files.** A pull request is a good place for the team to review the config. The committed `.claude/settings.json` turns singularity on for everyone who clones the project and trusts the folder, but doesn't download it: each teammate installs it once, with `claude plugin install singularity@singularity --scope project`. Until they do, `/plugin` shows on its Errors tab that the plugin is enabled in project settings but isn't installed. New releases then arrive through auto-update.

**5. Check it.** Start a new session in the project:

- `claude plugin list`, in a terminal, shows `singularity@singularity` and its version;
- typing `/singularity:` lists the commands, and `@agent-singularity:` lists the shared agents.

Then try a small ticket with the approval gates on, as in the first scenario below.

**Updates.** A session already running when a release comes out keeps the old version. To switch it, run `/plugin marketplace update singularity`, then `/reload-plugins`. To hold a project on one release, see [Pin a project to a release](#pin-a-project-to-a-release).

### Usage scenarios

Each run of `/singularity:feature` keeps its files in a work dir, `<work_dir>/<slug>/` (`conventions.work_dir`, default `.agentic/work/`, git-ignored). It holds `spec.md`, `plan.md`, `review.md`, `summary.md`, the first drafts of the spec and plan, and `run.json`, the record a crashed run resumes from.

#### Implement a feature from a tracker ticket

```text
/singularity:feature ABC-123
/singularity:feature https://github.com/org/repo/issues/42
```

1. **Ticket.** The pipeline reads the ticket and moves it to in progress. It sizes the work: `small` (a change you could describe in one sentence, in a few files, away from risky areas such as authorization, payments, migrations or public APIs), `standard`, or `large`. Add `small` or `full` to the command to choose yourself.
2. **Spec, then a gate.** The spec writer turns the ticket into `spec.md` and shows you its acceptance criteria and open questions. Answer the questions, ask for changes, or edit `spec.md` yourself, then approve. The optimizer's learn job compares your final spec with the first draft, so your edits teach the next run.
3. **Plan, then a gate.** The same for `plan.md`: the approach, the steps and the risks. A small change skips this: its acceptance criteria are its plan.
4. **Implement.** On the branch named by `conventions.branch`, the implementer works through the plan step by step, test first. It freezes each test once it fails for the right reason, and the plugin then blocks edits to that test. When it says it's done, a hook runs the project's checks and sends it back while they fail.
5. **Checks.** The pipeline runs the project's build, lint, type check and tests itself (`checks.run`): pass or fail is the exit code. Checks that already failed before the run (it records them first) are listed in the summary but don't count against the change. It also reports tests that were changed after freezing, or existing tests changed or deleted without the plan naming them. Failures go back to the implementer before any reviewer is spent on them.
6. **Review.** One reviewer per lens and per project reviewer, on the whole change, new files included. Correctness and security findings can block; a second reviewer challenges each blocking one, and the implementer has to reproduce it with a failing test before fixing it. Maintainability and testability advise, on a cheaper model. Blocking findings go back to the implementer, for at most two rounds.
7. **Verify.** The verifier runs the checks, maps every acceptance criterion to a passing test, and confirms the tests are intact. A failure gets one fix round.
8. **Hand-off.** You get `summary.md` and a short report. The pipeline commits only if `conventions.auto_commit` is true, and opens a draft PR/MR only if `conventions.auto_pr` is true or you ask for one; then it moves the ticket to in review, with the link. A task file moves to review either way.
9. **Learn.** The optimizer's learn job finds the root cause of each defect the run turned up and of each correction you made, and changes the guidelines in `.claude/singularity/guidelines/` and `.claude/rules/singularity/` only where a weak guideline was the cause. It also corrects guidelines that this change made wrong, and tells you which it added, changed or removed, with the defect or correction behind each. See [Teach the agents by correcting them](#teach-the-agents-by-correcting-them).

If blocking findings remain after the fix rounds, or the checks or verification still fail, the run stops and comments on the ticket with the reason and the work dir.

One checkout holds one run at a time: a second `/singularity:feature` in the same checkout stops and says which run holds it. To run tickets in parallel, start each session in its own worktree, `claude --worktree <name>` (or `-w`): it gets its own checkout and work dir, and the files tracker still claims tasks in the main checkout's task folder. The ticket moves to blocked: a task file always, a Jira, GitHub or GitLab ticket if `tracker.states` maps `blocked`. Fix the cause, then resume the run.

#### Implement a feature from a prompt

```text
/singularity:feature Add CSV export to the orders page. Admins only, same filters as the table, at most 10,000 rows.
```

The text is the ticket. The pipeline is the same, without tracker reads or updates, and the work dir is named after the request, for example `.agentic/work/orders-csv-export/`. Write what you would put in a ticket: who it's for, what should happen, the constraints, and how you'll know it's done. Whatever is missing comes back as open questions at the spec gate.

#### Work through a queue of task files

With `tracker.type: files`, a task is a file in the task folder whose name starts with its status, for example `.tasks/TODO-T12-orders-csv-export.md`:

```markdown
---
priority: 1
---
# Add CSV export to the orders page

Admins only, same filters as the table, at most 10,000 rows.
```

Create the file yourself, or ask Claude to create a task. Then:

```text
/singularity:feature next      # the first TODO task: lowest priority number, then ID
/singularity:feature T12       # a task you name
```

`next` claims the task by renaming it to `PROGRESS-…`, so two sessions working in the same folder never take the same task. At hand-off the task moves to `REVIEW`, and Claude asks whether to mark it `DONE`. Statuses and their names are described under [Trackers](#trackers). Other trackers have no queue to take from, so with them `next` asks which ticket to take.

#### Fix a defect or apply a refactoring

```text
/singularity:feature ABC-456
/singularity:feature Defect: saving a draft with an empty title returns 500 instead of 400
/singularity:feature Refactoring: replace the hand-written retry loops in api/ with RetryPolicy
```

The pipeline is the same, adapted to the kind of work. A defect spec starts with the reproduction, and the plan's first step is a failing test that reproduces it. For a refactoring, `conventions.breaking_changes` says whether it may drop backward compatibility; client contracts are tested either way.

#### Run without the approval gates

```text
/singularity:feature ABC-123 no-gates
```

Use this for small, well-specified tickets, and for scheduled or headless runs, where nobody is there to approve. Review, verification and their stop rules still apply, and the pipeline still commits or opens a PR/MR only as `conventions` allows. A scheduled or headless run never resumes a ticket that is in progress, blocked or in review, and it leaves a finished task file in review.

#### Resume an interrupted run

If a session died, or a run stopped on blockers, run the same command again:

```text
/singularity:feature ABC-123
```

The pipeline shows the ticket's status and the last lines of its log or comments, and asks whether to resume, because another session may still be working on it. On yes, it continues in the existing work dir from the first stage `run.json` doesn't mark as done, and shows again any gate you hadn't approved. `next` never resumes a task.

Resuming finds the work dir by ticket ID, so it works for tracker tickets and task files, not for runs started from a prompt. For work that may take more than one session, start from a ticket or a task file.

#### Teach the agents by correcting them

The agents' guidelines change for two reasons only: a defect whose root cause is a weak guideline, and your corrections. When an agent gets something wrong, tell it, in the session as you would tell a colleague:

```text
No, we don't use moment here: dates go through formatDate in src/lib/dates.js.
```

The plugin's hooks notice prompts like this one ("that's wrong", "don't use", "you broke", or anything that starts with `correction:`) and queue each with the agent's last message before it, in `<work_dir>/corrections/`, which is never committed. The next `/singularity:feature` run hands the queue to the optimizer's learn job; outside the pipeline, a new session reminds you, and `@agent-singularity:optimizer learn from corrections` does it at once. For each correction the learn job decides:

- whether it corrects an agent at all. A new request, a question or a change of mind is dropped;
- whether it is a rule for the project ("we never mock the database") or only for the task at hand ("make this one blue"), which changes nothing;
- the root cause: a guideline that was missing, wrong or unclear is added or fixed, in the narrowest place the agent reads. A guideline the agent had and didn't follow gets a proposed check (a lint rule, a test or a hook) instead of more text.

Defects found in a run go through the same root-cause step. One that a person or a tool confirmed (a correction, a failed verification, a later fix) changes a guideline at once; one that only a model confirmed (a review finding) waits until it happens a second time. Each correction and defect is recorded in `runs.jsonl` with its cause, without the text of your prompt.

The hooks match English phrases. Add your team's own, for example in its language, as extended regular expressions in `.claude/singularity/correction-patterns.txt`. To stop capturing, set `learning.corrections: false`. Claude Code's own auto memory also saves corrections, on each machine and outside the guidelines; if you want the shared guidelines to be the one place agents learn, turn it off for the project with `"autoMemoryEnabled": false` in `.claude/settings.json`.

#### Learning from human reviews

Singularity has no human review of its own. If your team reviews the PRs/MRs, the defects reviewers catch that the agents missed can count as defects too. Set `learning.pr_reviews: true`, and every `/singularity:feature` run looks up the PRs/MRs of earlier runs by their branch, so it also finds ones you opened by hand. Once one is merged or closed, the optimizer's learn job reads its review comments, finds the root cause of what the reviewers caught, and turns each real defect the agents missed into a regression eval case, which the optimizer later validates review changes against. A PR/MR that is still open waits for a later run, and each run takes up to three. It needs a code host the pipeline can read (`code_host.type` other than `none`).

#### Review a branch without the pipeline

Review is a stage of `/singularity:feature`, not a command of its own. For a branch the pipeline didn't build, ask for the reviewer agent:

```text
@agent-singularity:reviewer review this branch against main through the security lens
```

It reviews through one lens from a fresh context and reports findings with severity, location, evidence and a fix. The pipeline's review adds the other lenses, the project reviewers, and a challenge of every finding by a second reviewer.

#### The optimizer: onboard, optimize, report upstream

The optimizer is an agent, not a command. Ask for it in a session, or run a whole session as it:

```text
@agent-singularity:optimizer onboard
@agent-singularity:optimizer optimize, focus on review false positives
@agent-singularity:optimizer the reviewer keeps flagging our generated clients; report it upstream
claude --agent singularity:optimizer
```

It is one agent that leads the harness to operational perfection for this project: agents that deliver what the project's users need, correctly and without waste. With no instruction it works out what is due. It has four jobs:

- **Learn: after every run, and when you have corrected an agent.** `/singularity:feature` runs it as its learn step, at opus · high. It finds the root cause of each defect and each of your corrections, turns those caused by a weak guideline into the agents' current guidelines, writes a run digest and eval cases, and proposes larger changes for the next optimization.
- **Onboard: the project and what it is for.** `init-project` starts it once; ask again when the project or its goals change. It drafts `.claude/singularity/goals.md` (who the users are, the value they get, the goals now, the trade-offs and constraints) for you to correct and confirm, then surveys the code, the history and recent reviews, writes as guidelines only what agents can't find out quickly for themselves, each where the agent that needs it reads (`CLAUDE.md`, the guideline files, path-scoped rules, the "Do not touch" list), checks the commands, and proposes the lenses, stages and role settings that fit the project.
- **Optimize: lead delivery towards its best.** This is the slow loop, and `/singularity:feature` offers it after every `optimization.every_runs` runs (default 10). It reads the evidence from past runs for three things: what fails, where time and effort are wasted (waiting at gates and for review, rework, stages that cost much and catch little), and whether the work serves the goals. It ranks by harm to the goals and their users, proposes up to five changes to models, lenses, stages, project agents and guidelines, validates them, and delivers them as a draft PR/MR on a `singularity/optimize-<date>` branch. Words after `optimize` narrow it to a focus.
- **Report upstream: improve singularity itself.** When a failure's cause is in the shared plugin, such as an agent's instructions, a default or a standard, it doesn't change the plugin. It writes an upstream report in `.claude/singularity/upstream/` with the problem, the evidence and the proposed fix, plus a local workaround if the project needs relief now. Reports leave out anything that identifies the project. Once the team has approved one in the PR/MR, the optimizer offers to file it as an issue in the singularity repository, and files it only if you say yes.

Some steps need your decision, such as which proposals to implement or which reports to file. In a session, the optimizer comes back with a **Decision needed** block, Claude shows it to you, and your answer goes back to the optimizer. A session started with `claude --agent singularity:optimizer` is the optimizer from start to finish: it asks you directly, and runs singularity's evidence and replay workflows itself.

For a scheduled run, ask for it unattended, for example `claude -p "Use the singularity:optimizer agent: optimize, unattended"`. It skips the gates, implements the context and curation changes and the behaviour changes whose replay passes within `optimization.max_eval_cost_usd`, leaves canaries for a person to choose, leaves the goals unconfirmed, and leaves upstream reports unfiled. Changes to gates, guardrails, permissions and the plugin are only ever proposed. Nothing it does merges without a human. How it works: [Guidelines and self-optimization](#guidelines-and-self-optimization).

### Customizing agents and turning them off

Most of this is set in `.claude/singularity.md` in the project. It is committed, so the whole team gets the same behaviour, and sessions load it when they start, so start a new session after changing it.

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

Set only what you change: a role you leave out keeps its shared default, listed under [Roles and models](#roles-and-models). The implementer's fix rounds run at high effort unless you set `roles.implement.effort`. [docs/models-and-effort.md](docs/models-and-effort.md) has the evidence behind each default.

#### Give the agents project knowledge

Most project specifics don't need a new agent. Put them where the shared agents already look:

- `CLAUDE.md`: what the project is, its architecture, and conventions that differ from the shared engineering standards. Every agent reads it.
- `.claude/singularity/guidelines/project.md`, loaded into every session, and `spec.md`, `plan.md`, `implement.md`, `review.md` and `verify.md` in the same folder, each read by its role.
- `.claude/rules/singularity/<area>.md` for guidelines about one part of the code. Each starts with `paths` frontmatter, such as `paths: ["api/**"]`, and Claude Code loads it only when an agent works on matching files.
- The "Do not touch" section at the end of `.claude/singularity.md`: generated code, vendored libraries, released migrations.

The optimizer keeps the guidelines current and each file within `learning.max_lines_per_file` guidelines (40 for `project.md`). You can edit them too: write the current right way in the present tense, and name the files each one depends on, so that the guideline check notices when they are gone.

The agents stay the shared ones, so their improvements keep reaching the project.

#### Tune the review

```yaml
review:
  lenses: [correctness, security, maintainability, testability]
  extra_lenses:
    - { name: performance, description: "N+1 queries, missing pagination" }
    - { name: accessibility, description: "labels, focus order, contrast" }
```

Each lens is one more reviewer, so it adds cost and time to every run. Only the lenses in `review.blocking_lenses` (default: correctness and security) and the project reviewers in `review.extra_reviewers` can block a change; they run on the review model, and each of their blocking findings gets a challenger. Every other lens advises: it reports at most `should-fix`, its findings aren't challenged, and it runs on `review.advisory` (default `{ model: sonnet, effort: high }`). Production reviewers converge on this: they focus on correctness by default, because style and design remarks that block a change are where false positives and rework come from. Drop a shared lens only with a reason, and write the reason next to it. A small change is reviewed through correctness, and security if it comes near a risky area; a large one gets a second, independent correctness pass.

#### Hooks

`init-project` can add three scripts in `.claude/singularity/hooks/`:

- `post-edit.sh` runs after every file edit, for example to format the file. Exit 2 with a message on stderr to send feedback to Claude.
- `pre-bash.sh` runs before every shell command, as well as the shared guard. Exit 2 with a message on stderr to block the command.
- `verify.sh` is run by the verifier, for checks the commands don't cover, such as contract tests or a smoke test.

`post-edit.sh` and `pre-bash.sh` run only while they are executable.

The plugin also has hooks of its own:

- a guard that blocks force-pushes to protected branches (main, master, develop, trunk, production, release branches and `conventions.default_branch`), skipping git hooks (`--no-verify`, `git commit -n`, `core.hooksPath`, `HUSKY=0`) and recursive deletes of `/` or the home directory. It reads commands the way a shell splits them, so quoting doesn't get past it and a commit message that mentions these commands doesn't trip it. It is a seatbelt against mistakes, not a security boundary: Claude Code's docs call Bash rules that constrain arguments fragile. Protect the default branch on your code host, and use Claude Code's sandbox (`/sandbox`) where you need enforcement;
- a stop gate: the implementer can't finish while the project's checks fail (`checks.implement_gate`, `checks.stop_retries`);
- a guard that blocks edits to tests the implementer froze;
- two that capture your corrections for the learn job (see [Teach the agents by correcting them](#teach-the-agents-by-correcting-them)).

#### Turn things off

| To turn off | Do this |
|---|---|
| The approval gates, for one run | Add `no-gates` to the command |
| Learning after each run | `learning.enabled: false`. This also stops capturing corrections, learning from human reviews, and the run digests that optimizations and their reminder work from |
| Capturing your corrections from prompts | `learning.corrections: false` |
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

The spec, plan, implement, checks, review and verify stages are the pipeline itself, so they can't be turned off one by one; small changes already skip the plan. To make a stage cheaper, give its role a smaller model or lower effort, or bind it to your own agent; for a different sequence of stages, write your own workflow (next section). The shared command guard stays on as long as the plugin is enabled.

### Creating custom roles and agents

The pipeline's roles are fixed: spec, plan, implement, review, verify and optimize, whose learn job is the pipeline's learn step. A project adds behaviour with its own agents, Markdown files in `.claude/agents/`, attached at one of four points:

| Point | Config | When it runs | Example |
|---|---|---|---|
| Replace a role | `roles.<role>.agent` | instead of the shared agent | `custom-implementer.md.example` |
| Add a reviewer | `review.extra_reviewers` | in the review stage, next to the lenses | `review-domain.md.example` |
| Add a pipeline step | `stages.after_plan`, `after_implement`, `before_handoff` | at that point in `/singularity:feature` | |
| Add a workflow or command | `.claude/workflows/*.js`, `.claude/skills/<name>/SKILL.md` | when someone runs it | `dependency-upgrade.js.example` |

The examples are in [`plugins/singularity/templates/project/.claude/`](plugins/singularity/templates/project/.claude/); `init-project` copies them if you ask.

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

- `name` is how the config refers to the agent: plain, unique, without `singularity:` and without `:`.
- `description` says what it does and where it runs. Claude uses it to decide when to delegate, so say when an agent is only for the pipeline.
- `tools`: the fewest it needs. Reviewers and checkers get no `Write` or `Edit`.
- `model` and `effort`: choose with [Choosing model and effort for a custom agent](docs/models-and-effort.md#choosing-model-and-effort-for-a-custom-agent). For an agent bound to a role, `roles.<role>.model` and `.effort` override them.
- `skills: [singularity:engineering-standards]` preloads the shared standards, as the shared agents do.
- In the body, name the guidelines file it should read, say exactly what to report and when a problem is blocking, and tell it to report only what it can prove.

Commit the agent; `git check-ignore .claude/agents/<name>.md` should print nothing. Try it on its own before wiring it in, for example by asking Claude to "use the migration-checker agent on this branch".

#### Replace a role's agent

```yaml
roles:
  implement: { agent: android-implementer }
```

Do this when the role needs instructions or tools the shared agent can't get from `CLAUDE.md` and the guidelines, such as a platform's build commands. The stages hand work to each other through files, so a replacement has to keep its role's contract:

| Role | Gets | Must deliver |
|---|---|---|
| spec | the ticket, its kind (feature, defect or refactoring) and an output path | a spec at that path, with numbered acceptance criteria and open questions |
| plan | the spec path and an output path | a plan at that path, with steps as checkboxes (`- [ ] 1. …`), which resuming relies on |
| implement | the spec and plan paths; in fix rounds, the findings or failures | code and tests on the current branch, each finished step ticked in the plan |
| review | a lens, the base and the spec (task A), or one finding to challenge (task B) | findings with severity, location, problem, evidence and fix; or a verdict: confirmed, severity, reason |
| verify | the spec path | a table of checks with evidence, the Test Coverage and Verification Summary, then PASS or FAIL |
| optimize, learn job | the work dir and the run record, and the human review comments on earlier runs' PRs/MRs | updated guidelines and a run digest; for each PR/MR, a `human_review` digest and an eval case per escaped defect |

The optimize role can be rebound too, with `roles.optimize.agent`, which also takes over its learn job, but its contract is the longest, and its playbooks in [`plugins/singularity/optimizer/`](plugins/singularity/optimizer/) are found through the plugin's own path, which a project agent doesn't get. Prefer an upstream report to a fork of the optimizer.

The safest start is a copy of the shared agent, [`plugins/singularity/agents/<agent>.md`](plugins/singularity/agents/), renamed, with the project specifics added. A replacement is a fork: later improvements to the shared agent no longer reach that role, so keep replacements few, and read the [changelog](CHANGELOG.md) for changes to the agents you replaced when you upgrade. To add project rules to the review, add a reviewer rather than replacing the review role.

#### Add a reviewer

```yaml
review:
  extra_reviewers: [review-domain]
```

A reviewer runs only when it is listed here. It gets the change's base and the spec, runs on its own model and effort, and must report findings with severity (`blocking`, `should-fix` or `nit`), location, problem, evidence and fix. The review role challenges each finding: confirmed ones count like lens findings, so blocking ones go to a fix round, and rejected ones go into `review.md` for the optimizer's learn job. `review-domain.md.example` is a starting point for rules such as "money amounts use the Money type".

#### Add a pipeline step

```yaml
stages:
  after_plan: [threat-modeler]           # read-only checks of the plan
  after_implement: [migration-checker]   # runs before review, so its changes get reviewed
  before_handoff: [release-notes-writer] # after review and verification
```

Each agent runs in list order and gets the work dir path, so it can read the spec, the plan and, later, `review.md`. If it reports a blocking problem, the pipeline shows it to you and asks whether to fix it and run the agent again, continue anyway, or stop. A scheduled or headless run stops, as it does on remaining review blockers. A `before_handoff` agent runs after review and verification, so anything it changes goes unreviewed: keep it to notes and documents, or make it read-only.

#### Add a workflow or a command

For a sequence of stages that `/singularity:feature` doesn't fit, write your own:

- **Workflow:** `.claude/workflows/<name>.js`, run as `/<name>`. It orchestrates agents in code with `agent(prompt, { agentType, model, effort, isolation, schema, label, phase })`, `pipeline` and `parallel`. `agentType` is a shared agent (`'singularity:implementer'`) or one of yours. `dependency-upgrade.js.example` upgrades each listed package in its own worktree with the shared implementer, then verifies each with the shared verifier; rename it to `.js` to use it.
- **Skill:** `.claude/skills/<name>/SKILL.md`, a command (`/<name>`), or knowledge Claude loads when it's relevant. A skill can use singularity's parts: the `tracker` skill for tickets, and the shared agents, such as `singularity:reviewer` for a review through one lens.

#### Let custom agents learn

Tell each custom agent which guidelines file to read: the one for the role it replaces, or `project.md`. Findings from extra reviewers count like any other finding: confirmed ones lead to implement or plan guidelines, and rejected ones to review guidelines. The optimizer covers project agents too: it can propose changes to them, with evidence, for you to approve.

## Roles and models

Every code-facing role preloads the `engineering-standards` skill (definition of done, no hardcoding, dependency injection, red-green-refactor, test pyramid, boundary and failure-mode coverage, deterministic assertions, zero debt). The standards are one file, `skills/engineering-standards/SKILL.md`; the roles enforce them at their own stage, and `docs/adopted-roles.md` maps each adopted guideline to where it is enforced.

Pipelines refer to **roles**, not agent names. Each role has a shared default, and a project can bind a role to its own agent.

| Role | Default agent | Model · effort | Why |
|---|---|---|---|
| spec | `singularity:spec-writer` | opus · high | ambiguity costs the most when caught late |
| plan | `singularity:planner` | opus · high | a precise plan lets a fast model implement it |
| implement | `singularity:implementer` | **sonnet · medium**, fix rounds high | fast; targeted tests during steps, full suite once at the end. Fix rounds escalate to high: re-running a failure at higher effort costs less than raising the baseline |
| review | `singularity:reviewer` | **fable · high** for the blocking lenses; sonnet · high for advisory ones | read-only, fresh context, four lenses (correctness and security block, maintainability and testability advise), blocking findings challenged. Opus 5.5 · high is the first trial to replay |
| verify | `singularity:verifier` | sonnet · medium | runs the checks through `run-checks.sh`, so pass and fail are exit codes, maps acceptance criteria to tests and confirms the tests are intact; lower effort makes fewer tool calls |
| optimize | `singularity:optimizer` | **fable · xhigh**; its learn job **opus · high** | onboarding and optimization are rare, high-leverage changes to the workflow itself; the learn job runs after every run, and curation needs a strong model but not that budget (`roles.learn` sets its model and effort) |

The defaults live in one place: the frontmatter of `plugins/singularity/agents/*.md`. A project overrides them in its `.claude/singularity.md`: see [Change a role's model or effort](#change-a-roles-model-or-effort) and [Replace a role's agent](#replace-a-roles-agent). The evidence behind each default, and how to choose model and effort for a project's own agents, is in [docs/models-and-effort.md](docs/models-and-effort.md).

If an organization's model allowlist blocks a model, Claude Code falls back to the newest allowed version of the same family, or else to the session model. On Amazon Bedrock, Google Cloud and Microsoft Foundry some aliases resolve to older models (for example `sonnet` to Sonnet 4.5); check with `/model`. Per-call `effort` overrides need Claude Code v2.1.292 or later.

## Trackers

One `tracker` skill exposes the same operations everywhere (`get`, `next`, `comment`, `move`, `link`, `open_change`, `find_change`, `review_comments`) and loads only the adapter the project uses:

| Project config | Adapter | Access |
|---|---|---|
| `tracker.type: jira` | `skills/tracker/jira.md` | Atlassian MCP server (`templates/mcp/jira.mcp.json`) |
| `tracker.type` / `code_host.type: github` | `skills/tracker/github.md` | `gh` CLI |
| `tracker.type` / `code_host.type: gitlab` | `skills/tracker/gitlab.md` | `glab` CLI |
| `tracker.type: files` | `skills/tracker/files.md` | Task files in a git-ignored folder, through `skills/tracker/scripts/tasks.sh` |

Tracker and code host are set independently, so Jira with GitLab MRs works. Logical states map to Jira statuses or to labels via `tracker.states`.

**Task files.** With `tracker.type: files`, each task is a file in a git-ignored folder (default `.tasks/`), and its status is the file name prefix: `TODO-T7-fix-login.md`, `PROGRESS-T3-add-search.md`, `DONE-T1-setup-ci.md`. The statuses are `TODO`, `PROGRESS`, `REVIEW`, `BLOCKED` and `DONE`. A project can rename them, and add any others it needs, such as `QA` or `ON_HOLD`, with `tracker.files.extra_statuses`. `/singularity:feature next` takes the first `TODO` task (lowest `priority` in its front matter, then lowest ID) and claims it by renaming it to `PROGRESS`. The rename is atomic, so two sessions never take the same task. At hand-off the task moves to `REVIEW`, and to `DONE` when you confirm. Naming a task that is already in progress, blocked or in review, for example after a session died, offers to resume it from where its work dir stopped.

## Guidelines and self-optimization

One agent, the **optimizer**, runs the self-improvement: its learn job after every run, onboarding, optimizations every ~10 runs, and upstream reports. It works towards what the project is for, written down with the team in `.claude/singularity/goals.md`. The agents doing the work follow **guidelines**: how to work in the project as it is now. They don't read how the guidelines came about; that history is kept apart, for the optimizer. Each project commits:

- `.claude/singularity/goals.md`: who the project's users are, the value they get, the goals now, the trade-offs and constraints. The team owns it: the optimizer drafts it at onboarding with `Status: draft`, and once the team changes that to `Status: confirmed`, the optimizer only proposes changes. The agents rely on it only once it is confirmed. The optimizer, the spec writer and the planner read it.
- `.claude/singularity/guidelines/`, what the agents read:
  - `project.md`, which every session loads, for what every role needs anywhere in the code;
  - `spec.md`, `plan.md`, `implement.md`, `review.md` and `verify.md`, each read by its role.
- `.claude/rules/singularity/`: guidelines for one part of the code. Each file is scoped by `paths`, and Claude Code loads it only when an agent works on matching files.
- `.claude/singularity/experience/`, the record, which the agents doing the work don't read:
  - `runs.jsonl`, with one digest line per run and per human review, including the guidelines each run added, changed or removed;
  - `optimizations.md`, the optimizer's archive;
  - `upstream.md`, guidelines that may apply to every project, with their evidence.
- `.claude/singularity/evals/`: regression cases built from real escaped defects and known false positives.
- `.claude/singularity/upstream/`: the optimizer's upstream reports for the singularity maintainers.

**Why guidelines, not a log of lessons.** Agents act on what is in their context. They copy retrieved past experience into new work, mistakes included, and a note about code that is gone misleads every run that reads it. So a guideline states only the current right way, names the files it depends on, and changes in the same PR/MR as the code it describes. The research behind this is in [docs/self-optimization.md](docs/self-optimization.md#guidelines-not-a-log-of-lessons).

**Onboarding (optimizer, once, and when the project changes).** Before there are runs to learn from, the optimizer forms the project context: the first guidelines, limited to what agents can't find out quickly for themselves (exact commands and tools, non-obvious conventions, risks, what not to touch), each where the agent that needs it reads. It writes no repository overview: research found that overviews don't help agents, and that context files written by an LLM can hurt, so what it writes is small and the team reviews it. The context audit in every optimization keeps them current.

**Fast loop (the optimizer's learn job, every run, and whenever corrections are waiting).** Guidelines change for two signals only:

- **defects whose root cause is a weak guideline:** confirmed review findings, rejected findings (reviewer false positives), verification failures, a later run fixing a pipeline change, and, where a project turns it on, what human reviewers caught. Each defect that got past the review also becomes an eval case;
- **your corrections:** prompts in which you tell an agent it did something wrong, which the plugin's hooks capture, and your edits at the approval gates.

For each one the learn job finds the root cause first: a guideline that was missing, wrong or unclear is added or fixed; a guideline the agent had and ignored gets a proposed check instead of more text; anything else (a one-off slip, a flaky environment, a request for this task only) changes no guideline. What a person or a tool confirmed counts at once; what only a model confirmed counts when it recurs. Apart from these, the run's own change keeps the guidelines true: guidelines about code the run renamed, moved or removed are corrected or removed in the same run.

Before it finishes, the guideline check (`scripts/check-guidelines.sh` in the plugin) reports any path a guideline names that doesn't exist, rules that would load everywhere or nowhere, ids used twice, and wording left from the old lesson log. A span it reports that isn't a path goes into `.claude/singularity/guidelines/check-ignore.txt`. Where a lint rule, a test or a hook could enforce a guideline, the learn job proposes that check, and the change that adds the check removes the guideline.

**Slow loop (optimizer, every ~10 runs or on a schedule).** It runs a fixed cycle:

1. **Evidence:** quality and flow trends (lead time, the share of it spent working rather than waiting, rework, changes a later run had to fix, cost per run), how the effort splits across the goals, a failure taxonomy that says where each fix belongs (the project or the plugin), gate corrections, a guideline audit (history in place of guidance, duplicates, guidelines a check could enforce), a context audit (guidelines about code that is gone), due contracts, eval coverage, and a web practice scan for new Claude Code features, models and research.
2. **Propose:** up to five changes, ranked by harm to the goals and their users. Each is a falsifiable contract: the goal it serves, what it should fix, by how much, and what it might break.
3. **Challenge:** a reviewer tries to refute each proposal.
4. **Gate:** you choose which to implement.
5. **Implement:** one commit per change.
6. **Validate:** replayed eval cases, or a canary. A change is adopted only without regressions, held-out cases included.
7. **Deliver:** everything goes into the archive and a draft PR/MR.

**Upstream (optimizer, whenever the cause is in the plugin).** A fix that suits one project can break another, so the optimizer never changes the plugin. It writes an upstream report, with the problem, the evidence as counts and categories, the exact fix and how to validate it, and the team files approved reports as issues in this repository.

**What the optimizer can never change:** the confirmed goals, approval gates, guardrails, permissions, existing eval cases or metric definitions, or the plugin itself, its own definition included. It can only propose those, the plugin through upstream reports. The goals, the eval cases and the reviewer that challenges each proposal are what measure it, so it doesn't grade itself.

Design rationale and sources: [docs/self-optimization.md](docs/self-optimization.md).

**Upgrading from 0.4.0.** The learner agent is now the optimizer's learn job: `roles.learn` still sets its model and effort, and a `roles.learn.agent` binding no longer applies. Projects set up before 0.5.0 keep a log of lessons in `.claude/singularity/experience/`, which the roles no longer read. `/singularity:feature` notices, and has the optimizer migrate it before the run (an attended run can stop instead): the optimizer checks each lesson against the code, rewrites the ones that still hold as guidelines, drops the rest with the reason, and delivers the result as a draft PR/MR.

**Improving singularity itself.** Projects don't send their experience here; their optimizers send upstream reports. Maintainers adopt them as described in [Adopting upstream reports](CONTRIBUTING.md#adopting-upstream-reports): reproduce the failure as a case in the plugin's own suite in `plugins/singularity/evals/`, make the change, check that nothing regresses, and release it to every project.

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
  hooks/ scripts/  guardrails, project hook extension points, correction capture, the guideline check
  templates/       project files for init-project, Jira MCP config
docs/                     design notes, adopted role prompts and where each clause lives
scripts/                  release.sh and version.js (versions and releases), check-evals.js, check-sensitive.sh
CHANGELOG.md              what changed in each release
```

## Changing the shared setup

1. Edit here, often to adopt an upstream report from a project, test with `claude --plugin-dir ./plugins/singularity` in any project, run `claude plugin validate --strict .` and the eval suite (see `plugins/singularity/evals/README.md`).
2. Add a line under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md) saying what changes for projects, and merge to the default branch.
3. Release when you want projects to get it (next section). Merging alone reaches no project.

## Versions and releases

The plugin's version lives in one place: `version` in `plugins/singularity/.claude-plugin/plugin.json`. Claude Code installs and updates plugins by version, so a project gets new files only when that string changes. Projects add the marketplace at the `stable` branch, which moves only when a release is published, so a version always means the same files. `main` carries merged but unreleased changes.

### What the version means

Versions follow [Semantic Versioning](https://semver.org). The public interface is everything a project depends on: the `/singularity:*` commands and their arguments, role and agent names, workflow names and arguments, the keys in `.claude/singularity.md`, the project hook extension points, the locations and formats of the guideline files and rules, and the formats of `runs.jsonl` and eval cases.

| Bump | When | Examples |
|---|---|---|
| Major | A project must change something to keep working | rename a config key or command, change the `runs.jsonl` or eval-case format, remove a role |
| Minor | New capability, or behaviour projects get without doing anything | a new command, config key or review lens; an agent's model, effort or instructions change |
| Patch | Fixes that keep the intended behaviour | a bug in a workflow or hook, clearer wording, docs |

While the version is 0.x the interface isn't stable yet: a breaking change bumps the minor version and its changelog line starts with **Breaking:**. There are no pre-release versions, because a marketplace serves one version at a time; try unreleased changes with `claude --plugin-dir`.

### Release

Releases are published by GitHub, in [hlistan/singularity](https://github.com/hlistan/singularity), never pushed from a local checkout. A release is a pull request to `main` that changes the version, and merging it starts the [Release workflow](https://github.com/hlistan/singularity/actions/workflows/release.yml), which:

- creates the [tag](https://github.com/hlistan/singularity/tags) `singularity--v<version>`, the same tag `claude plugin tag` creates;
- moves the [`stable`](https://github.com/hlistan/singularity/tree/stable) branch to the tagged commit;
- publishes a [GitHub release](https://github.com/hlistan/singularity/releases) whose notes are that version's changelog section.

Run one command from an up-to-date `main`:

```bash
scripts/release.sh minor
```

The level is `patch`, `minor` or `major`, chosen with the [table above](#what-the-version-means), or an explicit `X.Y.Z`. `--dry-run` checks everything and shows the plan, then stops; it changes nothing except fast-forwarding `main` if GitHub's is ahead. `--yes` skips the confirmation, and `--date YYYY-MM-DD` sets the changelog date (default: today, UTC). `--admin` is for maintainers on the ruleset's bypass list who have no one else to approve: GitHub never lets authors approve their own pull requests, so once every check on the pull request has passed, it merges with the bypass (`gh pr merge --admin`) instead of waiting for a review. The script needs `git`, Node.js, and `gh` signed in to github.com with write access to the repository.

It stops at the first problem, and does this:

1. **Checks** the GitHub repository named by `repository` in `plugin.json`, and the git remote that points at it, whatever it's called (https or ssh). Then it checks that:
   - you have write access to the repository;
   - you're on `main` with no uncommitted changes, at the same commit as GitHub (it fast-forwards if GitHub is ahead, and refuses if you have commits GitHub doesn't);
   - the last CI run on that commit passed, and `node scripts/version.js check` passes;
   - something is waiting under `## [Unreleased]`;
   - **Breaking:** lines aren't being released as a patch, or as a minor from 1.0 on;
   - the release branch and tag don't exist yet.
2. **Shows the plan** (versions, tag, release notes) and asks you to confirm.
3. **Bumps the version** on `release/<version>` with `node scripts/version.js bump`, checks that only `CHANGELOG.md` and `plugin.json` changed, commits `chore(release): singularity <version>` and pushes the branch.
4. **Opens the release pull request**, with the release notes as its description, and waits for its checks.
5. **Squash-merges it.** If `main` needs an approving review, it merges with your bypass when you passed `--admin`. Otherwise it turns on auto-merge for someone else's approval, tells you how to merge with the bypass on GitHub, and waits until the pull request is merged.
6. **Follows the Release workflow** run for the merge commit until it finishes.
7. **Checks the result:** the GitHub release is published, and the tag and `stable` point at the same commit.
8. **Updates your `main`**, fetches the tag, and deletes the release branch locally and on GitHub.

If a step fails, the script says where the release stopped and the exact commands to continue or undo it. A Release workflow that failed part-way can be re-run once the cause is fixed on `main`; it skips whatever is already done:

```bash
gh workflow run release.yml --repo hlistan/singularity --ref main
```

Projects with auto-update on, which the `init-project` template sets, download the release in the background when a session starts, and load it on `/reload-plugins` or at the following start. A session that was already running when the release came out keeps the old version: `/reload-plugins` reloads what is installed but doesn't download anything. To switch a running session, run `/plugin marketplace update singularity` first, then `/reload-plugins`. Projects without auto-update run `claude plugin update singularity@singularity`. `claude plugin list` shows the installed version, and each run digest records it as `plugin_version` (`+dev` for a `--plugin-dir` checkout), so the optimizer compares releases rather than commits.

CI enforces the rules with `node scripts/version.js check`: one valid version, set only in `plugin.json`; a changelog section for it; on pull requests, a version that only goes up and a changelog line for every change to `plugins/singularity/` (eval cases excepted).

### Pin a project to a release

To hold a project on one release, set `ref` in the marketplace source in its `.claude/settings.json` to that release's tag, and change it when you want to upgrade:

```json
"source": { "source": "git", "url": "https://github.com/hlistan/singularity.git", "ref": "singularity--v0.1.0" }
```

Claude Code registers a marketplace per user rather than per project, so the pin applies to every project on that machine. Projects that share machines should agree on the `ref`.

## Security and contributing

See [SECURITY.md](SECURITY.md) for what the plugin runs on your machine and how to report a vulnerability, [CONTRIBUTING.md](CONTRIBUTING.md) for the development setup and checks, and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## License

[MIT](LICENSE).
