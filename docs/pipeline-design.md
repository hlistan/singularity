# Pipeline design: autonomy, checks, review, sizing and isolation

Why `/singularity:feature` works this way, beyond roles and models (`docs/models-and-effort.md`) and learning (`docs/self-optimization.md`). Researched October 2026; mostly practitioner evidence.

## Autonomy: decide by evidence, ask only what only people know

- The `autonomy` skill (spec writer, planner, implementer, optimizer): find the answer cheapest first: request, goals, guidelines, config; the code and git history; earlier decisions in the record; the web (official docs first, the versions in use, at most 5 searches and 5 fetches per decision).
- Default: decide and record one line per decision, with its grounding and the option rejected. Escalate only intent only the team knows, a one-way door with no proven winner (public contract, data model or migration, new external service, security or privacy posture), or a hard line (goals constraint, "Do not touch", data leaving the system, spending money, deleting data). Each escalation carries options, evidence and a recommendation; work continues on it.
- One **design gate** after the plan, shown only for decisions needed (`gates.design: auto`; `always` and `never` too), replacing the spec and plan gates. The hand-off report lists every decision taken, for review after the fact. Small asks became automatic: resuming a run this checkout started, re-running a blocked project stage after a fix round, migrating old lesson files, starting a due optimization.
- Interventions (each stop for a person) and decisions are recorded per run. Answers at the gate that hold beyond the ticket become guidelines; topics researched in several runs become guideline proposals.

| Finding | Source | In singularity |
|---|---|---|
| Asking about intent (expected behaviour) raised resolve rates on underspecified tasks by up to 74%; asking about file locations barely helped a strong model, which finds code itself; models rarely ask unless prompted | Vijayvargiya et al., *Ambig-SWE* (CMU, 2026) | Escalate intent only; never ask what the repository answers |
| Detecting gaps once, up front, beat asking mid-task, with fewer questions on simple tasks | Edwards & Schuster, *Ask or Assume?* (EMNLP 2026) | Gaps settled in the spec; escalations collect at one gate |
| In 35% of the times Claude Code stopped itself, it asked the user to choose between approaches | Anthropic, *Measuring AI agent autonomy in practice* (February 2026) | Choices between approaches researched and decided, recorded |
| Devin asks for plan approval only when its confidence isn't high; Factory approves a spec once, then sets autonomy by reversibility; Copilot coding agent puts one human gate at the end, each change traceable to its session | Cognition, *Devin 2.1* (2025); Factory, *Specification mode*; GitHub, *Copilot coding agent* docs | `gates.design: auto`; decisions in the spec, plan and hand-off report |
| Decide two-way doors fast and one-way doors carefully; the auto-mode classifier's blocks centre on blast radius (destroying or exfiltrating data, weakening security, affecting others) | Amazon, *2015 letter to shareholders*; Anthropic, *How we built Claude Code auto mode* (March 2026) | The escalation list: one-way doors and hard lines |
| Unguided research agents chose SEO content farms until told to prefer primary sources; fact-finding needs about 3-10 tool calls | Anthropic, *How we built our multi-agent research system* (June 2025) | Official sources first; per-decision search budget |
| Models solve about half of tasks tied to specific library versions | Misra et al., *GitChameleon 2.0* (2025) | Research against the versions in the lockfile |
| Reusing earlier plans cut cost about 50% at 96.6% of performance | *Agentic Plan Caching* (NeurIPS 2025) | Earlier decisions read before researching; repeated research becomes a guideline |

## A library selected per project

- Library agents live with the shared agents (`agents/`); library skills in `library/skills/`, read by an agent only when the project's `skills` map gives them. Onboarding matches the catalog's signals against its survey; each selection is a canary.

| Finding | Source | In singularity |
|---|---|---|
| Every registered skill's name and description loads into each session, within 1% of the context; past it, descriptions are dropped | Claude Code docs, *Skills* | Library skills aren't registered: no cost where unused |
| With 1,000 irrelevant skills listed, agents loaded the relevant one 27.4% of the time instead of 73.6%; choosing skills explicitly up front kept 73.9% | Liu, Chen, Zhang, *Lost in Implicit Routing* (preprint, October 2026) | Skills chosen per role at onboarding and named in the agent's prompt |
| Curated skills helped (+16.2 points on average, +4.5 in software engineering); 16 of 84 tasks got worse; self-written skills added about nothing; focused beat comprehensive | *SkillsBench* (preprint, 2026) | Narrow, human-curated entries; each selection measured as a canary |
| 26.1% of 31,000 marketplace skills had a vulnerability; skills bundling scripts were 2.12× riskier | Liu et al., *Agent Skills in the Wild* (preprint, 2026) | Library skills hold Markdown only (`scripts/check-library.js`) |

## Mechanical checks before judgement

