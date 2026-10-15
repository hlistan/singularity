# Experience

The record of this project's learning loop: the defects and user corrections
behind every guideline change, and what the optimizer tried. The optimizer
analyses it. The agents doing the work don't read it: they follow the current
guidelines in `../guidelines/` and `.claude/rules/singularity/`, which say how
to do things now rather than what went wrong before.

- `runs.jsonl`: one digest line per pipeline run, per user correction and per
  human review, each defect and correction with its root cause, and the
  guidelines each one added, changed or removed.
- `optimizations.md`: the optimizer's archive.
- `upstream.md`: guideline candidates for every project, with evidence.

The corrections themselves wait in `<work_dir>/corrections/`, which is never
committed, until the learn job has turned them into guidelines or dropped
them.
