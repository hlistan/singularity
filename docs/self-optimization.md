# Self-optimization in singularity

How the workflow improves itself, and why it is built this way. Based on research and engineering practice current as of October 2026 (sources at the end).

## Two loops, and what comes before and after them

| | Fast loop: **learner** | Slow loop: **optimizer** |
|---|---|---|
| Runs | at the end of every `/singularity:feature` run, which also hands it the human reviews of earlier runs' PRs/MRs once they are merged or closed | every ~10 runs (`/singularity:feature` offers it), on a schedule, or on request |
| Changes | experience lessons, run digests, new regression eval cases | project context, role models and effort, lenses, stages, project agents and skills, lessons; upstream reports for the plugin |
| Evidence | one run, and the finished human reviews | all runs, all human reviews, eval replays, the optimization archive, a context audit, a web practice scan |
| Safeguard | curation rules + PR/MR review | tiers, falsifiable contracts, eval gates with a holdout set, challenger, PR/MR review; plugin changes only through its maintainers and a release |

The learner keeps experience close to the work: it is ACE's reflector/curator, and ReasoningBank-style learning from both successes and failures. The optimizer changes the harness, and it is built from what the self-improving-agent literature found works and what goes wrong.

Neither loop has anything to work with in a new project, so the optimizer first **onboards** the agents: it forms the project context they work from. And when the cause of a failure is in the shared plugin rather than in the project, it **reports it upstream** instead of changing the plugin. Both are below.

The optimizer is an agent (`singularity:optimizer`), not a command: the user asks for it, `/singularity:feature` offers it when it is due, and `/singularity:init-project` starts its onboarding. Its procedures are playbooks in `plugins/singularity/optimizer/`. As a subagent it can't ask the user or run workflows, so it stops at each gate with a **Decision needed** block, keeps its state in the run directory, and does the workflows' work with its own subagents. Run as the session (`claude --agent singularity:optimizer`), it does both itself.

## Research findings and how singularity applies them

| Finding | Source | In singularity |
|---|---|---|
| Error analysis comes first: read traces, label failures, group them into categories, count them. Build evals for failures you found, not ones you imagine | Husain & Shankar evals FAQ; Anthropic, *Demystifying evals* | `optimize-scan` builds a failure taxonomy with counts per stage at fault, and where each fix belongs, before anything is proposed |
| Good context is the smallest set of high-signal tokens; keep identifiers such as file paths and load the detail when needed. `CLAUDE.md` is loaded up front, so what goes in it costs every session | Anthropic, *Effective context engineering for AI agents* | Onboarding writes facts with file refs where each role reads them, keeps `CLAUDE.md` and `project.md` short, and points to files rather than copying them; the context audit flags stale lessons |
| Start evals with 20–50 tasks drawn from real failures; separate capability from regression evals; read transcripts | Anthropic, *Demystifying evals* | Every escaped defect becomes a replayable eval case (learner); the plugin has its own regression suite (`plugins/singularity/evals/`) |
| Monolithic rewrites of context cause **context collapse** (18k→122 tokens, accuracy drop); prefer incremental delta updates. Contexts work as evolving playbooks | ACE (Zhang et al., ICLR 2026) | Learner and optimizer edit individual lessons and lines, never regenerate files; lessons carry Seen/Last counters |
| Agents improve by distilling strategies from **failures** as well as successes | ReasoningBank (Google, ICLR 2026) | Rejected findings, verification failures and gate edits are all learning signals; precision eval cases come from false positives |
| Gains come mostly from structural components (tools, middleware, memory), not from system-prompt prose; factual structure transfers, prose strategy doesn't | AHE (Lin et al., 2026); Zhang, *Self-Evolving Agentic Harnesses* (2026) | Optimizer's preference order: config → checks/tools → facts/evals → targeted prompt additions → prose rewrites; agent files capped at ~120 lines |
| Each edit as a **falsifiable contract**: predict what it fixes, check it next round | AHE | Every proposal states hypothesis, targets, predicted metric change, counter-metric, check-after point; the contract check in a later optimization verifies it |
| Non-regression gates and held-out splits; most proposed edits should be rejected by the gate | SkillOpt (Microsoft, 2026); Anthropic, *Writing tools for agents* | Adopt only if targets improve and nothing regresses; holdout cases are never used for tuning |
| Keep an **archive** of variants, including failed ones, as stepping stones and negative feedback | Darwin Gödel Machine (Sakana, ICLR 2026) | `optimizations.md` records every proposal with status, rejected ones included |
| Reflection on trajectories in natural language is sample-efficient (GEPA beats GRPO with up to 35× fewer rollouts) | GEPA (ICLR 2026) | The optimizer reflects over evidence and digests rather than needing large eval batteries; evals are for validating the change, not searching for it |
| Self-modifiers **hack their verifier**: DGM deleted the markers its hallucination detector read; STOP turned off its sandbox | DGM; STOP via Zhang (2026) | Tier 3: the optimizer can't touch eval cases, graders, metric definitions, gates, guardrails or permissions, can only add checks to the project's hooks, never removes them, and never edits the plugin, its own definition included. Plugin eval runs hide case definitions from the agent under test |
| **Misevolution**: memory and tool evolution can degrade safety and quality | Shao et al., ICLR 2026; Zhou et al. survey (2026) | Lessons need evidence and provenance and are reviewed in PRs; nothing auto-merges; web content is untrusted data |
| Evaluation, not proposal, dominates cost; use staged cascades | Zhang (2026) | Cheap evidence first (files), then free graders, then targeted replays; `max_eval_cost_usd` ceiling |
| Re-tune when the base model changes; evals decide how fast you adopt new models | Zhang (2026); Anthropic, *Demystifying evals* | The practice scan flags new models and Claude Code features; the optimizer proposes evaluated trials, not switches |

