# Pipeline design: checks, review, sizing and isolation

Why `/singularity:feature` is shaped the way it is, beyond the roles and models (`docs/models-and-effort.md`) and the learning loop (`docs/self-optimization.md`). Researched in October 2026; sources at the end. Most of the evidence on whole pipelines is practitioner experience rather than controlled studies, and the tables say which is which.

## Mechanical checks before judgement

The pipeline runs the project's build, lint, type check and tests itself (`scripts/run-checks.sh`), and pass or fail is the exit code. A `SubagentStop` hook (`scripts/subagent-stop.sh`) keeps the implementer working while they fail, for at most `checks.stop_retries` attempts, and the checks run again as their own stage before any reviewer is spent on the change. Checks that already failed before the change, recorded as a baseline before implementing, are reported but don't block: without the baseline, a project with one broken suite would send every implementer after a failure that isn't its own. In a live run, the implementer given a check that predated its work stopped and said so, rather than changing files it had been told to leave alone.

| Finding | Source | In singularity |
|---|---|---|
| "Claude stops when the work looks done." The documented escalation runs from a prompt to a Stop hook that "blocks the turn from ending until it passes"; a `SubagentStop` hook that exits 2 "prevents the subagent from stopping" and delivers its message as the subagent's next instruction | Claude Code docs, *Best practices* and *Hooks* | The stop gate on the implementer, with its own retry limit, since none is documented for `SubagentStop` |
| Claude "tended to mark a feature as complete without proper testing" | Anthropic, *Effective harnesses for long-running agents* (November 2025) | The implementer can't declare success; the gate and the checks stage decide |
| In single-control τ²-bench domains, 45–48% of failures were false successes, and LLM judges mostly missed them | *From Confident Closing to Silent Failure* (preprint, 2026) | The verifier reports the scripts' exit codes, never its reading of the output |
| "Success is silent, and only failures produce verbose output"; back-pressure from checks is one of the highest-leverage investments | HumanLayer, *Skill issue* (March 2026) | `run-checks.sh` prints one line on success and the tail of each failure otherwise |
| Verification is "probably the most important thing", worth "2-3x the quality", made more deterministic with a Stop hook | B. Cherny, Claude Code team (January 2026) | Practitioner evidence for the same design |
| About half of the test-passing SWE-bench Verified PRs would not have been merged by maintainers | METR (March 2026) | Passing tests aren't the bar on their own: the review and the verifier's acceptance-criteria mapping still follow |

## Tests the agent can't quietly change

The implementer freezes each test once it fails for the right reason (`scripts/test-guard.sh freeze`). A `PreToolUse` hook then blocks edits to it, and `test-guard.sh check` reports frozen tests changed after freezing, and existing tests changed or deleted without the plan naming them. Those become blocking findings, challenged like any other. When a test turns out to be wrong, the implementer stops and reports.

| Finding | Source | In singularity |
|---|---|---|
| Frontier models cheat on 50–76% of tasks whose tests contradict the spec. Read-only tests stopped test edits but not special-casing, and an explicit option to abort cut cheating sharply; retry loops raised it | *ImpossibleBench* (ICLR 2026) | Frozen tests, plus the check that covers edits made by other means, plus "stop and report" as a good outcome in the implementer's instructions and in the stop gate's message |
| "It is unacceptable to remove or edit tests" | Anthropic, *Effective harnesses for long-running agents* | The same rule, enforced by the hook rather than only stated |
| TDD instructions alone raised regressions (9.94% vs 6.08%) on small open models; showing the agent which tests a change affects cut them | *TDAD* (preprint, 2026) | Test-first stays, but backed by checks and the test guard rather than by instructions |

## Review: correctness and security block, the rest advise

Lenses in `review.blocking_lenses` (default correctness and security) and project reviewers can block a change; a challenger tests each blocking finding, and the fix round has to reproduce it with a failing test first. Maintainability and testability advise, on a cheaper model, unchallenged. Every reviewer reads the whole change from one diff (`scripts/change-diff.sh`), because `git diff` leaves out files that aren't committed yet, and the implementer doesn't commit unless `auto_commit` is on.

| Finding | Source | In singularity |
|---|---|---|
| Anthropic's Code Review runs several agents in parallel, then a verification step that filters false positives, and focuses on correctness by default, "not formatting preferences or missing test coverage" | Anthropic, *Code Review* (March 2026) | Correctness and security block; blocking findings are challenged |
| Stylistic comments rated poorly at Uber; 79% of one reviewer's comments were nits until it learned from feedback; correct but low-value comments "may provide net negative value" | Uber, *uReview* (2025); Greptile (2024); Google, *AutoCommenter* (2024) | Advisory lenses report at most should-fix and never stop a run |
| A reviewer paired with a critic scored below a single reviewer (F1 0.457 vs 0.495); ten reviewers unanimously endorsed a vulnerability that didn't exist, which only an empirical test refuted | *Adversarial Review* (preprint, 2026); *Refute-or-Promote* (preprint, 2026) | The challenger may answer `uncertain`; the fix round reproduces each blocking finding with a failing test, and one no test can show where a test should be possible is rejected |
| Repeated review runs find different issues; aggregating runs raised recall 118.8% and F1 43.7% | *SWR-Bench* (FSE 2026) | A `large` change gets a second, independent correctness pass |
| No production reviewer found runs the strongest model on every lens plus a strongest-model challenger on every finding; cheap graders next to strong finders are common | Survey of Anthropic, Cursor, Uber, Atlassian, GitHub, Factory write-ups | Advisory lenses on Sonnet; challengers only for blocking findings |

