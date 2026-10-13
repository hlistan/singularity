# Project Singularity

[![CI](https://github.com/hlistan/singularity/actions/workflows/ci.yml/badge.svg)](https://github.com/hlistan/singularity/actions/workflows/ci.yml) [![Sensitive information checks](https://github.com/hlistan/singularity/actions/workflows/sensitive-info.yml/badge.svg)](https://github.com/hlistan/singularity/actions/workflows/sensitive-info.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A self-improving harness for autonomous software delivery with [Claude Code](https://code.claude.com), packaged as **one plugin**. Shared behaviour (agents, pipelines, guardrails, standards) lives in this repository. Each project repo holds only its config, its own agents and workflows, its accumulated experience and its eval cases. Change something here and every project picks it up.

> **Status:** early. The structure validates and the workflows pass dry runs, but the pipelines have not yet been exercised at scale on real projects. Feedback and experience reports are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md).

The plugin is loaded straight from this git repository through `marketplace.json`; nothing is published to a registry.

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
| implement | `singularity:implementer` | **sonnet · medium** | fast; targeted tests during steps, full suite once at the end |
| review | `singularity:reviewer` | **fable · high** | strongest model, read-only, fresh context, four lenses (correctness, security, maintainability, testability), findings challenged |
| verify | `singularity:verifier` | sonnet · low | runs commands, reports evidence |
| learn | `singularity:learner` | opus · high | curation decides whether experience helps or hurts |
| optimize | `singularity:optimizer` | **fable · xhigh** | rare, high-leverage changes to the workflow itself |

The defaults live in one place: the frontmatter of `plugins/singularity/agents/*.md`. A project overrides a role in its `.claude/singularity.md`:

```yaml
roles:
  implement: { agent: android-implementer }      # project agent in .claude/agents/
  review:    { model: opus, effort: xhigh }      # e.g. if Fable isn't enabled for the org
```

If an organization's model allowlist blocks a model, Claude Code falls back to the session model. Per-call `effort` overrides need Claude Code v2.1.292 or later.

## Trackers

One `tracker` skill exposes the same operations everywhere (`get`, `comment`, `move`, `link`, `open_change`, `review_comments`) and loads only the adapter the project uses:

| Project config | Adapter | Access |
|---|---|---|
| `tracker.type: jira` | `skills/tracker/jira.md` | Atlassian MCP server (`templates/mcp/jira.mcp.json`) |
| `tracker.type` / `code_host.type: github` | `skills/tracker/github.md` | `gh` CLI |
| `tracker.type` / `code_host.type: gitlab` | `skills/tracker/gitlab.md` | `glab` CLI |

Tracker and code host are set independently, so Jira with GitLab MRs works. Logical states map to Jira statuses or to labels via `tracker.states`.

## Project customisation

| Need | Where (in the project repo) |
|---|---|
| Swap an agent for a role | `.claude/agents/<name>.md` + `roles.<role>.agent` |
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
```

## Connect a project

1. Once per machine: `claude plugin marketplace add hlistan/singularity`, then `claude plugin install singularity@singularity`.
2. In the project: run `/singularity:init-project`, review the generated files, and commit them. From then on, anyone who clones the project and trusts the folder gets singularity through `.claude/settings.json`.

## Changing the shared setup

1. Edit here (or let `/singularity:optimize shared` propose the change), test with `claude --plugin-dir ./plugins/singularity` in any project, run `claude plugin validate .` and the eval suite (see `plugins/singularity/evals/README.md`).
2. Merge to the default branch. Projects pick it up through auto-update or with `/plugin marketplace update singularity`.

`plugin.json` has no `version`, so projects follow the latest commit. To release deliberately, add a `version` and bump it, or pin a project to a tag with `"ref": "v1"` in its settings source.

## Security and contributing

See [SECURITY.md](SECURITY.md) for what the plugin runs on your machine and how to report a vulnerability, [CONTRIBUTING.md](CONTRIBUTING.md) for the development setup and checks, and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## License

[MIT](LICENSE).
