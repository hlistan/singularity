---
name: optimize
description: Run the workflow optimizer. It analyses evidence from past runs, proposes evidence-backed changes to agents, models, lenses, protocol and experience, validates them against eval cases, and delivers them as a PR/MR. Use when the user runs /singularity:optimize or asks to improve or tune the agent workflow.
argument-hint: "[project|shared] [focus ...] [unattended]"
disable-model-invocation: true
---

# Optimize the workflow

Arguments: $ARGUMENTS

You orchestrate. The **optimize** role does the thinking: `roles.optimize.agent` from the config, default `singularity:optimizer`. Pass `model` and `effort` only if the config sets them. Everything you produce goes into one run directory and one branch, and nothing merges without a human.

## 0. Set up

- **Scope.** Use `shared` if the argument says so, or if the current repo is the singularity repo (it has `plugins/singularity/`). Otherwise use `project`.
- **Settings.** In project scope, read the `optimization` settings (`every_runs`, `web_scan`, `max_eval_cost_usd`) from `.claude/singularity.md`. In shared scope, use the defaults (10, true, 10).
- **Run directory.**
  - project: `<work_dir>/optimize-<YYYY-MM-DD>/`;
  - shared: `optimizer/runs/<YYYY-MM-DD>/`.
- **Branch.** Create `singularity/optimize-<YYYY-MM-DD>` from the default branch.
- **Sources.**
  - project: this repo, with its `learning.dir`, `work_dir` and `.claude/singularity/evals/`.
  - shared: every repo in `optimizer/projects.yaml` (git-ignored; copy `optimizer/projects.example.yaml`). Shallow, sparse-clone each one's `.claude/singularity/` into `<run dir>/sources/<name>`, for example `git clone --depth 1 --filter=blob:none --sparse <repo> <dir> && git -C <dir> sparse-checkout set .claude/singularity`. Skip any you can't access, and say so.
- **Unattended.** If `unattended` is in the arguments, or this is a scheduled or headless run, there are no gates (see step 4).

## 1. Evidence

Run the `singularity:optimize-scan` workflow (Workflow tool) with these args:
`{ scope, sources: [{ name, experienceDir, workDir, evalsDir }] (absolute paths), focus, webScan: <web_scan>, today: <YYYY-MM-DD>, pluginRoot: "${CLAUDE_PLUGIN_ROOT}" }`.

Save the result as `evidence.json`. Also write `evidence.md`, a readable digest that starts with a **health dashboard**: the metric trends and whether each is getting better or worse. If workflows are unavailable, spawn the same analyses as parallel subagents.

## 2. Propose

Spawn the optimize role in mode **propose**, with the evidence path, the scope, the focus and the run directory. It writes `proposals.md`.

## 3. Challenge

For each tier-2 proposal, spawn `singularity:reviewer` with **Task C**, giving it the proposal and the evidence it cites. Attach each verdict to `proposals.md`. Drop proposals that get **reject**, unless the optimizer answers the objection with evidence.

## 4. Gate

Show the user a compact table: id, tier, change, predicted effect, validation and its estimated cost, challenger verdict. Add any contracts that are due. Ask which proposals to implement. Present tier 3 as recommendations only; a human makes those changes.

Unattended: implement every tier-1 proposal, plus each tier-2 proposal whose validation fits within `max_eval_cost_usd`. Never tier 3.

## 5. Implement

Spawn the optimize role in mode **implement** with the approved ids. It makes one commit per proposal.

## 6. Validate (tier 2)

Follow each proposal's validation plan:

- **Review behaviour** (lenses, reviewer model or effort, review agents): run the `singularity:replay-evals` workflow on the project's eval cases.
  - Read each `.claude/singularity/evals/<id>/case.md` and pass its frontmatter fields, plus the **absolute** path of its `change.patch`.
  - Run two variants, `baseline` (the current config) and `candidate` (the proposed config). Give **both** their full lens list and reviewer binding, so the only difference between them is the proposed change.
  - Report non-holdout and holdout results separately.
- **Shared plugin changes** (agents, skills, workflows in the singularity repo): run the plugin's eval suite on the candidate branch and on the default branch, then compare case by case. Use a worktree for the default branch: `git worktree add <run dir>/baseline <default>`.
  - Command: `claude plugin eval <plugin dir> --scaffold --trust-plugin --allow-tools "Bash(git *)" "Bash(gh *)" "Bash(glab *)" --json <run dir>/eval-<arm>.json --no-publish --max-cost-usd <budget>`.
  - `--trust-plugin` is acceptable because this is the team's own suite.
  - Tell the user the estimated cost before running, unless the run is unattended.
- **Not replayable** (spec, plan or implementer prompts, the implementer's model): ship it as a **canary**. Record the current baseline metrics and the check-after point.

Adopt a proposal only if its target cases improve and nothing else regresses, holdout included. Otherwise `git revert` its commit and record it as `rejected`, with the numbers.

## 7. Contracts and archive

If the evidence lists contracts that are due, spawn the optimize role in mode **check-contracts**. Make sure every proposal from this run is in `optimizations.md` with its final status, including rejected ones. Rejected ideas are knowledge too.

## 8. Hand-off

Push the branch and open a **draft** PR/MR with the tracker skill's `open_change`: in the project repo for project scope, in the singularity repo for shared scope. Title it "singularity: workflow optimization <date>". Include the dashboard, the adopted and rejected proposals with their numbers, the tier-3 recommendations, and when each contract is due.

Tell the user, briefly:

- what changed and the measured effect;
- what was rejected and why;
- what needs a human decision;
- when to run the optimizer next.
