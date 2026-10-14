---
name: feature
description: Run the team's end-to-end pipeline for a ticket (spec, plan, implement, review, verify, learn) with human approval gates. Use only when the user runs /singularity:feature or explicitly asks for the singularity pipeline.
argument-hint: <ticket id, URL or description | next> [no-gates]
disable-model-invocation: true
---

# Feature pipeline

You are the orchestrator. You don't write the spec, plan or code yourself. You delegate each stage to the agent bound to that **role**, and stages hand work to each other **through files** in the work directory, not through your summaries.

Request: $ARGUMENTS

## 0. Resolve the project setup

The pipeline is the same for a feature, a defect report, a QA issue or a refactoring recommendation: the roles adapt (a defect spec starts with the reproduction, and the plan starts with the failing test). Tell the spec role which kind it is.

The project config `.claude/singularity.md` is normally in your context through CLAUDE.md; if not, read it. If it doesn't exist, stop and tell the user to run `/singularity:init-project`.

**Role bindings.** For each role, use `roles.<role>.agent` from the config, or the default:

| role | default agent |
|---|---|
| spec | singularity:spec-writer |
| plan | singularity:planner |
| implement | singularity:implementer |
| review | singularity:reviewer |
| verify | singularity:verifier |
| learn | singularity:learner |
| optimize | singularity:optimizer |

When spawning a role's agent, pass `model` and `effort` **only** if the config sets them for that role. Otherwise leave them out, so the shared defaults in the agent definitions apply.

One exception: **fix rounds** of the implement role (blocking review findings in step 4, verification failures in step 5) pass `effort: high`, unless the config sets `roles.implement.effort`. Re-running a failure at higher effort costs less than raising the effort of every first attempt.

**Unattended runs.** A scheduled or headless run, where nobody can answer a question, is unattended. `no-gates` only skips the two approval gates; on its own it doesn't make a run unattended.

**Project stages.** `stages.after_plan`, `stages.after_implement` and `stages.before_handoff` list project agents. Run them one at a time, in list order, giving each the work dir path and the stage it follows. If one reports a blocking problem, show it to the user and ask whether to fix it (for example with an implement fix round) and run that agent again, continue anyway, or stop early (step 5). In unattended runs, stop early.

**Ticket.** Use the singularity `tracker` skill:

- If the request is `next` (or empty), `next()` picks the ticket. Trackers without a queue don't support it: ask the user which ticket to take. `next` only starts new work; it never resumes a task.
- Then `get(ticket)`. A ticket waiting to be started (`todo`, or a tracker without that state) gets `move(ticket, in_progress)`. For the files tracker this move is a claim. If another session took the task first, run `next()` again (when the request was `next`) or tell the user (when they named the task).
- A ticket the user named that is already `in_progress`, `blocked` or `in_review` was started before, by this or another session. Show its status and the last lines of its log or comments, and ask whether to **resume** it, because another session may still be working on it. Only on a yes: `move(ticket, in_progress)` (the files tracker checks it is still in one of those states), `comment(ticket, "Resumed")`, then continue as described under **Resuming**. In unattended runs, don't resume: report the ticket's state and stop.
- A ticket that is `done`: tell the user and stop, unless they ask to reopen it.
- If `tracker.type` is `none` or the request is plain text, use the text as the ticket.

