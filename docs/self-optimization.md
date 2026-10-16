# Self-optimization in singularity

Research and engineering practice as of October 2026.

## One agent, two cadences

| | Learn job: **every run** | Optimize job: **every ~10 runs** |
|---|---|---|
| Runs | end of every `/singularity:feature` run; pending user corrections | `/singularity:feature` says it is due; schedule; request |
| Changes | guidelines (only for defects caused by a weak guideline, and user corrections); run digests; new regression eval cases; the rest as proposals | project context and guidelines, role models and effort, lenses, stages, project agents and skills; upstream reports |
| Evidence | one run's defects, hook-captured corrections, the run's change, later fixes and reverts of earlier runs' lines, finished human reviews and edits before merge (if enabled) | all runs, corrections and human reviews vs. the goals; eval replays; optimization archive; guideline and context audits; web practice scan |
| Model · effort | opus · high | fable · xhigh |
| Safeguard | curation rules + PR/MR review | tiers, falsifiable contracts, eval gates with a holdout set, challenger, PR/MR review; plugin changes only via a maintainer release |

- `singularity:optimizer` runs both jobs; since 0.5.0 it replaces a separate learner and optimizer that curated the same record.
- Evaluation stays separate: the reviewer challenges every proposal and keep verdict; contracts are judged on mechanical pipeline records, not the optimizer's labels; eval cases and the team's goals measure the result ([goals](#optimizing-towards-what-the-project-is-for)).
- The learn job keeps current guidance, not a log ([why](#guidelines-not-a-log-of-lessons)).
- New project → it first **onboards** the agents (drafts the goals with the team, forms the project context). Cause in the shared plugin → it **reports it upstream**.
- An agent, not a command: started by `/singularity:feature` (learn job; offers a due optimization), `/singularity:init-project` (onboarding) or the user. Playbooks: `plugins/singularity/optimizer/`.
- As a subagent (can't ask the user or run workflows): stops at each gate with a **Decision needed** block, keeps state in the run directory, does the workflows' work with its own subagents. As the session (`claude --agent singularity:optimizer`): does both itself.

## Optimizing towards what the project is for

- Faster and cleaner can mean less user value → the optimizer works from `.claude/singularity/goals.md`: users, their value, the team's goals and how it will know, trade-offs, constraints.
- Team-owned: drafted at onboarding from the team's writing (README, roadmap, tickets, release notes), confirmed at the gate; afterwards the optimizer only proposes changes.
- Spec writer names each work item's goal; planner follows the trade-off order; every proposal names its goal.

| Finding | Source | In singularity |
|---|---|---|
| User-focused teams have 40% higher organizational performance | DORA, *2023 Accelerate State of DevOps* | `goals.md` names users and their value; problems ranked by harm to them |
| AI amplifies: throughput rises with instability; user focus and mature value-stream management amplify its benefits | DORA, *2025 State of AI-assisted Software Development* | Evidence packs: quality and stability beside throughput; the pipeline's value stream (start → hand-off, review → merge) measured |
| Throughput: lead time, deployment frequency, failed-deployment recovery time; instability: change fail rate, deployment rework rate (since 2024) | DORA metrics | Analogues: lead time start → hand-off, fix rounds before merge, `fixes` as change-failure signal |
| Flow time, efficiency (active over total time), load, distribution (features, defects, risks, debt) | Kersten, Flow Framework | `lead_s`, `active_s`, `gate_wait_s` → flow efficiency; `kind`, `goal` → effort per goal |
| Developers believed AI made them 20% faster; it made them 19% slower | METR, randomized controlled trial (2025) | Flow from run-record timestamps, never estimates |
| Frontier models hacked scores (e.g. patched evaluators) in 30% of RE-Bench runs; o3 in 70–95% on one task even when told not to | METR, *Recent Frontier Models Are Reward Hacking* (2025) | Confirmed goals, eval cases, graders, metric definitions off-limits; challenger asks: goals or only a proxy? |
| Specification and design failures ~44%, inter-agent misalignment a third, verification a quarter; many verifiers "perform only superficial checks" | Cemri et al., *Why Do Multi-Agent LLM Systems Fail?* (NeurIPS 2025) | One agent instead of learner + optimizer; verification stays independent (above) |
| Add complexity "only when it demonstrably improves outcomes"; an evaluator-optimizer loop needs "clear evaluation criteria" | Anthropic, *Building effective agents* | One agent with jobs; people own the criteria (goals, eval cases) |

## Research findings and how singularity applies them

| Finding | Source | In singularity |
|---|---|---|
| Error analysis first: label and count real failures; eval those, not imagined ones | Husain & Shankar evals FAQ; Anthropic, *Demystifying evals* | `optimize-scan` failure taxonomy (counts per stage at fault, where each fix belongs) before any proposal |
| Smallest high-signal context: identifiers (file paths), detail on demand; `CLAUDE.md` costs every session | Anthropic, *Effective context engineering for AI agents* | Facts with file refs; `CLAUDE.md` and `project.md` short |
| Start evals with 20–50 tasks from real failures; separate capability from regression evals; read transcripts | Anthropic, *Demystifying evals* | Escaped defect → replayable eval case (learn job); plugin suite `plugins/singularity/evals/` |
| Monolithic rewrites cause **context collapse** (18,282 → 122 tokens, below the no-adaptation baseline); itemized delta updates keep detail | ACE (Zhang et al., ICLR 2026) | Guidelines have ids, edited one at a time; files never regenerated; lessons migrated one by one; history in run digests |
| Agents learn from **failures** as well as successes | ReasoningBank (Google, ICLR 2026) | Signals: rejected findings, verification failures, gate edits; precision eval cases from false positives |
| Gains come from structure (tools, middleware, memory), not prompt prose; factual structure transfers, prose strategy doesn't | AHE (Lin et al., 2026); Zhang, *Self-Evolving Agentic Harnesses* (2026) | Preference: config → checks/tools → facts/evals → targeted prompt additions → prose rewrites; agent files capped at ~120 lines |
| Each edit a **falsifiable contract**: predict what it fixes, check next round | AHE | Proposals state hypothesis, targets, predicted metric change, counter-metric, check-after point; a later contract check verifies |
| Non-regression gates and held-out splits; the gate rejects most edits | SkillOpt (Microsoft, 2026); Anthropic, *Writing tools for agents* | Adopt only if targets improve and nothing regresses; holdout cases never used for tuning |
| Keep an **archive** of variants, failed ones included | Darwin Gödel Machine (Sakana, ICLR 2026) | `optimizations.md`: every proposal with status, rejected included |
| Natural-language reflection beats GRPO with up to 35× fewer rollouts | GEPA (ICLR 2026) | Reflect over evidence and digests; evals validate a change, not search for it |
| Self-modifiers **hack their verifier**: DGM deleted its hallucination detector's markers; STOP turned off its sandbox | DGM; STOP via Zhang (2026) | Tier 3: eval cases, graders, metric definitions, gates, guardrails, permissions off-limits; plugin never edited (own definition included); project hooks: add checks only. Plugin eval runs hide case definitions from the agent under test |
| **Misevolution**: evolving memory and tools can degrade safety and quality | Shao et al., ICLR 2026; Zhou et al. survey (2026) | Guidelines need evidence, grounded in named files, PR-reviewed; no auto-merge; web content is untrusted |
| Evaluation, not proposal, dominates cost; use staged cascades | Zhang (2026) | Files → free graders → targeted replays; `max_eval_cost_usd` ceiling |
| Re-tune when the base model changes; evals set adoption speed | Zhang (2026); Anthropic, *Demystifying evals* | Practice scan flags new models and Claude Code features; evaluated trials, not switches |

## Guidelines, not a log of lessons

Since 0.5.0 the learn job keeps **guidelines** (how to work in the project now), not a lesson log (`_Why:_`, `_Seen:_`, `_Refs:_`; evicted only when a file was full). Reason: a log keeps what was once true after its code changes, and agents read it all as instructions.

| Finding | Source | In singularity |
|---|---|---|
| Agents copy retrieved experience, errors included; adding everything to memory fell below a small fixed one (67.5 → 55.5 on one agent); quality-gated addition plus deletion gained 11–29 points | Xiong et al., *How Memory Management Impacts LLM Agents* (2025) | Guidelines true of current code: learn job corrects or removes on code change; optimize job replaces those whose failure category recurs |
| Instructions are context, not enforcement: Claude may "pick one arbitrarily" between contradictions; prune "outdated or conflicting instructions" and "references to files or commands that don't exist"; under 200 lines; path-scope area rules; hook what must always happen | Claude Code docs, *How Claude remembers your project* | One home per guideline; replace, don't annotate; `scripts/check-guidelines.sh` finds named paths that are gone; area rules in `.claude/rules/singularity/` with `paths`; "a check beats a guideline" |
| LLM-written context files lowered success in 5 of 8 settings and cost ~20% more; developer-written ones gained ~4% at up to 19% more cost; overviews didn't help, named tools did | Gloaguen et al., *Evaluating AGENTS.md* (ETH Zürich and LogicStar.ai, 2026) | Only what an agent needs here; dates, counts, tickets stay in `runs.jsonl` |
| Performance degrades as input grows, worse with distractors (related but non-answering content) | Hong, Troynikov and Huber, *Context Rot* (Chroma, 2025) | By analogy (the study measured retrieval): a stale lesson on the same module is a distractor; area guidelines load only where they apply |
| Models follow "~150-200 instructions with reasonable consistency" (rough figure); `file:line` references beat snippets, which "become out-of-date quickly"; "never send an LLM to do a linter's job"; don't auto-generate `CLAUDE.md` | HumanLayer, *Writing a good CLAUDE.md* (2025) | Name files, don't copy code; enforceable guideline → proposed check; onboarding output small, team-reviewed |
| Compare each new fact with memory, then ADD, UPDATE, DELETE ("removal of memories contradicted by new information") or NOOP | Chhikara et al., *Mem0* (2025) | Learn job adds, changes or removes; the run digest records which and the finding each answers, outside the agents' context |

## Two signals: defects with a guideline cause, and user corrections

- No human review of its own → nobody checks a guideline before agents read it; only two signals change guidelines: **a defect whose root cause is a weak guideline**, and **a user correction** (the user told or showed an agent it did something wrong).
- Each guideline goes in the narrowest file the agent at fault reads. Clean runs, praise, unconfirmed findings, practices that only seem good → no guideline.
- Root cause first: `guideline-missing`, `guideline-wrong`, `guideline-unclear`, `guideline-ignored` or `not-guideline`. Only the first three change guideline text.

| Signal | Source | Captured by | Evidence |
|---|---|---|---|
| Defect | confirmed and rejected review findings | run record | model: on recurrence, unless a test reproduces it |
| Defect | failed checks, stop-gate blocks, verification failures | `run-checks.sh` exit codes; `.state/stop-gate.log` | tool: at once |
| Defect | later fixes and reverts of a run's lines | `outcomes.sh later-fixes` (blame at the fix's parent) | person, once the learn job reads the commit: at once |
| Defect | review comments and edits before merge that fix a defect | `learning.pr_reviews`; `outcomes.sh edits` | person: at once |
| Correction | prompts that read like a correction | `UserPromptSubmit` hook, phrase filter | person: at once if explicit |
| Correction | what the user types after an interrupt or a rejected tool call | `UserPromptSubmit` and `Stop` hooks, prompt ids, session transcript | person if it says what was wrong; implicit (only a rephrased request): on recurrence |
| Correction | gate edits; edits before merge that apply a project convention | spec and plan drafts; `outcomes.sh edits` | person: at once |

Citations point at a guideline and never add one: reviewers cite the guideline a finding breaks, the planner and implementer the guidelines that decided a choice.

| Finding | Source | In singularity |
|---|---|---|
| Copilot Memory, the one production-measured learning loop, raised PR merge rate 83% → 90% (p<0.00001); memories cite code, are re-checked against the current branch, expire after 28 days unused | GitHub, *Building an agentic memory system for GitHub Copilot* (January 2026) | Guidelines name their files; guideline check every learn job; context audit removes guidelines about code that is gone |
| Add a rule when "Claude makes the same mistake a second time" or a review catches it; an ignored rule suggests the file is too long | Claude Code docs, *Best practices* and *How Claude remembers your project* | Model-only evidence changes a guideline on its second occurrence (`pending` until then); ignored guideline → proposed check or path-scoped rule, not more text |
| Cursor dropped its memories UI for rules; Windsurf keeps auto memories machine-local and recommends rules or AGENTS.md | Cursor forum (2025); Windsurf / Devin Desktop docs (2026) | Corrections → versioned guidelines in the repo, cause in `runs.jsonl`; raw prompt queue never committed |
| A source-file comment made an auto-invoked memory tool store attacker instructions; queries alone injected memories 98.2% of the time, and LLM detectors flagged 0 of 135 | Rehberger, *SpAIware* (August 2025); Dong et al., *MINJA* (2025) | Only what the user typed is a correction: pasted content, notifications, other agents' messages cut before matching; files, tool output, tickets, PR comments are data; no correction loosens a check, guardrail or permission |
| Best automated attribution: right agent for 53.5% of multi-agent failures, decisive step for 14.2%; counterfactual methods reach about 77% and 52% | Zhang et al., *Which Agent Causes Task Failures and When?* (ICML 2025); Wang et al., *CHIEF* (2026) | Guideline changes need a defect confirmed by a person or tool, or a recurrence |
| Defect causal analysis and orthogonal defect classification act only on systematic causes, cutting defect rates by over half | Card (IEEE Software, 1998); Chillarege et al. (IEEE TSE, 1992); Kalinowski, Travassos and Card (2008) | `not-guideline` (slips, flaky environments, ambiguous tickets, one-off requests): recorded, no change |
| Claude Code transcript miners: cheap phrase filter, then an LLM pass drops questions, one-time instructions, vague feedback | claude-reflect; claude-diary (2025) | Hooks queue prompts matching `correction-patterns.txt` (projects add their own, any language); learn job drops non-corrections |
| Feedback is implicit at least half the time: of 101 cases, 37 repeat or rephrase the request, 18 state the correction; models classify feedback types with 47–49% accuracy | Don-Yehiya, Choshen and Abend (2024); Liu, Zhang and Choi (EMNLP 2025) | Prompts after an interrupt or a rejected tool call are queued without a phrase; a rephrased request alone is implicit: acts on recurrence |
| Users push back in 50% of coding-agent turns, interruptions included; only 59% of agent-written code reaches commits. 91.49% of resolved misalignments needed the developer's pushback; violating a stated constraint is the largest class (38.33%) | Baumann et al., *SWE-chat* (COLM 2026); Tang et al., *How Coding Agents Fail Their Users* (2026, preprint) | Interrupt and rejection triggers; an ignored constraint → proposed check, not more text |
| Only 54.9% of merged Claude Code PRs went in unmodified; of those revised, 47.7% got bug fixes and 23.4% style or project conventions | Watanabe et al., 567 Claude Code PRs (TOSEM, accepted) | Hand-off snapshot; people's edits before merge → escaped defects and convention corrections; `unmodified` share on the dashboard |
| Learning preferences from users' edits to agent output cut cumulative edit distance 31,103 → 8,391 (email writing) | Gao et al., *PRELUDE/CIPHER* (NeurIPS 2024) | Edits are corrections, as gate edits already were |
| R-SZZ (blame, most recent commit) has precision 0.66, 0.73 with a date filter; B-SZZ recall 0.69 at precision 0.39. Keyword-labelled fixes: 36% false positives; full issue keys find 99.7% of links | Rosa et al. (ICSE 2021); Berger et al. (TOPLAS 2019); Herbold et al. (EMSE 2022) | `outcomes.sh later-fixes`: blame of the lines a fix changes, 90-day window, explicit `Singularity-Run` trailer or PR/MR ref; the learn job reads every candidate before counting it |
| 1–5% of commits are reverted, most at one company for external reasons (dropped features, vendor fixes) | Shimagaki et al. (ICSME 2016) | A revert counts only for a bug or a wrong approach |
| The same analysis had a fix rate near 0% as a nightly list and over 70% as diff-time comments; compile-time findings were "real problems" 74% of the time, patches to checked-in code 21% | Distefano et al., Infer (CACM 2019); Sadowski et al. (CACM 2018) | Ignored guideline → check at diff time (lint, test, hook); stop-gate blocks recorded as defects |
| A change within one line of a review comment is the strongest sign it was useful (classifier precision 89.1%); LLM comments were acted on 38.7% of the time, humans' 44.45%; Bugbot's resolution rate rose 52% → 78% | Bosu, Greiler and Bird (MSR 2015); Atlassian RovoDev (ICSE-SEIP 2026); Cursor, *Bugbot learning* (2026) | `addressed` per lens in `human_review` lines: the reviewers' precision; a lens people rarely act on → narrowed or advisory |
| Items carry helpful/harmful counts (ACE) or votes, deleted at zero (ExpeL); suppressing non-actionable practices raised useful comments 54% → 80% | ACE (ICLR 2026); Zhao et al., *ExpeL* (AAAI 2024); Google, *AutoCommenter* (2024) | Guideline lifecycle per id: applied, cited, ignored against, misled; always-loaded and unused → path-scoped rule |
| Admitting a memory only if a replay with it beats one without gave most of the gain (57 → 64); verified experience helped 4 of 5 solvers while 11 of 12 memory systems failed to beat none | Liu et al., *SEDM* (2025); Fan et al., *VibeMemBench* (2026, preprint) | Guideline admission: review guidelines replayed with and without them at the next optimization |
| Unscoped repository memory dropped a coding agent from 42% to 31%; self-written skills changed pass rates by −1.3 points, focused curated ones +18.6 | Lindenbauer et al., *CTIM-Rover* (2025); Li et al., *SkillsBench* (2026) | Path-scoped rules; one short guideline per cause; held-out eval cases |
| 70% of high-priority bugs had a coupled mutant that a test killing it could have caught | Petrović et al., mutation testing at Google (ICSE 2021) | Recurring weak-test defects → proposed mutation check on changed lines in `verify.sh` |

**Considered, not adopted.**

- Tool failures (`PostToolUseFailure`) as friction: test-first runs fail on purpose; the checks' exit codes and stop-gate blocks already record real failures.
- Agents' reports of what they lacked: self-reports were wrong in 22.58% of episodes (Tang et al.); no study uses them to learn rules.
- Praise and clean runs: feedback appears in 12.8% of conversations and models agree with people on dissatisfaction at κ=0.50 (WildFeedback); learning without ground truth fell below the base model (ACE).
- Code survival as a trigger: slow and noisy (Ziegler et al., 2022); only the share of changes merged unedited is measured.
- Expiry after disuse: a guideline added for a defect may be what prevents it; disused always-loaded guidelines move to path-scoped rules instead.
- Leave-one-out ablation of every guideline: one replay per guideline, and it misses duplicates (MeClear); only review guidelines with an eval case are replayed.

**How a correction is captured.**

- `Stop` and `StopFailure` hooks: mark the turn ended (its prompt id); `Stop` keeps the agent's last message.
- `UserPromptSubmit` hook: cuts pasted content, notifications and other agents' messages, then queues the prompt in `<work_dir>/corrections/` (keeps itself out of git: prompts can hold secrets) with trigger `phrase` (starts with `correction:`, or matches `scripts/correction-patterns.txt` after the agent's first turn: a session's first prompt sets the task, and its "don't commit" corrects nothing), `interrupt` (the previous prompt's turn never reached Stop) or `rejection`, with the agent's last message. "Continue" and "yes" are never queued.
- Both hooks read the session transcript from where they last stopped: a rejected tool call with typed feedback is queued at once, with the call; one without feedback marks the next prompt. Claude Code doesn't document the transcript format: best effort, nothing queued if it changes.
- Learn job: reads the queue, records each kept correction as a `correction` line in `runs.jsonl` (trigger, role, category, scope, cause, action; never the prompt's text), clears the queue.

**How a later fix is found.**

- At hand-off the pipeline keeps the change as `refs/singularity/handoff/<slug>` (`outcomes.sh snapshot`; local, index and working tree untouched) and, when it commits, adds the trailer `Singularity-Run: <slug>`.
- `outcomes.sh later-fixes`: first-parent commits on the default branch from the last 90 days whose message reads like a fix or a revert; `git blame -w -M -C` of the lines each changes, at its parent; a blamed line belongs to a run through the trailer, the run's squash commit or merge (PR/MR ref or branch from `runs.jsonl`), or the snapshot's added lines. Lines older than the window, a run's own commits, and commits a `later_fix` line records are left out.
- The learn job reads up to three per run: a fix of that run's defect is root-caused at once; a revert counts only for a bug or a wrong approach; refactorings and new requirements are recorded as no defect.

**Validating with noise in mind.**

- Reviewer is non-deterministic → `replay-evals` runs each variant several times per case (`trials`, default 3), reports which cases are right in most trials and which flip.
- At 20 cases, a one- or two-case difference is noise.
- Canary over ten runs: shows breakage, not small gains → judged on whether its target defects and corrections stopped.

## Onboarding: context before optimization

- Survey the repository, its history and recent human reviews; write as guidelines only what an agent can't quickly find out or would get wrong: exact commands and tools, non-obvious conventions, domain rules and risks, what not to touch. No overviews.
- Place each fact where its agent reads: project sections of `CLAUDE.md`, guideline files, path-scoped rules, the "Do not touch" list.
- Learn-job rules: current right way, grounded in named files; smallest context that works (`CLAUDE.md`, `guidelines/project.md` load into every session); edits, never rewrites.
- Setup changes (lenses, stages, role settings): no runs to measure → canaries.
- Past human review catches → baseline eval cases where possible, so the first optimization can validate review changes.
- Afterwards: each optimization's context audit keeps it current.

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

- The optimizer never edits the shared plugin: a fix for one project can break another; only a release reaches all.
- Fix belongs in the plugin (shared agent instructions, protocol, defaults, standards, templates) → upstream report in the project's `.claude/singularity/upstream/`: problem, evidence (counts, categories), exact fix, contract with a validation plan (ideally a plugin eval case). Same path for guidelines right everywhere (`upstream.md`).
- Publishable: nothing identifies the project; the challenger checks that and that the cause is the plugin's.
- Team reviews reports in the optimizer's PR/MR; approved ones filed as issues in this repository only on the user's yes.
- Local workaround meanwhile, proposed for removal once a release with the fix reaches the project.
- Maintainers adopt per `CONTRIBUTING.md`: plugin eval case reproducing the failure → change → suite on the candidate and the default branch → release. Several projects reporting the same problem: the strongest evidence.

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
| Change-failure share | `fixes` in later run digests, `later_fix` lines with `"defect":true` | none for gaming; read it with escaped defects |
| Changes merged unedited | `unmodified` in `human_review` lines | escaped defects, later fixes |
| Open findings addressed, per lens | `addressed` in `human_review` lines | recall cases, escaped defects: fewer findings must not mean fewer catches |
| Work mix across the goals | `kind` and `goal` in run digests | the team's review of the goal labels at the spec gate |

## Change tiers

| Tier | Scope | Rule |
|---|---|---|
| 1 · Context and curation | project context, new "Do not touch" entries, guidelines and path-scoped rules, new eval cases, commands, upstream reports | implemented; reviewed in the PR/MR |
| 2 · Behaviour | models and effort, new lenses and extra reviewers, stages, project agents, skills and workflows, new checks in the project's `verify.sh` and `post-edit.sh`, learning limits | contract + passing validation, or explicit canary; unattended, only with a passing replay |
| 3 · Oversight | the confirmed goals, removing review coverage (a lens, an extra reviewer, a stage), gates, guardrail hooks, removing or weakening a project check, removing a "Do not touch" entry, permissions, tracker writes, autonomy settings, existing evals and graders, metric definitions, `roles.optimize` (binding, model, effort) and `roles.learn` (model, effort) | proposal only; a human changes it |
| Upstream | the plugin: shared agents (the optimizer included), skills, workflows, standards, templates, defaults | never edited by the optimizer; upstream report, adopted by maintainers |

## Validation methods

- **replay-evals** (project): the project's eval cases (real escaped defects and known false positives, each a `change.patch` on a base commit), replayed by the reviewer in isolated worktrees, baseline vs candidate variant; a judge scores recall and precision, holdout cases separately.
- **claude plugin eval** (maintainers, adopting an upstream report): the plugin's suite under `plugins/singularity/evals/`, on the candidate and default branch.
- **canary**: unreplayable changes (spec, plan or implementer behaviour) ship with recorded baseline metrics and a check-after point; the contract check keeps or reverts them. Fix released upstream: count only runs on the release that shipped it (`plugin_version` in the run digests), never `+dev` runs from an unreleased checkout.

## Running it unattended

- Ask with `unattended` (e.g. a weekly scheduled task or CI job), in auto mode: `claude -p --permission-mode auto "Use the singularity:optimizer agent: optimize, unattended"`. Claude Code treats `.claude/` as protected: it asks before every write there, where guidelines, the record and eval cases live; headless in default, `acceptEdits` or `dontAsk` mode the write is refused, while auto mode's classifier decides ([permission modes](https://code.claude.com/docs/en/permission-modes#protected-paths)).
- Implements tier 1 plus tier 2 changes whose replay passes within the budget; canaries wait for a person.
- Writes upstream reports, unfiled; opens a draft PR/MR.
- Nothing merges without a human; plugin changes reach projects only through a maintainer release.

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
- SWR-Bench, on reviewer non-determinism (multiple trials, pass^k: *Demystifying evals*, above): <https://arxiv.org/abs/2509.01494>
- Dong et al., *MINJA*, memory injection through queries (2025): <https://arxiv.org/abs/2503.03704>
- Wang et al., *CHIEF*, counterfactual failure attribution (2026): <https://arxiv.org/abs/2602.23701>
- S. Don-Yehiya, L. Choshen, O. Abend, *Learning from Naturally Occurring Feedback* (2024): <https://arxiv.org/abs/2407.10944>
- Liu, Zhang and Choi, implicit feedback in conversations (EMNLP 2025): <https://arxiv.org/abs/2507.23158>
- Baumann et al., *SWE-chat* (COLM 2026): <https://arxiv.org/abs/2604.20779>
- Tang et al., *How Coding Agents Fail Their Users* (2026, preprint): <https://arxiv.org/abs/2605.29442>
- Watanabe et al., Claude Code pull requests in open source (TOSEM, accepted): <https://arxiv.org/abs/2509.14745>
- G. Gao et al., *Aligning LLM Agents by Learning Latent Preference from User Edits* (NeurIPS 2024): <https://arxiv.org/abs/2404.15269>
- G. Rosa et al., *Evaluating SZZ Implementations Through a Developer-informed Oracle* (ICSE 2021): <https://arxiv.org/abs/2102.03300>
- E. Berger et al., on the reproducibility of a large-scale study of programming languages and code quality (TOPLAS 2019): <https://arxiv.org/abs/1901.10220>
- S. Herbold et al., *Problems with SZZ and features* (EMSE 2022): <https://arxiv.org/abs/1911.08938>
- J. Shimagaki et al., *Why are Commits being Reverted?* (ICSME 2016): <https://rebels.cs.uwaterloo.ca/papers/icsme2016_shimagaki.pdf>
- D. Distefano et al., *Scaling Static Analyses at Facebook* (CACM 2019): <https://doi.org/10.1145/3338112>
- C. Sadowski et al., *Lessons from Building Static Analysis Tools at Google* (CACM 2018): <https://research.google/pubs/lessons-from-building-static-analysis-tools-at-google/>
- A. Bosu, M. Greiler, C. Bird, *Characteristics of Useful Code Reviews* (MSR 2015): <https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/bosu2015useful.pdf>
- Atlassian, RovoDev code review (ICSE-SEIP 2026): <https://arxiv.org/abs/2601.01129>
- Cursor, *Bugbot learning* (April 2026): <https://cursor.com/blog/bugbot-learning>
- A. Zhao et al., *ExpeL: LLM Agents Are Experiential Learners* (AAAI 2024): <https://arxiv.org/abs/2308.10144>
- Google, *AI-assisted Assessment of Coding Practices in Modern Code Review* (AutoCommenter, 2024): <https://arxiv.org/abs/2405.13565>
- Liu et al., *SEDM*, verifiable self-evolving memory (2025): <https://arxiv.org/abs/2509.09498>
- Fan et al., *VibeMemBench* (2026, preprint): <https://arxiv.org/abs/2609.23570>
- Lindenbauer, Groh, Schütze, *CTIM-Rover* (REALM 2025): <https://arxiv.org/abs/2505.23422>
- Li et al., *SkillsBench* (2026): <https://arxiv.org/abs/2602.12670>
- G. Petrović et al., *Does mutation testing improve testing practices?* (ICSE 2021): <https://arxiv.org/abs/2103.07189>
- Shi et al., *WildFeedback* (ACL 2026): <https://arxiv.org/abs/2408.15549>
- Yang et al., *MeClear*, attributing harmful memories (2026): <https://arxiv.org/abs/2609.09115>
- A. Ziegler et al., *Productivity Assessment of Neural Code Completion* (MAPS 2022): <https://arxiv.org/abs/2205.06537>
