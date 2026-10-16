---
description: A person's edit before merge that applies a project convention becomes a correction and a guideline, and the human_review line records the change as modified
tags: [optimizer, learn, human-review]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Grep, Glob, Write, Edit, Agent, Bash]
---

The singularity feature pipeline collected a finished human review of an earlier run for its learn step: run 9-csv-export, PR #14, merged; opened 2026-10-10T09:00:00Z, merged 2026-10-11T09:00:00Z; base commit: tag base-9, reviewed commit: tag reviewed-9. Review comments are in .agentic/work/9-csv-export/human-review.md, people's edits after hand-off in .agentic/work/9-csv-export/human-edits.diff. There is no new pipeline run. Run the singularity optimizer's learn job on this review. Don't commit.
