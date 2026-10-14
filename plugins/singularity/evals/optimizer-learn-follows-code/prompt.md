---
description: When a run moves code, the optimizer's learn job rewrites the guideline that described it to the current state, without history notes, and records the change in the run digest
tags: [optimizer, learn, guidelines]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Grep, Glob, Write, Edit, Agent, Bash]
---

The pipeline run in .agentic/work/t1-move-retry has just finished; its run record is run.json there. Run the singularity optimizer's learn job on it, as the feature pipeline's learn step would. Don't commit.
