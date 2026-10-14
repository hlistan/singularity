# Optimize: lead feature delivery towards its best

The optimizer's playbook for the slow loop. The learn job records every run; this loop reads all of them and asks three questions: what fails, where time and effort are wasted, and whether the work serves the project's goals (`goals.md`). It changes the harness where the answers point, and proves that each change helps. Everything a run produces goes into one run directory and one branch, and nothing merges without a human.

## 0. Set up

- **Settings**: `optimization.every_runs`, `web_scan` and `max_eval_cost_usd` from `.claude/singularity.md` (defaults 10, true, 10).
- **Run directory**: `<work_dir>/optimizer-<YYYY-MM-DD>/`.
- **Branch and worktree**: `singularity/optimize-<YYYY-MM-DD>`, from the default branch, checked out in `<run dir>/worktree` (see "Your own worktree" in the agent definition). Every change in steps 2 to 7 is made there.
- **Sources**: the goals in `.claude/singularity/goals.md`, the record in `learning.dir` (default `.claude/singularity/experience`), the guidelines in `.claude/singularity/guidelines/` and `.claude/rules/singularity/`, the work dir and `.claude/singularity/evals/`.
- **Focus**: words in the request beyond the job, such as "review false positives", narrow the evidence and the proposals.

## 1. Evidence

As the session, run the `singularity:optimize-scan` workflow with
`{ sources: [{ name, experienceDir, workDir, evalsDir }] (absolute paths), focus, webScan: <web_scan>, today: <YYYY-MM-DD>, pluginRoot: "<plugin root>" }`.

As a subagent, read `<plugin root>/workflows/optimize-scan.js` and do what it does: spawn one read-only subagent per evidence stream in its `streams` list, in parallel, each with that stream's prompt followed by the `common` text, at the stream's `effort` (and `model`, if set), and ask each for JSON that matches the stream's schema. Skip the `practice` stream when `web_scan` is false.

If the guideline audit reports lesson files from before 0.5.0, migrate them first (`onboard.md`, "Migrating lessons"), then gather the evidence again.

Save the result as `evidence.json`. Also write `evidence.md`, a readable digest that starts with a **health dashboard** in three parts, each metric with its trend and whether it is getting better or worse: **quality** (escaped defects, blocking findings, first-pass verification, changes that later needed a fix), **flow** (lead time, the share of it spent working rather than waiting, rework, runs that stopped, cost per run) and **value** (how the effort splits across the goals, defects and maintenance, and where the quality problems hit what users rely on). Name any stream that failed; don't fill its gap by guessing.

## 2. Propose

Read the goals, the evidence pack, `optimizations.md`, the current config, the context files and project agents the evidence points at, and, for failures whose fix belongs in the plugin, the plugin files behind them (`<plugin root>`).

1. For contracts the evidence marks as due, recommend keep, extend or revert, with the numbers.
2. Write `proposals.md`, ranked by harm to the goals and their users, times frequency (principle 2 in the agent definition), with at most 5 project changes. Look for flow waste as well as failures: time spent waiting at gates or for human review, rework loops, stages that cost much and catch little for this project, process that is heavier than a kind of work needs, and effort going to work that serves no goal. For each, give:
   - an id (`O-<date>-<n>`), a title, its tier and the goal it serves;
   - the contract fields;
   - a diff sketch (file and exact lines);
   - the validation plan, with an eval cost estimate.
3. Act on the context and guideline audits: stale, wrong or missing guidelines are a tier-1 proposal, handled as in `onboard.md` ("Refreshing the context"); a guideline that a check could enforce is a proposal for that check; a guideline that keeps failing (its category recurs after it was added or changed, per `runs.jsonl`) is rewritten or replaced by a check.
4. For each failure whose fix belongs in the plugin, draft an upstream report (`upstream.md`), and list it in `proposals.md` with its local workaround, if any, and the run refs behind its evidence.
5. Weigh the learn job's `proposals` and `proposed_checks` from recent runs (in the guideline audit): one that recurs across runs is evidence; make it a proposal here, with a contract, or say in the rejected list why not.
6. When the evidence says the goals themselves look out of date (most effort goes to something no goal names, or a goal has had no work in months), recommend a change to `goals.md` for the team to make: it is tier 3.
7. End with a short "considered and rejected" list.

