# Self-optimization in singularity

How the workflow improves itself, and why it is built this way. Based on research and engineering practice current as of October 2026 (sources at the end).

## One agent, two cadences

| | Learn job: **every run** | Optimize job: **every ~10 runs** |
|---|---|---|
| Runs | at the end of every `/singularity:feature` run, and whenever user corrections are waiting | when `/singularity:feature` says it is due, on a schedule, or on request |
| Changes | guidelines, only for defects whose root cause is a weak guideline and for user corrections; run digests, new regression eval cases; everything else only as proposals | project context and guidelines, role models and effort, lenses, stages, project agents and skills; upstream reports for the plugin |
| Evidence | one run's defects, the user corrections the hooks captured, the run's own change, and, where a project turns it on, finished human reviews | all runs, corrections and human reviews against the project's goals, eval replays, the optimization archive, guideline and context audits, a web practice scan |
| Model · effort | opus · high | fable · xhigh |
| Safeguard | curation rules + PR/MR review | tiers, falsifiable contracts, eval gates with a holdout set, challenger, PR/MR review; plugin changes only through its maintainers and a release |

Both are jobs of one agent, `singularity:optimizer`, which leads the harness towards operational perfection for the project: agents that deliver what its users need, correctly and without waste. Until 0.5.0 they were two agents, a learner and an optimizer, that read the same record, curated the same guidance and had to agree on formats and on which of them changes what. One agent now owns the guidelines and their history. Evaluation stays as separate as it can: the reviewer challenges every proposal and every keep verdict, contracts are judged on what the pipeline records mechanically rather than on labels the optimizer assigned, and the eval cases and the team's goals measure the result (see [Optimizing towards what the project is for](#optimizing-towards-what-the-project-is-for)).