## Onboarding: context before optimization

An agent that doesn't know the project relearns it on every run, and the first runs would teach the learner mostly what a survey could have told it. So onboarding comes first. The optimizer surveys the repository, its history and its recent human reviews, and writes each fact where the agent that needs it reads: the project sections of `CLAUDE.md`, the role experience files, the "Do not touch" list. It follows the learner's rules: facts with refs, not prose strategy; the smallest context that does the job, because `CLAUDE.md` and `project.md` load into every session; edits, never rewrites. The setup changes it proposes (lenses, stages, role settings) have no runs to measure yet, so they ship as canaries. Where it can, it also turns past human review catches into baseline eval cases, so the first optimization can validate review changes. Afterwards, the context audit in each optimization keeps the context current.

## The optimization cycle

```text
evidence (optimize-scan: metrics · failures · corrections · experience · context · contracts · evals · practice scan)
   → propose (optimizer, ≤5 ranked proposals with contracts, and upstream reports for causes in the plugin)
   → challenge (reviewer Task C: overfitting? metric gaming? less oversight? tried before? really the plugin's?)
   → gate (human picks; tier 3 is recommendation only)
   → implement (one commit per proposal on singularity/optimize-<date>)
   → validate (replay-evals | canary)
   → archive (optimizations.md) → draft PR/MR
```

## Upstream reports

