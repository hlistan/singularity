# Models and effort per role

Model and effort per role, the evidence, and how to choose them for a project's own agents. Researched October 2026 for Claude Fable 5.1, Opus 5.5, Sonnet 5.5 and Haiku 5.5. Effort scales are calibrated per model: re-check on every new model (the optimizer's practice scan flags them).

## The short answer

| Role | Model · effort | Confidence | Main evidence |
|---|---|---|---|
| spec | opus · high | medium | unverifiable; errors flow into every later stage; once per ticket |
| plan | opus · high | medium | the architect sets the architect/editor pair's ceiling (Aider); planner under 0.4% of a long run's cost (Anthropic) |
| implement | sonnet · medium, **fix rounds at high** | medium | Anthropic's Sonnet 5.5 guidance: medium for well-specified agentic coding, high for harder; re-running failures at high beats high for all |
| review | fable · high | medium for the tier and effort; **open** between Fable and Opus | a judge needs a frontier model; evidence leans to Opus 5.5 matching Fable 5.1 for less, so T1 replays `opus · high` first |
| verify | sonnet · **medium** (was low) | low (canary C1) | Sonnet 5.5 guidance starts multistep tool use at medium; lower effort, fewer tool calls; the coverage summary needs judgment |
| optimize, learn job | opus · high | medium | runs every run; ACE needs "a reasonably strong Reflector"; a small reflector changed nothing where frontier ones helped (Decagon) |
| optimize | fable · xhigh | medium | Anthropic positions Fable for hours-long sessions and deep research, xhigh for agentic work over 30 minutes; runs at onboarding, every ~10 runs |

Confidence: **high** = measured on these models and this work (none here); **medium** = Anthropic's guidance plus indirect evidence; **low** = reasoned from guidance, shipped as a canary.

### What "proven" means here

No published study measures model tiers across a pipeline like this one. Evidence, by weight:

1. Anthropic's measurements and documentation for these models.
2. Independent benchmarks of them.
3. Peer-reviewed papers and preprints on similar work, mostly earlier models.
4. Small-sample practitioner tests.