The learn job keeps the guidelines close to the work: it is ACE's reflector and curator, and ReasoningBank-style learning from both successes and failures, but what it keeps in the agents' context is current guidance, not a log (see [Guidelines, not a log of lessons](#guidelines-not-a-log-of-lessons)). The optimize job changes the harness, and it is built from what the self-improving-agent literature found works and what goes wrong.

Neither job has anything to work with in a new project, so the optimizer first **onboards** the agents: it drafts the project's goals with the team and forms the project context. And when the cause of a failure is in the shared plugin rather than in the project, it **reports it upstream** instead of changing the plugin. Both are below.

The optimizer is an agent, not a command: `/singularity:feature` runs its learn job and offers an optimization when one is due, `/singularity:init-project` starts its onboarding, and the user can ask for it. Its procedures are playbooks in `plugins/singularity/optimizer/`. As a subagent it can't ask the user or run workflows, so it stops at each gate with a **Decision needed** block, keeps its state in the run directory, and does the workflows' work with its own subagents. Run as the session (`claude --agent singularity:optimizer`), it does both itself.

## Optimizing towards what the project is for

A pipeline can get faster and cleaner while delivering less of what users need. So the optimizer works from `.claude/singularity/goals.md`: who the users are, the value they get, the goals the team is working towards and how it will know, the trade-offs and the constraints. The team owns the file. The optimizer drafts it at onboarding from what the team has written (README, roadmap, tickets, release notes), the team confirms it at the gate, and after that the optimizer can only propose changes. The spec writer names the goal each piece of work serves, the planner follows the trade-off order, and every proposal says which goal it serves.

| Finding | Source | In singularity |
|---|---|---|
| Teams that focus on the user have 40% higher organizational performance; it is one of the strongest predictors of it | DORA, *2023 Accelerate State of DevOps* | `goals.md` names the users and the value they get, and the optimizer ranks problems by harm to them |
| AI is an amplifier: it strengthens strong organizations and weakens struggling ones. With AI, throughput now rises but delivery instability keeps rising too. A user-centric focus and mature value-stream management amplify AI's benefits; without user focus, effects on team performance are often negative | DORA, *2025 State of AI-assisted Software Development* | Quality and stability metrics sit next to throughput in every evidence pack, and the pipeline's part of the value stream (from start to hand-off, then review to merge) is measured, not assumed |
| Throughput is change lead time, deployment frequency and failed-deployment recovery time; instability is change fail rate and, since 2024, deployment rework rate | DORA metrics | Pipeline analogues, not DORA metrics themselves: lead time from start to hand-off, fix rounds before merge, and `fixes` (a later run fixing a pipeline change) as a change-failure signal |
| Flow time, flow efficiency (active time over total flow time), flow load and flow distribution (the mix of features, defects, risks and debt) show where value stream time goes | Kersten, Flow Framework | `lead_s`, `active_s` and `gate_wait_s` give flow efficiency; `kind` and `goal` give the distribution of effort across the goals |
| Experienced developers believed AI had made them 20% faster while it had made them 19% slower | METR, randomized controlled trial (2025) | Flow is measured from the run record's timestamps, never estimated; "measure rather than trust impressions" is a principle |
| Frontier models optimizing a measured score hacked it: they patched evaluators, cached answers and overrode equality checks, in 30% of runs on one benchmark (RE-Bench) and under 1% on another (HCAST). On one task, o3 kept doing so in 70–95% of runs even when told not to, and said afterwards that it wasn't what the user wanted | METR, *Recent Frontier Models Are Reward Hacking* (2025) | The optimizer can't touch eval cases, graders, metric definitions or the confirmed goals; the challenger asks whether a proposal serves the goals or only moves a proxy |
| In multi-agent systems, failures of specification and system design make up the largest group (their failure modes add up to about 44% in the paper's taxonomy, and include agents disobeying the spec), a third come from misalignment between agents and a quarter from verification; step repetition is the most common single failure mode. Clearer role specifications help (+9.4% for one system) but don't fix everything; many verifiers "perform only superficial checks", and a verifier "is not a silver bullet" | Cemri et al., *Why Do Multi-Agent LLM Systems Fail?* (NeurIPS 2025) | By analogy with misalignment between agents, the learner and the optimizer, which read and curated the same record, are one agent. Verification stays independent and substantive: a separate challenger, held-out eval cases, contracts judged on mechanical records |
| Add complexity "only when it demonstrably improves outcomes"; an evaluator-optimizer loop works "when we have clear evaluation criteria" | Anthropic, *Building effective agents* | One optimizer agent with jobs instead of more agents; the evaluation criteria are the goals and the eval cases, owned by people |

## Research findings and how singularity applies them

| Finding | Source | In singularity |
|---|---|---|
| Error analysis comes first: read traces, label failures, group them into categories, count them. Build evals for failures you found, not ones you imagine | Husain & Shankar evals FAQ; Anthropic, *Demystifying evals* | `optimize-scan` builds a failure taxonomy with counts per stage at fault, and where each fix belongs, before anything is proposed |
| Good context is the smallest set of high-signal tokens; keep identifiers such as file paths and load the detail when needed. `CLAUDE.md` is loaded up front, so what goes in it costs every session | Anthropic, *Effective context engineering for AI agents* | Onboarding writes facts with file refs where each role reads them, keeps `CLAUDE.md` and `project.md` short, and points to files rather than copying them; the guideline check and the context audit flag guidelines about code that is gone |
| Start evals with 20–50 tasks drawn from real failures; separate capability from regression evals; read transcripts | Anthropic, *Demystifying evals* | Every escaped defect becomes a replayable eval case (the learn job); the plugin has its own regression suite (`plugins/singularity/evals/`) |
| Monolithic rewrites of context cause **context collapse** (18k→122 tokens, accuracy drop); prefer incremental delta updates. Contexts work as evolving playbooks | ACE (Zhang et al., ICLR 2026) | The optimizer edits individual guidelines, each with an id, and never regenerate files; each guideline's history is in the run digests |
| Agents improve by distilling strategies from **failures** as well as successes | ReasoningBank (Google, ICLR 2026) | Rejected findings, verification failures and gate edits are all learning signals; precision eval cases come from false positives |
| Gains come mostly from structural components (tools, middleware, memory), not from system-prompt prose; factual structure transfers, prose strategy doesn't | AHE (Lin et al., 2026); Zhang, *Self-Evolving Agentic Harnesses* (2026) | Optimizer's preference order: config → checks/tools → facts/evals → targeted prompt additions → prose rewrites; agent files capped at ~120 lines |
| Each edit as a **falsifiable contract**: predict what it fixes, check it next round | AHE | Every proposal states hypothesis, targets, predicted metric change, counter-metric, check-after point; the contract check in a later optimization verifies it |
| Non-regression gates and held-out splits; most proposed edits should be rejected by the gate | SkillOpt (Microsoft, 2026); Anthropic, *Writing tools for agents* | Adopt only if targets improve and nothing regresses; holdout cases are never used for tuning |
| Keep an **archive** of variants, including failed ones, as stepping stones and negative feedback | Darwin Gödel Machine (Sakana, ICLR 2026) | `optimizations.md` records every proposal with status, rejected ones included |
| Reflection on trajectories in natural language is sample-efficient (GEPA beats GRPO with up to 35× fewer rollouts) | GEPA (ICLR 2026) | The optimizer reflects over evidence and digests rather than needing large eval batteries; evals are for validating the change, not searching for it |
| Self-modifiers **hack their verifier**: DGM deleted the markers its hallucination detector read; STOP turned off its sandbox | DGM; STOP via Zhang (2026) | Tier 3: the optimizer can't touch eval cases, graders, metric definitions, gates, guardrails or permissions, can only add checks to the project's hooks, never removes them, and never edits the plugin, its own definition included. Plugin eval runs hide case definitions from the agent under test |
| **Misevolution**: memory and tool evolution can degrade safety and quality | Shao et al., ICLR 2026; Zhou et al. survey (2026) | Guidelines need evidence, are grounded in the files they name, and are reviewed in PRs; nothing auto-merges; web content is untrusted data |
| Evaluation, not proposal, dominates cost; use staged cascades | Zhang (2026) | Cheap evidence first (files), then free graders, then targeted replays; `max_eval_cost_usd` ceiling |
| Re-tune when the base model changes; evals decide how fast you adopt new models | Zhang (2026); Anthropic, *Demystifying evals* | The practice scan flags new models and Claude Code features; the optimizer proposes evaluated trials, not switches |

## Guidelines, not a log of lessons

Until 0.5.0 a separate learner agent kept a log. Each lesson recorded what had gone wrong, why, how often and in which tickets (`_Why:_`, `_Seen:_`, `_Refs:_`), and lessons left only when a file was full. A log keeps whatever was once true, nothing took a lesson out when the code it described changed, and the agents read it all as instructions. Since 0.5.0 the optimizer's learn job keeps **guidelines** instead: how to work in the project as it is now. An agent avoids what doesn't work because the guidelines say what does, not because it reads the history of what went wrong.

| Finding | Source | In singularity |
|---|---|---|
| Agents follow retrieved experience closely ("experience-following"): similar inputs give near-identical outputs, so a flawed or outdated record carries its error into new work, and that work can be stored and spread it further. Adding everything to memory left every agent studied below a small fixed memory (67.5 → 55.5 on one); strict addition did much better, and deleting records that later proved harmful often helped further. Memory needn't grow without bound | Xiong et al., *How Memory Management Impacts LLM Agents* (2025) | A guideline must be true of the current code. The learn job corrects or removes guidelines when the code changes, and the optimize job rewrites or replaces those whose failure category keeps recurring |
| Instructions are context, not enforcement. Contradicting instructions make Claude "pick one arbitrarily"; review them "periodically to remove outdated or conflicting instructions", and an audit looks for "references to files or commands that don't exist". Keep files under 200 lines, move what matters for one part of the codebase into path-scoped rules, and use a hook for what must always happen | Claude Code docs, *How Claude remembers your project* | One home per guideline; replace rather than annotate; `scripts/check-guidelines.sh` finds named paths that are gone; area guidelines are rules in `.claude/rules/singularity/` with `paths`; "a check beats a guideline" |
| Context files written by an LLM lowered task success in 5 of 8 settings (by 0.5–2% on average) and raised cost by about 20%; developer-written ones helped only marginally (about 4%) at up to 19% more cost. Neither worked as a repository overview, while agents did use the tools a file named. "Unnecessary requirements from context files make tasks harder": describe "only minimal requirements" | Gloaguen et al., *Evaluating AGENTS.md* (ETH Zürich and LogicStar.ai, 2026) | Guidelines say only what an agent needs to do the work right here; dates, counts and tickets stay in `runs.jsonl`. Onboarding, itself an LLM writing context, writes no overviews: only commands, tools, non-obvious conventions, risks and what not to touch, as a draft the team reviews |
| Performance grows less reliable as input grows, and distractors (related content that doesn't answer the question) make it worse; how information is presented matters as much as whether it is there | Hong, Troynikov and Huber, *Context Rot* (Chroma, 2025) | The study measured retrieval, not instructions, but by analogy a stale lesson about the same module is such a distractor. Area guidelines load only where they apply |
| Frontier models follow "~150-200 instructions with reasonable consistency" (a rough figure, not rigorously established); prefer `file:line` references to code snippets, which "become out-of-date quickly"; "never send an LLM to do a linter's job"; don't auto-generate `CLAUDE.md` | HumanLayer, *Writing a good CLAUDE.md* (2025) | Guidelines name files rather than copy code; a guideline a check could enforce comes with a proposal for that check; what onboarding generates is kept small and reviewed by the team |
| A memory stays consistent when each new fact is compared with what is stored and applied as ADD, UPDATE, DELETE ("removal of memories contradicted by new information") or NOOP. Mem0's graph variant keeps outdated facts, marked invalid, for temporal reasoning | Chhikara et al., *Mem0* (2025) | The learn job adds, changes or removes guidelines and records which in the run digest. The history lives in the record, outside the agents' context |
| Rewriting a whole context loses detail: one context collapsed from 18,282 to 122 tokens, below the no-adaptation baseline. Itemized entries with ids, updated by small deltas, keep it | ACE (Zhang et al., ICLR 2026) | Guidelines are itemized with ids and edited one at a time; files are never regenerated, and the migration from lessons rewrites each lesson on its own |

The history isn't lost. Each run digest records which guidelines the run added, changed or removed, and which finding each one answers, so the optimizer can still tell whether a guideline works. It just isn't in the context of the agents doing the work.

## Two signals: defects with a guideline cause, and user corrections

Singularity has no human review of its own, so nobody checks a guideline before every agent reads it. What changes the guidelines is therefore narrow: **a defect whose root cause is a weak guideline**, and **a user correction**, a prompt in which the user tells an agent that it did something wrong. A clean run adds no guideline, and neither does a finding nobody confirmed or a practice that only seems good. Every defect and correction first gets a root cause (`guideline-missing`, `guideline-wrong`, `guideline-unclear`, `guideline-ignored` or `not-guideline`), and only the first three change a guideline's text.

| Finding | Source | In singularity |
|---|---|---|
| The one learning loop with a measured production result: Copilot Memory raised the coding agent's PR merge rate from 83% to 90% (p<0.00001). Each memory cites code, citations are re-checked against the current branch before use, and unused memories expire after 28 days | GitHub, *Building an agentic memory system for GitHub Copilot* (January 2026) | Each guideline names the files it depends on, the guideline check verifies them on every learn job, and the context audit removes guidelines about code that is gone |
| Add a rule when "Claude makes the same mistake a second time" or a review catches something; ask of each line "Would removing this cause Claude to make mistakes?"; if Claude ignores a rule, the file is probably too long; use hooks for what must always happen | Claude Code docs, *Best practices* and *How Claude remembers your project* | Evidence that only a model confirmed changes a guideline on its second occurrence (`pending` until then); a guideline that was ignored gets a proposed check, not more text, or moves to a rule scoped to its code |
| Adding every experience to memory left agents flat or worse; strict, quality-gated addition with deletion gained 11–29 points | Xiong et al., *How Memory Management Impacts LLM Agents* (2025) | The two signals and the evidence gate are the quality gate; `guideline-wrong` corrects or removes |
| Context files written by an LLM gave no reliable gain and cost about 20% more | Gloaguen et al., *Evaluating AGENTS.md* (2026) | No guideline without a defect or a correction behind it, and each in the narrowest file the agent at fault reads |
| Auto-generated memories were rolled back towards curated rule files: Cursor removed its memories UI and points users to rules; Windsurf keeps auto memories machine-local and recommends rules or AGENTS.md for lasting knowledge | Cursor forum (2025); Windsurf / Devin Desktop docs (2026) | Corrections become versioned guidelines in the repository, recorded with their cause in `runs.jsonl`; the queue of raw prompts is never committed |
| A comment in a source file made an agent store attacker instructions in its long-term memory, because the memory tool was invoked automatically | Rehberger, *SpAIware* (August 2025) | Only what the user typed counts as a correction. Text from files, tool output, tickets or PR comments is data, and no correction can loosen a check, a guardrail or a permission |
| The best automated method attributed a multi-agent failure to the right agent 53.5% of the time, and to the decisive step 14.2% | Zhang et al., *Which Agent Causes Task Failures and When?* (ICML 2025) | An inferred cause isn't proof: a person or a tool must confirm the defect, or it must recur, before a guideline changes |
| Defect causal analysis and orthogonal defect classification act only on systematic causes; programmes that did so cut defect rates by over half | Card (IEEE Software, 1998); Chillarege et al. (IEEE TSE, 1992); Kalinowski, Travassos and Card (2008) | `not-guideline` covers slips, flaky environments, ambiguous tickets and one-off requests: they are recorded and change nothing |
| Transcript-mining tools for Claude Code catch corrections with a cheap phrase filter, then drop questions, one-time instructions and vague feedback in an LLM pass | claude-reflect; claude-diary (2025) | The hooks queue prompts that match `correction-patterns.txt` (projects add their own, in any language); the learn job drops what isn't a correction of an agent |

**How a correction is captured.** Two plugin hooks do it mechanically. The `Stop` hook keeps the agent's last message of each session; the `UserPromptSubmit` hook queues a prompt that starts with `correction:` or matches a phrase in `scripts/correction-patterns.txt`, paired with that message, in `<work_dir>/corrections/`, which keeps itself out of git because prompts can hold secrets. The learn job reads the queue, records each correction it keeps as a `correction` line in `runs.jsonl` (role, category, scope, cause, action; never the prompt's text) and clears the queue.

**Validating with noise in mind.** The reviewer isn't deterministic: repeated runs of one configuration find different issues. `replay-evals` therefore runs each variant several times on every case (`trials`, default 3) and reports which cases are right in most trials and which flip; at 20 cases, a difference of one or two cases is noise. A canary over ten runs can show breakage, not a small improvement, so it is judged on whether the defects and corrections it targets stopped.

## Onboarding: context before optimization

An agent that doesn't know the project relearns it on every run, and the first runs would teach the learn job mostly what a survey could have told it. So onboarding comes first. The optimizer surveys the repository, its history and its recent human reviews, and writes as guidelines only what an agent can't find out quickly for itself or would get wrong: exact commands and tools, conventions the code doesn't make obvious, domain rules and risks, what not to touch. No repository overviews, which the research above found don't help. Each fact goes where the agent that needs it reads: the project sections of `CLAUDE.md`, the guideline files, path-scoped rules, the "Do not touch" list. It follows the learn job's rules: the current right way, grounded in the files it names, not prose strategy; the smallest context that does the job, because `CLAUDE.md` and `guidelines/project.md` load into every session; edits, never rewrites. The setup changes it proposes (lenses, stages, role settings) have no runs to measure yet, so they ship as canaries. Where it can, it also turns past human review catches into baseline eval cases, so the first optimization can validate review changes. Afterwards, the context audit in each optimization keeps the context current.

## The optimization cycle

```text
evidence (optimize-scan: quality and flow metrics · failures · value against the goals · corrections · guidelines · context · contracts · evals · practice scan)
   → propose (≤5 proposals ranked by harm to the goals, each with a contract, and upstream reports for causes in the plugin)
   → challenge (reviewer Task C: overfitting? metric gaming? less oversight? tried before? really the plugin's?)
   → gate (human picks; tier 3 is recommendation only)
   → implement (one commit per proposal on singularity/optimize-<date>)
   → validate (replay-evals | canary)
   → archive (optimizations.md) → draft PR/MR
```

## Upstream reports

The plugin is shared, so the optimizer never changes it: a fix that suits one project can break another, and only a release reaches them all. When the failure taxonomy says a fix belongs in the plugin (a shared agent's instructions, the protocol, a default, a standard, a template), the optimizer writes an upstream report in the project's `.claude/singularity/upstream/`: the problem, the evidence as counts and categories, the exact fix, and a contract with a validation plan, ideally a plugin eval case. Guidelines the optimizer thinks would be right everywhere (`upstream.md`) take the same path.

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
| Lead time, flow efficiency (working over waiting) | `lead_s`, `active_s`, `gate_wait_s` in run digests | escaped defects, `fixes` (later runs fixing a pipeline change), gate edit rate: going faster must not mean checking less |
| Gate wait | `gate_wait_s` | gate edit rate and escaped defects: a gate that is quick to approve but often edited is doing its job |
| Change-failure share | `fixes` in later run digests | none for gaming; read it with escaped defects |
| Work mix across the goals | `kind` and `goal` in run digests | the team's review of the goal labels at the spec gate |

## Change tiers

| Tier | Scope | Rule |
|---|---|---|
| 1 · Context and curation | project context, new "Do not touch" entries, guidelines and path-scoped rules, new eval cases, commands, upstream reports | implemented; reviewed in the PR/MR |
| 2 · Behaviour | models and effort, new lenses and extra reviewers, stages, project agents, skills and workflows, new checks in the project's `verify.sh` and `post-edit.sh`, learning limits | contract + passing validation, or explicit canary; unattended, only with a passing replay |
| 3 · Oversight | the confirmed goals, removing review coverage (a lens, an extra reviewer, a stage), gates, guardrail hooks, removing or weakening a project check, removing a "Do not touch" entry, permissions, tracker writes, autonomy settings, existing evals and graders, metric definitions, `roles.optimize` (binding, model, effort) and `roles.learn` (model, effort) | proposal only; a human changes it |
| Upstream | the plugin: shared agents (the optimizer included), skills, workflows, standards, templates, defaults | never edited by the optimizer; upstream report, adopted by maintainers |

## Validation methods

- **replay-evals** (project): the project's eval cases, which are real escaped defects and known false positives, each a `change.patch` on a base commit. The reviewer replays them in isolated worktrees for a baseline and a candidate variant, and a judge scores recall and precision, reported separately for holdout cases.
- **claude plugin eval** (maintainers, adopting an upstream report): the plugin's own suite under `plugins/singularity/evals/`, run on the candidate branch and on the default branch.
- **canary**: for changes that can't be replayed (spec, plan or implementer behaviour), ship with recorded baseline metrics and a check-after point. The contract check keeps or reverts the change. For a fix released upstream, the check counts only runs on the release that shipped it (`plugin_version` in the run digests), never `+dev` runs from an unreleased checkout.

## Running it unattended

Ask for the optimizer with `unattended`, for example from a weekly scheduled task or a CI job: `claude -p "Use the singularity:optimizer agent: optimize, unattended"`. It implements tier 1, plus tier 2 changes whose replay passes within the budget (a canary waits for a person to choose it), writes upstream reports without filing them, and opens a draft PR/MR. Nothing merges without a human, and plugin changes reach projects only when its maintainers release a new version.

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
- Z. Xiong et al., *How Memory Management Impacts LLM Agents: An Empirical Study of Experience-Following Behavior* (2025): <https://arxiv.org/abs/2505.16067>
- Claude Code, *How Claude remembers your project*: <https://code.claude.com/docs/en/memory>
- T. Gloaguen et al., *Evaluating AGENTS.md: Are Repository-Level Context Files Helpful for Coding Agents?* (February 2026; ICLR 2026 MemAgents workshop): <https://arxiv.org/abs/2602.11988>
- K. Hong, A. Troynikov, J. Huber, *Context Rot: How Increasing Input Tokens Impacts LLM Performance* (Chroma, July 2025): <https://www.trychroma.com/research/context-rot>
- HumanLayer, *Writing a good CLAUDE.md* (November 2025): <https://www.humanlayer.dev/blog/writing-a-good-claude-md>
- P. Chhikara et al., *Mem0: Building Production-Ready AI Agents with Scalable Long-Term Memory* (2025): <https://arxiv.org/abs/2504.19413>
- Claude Code, *Test plugins with evals*: <https://code.claude.com/docs/en/plugin-evals>
- DORA, *2023 Accelerate State of DevOps Report*, announcement: <https://cloud.google.com/blog/products/devops-sre/announcing-the-2023-state-of-devops-report>
- DORA, *2025 State of AI-assisted Software Development*: <https://cloud.google.com/resources/content/2025-dora-ai-assisted-software-development-report>, summarized by InfoQ: <https://www.infoq.com/news/2025/09/dora-state-of-ai-in-dev-2025>
- DORA, *The history of DORA's software delivery metrics*: <https://dora.dev/guides/dora-metrics/history/>
- Flow Framework metrics (M. Kersten), overview: <https://getdx.com/blog/flow-metrics/>
- METR, *Measuring the Impact of Early-2025 AI on Experienced Open-Source Developer Productivity*: <https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/>
- METR, *Recent Frontier Models Are Reward Hacking* (June 2025): <https://metr.org/blog/2025-06-05-recent-reward-hacking>
- M. Cemri et al., *Why Do Multi-Agent LLM Systems Fail?* (NeurIPS 2025): <https://arxiv.org/abs/2503.13657>
- Anthropic, *Building effective agents* (December 2024): <https://www.anthropic.com/research/building-effective-agents>
- GitHub, *Building an agentic memory system for GitHub Copilot* (January 2026): <https://github.blog/ai-and-ml/github-copilot/building-an-agentic-memory-system-for-github-copilot/>
- Claude Code, *Best practices*: <https://code.claude.com/docs/en/best-practices>
- Claude Code, *Hooks* (UserPromptSubmit, Stop): <https://code.claude.com/docs/en/hooks>
- Cursor forum, *Saved memories in Cursor and their viability* (August 2025): <https://forum.cursor.com/t/saved-memories-in-cursor-and-their-viability/128968>
- Windsurf / Devin Desktop, *Memories*: <https://docs.devin.ai/desktop/cascade/memories>
- J. Rehberger, Embrace The Red, on the SpAIware exploit in Windsurf (August 2025): <https://embracethered.com/blog/posts/2025/windsurf-spaiware-exploit-persistent-prompt-injection/>
- S. Zhang et al., *Which Agent Causes Task Failures and When?* (ICML 2025): <https://arxiv.org/abs/2505.00212>
- M. Kalinowski, G. Travassos, D. Card, a review of defect causal analysis in industry (2008): <https://sol.sbc.org.br/index.php/sbqs/article/view/15540>
- claude-reflect: <https://github.com/BayramAnnakov/claude-reflect>; claude-diary: <https://github.com/rlancemartin/claude-diary>
- Anthropic, *Demystifying evals for AI agents* (multiple trials, pass^k), listed above; SWR-Bench, on reviewer non-determinism: <https://arxiv.org/abs/2509.01494>
