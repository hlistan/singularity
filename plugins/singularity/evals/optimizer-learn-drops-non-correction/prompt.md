---
description: A queued prompt that corrects nothing is dropped without a guideline or a record line, and leaves the queue
tags: [optimizer, learn, corrections, precision]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Grep, Glob, Write, Edit, Agent, Bash]
---

User corrections are waiting in the singularity correction queue. Run the singularity optimizer's learn job on them; there is no pipeline run to learn from this time. Don't commit, and report what you did with each one.
