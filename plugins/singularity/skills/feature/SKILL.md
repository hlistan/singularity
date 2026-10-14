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

- each stage as it finishes (`spec`, `plan`, `implement`, `review`, `verify`, `handoff`), and each gate the user approves;
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

Run the `singularity:deep-review` workflow (Workflow tool) with args:
`{ base: <branch point>, spec: <spec path>, lenses: <review.lenses (default: correctness, security, maintainability, testability), then review.extra_lenses, with descriptions>, extraReviewers: <review.extra_reviewers>, reviewer: <roles.review if set> }`.
If workflows are unavailable, spawn the **review** role once per lens and each extra reviewer in parallel instead. If the result lists `failed` reviewers, re-run those before going on: a missing lens is not a clean review.

Write `review.md`: confirmed findings deduplicated and sorted by severity, then the rejected ones with the reason. Rejected findings are a learning signal, so keep them.

If there are **blocking** findings, spawn **implement** as a fix round with only those findings, then re-review only the lenses that raised them. At most 2 rounds; if blockers remain after that, stop early (below).

## 5. Verify

Spawn the **verify** role with the spec path; its report includes the Test Coverage and Verification Summary, which goes first in `summary.md`. On FAIL, send the failures to **implement** once as a fix round, then verify again. If it still fails, stop early (below).
Then run the `stages.before_handoff` agents.

**Stopping early.** When the pipeline stops on remaining blockers or failed verification, `move(ticket, blocked)` and `comment` with the reason and the path to the work dir, then report to the user.

## 6. Hand-off

Write `summary.md`: what changed, verification evidence, open non-blocking findings, follow-ups.

- Commit only if `conventions.auto_commit` is true, using the project's commit convention.
- Open a draft PR/MR (tracker skill `open_change`, then `link`) only if `conventions.auto_pr` is true or the user asks. Then `move(ticket, in_review)` and `comment` with the link.
- With the files tracker and no PR/MR, `move(ticket, in_review)` and `comment` with the path to `summary.md` (and the commit, if you committed). Task files have no merge event to close them: ask the user whether to `move(ticket, done)`. In unattended runs, leave the task in review.

## 7. Learn

If `learning.enabled` isn't false, spawn the **learn** role with the work dir path and the run record. It updates the project's experience files. Tell the user which lessons it added or changed. They are part of the diff, so the team reviews them in the PR/MR like code.

## 8. Optimization check

Skip this step if `optimization.every_runs` is 0. Otherwise, count the `"type":"run"` lines in `runs.jsonl` dated after the last entry in `optimizations.md`. If there are at least `optimization.every_runs` (default 10), tell the user it is time to run `/singularity:optimize`.

Finish with a short report to the user: result, verification, open findings, lessons learned, and the PR/MR link if one was opened.
