# Models and effort per role

Which model and effort each role runs on, the evidence behind each choice, and how a project picks them for its own agents. Researched in October 2026 for Claude Fable 5.1, Opus 5.5, Sonnet 5.5 and Haiku 5.5 (sources at the end). Effort scales are calibrated per model, so every new model is a reason to re-check this page; the optimizer's practice scan flags new models.

## The short answer

| Role | Model · effort | Confidence | Main evidence |
|---|---|---|---|
| spec | opus · high | medium | unverifiable work whose errors flow into every later stage; runs once per ticket, so the strong model is cheap |
| plan | opus · high | medium | a stronger architect gives an architect/editor pair a higher ceiling (Aider); the planner was under 0.4% of a long run's cost (Anthropic) |
| implement | sonnet · medium, **fix rounds at high** | medium | Anthropic's Sonnet 5.5 guidance names this case: medium for well-specified agentic coding, high for harder work; re-running failures at high beat running everything at high (Anthropic) |
| review | fable · high | medium for the tier and effort; **open** between Fable and Opus | a judge needs a frontier model; the published evidence leans towards Opus 5.5 matching Fable 5.1 at lower cost, so trial T1 replays `opus · high` before any switch |
| verify | sonnet · **medium** (was low) | low (canary C1) | Anthropic's Sonnet 5.5 guidance starts multistep tool use at medium; lower effort makes fewer tool calls; the coverage summary needs judgment |
| learn | opus · high | medium | ACE needs "a reasonably strong Reflector"; a small reflector left a prompt unchanged where frontier ones improved it (Decagon) |
| optimize | fable · xhigh | medium | Anthropic positions Fable for hours-long sessions and deep research, and xhigh for agentic work over 30 minutes; it runs at onboarding and every ~10 runs |

Confidence: **high** would mean measurements on these models and this kind of work; **medium** means Anthropic's guidance for these models plus indirect evidence; **low** means a reasoned call from guidance, shipped as a canary. Nothing here reaches high.

### What "proven" means here

No published study measures model tiers across a pipeline shaped like this one. The evidence comes in four kinds, from most to least weight:

1. Anthropic's own measurements and documentation for these exact models.
2. Independent benchmarks of these models.
3. Peer-reviewed papers and preprints on the same kind of work, mostly with earlier models.
4. Practitioner tests with small samples.

Anthropic's own advice is to tune effort on your own evals rather than carry settings over from an earlier model. Singularity can do that: replay-evals for review, canaries for everything else (see [Open trials](#open-trials)).

## The models (October 2026)

| Model | Alias | $ per MTok in · out | Speed | Anthropic's positioning | Default effort in Claude Code |
|---|---|---|---|---|---|
| Fable 5.1 | `fable` | 10 · 50 | slower | highest capability: "agent sessions that run for hours, multistep deep research, analysis carried through to a finished document" | high |
| Opus 5.5 | `opus` | 4 · 20 | moderate | "Most workloads start with Claude Opus 5.5": complex agentic coding, large refactors | medium |
| Sonnet 5.5 | `sonnet` | 2 · 10 | fast | everyday coding, agentic tool use; "complements Opus 5.5 best when running at lower effort settings" | medium |
| Haiku 5.5 | `haiku` | from 0.10 · 0.50 | fastest | classification, extraction, summaries, subagent work; "Sonnet 5.5 and Opus 5.5 remain better choices for complex agentic coding" | medium |

- **Opus 5.5 is at Fable 5.1's level on coding, for less.** In Anthropic's launch table Opus 5.5 scored higher on Terminal-Bench 4.0 (66.4% vs 55.8%), FrontierCode (54.4% vs 50.3%) and CursorBench (57.8% vs 51.8%). On a SWE-bench Pro subset it solved 92.8% at its default effort for $0.22 per solved task, against Fable 5.1's 92.3% at its default for $1.19. Fable 5.1 uses fewer tokens per task (about 78k vs 119k output tokens at max, Artificial Analysis), so the real price gap is smaller than the 2.5× per-token gap.
- **Aliases differ by provider.** On Amazon Bedrock and Google Cloud, `sonnet` resolves to Sonnet 4.5 and `haiku` to Haiku 4.5; on Microsoft Foundry, `opus` resolves to Opus 4.6. There the implementer and verifier silently run an older generation. Check with `/model`, and if your provider offers the newer model, bind the role to a project agent with the full model ID.
- **Blocked models fall back.** If an org's allowlist blocks a family alias, Claude Code uses the newest allowed version of that family; anything else falls back to the session's model. The run digest records the model each role actually ran on.
- **Effort names mean different things per model.** Claude Code's docs: "The effort scale is calibrated per model, so the same level name does not represent the same underlying value across models." Opus 5.5 also defaults one level lower than Opus 5 did. Always set `effort` explicitly.

