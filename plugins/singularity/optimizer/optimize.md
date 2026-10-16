# Optimize: lead feature delivery towards its best

The optimizer's slow loop: read all runs the learn job recorded for failures, waste and fit to the goals (`goals.md`); change the harness accordingly; prove each change helps. Nothing merges without a human.

## 0. Set up

- **Settings**: `optimization.every_runs`, `web_scan` and `max_eval_cost_usd` from `.claude/singularity.md` (defaults 10, true, 10).
- **Run directory**: `<work_dir>/optimizer-<YYYY-MM-DD>-optimize/` (agent definition, "State lives in files").
- **Branch and worktree**: `singularity/optimize-<YYYY-MM-DD>` from the default branch, in `<run dir>/worktree` (agent definition, "Your own worktree"); all changes in steps 2 to 7 go there.
- **Sources**: goals (`.claude/singularity/goals.md`), the record (`learning.dir`, default `.claude/singularity/experience`), guidelines (`.claude/singularity/guidelines/`, `.claude/rules/singularity/`), the work dir, `.claude/singularity/evals/`.
- **Focus**: extra words in the request (e.g. "review false positives") narrow evidence and proposals.

## 1. Evidence

Session: run the `singularity:optimize-scan` workflow with
`{ sources: [{ name, experienceDir, workDir, evalsDir }] (absolute paths), focus, webScan: <web_scan>, today: <YYYY-MM-DD>, pluginRoot: "<plugin root>" }`.

Subagent: do what `<plugin root>/workflows/optimize-scan.js` does: one read-only subagent per stream in its `streams` list, in parallel, with the stream's prompt plus the `common` text, at its `effort` (and `model`, if set), returning JSON matching its schema. `web_scan` false -> skip the `practice` stream.

Guideline audit reports lesson files from before 0.5.0 -> migrate them (`onboard.md`, "Migrating lessons"), then re-gather the evidence.

