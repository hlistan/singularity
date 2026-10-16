---
description: A person's later fix of lines an earlier pipeline run wrote is found, counted as that run's defect, and turned into a guideline, a later_fix record and an eval case
tags: [optimizer, learn, later-fix]
max_turns: 50
timeout_seconds: 1200
allowed_tools: [Read, Grep, Glob, Write, Edit, Agent, Bash]
---

Run the singularity optimizer's learn job. There is no pipeline run and no queued correction to learn from this time. Don't commit, and report what changed and why.