- `scripts/run-checks.sh` runs build, lint, type check and tests; exit code = pass/fail.
- `SubagentStop` hook (`scripts/subagent-stop.sh`): keeps the implementer working while checks fail, up to `checks.stop_retries` attempts; checks then rerun as a stage before review.
- Baseline failures (recorded before implementing): reported, not blocking; else implementers chase failures not their own.

| Finding | Source | In singularity |
|---|---|---|
| Claude "stops when the work looks done" and "tended to mark a feature as complete without proper testing"; a `SubagentStop` hook that exits 2 "prevents the subagent from stopping" | Claude Code docs, *Best practices* and *Hooks*; Anthropic, *Effective harnesses for long-running agents* (November 2025) | Stop gate, own retry limit (none documented); gate and checks stage decide success |
| 45–48% of single-control τ²-bench failures were false successes, mostly missed by LLM judges | *From Confident Closing to Silent Failure* (preprint, 2026) | Verifier reports exit codes, not its reading |
| "Success is silent, and only failures produce verbose output"; verification is worth "2-3x the quality", more deterministic with a Stop hook | HumanLayer, *Skill issue* (March 2026); B. Cherny, Claude Code team (January 2026) | `run-checks.sh`: one line on success, failure tails otherwise |
| ~Half of test-passing SWE-bench Verified PRs wouldn't be merged by maintainers | METR (March 2026) | Review and acceptance-criteria mapping still follow |

## Tests the agent can't quietly change

- The implementer freezes each test once it fails for the right reason (`scripts/test-guard.sh freeze`); a `PreToolUse` hook then blocks edits to it.
- `test-guard.sh check` → blocking findings (challenged as usual): frozen tests changed; existing tests changed or deleted that the plan doesn't name.
- Wrong test → implementer stops, reports.

| Finding | Source | In singularity |
|---|---|---|
| Frontier models cheat on 50–76% of tasks whose tests contradict the spec; an explicit abort option cut cheating sharply, retry loops raised it, read-only tests didn't stop special-casing; "It is unacceptable to remove or edit tests" | *ImpossibleBench* (ICLR 2026); Anthropic, *Effective harnesses for long-running agents* | Hook-enforced frozen tests, a check for edits by other means, "stop and report" as a good outcome |
| TDD instructions alone raised regressions on small open models (9.94% vs 6.08%); showing affected tests cut them | *TDAD* (preprint, 2026) | Test-first, backed by checks and test guard |

## Review: correctness and security block, the rest advise

- Block: `review.blocking_lenses` (default correctness, security) and project reviewers; a challenger tests each blocking finding; the fix round first reproduces it with a failing test.
- Advise: maintainability, testability; cheaper model; unchallenged.
- Reviewers read one whole-change diff (`scripts/change-diff.sh`). Reason: `git diff` omits untracked files; the implementer commits only with `auto_commit` on.

| Finding | Source | In singularity |
|---|---|---|
| Anthropic's Code Review filters false positives and targets correctness, "not formatting preferences or missing test coverage"; 79% of one AI reviewer's comments were nits; correct but low-value comments "may provide net negative value" | Anthropic, *Code Review* (March 2026); Uber, *uReview* (2025); Greptile (2024); Google, *AutoCommenter* (2024) | `review.blocking_lenses` default; advisory lenses: at most should-fix, never stop a run |
| Reviewer + critic scored below one reviewer (F1 0.457 vs 0.495); ten reviewers endorsed a nonexistent vulnerability only a test refuted | *Adversarial Review* (preprint, 2026); *Refute-or-Promote* (preprint, 2026) | Challenger may answer `uncertain`; no failing test where one should be possible → finding rejected |
| Aggregating repeated review runs raised recall 118.8% and F1 43.7% | *SWR-Bench* (FSE 2026) | `large`: second, independent correctness pass |
| No surveyed production reviewer pairs strongest-model lenses with a strongest-model challenger per finding; cheap graders beside strong finders are common | Survey of Anthropic, Cursor, Uber, Atlassian, GitHub, Factory write-ups | Advisory lenses on Sonnet; challengers only for blocking findings |

## The process fits the change

- `small` (one-sentence change, few files, off the risk list): short spec, no plan stage, correctness review; the design gate only for decisions needed. `large`: everything plus the second correctness pass.

| Finding | Source | In singularity |
|---|---|---|
| "If you could describe the diff in one sentence, skip the plan" | Claude Code docs, *Best practices* | `small` skips the plan |
| A spec-driven tool turned a small bug into 4 user stories and 16 acceptance criteria; Spec Kit took ~10× longer than iterative prompting on one task (agent time plus review), no quality gain seen; tools need "different core workflows, for different sizes and types of changes" | B. Böckeler, martinfowler.com (October 2025); C. Eberhardt, Scott Logic (November 2025) | Three sizes; orchestrator picks, or `small` / `full` |

## One run per checkout

- A run locks its work dir; it won't start beside another run or on uncommitted work not its own.
- Parallel runs: own worktrees. The files tracker claims tasks in the main checkout's task folder, atomic across worktrees.

