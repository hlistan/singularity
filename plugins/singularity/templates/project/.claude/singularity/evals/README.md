# Project eval cases

Regression cases built from **real** failures on this project. The optimizer
creates them from escaped defects (what human reviewers caught in a PR/MR
that the agents missed) and replays them (`replay-evals` workflow) to prove
that a workflow change helps and breaks nothing.

One directory per case:

```text
<id>/
  case.md        # front matter below, then a short note
  change.patch   # git diff <base> <reviewed commit>:
                 # the change as it was first reviewed
```

```yaml
---
# recall: the reviewer must find it.
# precision: a known false positive it must NOT flag.
kind: recall
lens: security            # the lens expected to catch it
base: <sha on the default branch>
expect: "Endpoint /orders/:id returns other users' orders: no ownership check"
location: src/api/orders.ts:42
# Every 5th case is held out; the optimizer never tunes on these.
holdout: false
source: "!123 human review, 2026-10-14"
---
```

Rules: cases are only ever added. Editing or deleting one is a human decision
(tier 3): these cases measure the agents.