## The process fits the change

The pipeline sizes each change. A `small` one (a change you could describe in one sentence, in a few files, away from the risk list) gets a short spec, one gate, no plan stage and a correctness review. A `large` one gets everything plus the second correctness pass.

| Finding | Source | In singularity |
|---|---|---|
| "Plan mode is useful, but also adds overhead… If you could describe the diff in one sentence, skip the plan" | Claude Code docs, *Best practices* | The `small` path skips the plan |
| A spec-driven tool turned a small bug into four user stories with 16 acceptance criteria; tools should offer "different core workflows, for different sizes and types of changes" | B. Böckeler, martinfowler.com (October 2025) | Three sizes, chosen by the orchestrator or with `small` / `full` |
| Spec Kit took about ten times longer than iterative prompting on the same task (agent time plus review), with no quality gain seen | C. Eberhardt, Scott Logic (November 2025), one task | Practitioner evidence that a full spec and plan don't pay for small changes |

## One run per checkout

A run takes a lock in its work dir and refuses to start next to another run, or on top of uncommitted work that isn't its own. Parallel runs go in their own worktrees. The files tracker claims tasks in the main checkout's task folder, so claims stay atomic across worktrees.

| Finding | Source | In singularity |
|---|---|---|
| `claude --worktree <name>` (or `-w`) starts a session in its own worktree under `.claude/worktrees/`; worktrees "isolate file edits" and are one of several ways to run Claude in parallel | Claude Code docs, *Worktrees* | The lock's message points to `claude --worktree` |

## The command guard is a seatbelt

`scripts/guard-bash.sh` blocks force-pushes to protected branches, skipping git hooks and recursive deletes of `/` or home. It splits commands the way a shell does, so quoting doesn't get past it and commit messages don't trip it. It stays an aid against mistakes.

| Finding | Source | In singularity |
|---|---|---|
| "Bash permission patterns that try to constrain command arguments are fragile." For enforcement that doesn't depend on the command text, use sandboxing; to inspect the full command text with your own logic, use a `PreToolUse` hook | Claude Code docs, *Permissions* | The guard parses the command text in a `PreToolUse` hook; the README and `init-project` point to branch protection on the code host and to the sandbox for enforcement. A plugin can't ship permission rules or sandbox settings |

## Sources

- Claude Code docs: *Best practices* <https://code.claude.com/docs/en/best-practices>; *Hooks* <https://code.claude.com/docs/en/hooks>; *Permissions* <https://code.claude.com/docs/en/permissions>; *Worktrees* <https://code.claude.com/docs/en/worktrees>; *Code Review* <https://code.claude.com/docs/en/code-review>
- Anthropic, *Effective harnesses for long-running agents* (November 2025): <https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents>
- Anthropic, announcement of Code Review (March 2026): <https://claude.com/blog/code-review>
- HumanLayer, on harness engineering for coding agents (March 2026): <https://www.humanlayer.dev/blog/skill-issue-harness-engineering-for-coding-agents>
- B. Cherny, thread on Claude Code practices (January 2026): <https://threadreaderapp.com/scrolly/2007179832300581177>
- METR, note on SWE-bench-passing PRs that maintainers would not merge (March 2026): <https://metr.org/notes/2026-03-10-many-swe-bench-passing-prs-would-not-be-merged-into-main/>
- *From Confident Closing to Silent Failure: Characterizing False Success in LLM Agents* (2026): <https://arxiv.org/abs/2606.09863>
- *ImpossibleBench* (ICLR 2026): <https://arxiv.org/abs/2510.20270>
- *TDAD* (2026): <https://arxiv.org/abs/2603.17973>
- Uber, *uReview* (2025): <https://www.uber.com/blog/ureview/>
- Greptile, on cutting nit comments from AI review (December 2024): <https://www.greptile.com/blog/make-llms-shut-up>
- Google, AutoCommenter (2024): <https://arxiv.org/abs/2405.13565>
- *Adversarial Review* (2026): <https://arxiv.org/abs/2608.18167>; *Refute-or-Promote* (2026): <https://arxiv.org/abs/2604.19049>
- *SWR-Bench* (FSE 2026): <https://arxiv.org/abs/2509.01494>
- B. Böckeler, martinfowler.com, on three spec-driven development tools (October 2025): <https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html>
- C. Eberhardt, Scott Logic, trying Spec Kit on a real task (November 2025): <https://blog.scottlogic.com/2025/11/26/putting-spec-kit-through-its-paces-radical-idea-or-reinvented-waterfall.html>
