# Self-optimization in singularity

How the workflow improves itself, and why it is built this way. Based on research and engineering practice current as of October 2026 (sources at the end).

## Two loops

| | Fast loop: **learner** | Slow loop: **optimizer** |
|---|---|---|
| Runs | after every pipeline run, and on human PR/MR reviews | every ~10 runs (`/singularity:optimize`), or on a schedule |
| Changes | experience lessons, run digests, new regression eval cases | agent definitions, role models and effort, lenses, stages, protocol, learner rules, project agents and skills |
| Evidence | one run | all runs, all human reviews, eval replays, the optimization archive, a web practice scan |
| Safeguard | curation rules + PR/MR review | tiers, falsifiable contracts, eval gates with a holdout set, challenger, PR/MR review, and for shared changes a human-made release |

The learner keeps experience close to the work: it is ACE's reflector/curator, and ReasoningBank-style learning from both successes and failures. The optimizer changes the harness, and it is built from what the self-improving-agent literature found works and what goes wrong.

## Research findings and how singularity applies them

| Finding | Source | In singularity |
|---|---|---|
| Error analysis comes first: read traces, label failures, group them into categories, count them. Build evals for failures you found, not ones you imagine | Husain & Shankar evals FAQ; Anthropic, *Demystifying evals* | `optimize-scan` builds a failure taxonomy with counts per stage at fault before anything is proposed |
| Start evals with 20–50 tasks drawn from real failures; separate capability from regression evals; read transcripts | Anthropic, *Demystifying evals* | Every escaped defect becomes a replayable eval case (learner); the plugin has its own regression suite (`plugins/singularity/evals/`) |
| Monolithic rewrites of context cause **context collapse** (18k→122 tokens, accuracy drop); prefer incremental delta updates. Contexts work as evolving playbooks | ACE (Zhang et al., ICLR 2026) | Learner and optimizer edit individual lessons and lines, never regenerate files; lessons carry Seen/Last counters |
| Agents improve by distilling strategies from **failures** as well as successes | ReasoningBank (Google, ICLR 2026) | Rejected findings, verification failures and gate edits are all learning signals; precision eval cases come from false positives |
| Gains come mostly from structural components (tools, middleware, memory), not from system-prompt prose; factual structure transfers, prose strategy doesn't | AHE (Lin et al., 2026); Zhang, *Self-Evolving Agentic Harnesses* (2026) | Optimizer's preference order: config → checks/tools → facts/evals → targeted prompt additions → prose rewrites; agent files capped at ~120 lines |
| Each edit as a **falsifiable contract**: predict what it fixes, check it next round | AHE | Every proposal states hypothesis, targets, predicted metric change, counter-metric, check-after point; `check-contracts` mode verifies it |
| Non-regression gates and held-out splits; most proposed edits should be rejected by the gate | SkillOpt (Microsoft, 2026); Anthropic, *Writing tools for agents* | Adopt only if targets improve and nothing regresses; holdout cases are never used for tuning |
| Keep an **archive** of variants, including failed ones, as stepping stones and negative feedback | Darwin Gödel Machine (Sakana, ICLR 2026) | `optimizations.md` records every proposal with status, rejected ones included |
| Reflection on trajectories in natural language is sample-efficient (GEPA beats GRPO with up to 35× fewer rollouts) | GEPA (ICLR 2026) | The optimizer reflects over evidence and digests rather than needing large eval batteries; evals are for validating the change, not searching for it |
| Self-modifiers **hack their verifier**: DGM deleted the markers its hallucination detector read; STOP turned off its sandbox | DGM; STOP via Zhang (2026) | Tier 3: the optimizer can't touch eval cases, graders, metric definitions, gates, hooks, permissions or its own definition. Plugin eval runs hide case definitions from the agent under test |
| **Misevolution**: memory and tool evolution can degrade safety and quality | Shao et al., ICLR 2026; Zhou et al. survey (2026) | Lessons need evidence and provenance and are reviewed in PRs; nothing auto-merges; web content is untrusted data |
| Evaluation, not proposal, dominates cost; use staged cascades | Zhang (2026) | Cheap evidence first (files), then free graders, then targeted replays; `max_eval_cost_usd` ceiling |
| Re-tune when the base model changes; evals decide how fast you adopt new models | Zhang (2026); Anthropic, *Demystifying evals* | The practice scan flags new models and Claude Code features; the optimizer proposes evaluated trials, not switches |

## The optimizer cycle (`/singularity:optimize`)

```text
evidence (optimize-scan workflow: metrics · failures · corrections · experience · contracts · evals · practice scan)
   → propose (optimizer, ≤5 ranked proposals with contracts)
   → challenge (reviewer Task C: overfitting? metric gaming? less oversight? tried before?)
   → gate (human picks; tier 3 is recommendation only)
   → implement (one commit per proposal on singularity/optimize-<date>)
   → validate (replay-evals | claude plugin eval | canary)
   → archive (optimizations.md) → draft PR/MR
```

Scopes:

- **project**: run inside a project repo. Changes that project's config, project agents, skills and experience.
- **shared**: run inside this repo. Reads the committed experience of every repo in `optimizer/projects.yaml`, and changes the shared agents, skills, workflows and standards. Lessons that apply everywhere arrive here through each project's `upstream.md`.

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
| 1 · Curation | lessons, new eval cases, commands, docs | implemented; reviewed in the PR/MR |
| 2 · Behaviour | agents, models and effort, lenses, stages, protocol, learner rules, project agents and skills | contract + passing validation, or explicit canary |
| 3 · Oversight | gates, hooks, permissions, tracker writes, autonomy settings, existing evals and graders, metric definitions, the optimizer itself | proposal only; a human changes it |

## Validation methods

- **replay-evals** (project): the project's eval cases, which are real escaped defects and known false positives, each a `change.patch` on a base commit. The reviewer replays them in isolated worktrees for a baseline and a candidate variant, and a judge scores recall and precision, reported separately for holdout cases.
- **claude plugin eval** (shared): the plugin's own suite under `plugins/singularity/evals/`, run on the candidate branch and on the default branch.
- **canary**: for changes that can't be replayed (spec, plan or implementer behaviour), ship with recorded baseline metrics and a check-after point. `check-contracts` keeps or reverts the change. For a shared change, the check counts only runs on the release that shipped it (`plugin_version` in the run digests), never `+dev` runs from an unreleased checkout.

## Running it unattended

`/singularity:optimize unattended` (for example from a weekly scheduled task or CI job running `claude -p`) implements tier 1, plus tier 2 changes whose validation fits the budget, and opens a draft PR/MR. Nothing merges without a human, and shared changes reach projects only when a human releases a new plugin version: the optimizer adds changelog lines but never changes the version.

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
- H. Husain, *LLM Evals FAQ*: <https://hamel.dev/blog/posts/evals-faq/>
- Claude Code, *Test plugins with evals*: <https://code.claude.com/docs/en/plugin-evals>