| Finding | Source | In singularity |
|---|---|---|
| `claude --worktree <name>` (`-w`) starts a session in its own worktree under `.claude/worktrees/` | Claude Code docs, *Worktrees* | Lock message points to `claude --worktree` |

## The command guard is a seatbelt

- `scripts/guard-bash.sh` blocks force-pushes to protected branches, skipping git hooks, recursive deletes of `/` or home, and stopping processes by name (`pkill`, `killall`). Shell-style splitting: quoting doesn't evade it, commit messages don't trip it. An aid against mistakes, not enforcement.

| Finding | Source | In singularity |
|---|---|---|
| "Bash permission patterns that try to constrain command arguments are fragile"; enforce via sandbox; inspect full commands in a `PreToolUse` hook | Claude Code docs, *Permissions* | Guard is a `PreToolUse` hook; README and `init-project` point to code-host branch protection and sandboxing; plugins can't ship permission rules or sandbox settings |

## Sources

- Vijayvargiya et al., *Interactive agents to overcome ambiguity in software engineering* (Ambig-SWE, 2026): <https://arxiv.org/abs/2502.13069>
- Edwards & Schuster, *Ask or Assume?* (EMNLP 2026): <https://arxiv.org/abs/2603.26233>
- Anthropic, *Measuring AI agent autonomy in practice* (February 2026): <https://www.anthropic.com/research/measuring-agent-autonomy>
- Cognition, *Devin 2.1* (May 2025): <https://cognition.com/blog/devin-2-1>
- Factory, *Specification mode*: <https://docs.factory.com/cli/user-guides/specification-mode>
- GitHub, *Responsible use of Copilot coding agent*: <https://docs.github.com/en/copilot/responsible-use/copilot-coding-agent>
- Amazon, *2015 letter to shareholders* (April 2016): <https://www.sec.gov/Archives/edgar/data/1018724/000119312516530910/d168744dex991.htm>
- Anthropic, *How we built Claude Code auto mode* (March 2026): <https://www.anthropic.com/engineering/claude-code-auto-mode>
- Anthropic, *How we built our multi-agent research system* (June 2025): <https://www.anthropic.com/engineering/multi-agent-research-system>
- Misra et al., *GitChameleon 2.0* (2025): <https://arxiv.org/abs/2507.12367>
- *Agentic Plan Caching* (NeurIPS 2025): <https://arxiv.org/abs/2506.14852>
- Claude Code docs, *Skills*: <https://code.claude.com/docs/en/skills>
- Liu, Chen, Zhang, *Lost in Implicit Routing* (October 2026): <https://arxiv.org/abs/2610.18522>
- *SkillsBench* (2026): <https://arxiv.org/abs/2602.12670>
- Liu et al., *Agent Skills in the Wild* (2026): <https://arxiv.org/abs/2601.10338>
- Claude Code docs: *Best practices* <https://code.claude.com/docs/en/best-practices>; *Hooks* <https://code.claude.com/docs/en/hooks>; *Permissions* <https://code.claude.com/docs/en/permissions>; *Worktrees* <https://code.claude.com/docs/en/worktrees>; *Code Review* <https://code.claude.com/docs/en/code-review>
- Anthropic, *Effective harnesses for long-running agents* (November 2025): <https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents>
- Anthropic, *Code Review* announcement (March 2026): <https://claude.com/blog/code-review>
- HumanLayer, *Skill issue* (March 2026): <https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents>
- B. Cherny, thread on Claude Code practices (January 2026): <https://threadreaderapp.com/scrolly/2007179832300581177>
- METR, on SWE-bench-passing PRs maintainers would not merge (March 2026): <https://metr.org/notes/2026-03-10-many-swe-bench-passing-prs-would-not-be-merged-into-main/>
- *From Confident Closing to Silent Failure: Characterizing False Success in LLM Agents* (2026): <https://arxiv.org/abs/2606.09863>
- *ImpossibleBench* (ICLR 2026): <https://arxiv.org/abs/2510.20270>
- *TDAD* (2026): <https://arxiv.org/abs/2603.17973>
- Uber, *uReview* (2025): <https://www.uber.com/blog/ureview/>
- Greptile, on cutting AI-review nits (December 2024): <https://www.greptile.com/blog/make-llms-shut-up>
- Google, AutoCommenter (2024): <https://arxiv.org/abs/2405.13565>
- *Adversarial Review* (2026): <https://arxiv.org/abs/2608.18167>; *Refute-or-Promote* (2026): <https://arxiv.org/abs/2604.19049>
- *SWR-Bench* (FSE 2026): <https://arxiv.org/abs/2509.01494>
- B. Böckeler, martinfowler.com, on three spec-driven tools (October 2025): <https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html>
- C. Eberhardt, Scott Logic, Spec Kit on a real task (November 2025): <https://blog.scottlogic.com/2025/11/26/putting-spec-kit-through-its-paces-radical-idea-or-reinvented-waterfall.html>