## What effort does, and where it stops paying

Effort controls every output token: thinking, tool calls and text. It is a behavioural signal, not a hard budget. At lower effort the model makes fewer tool calls and checks less.

| Finding | Evidence |
|---|---|
| Gains are steep up to medium or high, then flatten | Opus 5.5 on SWE-bench Pro, against high: medium about 2.5 points lower for ~70% of the cost, low about 8 points lower for ~⅓, xhigh about 1.4 points higher for 2.5× the cost (Anthropic) |
| `max` can be worse, not just costlier | Sonnet 5.5 scored 46.2% at max vs 52.1% at xhigh on FrontierCode. At max it more often ran Claude Code's code-review skill, and in two cases Cognition examined this caused a timeout or out-of-scope edits (Anthropic). Claude Code's docs call max "prone to overthinking". Longer reasoning lowered accuracy on several task types in *Inverse Scaling in Test-Time Compute* |
| Mechanical checks make effort matter less | Opus 5 on six multi-file bug fixes with the failing tests visible: 18/18 at every level, and max cost 1.9× low per solve. With the tests hidden: 0/13 at low, 8/13 at max (Latitude, 155 runs; the hidden-test tier is a single task, and the visible tier may be at its ceiling) |
| Escalate on failure instead of raising the baseline | Opus 5.5 on SWE-bench Pro: low, then failures re-run at high, about 97.0% at $0.17 per task; high for everything, 95.3% at $0.29 (Anthropic) |
| Try lower effort before a cheaper model | "Tuning effort is often a better lever than switching models" (Anthropic). Opus 5.5 at low solved 87.4% of the SWE-bench Pro subset at $0.12 per solved task, against the older Sonnet 5's 77.4% at $0.84. Orchestrator and worker splits saved nothing on work one model could handle: the same model at lower effort was cheaper every time |
| More effort does not reliably improve review | CodeRabbit, Opus 5.5 in its review pipeline: "Turning up effort did not consistently produce a better review" (80 open-source bug patterns). Claude Code's `/code-review`: "At `low`, the review reports the findings it's most confident in … From `medium` through `max`, the review broadens coverage" |

Rule of thumb: effort buys depth where nothing checks the output. Where tests, exit codes or a later stage check it, buy effort on retries.

## Role by role

### spec · opus · high

The work: turn a ticket into testable acceptance criteria and surface what's missing. Only the human gate checks it, and a gap here flows into the plan, the code and the tests.

- Models often miss that a coding task is underspecified, and asking clarifying questions improved results by up to 74% (Ambig-SWE).
- Claude Code puts work "where verification matters or edge cases are likely" at `high`.
- It runs once per ticket, so the strong model costs little.
- Not Fable: the task is short rather than long-horizon, and Opus 5.5 "performs at the level of Claude Fable 5.1 on most work".

When to deviate: a project with mostly trivial tickets could trial `opus · medium` and watch the spec gate-edit rate.

### plan · opus · high

The work: read the codebase and design small, verifiable steps. This is the architect in an architect/editor split.

- In Aider's 2024 benchmark, o1-preview as architect with a cheaper editor scored up to 85.0%, against 79.7% working alone. A weaker architect lifted its editor too (o1-mini from 61.1% alone to 71.4%), but the pair stayed well below the strong model alone: the architect's strength sets how high the pair gets.
- In Plan-and-Act (ICML 2025), dynamic replanning added about 10 points, and the authors suggest the bottleneck "may lie more in plan quality". Singularity covers replanning with the implementer's "stop and report if the plan is wrong".
- In Anthropic's long-running app harness, the planner cost $0.46 of a $124.70 run. High effort on the plan is cheap insurance.
- Not xhigh: Anthropic documents xhigh for runs over 30 minutes, and on SWE-bench Pro it bought 1.4 points for 2.5× the cost.

### implement · sonnet · medium, fix rounds at high

