---
name: learn
description: Run the fast learning loop. Learn from a finished singularity run, or from human review comments on a PR/MR, into project lessons, run digests and regression eval cases. Use when the user runs /singularity:learn or asks the agents to learn from a review or a run.
argument-hint: <run slug | PR/MR number or URL>
---

# Learn

Argument: $ARGUMENTS

The project config is in context through CLAUDE.md (read `.claude/singularity.md` if it isn't). The learn role is `roles.learn.agent` (default `singularity:learner`); pass `model` and `effort` only if the config sets them.

To review trends or change how the agents work, use `/singularity:optimize`. This command only records experience.

## A run slug (`<work_dir>/<slug>/`)

Spawn the learn role with that work dir. Rebuild the run record from the files there: spec/plan drafts vs final versions, review.md rounds with confirmed and rejected findings, and the verifier result in summary.md.

## A PR/MR number or URL

This is the most valuable signal: what **human** reviewers caught that the agents didn't.

1. Use the singularity `tracker` skill's `review_comments(change)` on the code host.
2. Save the comments to `<work_dir>/<slug>/human-review.md`, with file:line, the point made, and the commit each comment was made on. Leave out reviewer names. Use the run's slug if the branch matches one, otherwise `pr-<n>`.
3. Spawn the learn role with that file, the PR/MR's base commit and the reviewed commit. Ask it to:
   - decide which comments are real defects the agents missed (escaped defects);
   - record lessons;
   - append a `human_review` digest line;
   - create a regression eval case for each escaped defect.
