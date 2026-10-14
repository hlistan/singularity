# Project Singularity

[![CI](https://github.com/hlistan/singularity/actions/workflows/ci.yml/badge.svg)](https://github.com/hlistan/singularity/actions/workflows/ci.yml) [![Sensitive information checks](https://github.com/hlistan/singularity/actions/workflows/sensitive-info.yml/badge.svg)](https://github.com/hlistan/singularity/actions/workflows/sensitive-info.yml) [![Release](https://img.shields.io/github/v/release/hlistan/singularity?display_name=release&label=release)](https://github.com/hlistan/singularity/releases/latest) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A self-improving harness for autonomous software delivery with [Claude Code](https://code.claude.com), packaged as **one plugin**. Shared behaviour (agents, pipelines, guardrails, standards) lives in this repository. Each project repo holds only its config, its own agents and workflows, its accumulated experience and its eval cases. Change something here, release it, and every project picks it up.

> **Status:** early. The structure validates and the workflows pass dry runs, but the pipelines have not yet been exercised at scale on real projects. Feedback and experience reports are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md).

The plugin is loaded straight from this git repository through `marketplace.json`; nothing is published to a registry. Projects follow versioned releases: see [Versions and releases](#versions-and-releases).

## The pipeline

```text
/singularity:feature <ticket>

 tracker.get ─▶ spec ─▶ [gate] ─▶ plan ─▶ [gate] ─▶ after_plan* ─▶ implement ─▶ after_implement*
                                                                                  │
 learn ◀─ hand-off ◀─ before_handoff* ◀─ verify ◀─ fix blockers (≤2) ◀─ deep-review (lenses + extra reviewers, each finding challenged)
   │
   └─▶ lessons + run digest (fast loop)       every ~10 runs ─▶ /singularity:optimize (slow loop)
                                                                   * = project-defined stages
```

| Command | What it does |
|---|---|
| `/singularity:feature <ticket \| defect \| refactoring>` | Full pipeline with approval gates after the spec and the plan. A defect starts with its reproduction as a failing test |
| `/singularity:deep-review` | Workflow: one reviewer per lens and per project reviewer, every finding challenged by a second reviewer |
| `/singularity:learn <slug \| PR/MR>` | Fast loop: lessons, run digest, and regression eval cases from human-review misses |
| `/singularity:optimize [project\|shared] [focus] [unattended]` | Slow loop: evidence-based changes to the workflow itself, validated and delivered as a PR/MR |
| `/singularity:init-project` | Onboards a project repo |

## Roles and models

Every code-facing role preloads the `engineering-standards` skill (definition of done, no hardcoding, dependency injection, red-green-refactor, test pyramid, boundary and failure-mode coverage, deterministic assertions, zero debt). The standards are one file, `skills/engineering-standards/SKILL.md`; the roles enforce them at their own stage, and `docs/adopted-roles.md` maps each adopted guideline to where it is enforced.

Pipelines refer to **roles**, not agent names. Each role has a shared default, and a project can bind a role to its own agent.

| Role | Default agent | Model · effort | Why |
|---|---|---|---|
| spec | `singularity:spec-writer` | opus · high | ambiguity costs the most when caught late |
| plan | `singularity:planner` | opus · high | a precise plan lets a fast model implement it |
| implement | `singularity:implementer` | **sonnet · medium**, fix rounds high | fast; targeted tests during steps, full suite once at the end. Fix rounds escalate to high: re-running a failure at higher effort costs less than raising the baseline |
| review | `singularity:reviewer` | **fable · high** | read-only, fresh context, four lenses (correctness, security, maintainability, testability), findings challenged. Opus 5.5 · high is the first trial to replay |
| verify | `singularity:verifier` | sonnet · medium | runs every check and maps acceptance criteria to tests; lower effort makes fewer tool calls |
| learn | `singularity:learner` | opus · high | curation decides whether experience helps or hurts |
| optimize | `singularity:optimizer` | **fable · xhigh** | rare, high-leverage changes to the workflow itself |

The defaults live in one place: the frontmatter of `plugins/singularity/agents/*.md`. A project overrides a role in its `.claude/singularity.md`:

```yaml
roles:
  implement: { agent: android-implementer }      # project agent in .claude/agents/
  review:    { model: opus, effort: high }       # e.g. if Fable isn't enabled for the org
```

The evidence behind each default, and how to choose model and effort for a project's own agents, is in [docs/models-and-effort.md](docs/models-and-effort.md).

If an organization's model allowlist blocks a model, Claude Code falls back to the newest allowed version of the same family, or else to the session model. On Amazon Bedrock, Google Cloud and Microsoft Foundry some aliases resolve to older models (for example `sonnet` to Sonnet 4.5); check with `/model`. Per-call `effort` overrides need Claude Code v2.1.292 or later.

## Trackers

One `tracker` skill exposes the same operations everywhere (`get`, `next`, `comment`, `move`, `link`, `open_change`, `review_comments`) and loads only the adapter the project uses:

| Project config | Adapter | Access |
|---|---|---|
| `tracker.type: jira` | `skills/tracker/jira.md` | Atlassian MCP server (`templates/mcp/jira.mcp.json`) |
| `tracker.type` / `code_host.type: github` | `skills/tracker/github.md` | `gh` CLI |
| `tracker.type` / `code_host.type: gitlab` | `skills/tracker/gitlab.md` | `glab` CLI |
| `tracker.type: files` | `skills/tracker/files.md` | Task files in a git-ignored folder, through `skills/tracker/scripts/tasks.sh` |

Tracker and code host are set independently, so Jira with GitLab MRs works. Logical states map to Jira statuses or to labels via `tracker.states`.

**Task files.** With `tracker.type: files`, each task is a file in a git-ignored folder (default `.tasks/`), and its status is the file name prefix: `TODO-T7-fix-login.md`, `PROGRESS-T3-add-search.md`, `DONE-T1-setup-ci.md`. The statuses are `TODO`, `PROGRESS`, `REVIEW`, `BLOCKED` and `DONE`, and a project can rename them. `/singularity:feature next` takes the first `TODO` task (lowest `priority` in its front matter, then lowest ID) and claims it by renaming it to `PROGRESS`. The rename is atomic, so two sessions never take the same task. At hand-off the task moves to `REVIEW`, and to `DONE` when you confirm.

## Project customisation

| Need | Where (in the project repo) |
|---|---|
| Swap an agent for a role | `.claude/agents/<name>.md` + `roles.<role>.agent`; pick its model and effort with [docs/models-and-effort.md](docs/models-and-effort.md#choosing-model-and-effort-for-a-custom-agent) |
| Extra review dimensions | `review.extra_lenses` (text) or `review.extra_reviewers` (project agents) |
| Extra pipeline steps | `stages.after_plan / after_implement / before_handoff` |
| Project workflows | `.claude/workflows/*.js`, using shared agents via `agentType: 'singularity:…'` (example in templates) |
| Project commands / knowledge | `.claude/skills/<name>/SKILL.md` |
| Formatting, guards, extra checks | `.claude/singularity/hooks/{post-edit,pre-bash,verify}.sh` |

## Experience and self-optimization

Each project commits two things:

- `.claude/singularity/experience/`, written by the learner:
  - lessons per role, plus `project.md`, which every session loads;
  - `runs.jsonl`, with one digest line per run and per human review;
  - `upstream.md`, lessons that apply to every project;
  - `optimizations.md`, the optimizer's archive.
- `.claude/singularity/evals/`: regression cases built from real escaped defects and known false positives.

**Fast loop (learner, every run).** It records lessons from:

- confirmed review findings;
- rejected findings (reviewer false positives);
- verification failures;
- your edits at the approval gates;
- and, through `/singularity:learn <PR/MR>`, what human reviewers caught that the agents missed. Each of those also becomes an eval case.

**Slow loop (optimizer, every ~10 runs or on a schedule).** It runs a fixed cycle:

1. **Evidence:** the `optimize-scan` workflow gathers metric trends, a failure taxonomy, gate corrections, an experience audit, due contracts, eval coverage, and a web practice scan for new Claude Code features, models and research.
2. **Propose:** up to five changes. Each is a falsifiable contract: what it should fix, by how much, and what it might break.
3. **Challenge:** a reviewer tries to refute each proposal.
4. **Gate:** you choose which to implement.
5. **Implement:** one commit per change.
6. **Validate:** replayed eval cases, `claude plugin eval` for shared changes, or a canary. A change is adopted only without regressions, held-out cases included.
7. **Deliver:** everything goes into the archive and a draft PR/MR.

**What the optimizer can never change:** approval gates, guardrails, permissions, existing eval cases or metric definitions, or its own definition. It can only propose those.

Design rationale and sources: [docs/self-optimization.md](docs/self-optimization.md).

`/singularity:optimize shared`, run inside this repo, reads the committed experience of every project in `optimizer/projects.yaml` and improves the shared agents, skills and standards. It validates them with the plugin's own suite in `plugins/singularity/evals/`.

## Layout

```text
.claude-plugin/marketplace.json
plugins/singularity/
  .claude-plugin/plugin.json
  agents/          spec-writer, planner, implementer, reviewer, verifier, learner, optimizer
  skills/          feature, tracker (+ jira/github/gitlab), learn, optimize, engineering-standards, init-project
  workflows/       deep-review.js, optimize-scan.js, replay-evals.js
  evals/           regression suite for the shared plugin (claude plugin eval)
  hooks/ scripts/  guardrails + project hook extension points
  templates/       project files for init-project, Jira MCP config
optimizer/projects.example.yaml   template for the (git-ignored) list of projects the shared optimizer learns from
docs/                     design notes, adopted role prompts and where each clause lives
scripts/                  release.sh and version.js (versions and releases), check-evals.js, check-sensitive.sh
CHANGELOG.md              what changed in each release
```

## Connect a project

1. Once per machine: `claude plugin marketplace add hlistan/singularity#stable`, then `claude plugin install singularity@singularity`.
2. In the project: run `/singularity:init-project`, review the generated files, and commit them. From then on, anyone who clones the project and trusts the folder gets singularity through `.claude/settings.json`, and new releases arrive through auto-update.

## Changing the shared setup

1. Edit here (or let `/singularity:optimize shared` propose the change), test with `claude --plugin-dir ./plugins/singularity` in any project, run `claude plugin validate --strict .` and the eval suite (see `plugins/singularity/evals/README.md`).
2. Add a line under `## [Unreleased]` in [CHANGELOG.md](CHANGELOG.md) saying what changes for projects, and merge to the default branch.
3. Release when you want projects to get it (next section). Merging alone reaches no project.

## Versions and releases

The plugin's version lives in one place: `version` in `plugins/singularity/.claude-plugin/plugin.json`. Claude Code installs and updates plugins by version, so a project gets new files only when that string changes. Projects add the marketplace at the `stable` branch, which moves only when a release is published, so a version always means the same files. `main` carries merged but unreleased changes.

### What the version means

Versions follow [Semantic Versioning](https://semver.org). The public interface is everything a project depends on: the `/singularity:*` commands and their arguments, role and agent names, workflow names and arguments, the keys in `.claude/singularity.md`, the project hook extension points, and the formats of the experience files, `runs.jsonl` and eval cases.

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

Projects with auto-update on, which the `init-project` template sets, download the release in their next session and load it on `/reload-plugins` or the following start. Others run `claude plugin update singularity@singularity`. `claude plugin list` shows the installed version, and each run digest records it as `plugin_version` (`+dev` for a `--plugin-dir` checkout), so the optimizer compares releases rather than commits.

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