## 3. Challenge

For each tier-2 proposal and each upstream report, spawn `singularity:reviewer` with **Task C**, giving it the proposal or report and the evidence it cites. Attach each verdict to `proposals.md`. Drop proposals and reports that get **reject**, unless you answer the objection with evidence.

## 4. Gate

Show the user a compact table: id, tier, change, predicted effect, validation and its estimated cost, challenger verdict. Add the contracts that are due, the new upstream reports, and the approved ones waiting to be filed (`upstream.md`, "Deliver and file"). Ask which proposals to implement. Present tier 3 as recommendations only; a human makes those changes.

Unattended: implement every tier-1 proposal, plus each tier-2 proposal with a replay that passes within `max_eval_cost_usd`. A canary needs a person to choose it, so leave canaries as recommendations. Never tier 3.

## 5. Implement

In the worktree, on the optimization branch, implement each approved proposal as **one commit** (`singularity-optimize: O-… <title>`) that contains only the described change. When a proposal adds, changes or removes guidelines, also append a curation line to `runs.jsonl` with its id as `ref` (format in `learn.md`). Append each to `optimizations.md` with status `validating`, in the format in that file's header and wrapped at 80 columns, since projects lint it with markdownlint.

## 6. Validate (tier 2)

Follow each proposal's validation plan:

- **Review behaviour** (lenses, extra reviewers, the review model or effort): replay the project's eval cases.
  - Read each `.claude/singularity/evals/<id>/case.md`, and pass its frontmatter fields plus the **absolute** path of its `change.patch`.
  - Run two variants, `baseline` (the current config) and `candidate` (the proposed config). Give **both** their full lens list and reviewer binding, so that the only difference between them is the proposed change.
  - As the session, run the `singularity:replay-evals` workflow. As a subagent, do what `<plugin root>/workflows/replay-evals.js` does: for each variant, case and lens, spawn the variant's reviewer in its own worktree (`isolation: "worktree"`, or a `git worktree add --detach` under the run directory that you remove afterwards) with the same setup and Task A prompt; judge its findings with a `sonnet` subagent at `low` effort and the same judging prompt; score as the workflow does.
  - Report non-holdout and holdout results separately. Tell the user the estimated cost before running, unless the run is unattended.
- **Not replayable** (spec, plan or implement behaviour, a project stage, the implementer's model): ship it as a **canary**. Record the current baseline metrics and the check-after point.

Adopt a proposal only if its target cases improve and nothing else regresses, holdout included. Otherwise `git revert` its commit and record it as `rejected`, with the numbers.

## 7. Contracts and archive

For entries with status `canary`, `validating` or `adopted` whose check is due:

1. Compare the prediction with the actual results in the eval results and in what the pipeline records mechanically: review rounds, fix rounds, first-pass verification, escaped defects from human reviews, times and tokens. Don't judge a contract by the categories, `covered_by` or `goal` labels your own learn job assigned; use them only to explain. Note any change of `plugin_version` or models between the baseline and the check, since it can explain a difference. For a workaround waiting on a plugin fix, count only runs on a release (`plugin_version` without `+dev`).
2. Set the status to `adopted`, `extended` or `revert-proposed`, and record the numbers. Before you keep or extend a behaviour change, give the verdict and its numbers to `singularity:reviewer` (Task C), as you do for proposals.
3. For a failed contract, write the revert as a proposal.

Follow up filed upstream reports as `upstream.md` describes. Make sure every proposal from this run is in `optimizations.md` with its final status, rejected ones included: rejected ideas are knowledge too.

## 8. Deliver

Push the branch and open a **draft** PR/MR with the tracker skill's `open_change`, then remove the worktree (`git worktree remove <run dir>/worktree`); the branch stays. Title it "singularity: workflow optimization <date>". Include the dashboard, the adopted and rejected proposals with their numbers, the tier-3 recommendations, the upstream reports with the run refs behind their evidence, and when each contract is due.

Tell the user, briefly:

- what changed and the measured effect;
- what was rejected and why;
- what needs a human decision, including the upstream reports to file once the PR/MR is merged;
- when the optimizer should run next.