**Work dir.** The `<slug>` is the ticket ID in lower case, a hyphen, and a short kebab-case name (for task files, the task's own slug), for example `t7-fix-login`; a plain-text request gets just the name. Create `<work_dir>/<slug>/` (default `.agentic/work`). With the files tracker, `comment(ticket, "Started: <work dir path>")`. Note the start time with `date -u +%FT%TZ`.

Keep a **run record** in `<work_dir>/<slug>/run.json`, and write it after every stage and gate, so a run that crashes can be resumed and still learned from. The learner turns it into the digest the optimizer works from, so record facts, not impressions:

- each stage as it finishes (`spec`, `plan`, `implement`, `review`, `verify`, `handoff`, `learn`), and each gate the user approves;
- the branch, and the PR/MR once one is opened, so that the human review can be learned from later;
- for each stage, its duration (`date` before and after) and its tokens if the agent result reports them;
- the model each role actually ran on;
- `plugin_version`: the `version` in `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`. If `${CLAUDE_PLUGIN_ROOT}` is not inside Claude Code's plugins directory (a path containing `/plugins/cache/` or `/plugins/marketplaces/`), the plugin is a `--plugin-dir` checkout that may hold unreleased changes: append `+dev`;
- whether the user edited the spec or plan at the gates, and what kind of edit it was;
- review rounds, and every confirmed and rejected finding (lens, severity, location, one-line problem);
- whether verification passed first time.

**Resuming.** If a work dir for this ticket already exists (`<work_dir>/<ticket id in lower case>-*/`), continue in it instead of starting over:

- Read its `run.json` and continue from the first stage not marked done. Without a `run.json` (a run from before 0.4.0), infer the stage from the files: no `spec.md` → step 1; no `plan.md` → step 2; unchecked steps in `plan.md` → step 3, with only those steps; no `review.md` → step 4; no `summary.md` → step 5.
- Tell the user which stage you are resuming from. A gate that `run.json` doesn't record as approved is shown again before going past it.
- Keep the existing `spec.draft.md` and `plan.draft.md`: the learner compares them with the final versions.

## 1. Spec (gate)

Spawn the **spec** role with the ticket text and output path `spec.md`. Copy the result to `spec.draft.md`.
Show the user the acceptance criteria and open questions, then **stop for approval**. Apply their answers to `spec.md`.

## 2. Plan (gate)

Spawn the **plan** role with the spec path and output path `plan.md`. Copy the result to `plan.draft.md`.
Show the approach, steps and risks, then **stop for approval**.
Then run the `stages.after_plan` agents (see **Project stages**).

Skip both gates only when the arguments contain `no-gates` or the user said so.

## 3. Implement

Create or switch to the branch named by `conventions.branch`. Spawn the **implement** role with the spec and plan paths.
Then run the `stages.after_implement` agents.

## 4. Review

The **review** role reviews the change from a fresh context, once per lens and once per project reviewer, and a second reviewer challenges every finding before it counts. You run these agents yourself, in parallel; there is no separate review command.

- **Lenses**: `review.lenses` (default: correctness, security, maintainability, testability), then `review.extra_lenses` with their descriptions. The shared lenses are: **correctness**, logic, edge cases, error handling, test quality; **security**, injection, authz, secrets, unsafe input, sensitive data; **maintainability**, consistency with existing patterns, naming, duplication, complexity; **testability**, hardcoded values, non-injectable dependencies, non-deterministic or broad-assertion tests, obsolete tests left behind, missing boundary and failure-mode tests, untested contract changes.
- **Base**: the branch point, the merge base of the branch with `conventions.default_branch`.

1. **Review.** In one batch, spawn the review role once per lens: `Task A: review through the "<lens>" lens (<description>). Base: <base>. The spec is at <spec path>.` Spawn each agent in `review.extra_reviewers` alongside them, on its own model and effort: `Review the current change (base: <base>) according to your instructions. The spec is at <spec path>. Report only findings you can support with evidence.` Each returns findings with severity (`blocking`, `should-fix` or `nit`), location, problem, evidence and fix. Re-run any reviewer that fails or returns no answer before going on: a missing lens is not a clean review.
2. **Challenge.** In one batch, spawn the review role once per finding: `Task B: challenge this finding from the "<lens or reviewer>" reviewer. Base: <base>.`, followed by the finding's location, claimed severity, problem, evidence and proposed fix. Each returns whether the finding is confirmed, the corrected severity and the reason. A finding counts only if it is confirmed, at the challenger's severity. Re-run a challenger that fails; if it fails again, keep the finding at its claimed severity and mark it **unverified** in `review.md`.

Write `review.md`: confirmed and unverified findings deduplicated and sorted by severity, then the rejected ones with the reason. Rejected findings are a learning signal, so keep them.

If there are **blocking** findings, spawn **implement** as a fix round with only those findings, then review and challenge again through only the lenses and reviewers that raised them. At most 2 rounds; if blockers remain after that, stop early (below).

## 5. Verify

Spawn the **verify** role with the spec path; its report includes the Test Coverage and Verification Summary, which goes first in `summary.md`. On FAIL, send the failures to **implement** once as a fix round, then verify again. If it still fails, stop early (below).
Then run the `stages.before_handoff` agents.

**Stopping early.** When the pipeline stops on remaining blockers or failed verification, `move(ticket, blocked)` and `comment` with the reason and the path to the work dir, then report to the user.

## 6. Hand-off

Write `summary.md`: what changed, verification evidence, open non-blocking findings, follow-ups.

- Commit only if `conventions.auto_commit` is true, using the project's commit convention.
- Open a draft PR/MR (tracker skill `open_change`, then `link`) only if `conventions.auto_pr` is true or the user asks. Then `move(ticket, in_review)` and `comment` with the link, and record the PR/MR in `run.json`.
- With the files tracker and no PR/MR, `move(ticket, in_review)` and `comment` with the path to `summary.md` (and the commit, if you committed). Task files have no merge event to close them: ask the user whether to `move(ticket, done)`. In unattended runs, leave the task in review.

## 7. Learn

Skip this step if `learning.enabled` is false. Otherwise spawn the **learn** role once, with:

- this run: the work dir path and its `run.json`. For a run resumed from before 0.4.0, which has no `run.json`, rebuild the record from the files: the spec and plan drafts against the final versions, the rounds in `review.md` with their confirmed and rejected findings, and the verifier's result in `summary.md`;
- the **human reviews** of earlier runs that have finished since they were last learned from (see **Learning from human reviews** below).

It updates the project's experience files and eval cases. Tell the user which lessons it added or changed. They are part of the diff, so the team reviews them in the PR/MR like code.

## 8. Optimization check

Skip this step if `optimization.every_runs` is 0. Otherwise check whether the **optimize** role is due:

- **onboarding**, if `optimizations.md` has no onboarding entry (`O-…-onboard`);
- **an optimization**, if `runs.jsonl` has at least `optimization.every_runs` (default 10) `"type":"run"` lines dated after the last entry in `optimizations.md`;
- **upstream reports to file**, if `.claude/singularity/upstream/` on the default branch holds reports whose status is still `draft`: the team has approved them by merging.

If one is due, say so in your report. Unless the run is unattended, offer to start it now. On yes, spawn the optimize role with `onboard`, `optimize` or `file upstream reports`. Whenever it returns a **Decision needed** block, show it to the user and start the role again with their answer, until it reports that it's done.

Finish with a short report to the user: result, verification, open findings, lessons learned, and the PR/MR link if one was opened.

## Learning from human reviews

What human reviewers catch that the agents missed is the most valuable signal the pipeline gets, so every run collects it from the runs before it. Skip this if `code_host.type` is `none`.

1. **Find finished reviews.** Take the `"type":"run"` lines in `runs.jsonl` from the last 90 days that have a `branch` and no `"type":"human_review"` line with the same `slug`. Look at most 10 of them up, oldest first, with the tracker skill's `find_change(branch)`, and keep at most 3 that are merged or closed. A PR/MR that is still open isn't finished: leave it for a later run.
2. **Skip what was learned elsewhere.** Another branch may already have learned from a change and not be merged yet. Skip a change whose ref is in a `human_review` line on any branch: `git grep -l '"ref":"<ref>"' $(git for-each-ref --format='%(refname)' refs/heads refs/remotes) -- <learning.dir>/runs.jsonl`.
3. **Collect the comments.** For each, `review_comments(change)`, and save them to `<work_dir>/<slug>/human-review.md` (create the directory if it's gone), with file:line, the point made, and the commit each comment was made on. Leave out reviewer names.
4. **Fetch the reviewed code.** A merged branch is often deleted, and after a merge the reviewed commits are already on the default branch, so get them from the PR/MR itself: `git fetch origin pull/<n>/head` on GitHub, `git fetch origin merge-requests/<iid>/head` on GitLab. The **base** of the change is the merge base of the reviewed commit with the PR/MR's base commit from `find_change`, not with the default branch as it is now (`git merge-base <base commit> <reviewed commit>`).
5. **Hand them to the learner** in step 7, with each change's ref, its run's `slug`, the base and the reviewed commits. Ask it to decide which comments are real defects the agents missed (escaped defects), to record lessons, to append one `human_review` line per change with that `slug` and ref, and to create a regression eval case for each escaped defect. A change with no review comments still gets its `human_review` line, with an empty `escaped` list.