The work: follow an approved plan test-first. It is well specified and scoped, and checked by tests, then review, then verification.

- Anthropic's Sonnet 5.5 guidance: "For agentic coding and multistep tool use, start with `medium` for well-specified tasks and move to `high` for harder or longer ones." Claude Code: medium fits "day-to-day engineering work with a clear scope, such as implementing a new feature"; high fits "fixing a bug in an existing codebase".
- With failing tests to run, the effort level didn't change the solve rate in Latitude's test (Opus 5, small sample).
- A precise plan brings a cheaper editor close to a strong model working alone (Aider).
- **Fix rounds run at high.** A blocking finding or a failed verification is the reliable failure signal that makes escalation pay, and fixing it is bug-fixing, which Claude Code puts at high. `/singularity:feature` passes `effort: high` to the implement role for fix rounds unless the project config sets the role's effort.
- Not Haiku: Haiku 5.5 scored 39.2% on Terminal-Bench 4.0 against Sonnet 5.5's 70.6%, and Anthropic recommends Sonnet or Opus for complex agentic coding.
- Open question: Opus 5.5 at `low` may match Sonnet 5.5 at `medium` on quality and cost (trial T2). Sonnet stays the default because it is faster and Anthropic's guidance describes this work directly.

A watch-out no model choice removes: models take shortcuts to get green. In The New Stack's comparison, Fable 5.1 deleted a simulated slow call from the application code so a flaky test always passed, in all five runs; Opus 5.5 left the code alone and pointed at the test. The correctness lens and the spec's acceptance criteria are the guard.

### review · fable · high

The work: find defects in a diff by reading it, through one lens, from a fresh context; and challenge other reviewers' findings. It is the main quality gate, and escaped defects are the ground-truth metric. It is also the most frequent strong-model call: one per lens plus one per finding.

The tier and the effort are well supported:

- Judging is hard even for strong models: on difficult response pairs, strong judges such as GPT-4o did "just slightly better than random guessing" (JudgeBench). The challenger has to be as strong as the finder, because a wrong rejection becomes an escaped defect.
- Effort high: Claude Code puts work "where verification matters or edge cases are likely" at high, and more effort did not reliably improve review (CodeRabbit). Lower effort narrows coverage to the most confident findings (Claude Code's `/code-review`); here the challenger already provides precision, so the finders should cover broadly.

Fable 5.1 against Opus 5.5 is open, and the evidence leans towards Opus:

- Opus 5.5 beat Fable 5.1 on every agentic coding benchmark in Anthropic's launch table, and matched it on SWE-bench Pro for about a fifth of the cost per solved task.
- In the one independent head-to-head close to this work (finding and fixing three race conditions without running code, five runs at max effort), Fable 5.1 went 5/5 and Opus 5.5 3/5. Both Opus misses ran out of the 128k output limit; the author concludes that "Opus 5.5 matches Fable 5.1 on accuracy when it finishes" (The New Stack). At `high` the limit is less likely to bite.
- On code-review benchmarks the top frontier models land within about 4 points of each other, and price doesn't track quality: the second most expensive of 13 models scored near the bottom (Factory). Aggregating several review passes raised F1 by up to 43.7% (SWR-Bench), so savings spent on extra passes may buy more than a stronger single pass.

Verdict: keep Fable 5.1 until replay-evals show `opus · high` holds recall and precision, holdout cases included. Singularity doesn't switch the quality gate without a replay, and T1 is the first trial to run. Opus 5.5 is 2.5× cheaper per token but tends to use more tokens, so measure the cost in the trial too. If Fable isn't enabled for your org, use `roles.review: { model: opus, effort: high }`.

### verify · sonnet · medium

The work has two parts. First, run install, build, lint, typecheck, tests and the verify hook, and report each result with evidence. Second, map every acceptance criterion to the tests that cover its happy path, boundaries and failure modes. The first part is mechanical; the second needs judgment, and its summary is the first thing the human reads.

This is the weakest-evidenced change in this page, shipped as canary C1:

- For it: Anthropic's Sonnet 5.5 guidance starts "agentic coding and multistep tool use" at `medium`, and puts `low` with chat and latency-sensitive work. At lower effort the model makes fewer tool calls, and the verifier exists to not skip checks. Anthropic's Haiku 5.5 guidance makes the risk explicit for that model: at low, "in long agent prompts, the model is more likely to skip a search, stop early, or skip a check".
- Against it: Anthropic's general effort table lists `low` for "simpler tasks that need the best speed and lowest costs, such as subagents".
- Cost: one or two runs per pipeline run, mostly input tokens from logs, so the downside is small.

What matters more than effort: agents often claim success that didn't happen. In single-control τ²-bench domains, 45–48% of failures were confident false successes, and LLM judges mostly failed to detect them because they keyed on surface completion cues rather than verified state (2026 preprint). Pass/fail must come from exit codes and evidence lines, which the verifier's table already requires.

Not Haiku: on terminal work Haiku 5.5 trails Sonnet 5.5 by about 30 points (39.2% vs 70.6% on Terminal-Bench 4.0).

### learn · opus · high

The work: decide which lessons to add, merge or retire, and turn misses into eval cases. Its output loads into every future session, so a bad lesson costs on every run.

- ACE's authors list "a reasonably strong Reflector" as a requirement; without it the playbook "may become noisy or even harmful". Monolithic rewrites caused context collapse that dropped accuracy below the no-adaptation baseline.
- In one production task at Decagon (GEPA), a GPT-4o-mini reflector left the prompt "essentially unchanged". GPT-4.1, GPT-5.2, Claude Sonnet and Claude Opus reflectors each improved it by about 5–6%, and the reflector was 5–10% of the optimization cost.
- Memory that evolves can degrade safety (*Your Agent May Misevolve*, ICLR 2026), which is why lessons are reviewed in the PR/MR.
- Decagon's result suggests a Sonnet-class reflector could be enough. The learner runs once per run, so the saving would be small next to the risk. Opus stays.

### optimize · fable · xhigh

The work: a survey of the whole codebase at onboarding; then, every ~10 runs, hours of evidence analysis, a web practice scan, falsifiable proposals, their implementation, and upstream reports on the plugin.

- This is the work Anthropic positions Fable for. Its Fable 5.1 guidance is to step up to xhigh or max "for the most capability-sensitive agentic and coding work", and it documents xhigh for agentic tasks over 30 minutes.
- Meta-agents in the self-improvement literature are frontier models (Darwin Gödel Machine, ADAS), and a small reflector produced no change (Decagon). The optimizer runs rarely, so its cost is a small share of the total.
- Not max: Claude Code's docs say max "may show diminishing returns and is prone to overthinking", and the few published comparisons show no gain over xhigh.
- Without Fable, use `opus · xhigh`. Opus 5.5 scored above Fable 5.1 on Anthropic's knowledge-work benchmarks in the Opus 5.5 launch table (GDPval-AA v2.1: 1846 vs 1735 Elo), so this is a close second, not a big downgrade.

### Helper calls inside workflows

| Call | Model · effort | Why it fits |
|---|---|---|
| optimize-scan: list eval cases | sonnet · low | listing and counting files |
| optimize-scan: other evidence streams | session model; medium, or high for failures and the practice scan | analysis, on the strong session model |
| replay-evals: judge | sonnet · low | a reference-guided match ("same root cause as this known defect?"), which is much easier than open judging. It is a grader (tier 3): changing it breaks comparison with past baselines, so change it only by hand, after checking it against a few human labels |

## Choosing model and effort for a custom agent

This applies to any project agent in `.claude/agents/`: one bound to a role, added as an extra reviewer, or run as a stage. Describe the work it delivers, pick the model and the effort from the tables, then check the rules that override them.

### 1. Describe the work

| Question | Raise the model when… | Raise the effort when… |
|---|---|---|
| How open-ended is it? | it must decide what to do: design, judge, diagnose | the right answer isn't obvious from its inputs |
| What checks its output? | nothing checks it before it matters | there's no test, exit code or schema, and no human sees each result |
| How long does it run? | it works for hours unattended | it runs for over ~30 minutes with many steps |
| Who depends on its output? | many later stages, or every future run | an error would propagate silently |
| Does it judge another model's work? | always: a judge is never weaker than what it judges | yes |
| How often does it run? | rarely, so quality is cheap | (frequent calls: keep effort as low as quality allows) |

### 2. Pick the model

| The agent mostly… | Model | Examples |
|---|---|---|
| extracts, classifies, routes, lists, reads config, or searches where a later step re-checks the result | `haiku` | config readers, file finders, log triage, ticket labelling |
| executes well-specified work that something checks: follows a plan, writes code against tests, runs commands and reports, writes docs from a spec | `sonnet` | platform implementer, migration executor, contract-test runner, release-notes writer |
| judges, designs or diagnoses: specs, plans, reviews, root causes, curation; anything unverifiable or high-impact | `opus` | domain reviewer, architecture-rule checker, performance investigator, threat modeller |
| runs for hours on research-heavy or open-ended problems, or Opus at xhigh still falls short on your evals | `fable` | optimizer-style meta work, deep investigations |

### 3. Pick the effort

| Effort | Use when | Avoid when |
|---|---|---|
| `low` | the task is short and mechanical, and code or a later stage checks the output | the prompt is long with many required checks |
| `medium` | the scope is clear and tests or exit codes check the result; the starting point for Sonnet and Haiku agentic work | nothing checks the output |
| `high` | judgment, edge cases, no mechanical check: reviewers, challengers, specs, plans, bug fixes, retries after a failure | calls are high-volume and a check exists |
| `xhigh` | unattended runs of over ~30 minutes that are rare and high-leverage | the task is short or frequent: on Opus 5.5 it cost 2.5× high for ~1.4 points |
| `max` | your evals show a gain | as a default: diminishing returns, overthinking, out-of-scope edits |

### 4. Rules that override the tables

1. **Try lower effort before a cheaper model.** Anthropic found tuning effort "often a better lever than switching models".
2. **Escalate on retry.** Run first attempts at the cheapest level that usually works and re-run failures one or two levels higher. This needs a reliable failure signal, such as a failing test or a blocking finding.
3. **A judge is never weaker than what it judges.** Reviewers and challengers stay on opus or fable at high.
4. **Make pass/fail mechanical.** Read exit codes and require evidence lines; don't trust a model's "tests passed". For any agent that runs checks, this matters more than the model tier.
5. **Always set `effort`.** Without it the agent runs at the model's default (medium on Opus 5.5, high on Fable 5.1), which changes when the model does.
6. **Never default to `max`.**
7. **On Bedrock, Google Cloud or Foundry, check what each alias resolves to** before relying on a tier.

### 5. Prove it on your project

The tables give a starting point; the project's evals decide. Use the same mechanisms as the optimizer:

- **Reviewers:** add the agent to a `replay-evals` variant against the project's eval cases and compare recall and precision, holdout cases included.
- **Everything else:** ship it as a canary with baseline metrics (first-pass verification, review rounds, gate edit rate, escaped defects, seconds and tokens per stage) and a check-after point, recorded in `optimizations.md`.

The run digest records the model each role ran on, so the optimizer can compare before and after.

### Examples

| Custom agent | Model · effort | Why |
|---|---|---|
| `android-implementer`, bound to implement | sonnet · medium | a well-specified plan that tests check; fix rounds get high from the pipeline |
| `review-domain`, an extra reviewer for domain rules | opus · high | judges code with no mechanical check, and a miss escapes |
| security reviewer for a payments or auth service | opus · high, or fable · high if replay-evals show it catches more | read-only bug finding where a miss is costly; compare the two with replay-evals |
| `after_implement` stage that runs a contract-test suite and reports | sonnet · medium, or haiku · medium if it only reports exit codes | mechanical, and exit codes check it |
| `before_handoff` stage that writes release notes from the diff and spec | sonnet · low | short, and a human reads it in the PR/MR |
| dependency-upgrade executor following a written runbook | sonnet · medium | scoped, and tests check it; re-run failures at high |
| codebase search helper for other agents | haiku · low | the caller re-reads what it finds |
| performance investigator that profiles, forms hypotheses and proposes fixes | opus · high | diagnosis without a single right answer |

## Open trials

Contracts for the next optimizer run or a manual trial. C1 and C2 ship with this change as canaries; T1–T3 are proposals.

| # | Change | Prediction | Counter-metric | Validation |
|---|---|---|---|---|
| C1 | verify: sonnet · low → medium | fewer coverage gaps found later by review or humans; first-pass verification unchanged | seconds and tokens per verify stage | canary: check after 10 runs on the release that ships it |
| C2 | implement fix rounds at high | fewer second fix rounds, and fewer stops with blockers left after two rounds | tokens per fix round | canary: check after 10 runs on the release that ships it |
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
