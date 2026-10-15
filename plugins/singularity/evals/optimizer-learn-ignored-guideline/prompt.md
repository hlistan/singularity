---
description: A defect against a guideline the agent reads but didn't follow is classed guideline-ignored and gets a proposed check, not a duplicate guideline
tags: [optimizer, learn, root-cause]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Grep, Glob, Write, Edit, Agent, Bash]
---

The pipeline run in .agentic/work/t4-invoice-total has just finished; its run record is run.json there. Run the singularity optimizer's learn job on it, as the feature pipeline's learn step would. Don't commit.
