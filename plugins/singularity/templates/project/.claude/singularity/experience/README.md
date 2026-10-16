# Experience

The record of this project's learning loop: the defects and user corrections
behind every guideline change, and what the optimizer tried. The optimizer
analyses it; the working agents don't read it, but follow the current
guidelines in `../guidelines/` and `.claude/rules/singularity/`, which say how
to do things now, not what went wrong before.

- `runs.jsonl`: one digest line per pipeline run, per user correction, per
  later fix or revert of a run's lines and per human review, each defect and
  correction with its root cause, and the guidelines each one added, changed
  or removed.
- `optimizations.md`: the optimizer's archive.
- `upstream.md`: guideline candidates for every project, with evidence.

Pending corrections wait in `<work_dir>/corrections/` (never committed) until
the learn job turns them into guidelines or drops them. Each handed-off change
is kept as the local git ref `refs/singularity/handoff/<slug>`, so later learn
jobs can tell people's edits and fixes from the agents' work.
