---
name: feature
description: Run the team's end-to-end pipeline for a ticket (spec, plan, implement, review, verify, learn) with human approval gates. Use only when the user runs /singularity:feature or explicitly asks for the singularity pipeline.
argument-hint: <ticket id, URL or description> [no-gates]
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

**Ticket.** Use the singularity `tracker` skill: `get(ticket)`, then `move(ticket, in_progress)`. If `tracker.type` is `none` or the request is plain text, use the text as the ticket.

**Work dir.** Pick a kebab-case `<slug>` that includes the ticket ID if there is one. Create `<work_dir>/<slug>/` (default `.agentic/work`). Note the start time with `date -u +%FT%TZ`.

Keep a **run record** as you go. The learner turns it into the digest the optimizer works from, so record facts, not impressions:

- for each stage, its duration (`date` before and after) and its tokens if the agent result reports them;
- the model each role actually ran on;
- `plugin_version`: the `version` in `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`. If `${CLAUDE_PLUGIN_ROOT}` is not inside Claude Code's plugins directory (a path containing `/plugins/cache/` or `/plugins/marketplaces/`), the plugin is a `--plugin-dir` checkout that may hold unreleased changes: append `+dev`;
- whether the user edited the spec or plan at the gates, and what kind of edit it was;
- review rounds, and every confirmed and rejected finding (lens, severity, location, one-line problem);
- whether verification passed first time.

## 1. Spec (gate)

Spawn the **spec** role with the ticket text and output path `spec.md`. Copy the result to `spec.draft.md`.
Show the user the acceptance criteria and open questions, then **stop for approval**. Apply their answers to `spec.md`.

## 2. Plan (gate)

Spawn the **plan** role with the spec path and output path `plan.md`. Copy the result to `plan.draft.md`.
Show the approach, steps and risks, then **stop for approval**.
Then run each agent in `stages.after_plan`, giving it the work dir. If one reports a blocking problem, return to the user.

Skip both gates only when the arguments contain `no-gates` or the user said so.

## 3. Implement

Create or switch to the branch named by `conventions.branch`. Spawn the **implement** role with the spec and plan paths.
Then run each agent in `stages.after_implement`.

## 4. Review

Run the `singularity:deep-review` workflow (Workflow tool) with args:
`{ base: <branch point>, spec: <spec path>, lenses: <review.lenses + review.extra_lenses with descriptions>, extraReviewers: <review.extra_reviewers>, reviewer: <roles.review if set> }`.
If workflows are unavailable, spawn the **review** role once per lens and each extra reviewer in parallel instead. If the result lists `failed` reviewers, re-run those before going on: a missing lens is not a clean review.

Write `review.md`: confirmed findings deduplicated and sorted by severity, then the rejected ones with the reason. Rejected findings are a learning signal, so keep them.

If there are **blocking** findings, spawn **implement** as a fix round with only those findings, then re-review only the lenses that raised them. At most 2 rounds; if blockers remain after that, stop and report to the user.

## 5. Verify

Spawn the **verify** role; its report includes the Test Coverage and Verification Summary, which goes first in `summary.md`. On FAIL, send the failures to **implement** once as a fix round, then verify again. If it still fails, stop and report.
Then run each agent in `stages.before_handoff`.

## 6. Hand-off

Write `summary.md`: what changed, verification evidence, open non-blocking findings, follow-ups.

- Commit only if `conventions.auto_commit` is true, using the project's commit convention.
- Open a draft PR/MR (tracker skill `open_change`, then `link`) only if `conventions.auto_pr` is true or the user asks. Then `move(ticket, in_review)` and `comment` with the link.

## 7. Learn

If `learning.enabled` isn't false, spawn the **learn** role with the work dir path and the run record. It updates the project's experience files. Tell the user which lessons it added or changed. They are part of the diff, so the team reviews them in the PR/MR like code.

## 8. Optimization check

Count the `"type":"run"` lines in `runs.jsonl` dated after the last entry in `optimizations.md`. If there are at least `optimization.every_runs` (default 10), tell the user it is time to run `/singularity:optimize`.

Finish with a short report to the user: result, verification, open findings, lessons learned, and the PR/MR link if one was opened.