The plugin is shared, so the optimizer never changes it: a fix that suits one project can break another, and only a release reaches them all. When the failure taxonomy says a fix belongs in the plugin (a shared agent's instructions, the protocol, a default, a standard, a template), the optimizer writes an upstream report in the project's `.claude/singularity/upstream/`: the problem, the evidence as counts and categories, the exact fix, and a contract with a validation plan, ideally a plugin eval case. Lessons the learner thinks apply everywhere (`upstream.md`) take the same path.

Reports are written to be published, with nothing that identifies the project. The challenger checks that, and that the cause really is the plugin's. The team reviews reports in the optimizer's PR/MR, and the optimizer files approved ones as issues in this repository, only on the user's yes. Meanwhile the project can carry a local workaround, and the optimizer proposes removing it once a release with the fix reaches the project.

Maintainers adopt reports as described in `CONTRIBUTING.md`: reproduce the failure as a plugin eval case, make the change, compare the suite on the candidate and the default branch, and release. Several projects reporting the same problem is the strongest evidence a report can have.

## Metrics and counter-metrics

| Metric | Source | Counter-metric that stops it being gamed |
|---|---|---|
| Escaped defects per run | `human_review` lines | none: this is the ground truth |
| Blocking findings per run | run digests | escaped defects (fewer findings must not mean fewer catches) |
| Review rounds, first-pass verification | run digests | escaped defects |
| Gate edit rate (spec, plan) | run digests | escaped defects, review rounds |
| Reviewer precision | rejected findings, precision cases | recall cases |
| Seconds and tokens per stage | run digests | all quality metrics |

## Change tiers

| Tier | Scope | Rule |
|---|---|---|
| 1 · Context and curation | project context, new "Do not touch" entries, lessons, new eval cases, commands, upstream reports | implemented; reviewed in the PR/MR |
| 2 · Behaviour | models and effort, lenses and extra reviewers, stages, project agents, skills and workflows, new checks in the project's `verify.sh` and `post-edit.sh`, learning limits | contract + passing validation, or explicit canary |
| 3 · Oversight | gates, guardrail hooks, removing or weakening a project check, removing a "Do not touch" entry, permissions, tracker writes, autonomy settings, existing evals and graders, metric definitions, the optimize role's binding, model and effort | proposal only; a human changes it |
| Upstream | the plugin: shared agents (the optimizer included), skills, workflows, standards, templates, defaults | never edited by the optimizer; upstream report, adopted by maintainers |

## Validation methods

- **replay-evals** (project): the project's eval cases, which are real escaped defects and known false positives, each a `change.patch` on a base commit. The reviewer replays them in isolated worktrees for a baseline and a candidate variant, and a judge scores recall and precision, reported separately for holdout cases.
- **claude plugin eval** (maintainers, adopting an upstream report): the plugin's own suite under `plugins/singularity/evals/`, run on the candidate branch and on the default branch.
- **canary**: for changes that can't be replayed (spec, plan or implementer behaviour), ship with recorded baseline metrics and a check-after point. The contract check keeps or reverts the change. For a fix released upstream, the check counts only runs on the release that shipped it (`plugin_version` in the run digests), never `+dev` runs from an unreleased checkout.

## Running it unattended

Ask for the optimizer with `unattended`, for example from a weekly scheduled task or a CI job: `claude -p "Use the singularity:optimizer agent: optimize, unattended"`. It implements tier 1, plus tier 2 changes whose validation fits the budget, writes upstream reports without filing them, and opens a draft PR/MR. Nothing merges without a human, and plugin changes reach projects only when its maintainers release a new version.

## Sources

- ACE, *Agentic Context Engineering: Evolving Contexts for Self-Improving Language Models*: <https://huggingface.co/papers/2510.04618>
- Darwin Gödel Machine: <https://arxiv.org/abs/2505.22954>
- GEPA, *Reflective Prompt Evolution Can Outperform Reinforcement Learning*: <https://arxiv.org/abs/2507.19457>
- ReasoningBank: <https://research.google/blog/reasoningbank-enabling-agents-to-learn-from-experience/>
- AHE, *Agentic Harness Engineering*: <https://arxiv.org/abs/2604.25850>
- J. Zhang, *Self-Evolving Agentic Harnesses* (June 2026): <https://jxzhangjhu.github.io/blog/2026/self-evolving-agentic-harnesses/>
- Zhou et al., *Self-Evolving Coding Agents* (survey, Aug 2026): <https://arxiv.org/html/2608.03392v2>
- Shao et al., *Your Agent May Misevolve* (ICLR 2026): <https://mlanthology.org/iclr/2026/shao2026iclr-your/>
- SkillOpt overview: <https://explainx.ai/blog/microsoft-skillopt-self-improving-agent-skills-2026>
- Anthropic, *Demystifying evals for AI agents*: <https://anthropic.com/engineering/demystifying-evals-for-ai-agents>
- Anthropic, *Writing effective tools for agents*: <https://www.anthropic.com/engineering/writing-tools-for-agents>
- Anthropic, *Effective context engineering for AI agents* (September 2025): <https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents>
- H. Husain, *LLM Evals FAQ*: <https://hamel.dev/blog/posts/evals-faq/>
- Claude Code, *Test plugins with evals*: <https://code.claude.com/docs/en/plugin-evals>