Save the result as `evidence.json`, and a digest as `evidence.md` opening with a **health dashboard**, each metric with its trend: **quality** (escaped defects, blocking findings, first-pass verification, stop-gate blocks, changes merged without human edits, changes later fixed or reverted, open findings people addressed per lens), **flow** (lead time, share working vs waiting, rework, stopped runs, tokens and cost per run, **user interventions** per run by kind and stage), **value** (each KPI in `goals.md` against its target: current reading where its "measured by" is a read-only command or file, else the team's last recorded value; effort split across goals, defects and maintenance; where quality problems hit what users rely on). Name failed streams; don't fill their gaps by guessing.

## 2. Propose

Read the goals, evidence pack, `optimizations.md`, config, the context files and project agents the evidence points at, and the plugin files (`<plugin root>`) behind plugin-side failures.

1. Due contracts: recommend keep, extend or revert, with numbers.
2. Write `proposals.md`: at most 5 project changes, ranked by harm to the goals and their users, times frequency (agent definition, principle 2). Count flow waste too: waiting at gates or for human review, rework loops, costly stages that catch little here, process heavier than the work needs, effort serving no goal. **Interventions**: the same kind of decision reaching the team in several runs (`interventions`, `decisions` in run lines) with consistent answers -> a guideline settling it (tier 1); a gate stop research could have settled -> fix the role or skill that escalated it; the same topic researched again across runs -> a guideline recording the answer (tier 1), so later runs read it instead of searching. Each gives:
   - id (`O-<date>-<n>`), title, tier, goal served;
   - the contract fields; a diff sketch (file and exact lines);
   - the validation plan, with an eval cost estimate.
3. Context and guideline audits, per guideline: stale or wrong -> tier-1 proposal (`onboard.md`, "Refreshing the context"); enforceable by a check -> propose the check; keeps failing (its category recurs after an add or change, or `runs.jsonl` keeps classing defects and corrections `guideline-ignored` against it, `covered_by` or `cites`) -> replace with a check, don't reword again; missing -> add only for a defect or user correction it is the root cause of (`learn.md`), never on your own judgement. A `pending` category recurring without learn-job action -> tier-1 proposal.
   - **Lifecycle** (the guideline audit's counts per id): work that applied or cited it still failed -> correct it; in an always-loaded file (`CLAUDE.md`, `project.md`), never applied, cited or matched by a defect, and the files it names unchanged for 90 days -> move it to a path-scoped rule. Never remove a still-true guideline for disuse alone: it may be what prevents its defect.
   - **Weak tests** (later fixes or human edits adding the test that was missing, tests passing on wrong behaviour) recurring -> propose a mutation-testing check on changed lines in `verify.sh` (tier 2).
   - **Review precision**: a lens whose open findings people rarely address (`addressed` in `human_review` lines) -> narrow its description or make it advisory (tier 2); a blocking lens stays blocking unless a human decides (tier 3).
4. Plugin-side failure -> draft an upstream report (`upstream.md`); list it in `proposals.md` with any local workaround and the run refs behind its evidence.
5. Learn-job `proposals` and `proposed_checks` recurring across recent runs (guideline audit) are evidence -> a proposal with a contract, or a reason in the rejected list.
6. Goals look outdated (most effort on something no goal names, or a goal without work in months) -> recommend a `goals.md` change for the team (tier 3).
7. End with a short "considered and rejected" list.

## 3. Challenge

Each tier-2 proposal and upstream report, with its cited evidence -> `singularity:reviewer`, **Task C**. Attach verdicts to `proposals.md`. Drop what gets **reject** unless evidence answers the objection.

## 4. Gate

Evidence decides; the draft PR/MR is where the team reviews (the `autonomy` skill). Implement every tier-1 proposal and every tier-2 one whose replay passes within `max_eval_cost_usd`, without asking. What evidence can't settle goes to a person, all at once: **canaries** (behaviour changes no replay can validate) and **tier 3** recommendations. Session with a person: show those in a compact table (id, tier, change, predicted effect, validation and its estimated cost, challenger verdict), plus due contracts and upstream reports awaiting filing (`upstream.md`, "Deliver and file"), and ask which canaries to start. Subagent or unattended: list them in `proposals.md` and the PR/MR for a person to choose; start none. Never tier 3.

## 5. Implement

In the worktree, each approved proposal is **one commit** (`singularity-optimize: O-… <title>`) with only the described change; one that adds, changes or removes guidelines also appends a curation line to `runs.jsonl`, `ref` = its id (format in `learn.md`). Append each to `optimizations.md` as `validating`, in that file's header format, wrapped at 80 columns (projects markdownlint it).

## 6. Validate (tier 2)

Follow each proposal's validation plan:

- **Review behaviour** (lenses, extra reviewers, review model or effort): replay the project's eval cases.
  - Read each `.claude/singularity/evals/<id>/case.md`; pass its frontmatter fields plus the **absolute** path of its `change.patch`.
  - Two variants, `baseline` (current config) and `candidate` (proposed config), **both** given their full lens list and reviewer binding: only the proposed change differs.
  - `trials` of at least 3 per variant: the reviewer isn't deterministic; one trial can't tell a change from chance.
  - Session: the `singularity:replay-evals` workflow. Subagent: do what `<plugin root>/workflows/replay-evals.js` does: per variant, case, lens and trial, the variant's reviewer in its own worktree (`isolation: "worktree"`, or a `git worktree add --detach` under the run directory, removed afterwards) with the same setup and Task A prompt; a `sonnet` judge at `low` effort with the same judging prompt; the workflow's scoring.
  - Report non-holdout and holdout results separately, with the estimated and actual cost; replays beyond `max_eval_cost_usd` need the user's yes.
- **Not replayable** (spec, plan or implement behaviour, a project stage, the implementer's model) -> **canary**: record baseline metrics and the check-after point. Judge it by whether its targeted defects and corrections stopped and anything clearly got worse (ten runs show breakage, not small gains).

- **Guideline admission** (review guidelines): guidelines in `review.md`, or rules the reviewers load, that learn jobs added since the last optimization for a defect that has an eval case -> replay that case and the non-holdout cases with and without the guideline (two variants, same trials). Not better on its own case, or worse on another -> tier-1 proposal to rewrite or remove it. Counts toward `max_eval_cost_usd`.

Adopt only if, in most trials, it gets right cases the baseline gets wrong in most trials, and gets no case worse, holdout included. One or two cases, or cases flipping between trials (`flaky`), are noise. Not adopted -> `git revert` its commit; record `rejected` with numbers, plus `insufficient evidence` if that is why (retry once there are more cases).

## 7. Contracts and archive

Entries with status `canary`, `validating` or `adopted` whose check is due:

1. Compare the prediction with the eval results and the pipeline's mechanical records (review rounds, fix rounds, first-pass verification, escaped defects from human reviews, times, tokens). Use the categories, `covered_by` and `goal` labels your learn job assigned only to explain, never to judge a contract. Note `plugin_version` or model changes between baseline and check. Workaround waiting on a plugin fix -> count only release runs (`plugin_version` without `+dev`).
2. Set status `adopted`, `extended` or `revert-proposed`, with numbers; before keeping or extending a behaviour change, have `singularity:reviewer` (Task C) challenge the verdict and numbers.
3. Failed contract -> write the revert as a proposal.

Follow up filed upstream reports (`upstream.md`). Every proposal from this run, rejected ones included, gets its final status in `optimizations.md`.

## 8. Deliver

Push the branch, open a **draft** PR/MR titled "singularity: workflow optimization <date>" with the tracker skill's `open_change`, then remove the worktree (`git worktree remove <run dir>/worktree`; the branch stays). Include: dashboard, adopted and rejected proposals with numbers, tier-3 recommendations, upstream reports with the run refs behind their evidence, contract due dates.

Tell the user, briefly: what changed, and the measured effect; what was rejected and why; what needs a human decision, including upstream reports to file once the PR/MR merges; when to run the optimizer next.