Anthropic says to tune effort on your own evals; singularity does, with replay-evals for review and canaries for the rest ([Open trials](#open-trials)).

## The models (October 2026)

| Model | Alias | $ per MTok in · out | Speed | Anthropic's positioning | Default effort in Claude Code |
|---|---|---|---|---|---|
| Fable 5.1 | `fable` | 10 · 50 | slower | highest capability: "agent sessions that run for hours, multistep deep research, analysis carried through to a finished document" | high |
| Opus 5.5 | `opus` | 4 · 20 | moderate | "Most workloads start with Claude Opus 5.5": complex agentic coding, large refactors | medium |
| Sonnet 5.5 | `sonnet` | 2 · 10 | fast | everyday coding, agentic tool use; "complements Opus 5.5 best when running at lower effort settings" | medium |
| Haiku 5.5 | `haiku` | from 0.10 · 0.50 | fastest | classification, extraction, summaries, subagent work; "Sonnet 5.5 and Opus 5.5 remain better choices for complex agentic coding" | medium |

- **Opus 5.5 is at Fable 5.1's level on coding, for less.** Anthropic's launch table: Terminal-Bench 4.0 66.4% vs 55.8%, FrontierCode 54.4% vs 50.3%, CursorBench 57.8% vs 51.8%. SWE-bench Pro subset (*Optimizing for cost and intelligence*; one run; not comparable with the public leaderboard), default effort: 92.8% at $0.22 per solved task vs 92.3% at $1.19. Fable uses fewer output tokens (~78k vs 119k at max, Artificial Analysis), narrowing the 2.5× per-token gap.
- **Aliases differ by provider.** Amazon Bedrock, Google Cloud: `sonnet` = Sonnet 4.5, `haiku` = Haiku 4.5 (the implementer and verifier silently run an older generation); Microsoft Foundry: `opus` = Opus 4.6. Check `/model`; if the newer model exists, bind the role to a project agent with its full model ID.
- **Blocked models fall back.** An alias blocked by an org allowlist resolves to the newest allowed version of its family; anything else, to the session's model.
- **Effort names differ per model**; Opus 5.5 defaults one level lower than Opus 5. Always set `effort`.

## What effort does, and where it stops paying

Effort governs every output token (thinking, tool calls, text): a behavioural signal, not a hard budget. Lower effort: fewer tool calls, less checking.

| Finding | Evidence |
|---|---|
| Gains are steep up to medium or high, then flatten | Opus 5.5, SWE-bench Pro, vs high: medium −2.5 points at ~70% cost, low −8 at ~⅓, xhigh +1.4 at 2.5× (Anthropic) |
| `max` can be worse, not just costlier | Sonnet 5.5, FrontierCode: 46.2% at max vs 52.1% at xhigh, partly code-review subagent fan-out (a timeout or out-of-scope edits in two cases Cognition examined; Anthropic); "prone to overthinking" (Claude Code); longer reasoning hurt several task types (*Inverse Scaling in Test-Time Compute*) |
| Mechanical checks make effort matter less | Opus 5, six multi-file bug fixes: tests visible, 18/18 at every level (max 1.9× low's cost per solve); hidden, 0/13 at low, 8/13 at max (Latitude, 155 runs; hidden tier one task, visible tier maybe at ceiling) |
| Escalate on failure instead of raising the baseline | Opus 5.5, SWE-bench Pro: low with failures re-run at high ~97.0% at $0.17 per task, vs high for everything 95.3% at $0.29 (Anthropic) |
| Try lower effort before a cheaper model | "Tuning effort is often a better lever than switching models" (Anthropic): Opus 5.5 at low 87.4% at $0.12 per solved task vs the older Sonnet 5's 77.4% at $0.84; orchestrator/worker splits never undercut one model at lower effort on work it could handle |
| More effort does not reliably improve review | CodeRabbit (Opus 5.5, 80 open-source bug patterns): "Turning up effort did not consistently produce a better review"; `/code-review` keeps only its most confident findings at `low`, broadening from `medium` through `max` (Claude Code) |

Rule of thumb: nothing checks the output -> effort buys depth; tests, exit codes or a later stage check it -> buy effort on retries.

## Role by role

### spec · opus · high

- **Work:** ticket to testable acceptance criteria plus gaps; only the human gate checks it.
- **Ambig-SWE:** clarifying questions improved underspecified tasks by up to 74%, but models struggle to spot them.
- **Claude Code:** `high` for work "where verification matters or edge cases are likely".
- **Not Fable:** a short task, and Opus 5.5 "performs at the level of Claude Fable 5.1 on most work".
- **Deviate:** mostly trivial tickets: trial `opus · medium`, watch the spec gate-edit rate.

### plan · opus · high

- **Work:** read the codebase, design small verifiable steps (the architect).
- **Aider (2024):** o1-preview architect + cheaper editor 85.0% vs 79.7% alone; a weaker architect's pair (o1-mini, 71.4%; 61.1% alone) stayed well below.
- **Plan-and-Act (ICML 2025):** the bottleneck "may lie more in plan quality"; replanning (+~10 points) is the implementer's "stop and report if the plan is wrong".
- **Anthropic (long-running app harness):** planner $0.46 of a $124.70 run.
- **Not xhigh:** for runs over 30 minutes.

### implement · sonnet · medium, fix rounds at high

- **Work:** an approved plan, test-first, scoped; tests, review and verification check it.
- **Anthropic, Claude Code:** `medium` for well-specified, scoped feature work; `high` for harder tasks and "fixing a bug in an existing codebase".
- **Latitude, Aider:** with tests to run, effort didn't change the solve rate; a precise plan lifts a cheaper editor close to a strong model.
- **Fix rounds at high:** a blocking finding or failed verification is a reliable failure signal. `/singularity:feature` passes `effort: high` to the implement role for fix rounds unless the project config sets the role's effort.
- **Not Haiku:** Terminal-Bench 4.0 39.2% vs Sonnet 5.5's 70.6%.
- **Open (T2):** Opus 5.5 at `low` may match; Sonnet stays: faster, and Anthropic's guidance names this work.
- **Gotcha:** models take shortcuts to get green, e.g. deleting application code so a flaky test passes (The New Stack). Guard: the correctness lens and the acceptance criteria.

### review · fable · high

- **Work:** find defects by reading a diff, one lens, fresh context; challenge other reviewers' findings. Main quality gate (escaped defects: the ground truth); most frequent strong-model call (one per lens plus one per finding).
- **JudgeBench:** strong judges such as GPT-4o were "just slightly better than random guessing" on hard pairs; a weaker challenger turns wrong rejections into escaped defects.
- **Effort high:** lower effort narrows coverage, and the challenger already supplies precision.

Fable 5.1 vs Opus 5.5: open, leaning Opus.

- **Anthropic:** Opus 5.5 matched Fable 5.1 on coding for less (models above).
- **The New Stack** (three race conditions, found and fixed without running code, five runs at max): Fable 5/5, Opus 3/5, both misses at the 128k output limit (rarer at `high`).
- **Factory:** top models within ~4 points on review; the most expensive of 13 ranked 11th.
- **SWR-Bench:** aggregating several review passes raised F1 by up to 43.7%.
- **Verdict:** Fable 5.1 until replay-evals (T1) show `opus · high` holds recall and precision, holdout cases included. Measure cost too: Opus uses more tokens per task.
- **Without Fable:** `roles.review: { model: opus, effort: high }`.

### verify · sonnet · medium

- **Work:** run install, build, lint, typecheck, tests and the verify hook with evidence (mechanical); map each acceptance criterion to tests for happy path, boundaries, failure modes (judgment; the human reads it first).
- **Anthropic:** for, Sonnet 5.5 starts multistep tool use at `medium`, and Haiku 5.5 at low is "more likely to skip a search, stop early, or skip a check" in long agent prompts; against, `low` suits "simpler tasks that need the best speed and lowest costs, such as subagents".
- **Cost:** one or two runs per pipeline run, mostly log input tokens.
- **False success (2026 preprint):** in single-control τ²-bench domains, 45–48% of failures were confident false successes that LLM judges mostly missed. Exit codes and evidence lines (the verifier's table) matter more than effort.
- **Not Haiku:** ~30 points behind on Terminal-Bench 4.0.

### optimize, learn job · opus · high

- **Work:** add, correct, merge or remove guidelines; turn misses into eval cases. The output loads into every future session.
- **ACE:** needs "a reasonably strong Reflector"; monolithic rewrites collapsed context below the no-adaptation baseline.
- **Decagon (GEPA):** a GPT-4o-mini reflector left a production prompt "essentially unchanged"; GPT-4.1, GPT-5.2, Claude Sonnet and Claude Opus reflectors: ~5–6% better, at 5–10% of the optimization cost.
- ***Your Agent May Misevolve* (ICLR 2026):** evolving memory can degrade safety, so guidelines are reviewed in the PR/MR.
- **Not Sonnet:** might suffice, but at one call per run the saving is small.
- **Config:** the pipeline passes opus · high; fable · xhigh is the optimizer's own; `roles.learn` overrides the learn job alone.

### optimize · fable · xhigh

- **Work:** codebase survey at onboarding; every ~10 runs, hours of evidence analysis, web practice scan, falsifiable proposals, implementation, upstream reports.
- **Anthropic (Fable 5.1):** xhigh or max "for the most capability-sensitive agentic and coding work".
- **Darwin Gödel Machine, ADAS:** self-improvement meta-agents are frontier models. Rare runs keep cost small.
- **Not max:** no published gain over xhigh.
- **Without Fable:** `opus · xhigh` (GDPval-AA v2.1, Opus 5.5 launch table: 1846 vs Fable 5.1's 1735 Elo).

### Helper calls inside workflows

| Call | Model · effort | Why it fits |
|---|---|---|
| optimize-scan: list eval cases | sonnet · low | listing and counting files |
| optimize-scan: other evidence streams | session model; medium, or high for failures and the practice scan | analysis, on the strong session model |
| replay-evals: judge | sonnet · low | a reference-guided match ("same root cause as this known defect?"), far easier than open judging. A grader (tier 3): changing it breaks comparison with past baselines; change only by hand, after checking against a few human labels |

## Choosing model and effort for a custom agent

Any project agent in `.claude/agents/`: bound to a role, an extra reviewer, or a stage.

### 1. Describe the work

| Question | Raise the model when… | Raise the effort when… |
|---|---|---|
| How open-ended is it? | it decides what to do: design, judge, diagnose | the right answer isn't obvious from its inputs |
| What checks its output? | nothing, before it matters | no test, exit code or schema, and no human sees each result |
| How long does it run? | hours, unattended | over ~30 minutes, many steps |
| Who depends on its output? | many later stages, or every future run | an error would propagate silently |
| Does it judge another model's work? | always: a judge is never weaker than what it judges | yes |
| How often does it run? | rarely, so quality is cheap | (frequent calls: effort as low as quality allows) |

### 2. Pick the model

| The agent mostly… | Model | Examples |
|---|---|---|
| extracts, classifies, routes, lists, reads config, or searches where a later step re-checks the result | `haiku` | config readers, file finders, log triage, ticket labelling |
| executes checked, well-specified work: follows a plan, codes against tests, runs commands and reports, writes docs from a spec | `sonnet` | platform implementer, migration executor, contract-test runner, release-notes writer |
| judges, designs or diagnoses: specs, plans, reviews, root causes, curation; anything unverifiable or high-impact | `opus` | domain reviewer, architecture-rule checker, performance investigator, threat modeller |
| runs for hours on research-heavy or open-ended problems, or Opus at xhigh falls short on your evals | `fable` | optimizer-style meta work, deep investigations |

### 3. Pick the effort

| Effort | Use when | Avoid when |
|---|---|---|
| `low` | short, mechanical task; code or a later stage checks the output | long prompt with many required checks |
| `medium` | clear scope; tests or exit codes check the result; the start for Sonnet and Haiku agentic work | nothing checks the output |
| `high` | judgment, edge cases, no mechanical check: reviewers, challengers, specs, plans, bug fixes, retries after a failure | high-volume calls with a check in place |
| `xhigh` | rare, high-leverage unattended runs over ~30 minutes | short or frequent tasks: on Opus 5.5, 2.5× high's cost for ~1.4 points |
| `max` | your evals show a gain | as a default: diminishing returns, overthinking, out-of-scope edits |

### 4. Rules that override the tables

1. **Try lower effort before a cheaper model.**
2. **Escalate on retry.** First attempts at the cheapest level that usually works, failures one or two levels higher; needs a reliable failure signal (failing test, blocking finding).
3. **A judge is never weaker than what it judges.** Reviewers and challengers: opus or fable, at high.
4. **Make pass/fail mechanical.** Exit codes and evidence lines, never a model's "tests passed"; for checking agents this beats model tier.
5. **Always set `effort`.** Otherwise the default (medium on Opus 5.5, high on Fable 5.1) shifts with the model.
6. **Never default to `max`.**
7. **On Bedrock, Google Cloud or Foundry, check what each alias resolves to** before relying on a tier.

### 5. Prove it on your project

The project's evals decide:

- **Reviewers:** a `replay-evals` variant on the project's eval cases; compare recall and precision, holdout included.
- **Everything else:** a canary in `optimizations.md` with baseline metrics (first-pass verification, review rounds, gate edit rate, escaped defects, seconds and tokens per stage) and a check-after point.

The run digest records each role's model for before/after comparison.

### Examples

| Custom agent | Model · effort | Why |
|---|---|---|
| `android-implementer`, bound to implement | sonnet · medium | well-specified plan, tests check it; fix rounds get high from the pipeline |
| `review-domain`, an extra reviewer for domain rules | opus · high | no mechanical check; a miss escapes |
| security reviewer for a payments or auth service | opus · high, or fable · high if replay-evals show it catches more | read-only bug finding, costly misses; compare both with replay-evals |
| `after_implement` stage running a contract-test suite and reporting | sonnet · medium, or haiku · medium if it only reports exit codes | mechanical; exit codes check it |
| `before_handoff` stage writing release notes from the diff and spec | sonnet · low | short; a human reads it in the PR/MR |
| dependency-upgrade executor following a written runbook | sonnet · medium | scoped, tests check it; re-run failures at high |
| codebase search helper for other agents | haiku · low | the caller re-reads what it finds |
| performance investigator: profiles, forms hypotheses, proposes fixes | opus · high | diagnosis without a single right answer |

## Open trials

Contracts for the next optimizer run or a manual trial. C1, C2: shipped canaries; T1–T3: proposals.

| # | Change | Prediction | Counter-metric | Validation |
|---|---|---|---|---|
| C1 | verify: sonnet · low → medium | fewer coverage gaps found later by review or humans; first-pass verification unchanged | seconds and tokens per verify stage | canary: check after 10 runs on the release that ships it |
| C2 | implement fix rounds at high | fewer second fix rounds and fewer stops with blockers left after two rounds | tokens per fix round | canary: check after 10 runs on the release that ships it |
| T1 | review: fable · high → opus · high | recall and precision within one case of the baseline, holdout included, at lower review cost | escaped defects | `replay-evals` with two variants |
| T2 | implement: sonnet · medium → opus · low | first-pass verification and review rounds equal or better, cost per run within 10% | seconds per implement stage | canary, 10 runs |
| T3 | security lens at xhigh | more security recall cases caught | precision cases, cost | `replay-evals`; needs per-lens effort in the review stage |

## Sources

Anthropic documentation and announcements:

- Models overview: <https://platform.claude.com/docs/en/models/overview>
- Choosing a model: <https://platform.claude.com/docs/en/about-claude/models/choosing-a-model>
- Optimizing for cost and intelligence: <https://platform.claude.com/docs/en/about-claude/models/optimizing-for-cost-and-intelligence>
- Effort: <https://platform.claude.com/docs/en/build-with-claude/effort>
- Claude Code, subagents: <https://code.claude.com/docs/en/sub-agents>
- Claude Code, model configuration: <https://code.claude.com/docs/en/model-config>
- Claude Code, code review: <https://code.claude.com/docs/en/code-review>
- Claude Opus 5.5: <https://www.anthropic.com/claude-opus-5-5>
- Claude Sonnet 5.5: <https://www.anthropic.com/claude-sonnet-5-5>
- Claude Haiku 5.5: <https://www.anthropic.com/claude-haiku-5-5>
- Claude Fable and Mythos 5.1: <https://www.anthropic.com/claude-fable-and-mythos-5-1>
- *Harness design for long-running apps* (March 2026): <https://www.anthropic.com/engineering/harness-design-long-running-apps>
- *Inverse Scaling in Test-Time Compute*: <https://alignment.anthropic.com/2025/inverse-scaling>

Independent benchmarks and tests:

- Artificial Analysis, Claude Opus 5.5 (September 2026): <https://artificialanalysis.ai/articles/claude-opus-5-5>
- The New Stack, *Claude Opus 5.5 vs. Fable 5.1* (September 2026): <https://thenewstack.io/claude-opus-5-5-vs-fable-5-1/>
- CodeRabbit, *Claude Opus 5.5 for code review* (September 2026): <https://www.coderabbit.ai/blog/opus-5-5-model-review>
- Factory Review Benchmark (April 2026): <https://docs.factory.com/benchmarks/review-benchmark>
- Latitude, *Reasoning effort only matters without tests* (July 2026): <https://latitude.so/blog/reasoning-effort-only-matters-without-tests>
- Aider, architect/editor mode (2024): <https://aider.chat/2024/09/26/architect.html>
- Decagon, *Optimizing GEPA for production* (March 2026): <https://decagon.ai/blog/optimizing-gepa-for-production>

Research:

- Plan-and-Act (ICML 2025): <https://arxiv.org/abs/2503.09572>
- JudgeBench: <https://arxiv.org/abs/2410.12784>
- SWR-Bench (preprint): <https://arxiv.org/abs/2509.01494>
- Ambig-SWE: <https://arxiv.org/abs/2502.13069>
- *From Confident Closing to Silent Failure: Characterizing False Success in LLM Agents* (preprint, 2026): <https://arxiv.org/abs/2606.09863>
- ACE, *Agentic Context Engineering*: <https://arxiv.org/abs/2510.04618>
- Darwin Gödel Machine: <https://arxiv.org/abs/2505.22954>
- ADAS, *Automated Design of Agentic Systems*: <https://arxiv.org/abs/2408.08435>
- Shao et al., *Your Agent May Misevolve* (ICLR 2026): <https://mlanthology.org/iclr/2026/shao2026iclr-your/>
