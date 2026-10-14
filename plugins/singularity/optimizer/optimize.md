# Optimize: lead feature delivery towards its best

The optimizer's playbook for the slow loop. The learner records every run; this loop reads all of them, finds what fails and costs most, changes the harness, and proves that the change helps. Everything a run produces goes into one run directory and one branch, and nothing merges without a human.

## 0. Set up

- **Settings**: `optimization.every_runs`, `web_scan` and `max_eval_cost_usd` from `.claude/singularity.md` (defaults 10, true, 10).
- **Run directory**: `<work_dir>/optimizer-<YYYY-MM-DD>/`.
- **Branch and worktree**: `singularity/optimize-<YYYY-MM-DD>`, from the default branch, checked out in `<run dir>/worktree` (see "Your own worktree" in the agent definition). Every change in steps 2 to 7 is made there.
- **Sources**: `learning.dir` (default `.claude/singularity/experience`), the work dir and `.claude/singularity/evals/`.
- **Focus**: words in the request beyond the job, such as "review false positives", narrow the evidence and the proposals.

## 1. Evidence

As the session, run the `singularity:optimize-scan` workflow with
`{ sources: [{ name, experienceDir, workDir, evalsDir }] (absolute paths), focus, webScan: <web_scan>, today: <YYYY-MM-DD>, pluginRoot: "<plugin root>" }`.

As a subagent, read `<plugin root>/workflows/optimize-scan.js` and do what it does: spawn one read-only subagent per evidence stream in its `streams` list, in parallel, each with that stream's prompt followed by the `common` text, at the stream's `effort` (and `model`, if set), and ask each for JSON that matches the stream's schema. Skip the `practice` stream when `web_scan` is false.

Save the result as `evidence.json`. Also write `evidence.md`, a readable digest that starts with a **health dashboard**: the metric trends and whether each is getting better or worse. Name any stream that failed; don't fill its gap by guessing.

## 2. Propose

Read the evidence pack, `optimizations.md`, the current config, the context files and project agents the evidence points at, and, for failures whose fix belongs in the plugin, the plugin files behind them (`<plugin root>`).

1. For contracts the evidence marks as due, recommend keep, extend or revert, with the numbers.
2. Write `proposals.md`, ranked, with at most 5 project changes. For each, give:
   - an id (`O-<date>-<n>`), a title and its tier;
   - the contract fields;
   - a diff sketch (file and exact lines);
   - the validation plan, with an eval cost estimate.
3. Act on the context audit: stale or missing context is a tier-1 proposal, handled as in `onboard.md` ("Refreshing the context").
4. For each failure whose fix belongs in the plugin, draft an upstream report (`upstream.md`), and list it in `proposals.md` with its local workaround, if any, and the run refs behind its evidence.
5. End with a short "considered and rejected" list.

## 3. Challenge

For each tier-2 proposal and each upstream report, spawn `singularity:reviewer` with **Task C**, giving it the proposal or report and the evidence it cites. Attach each verdict to `proposals.md`. Drop proposals and reports that get **reject**, unless you answer the objection with evidence.

## 4. Gate

Show the user a compact table: id, tier, change, predicted effect, validation and its estimated cost, challenger verdict. Add the contracts that are due, the new upstream reports, and the approved ones waiting to be filed (`upstream.md`, "Deliver and file"). Ask which proposals to implement. Present tier 3 as recommendations only; a human makes those changes.

Unattended: implement every tier-1 proposal, plus each tier-2 proposal whose validation fits within `max_eval_cost_usd`. Never tier 3.

## 5. Implement

In the worktree, on the optimization branch, implement each approved proposal as **one commit** (`singularity-optimize: O-… <title>`) that contains only the described change. Append each to `optimizations.md` with status `validating`, in the format in that file's header and wrapped at 80 columns, since projects lint it with markdownlint.

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

1. Compare the prediction with the actual results in `runs.jsonl` and the eval results. Note any change of `plugin_version` or models between the baseline and the check, since it can explain a difference. For a workaround waiting on a plugin fix, count only runs on a release (`plugin_version` without `+dev`).
2. Set the status to `adopted`, `extended` or `revert-proposed`, and record the numbers.
3. For a failed contract, write the revert as a proposal.

Follow up filed upstream reports as `upstream.md` describes. Make sure every proposal from this run is in `optimizations.md` with its final status, rejected ones included: rejected ideas are knowledge too.

## 8. Deliver

Push the branch and open a **draft** PR/MR with the tracker skill's `open_change`, then remove the worktree (`git worktree remove <run dir>/worktree`); the branch stays. Title it "singularity: workflow optimization <date>". Include the dashboard, the adopted and rejected proposals with their numbers, the tier-3 recommendations, the upstream reports with the run refs behind their evidence, and when each contract is due.

Tell the user, briefly:

- what changed and the measured effect;
- what was rejected and why;
- what needs a human decision, including the upstream reports to file once the PR/MR is merged;
- when the optimizer should run next.
