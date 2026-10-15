---
description: A user correction captured by the hook becomes a guideline with a root cause, is recorded without the prompt's text, and leaves the queue
tags: [optimizer, learn, corrections]
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Grep, Glob, Write, Edit, Agent, Bash]
---

User corrections are waiting in the singularity correction queue. Run the singularity optimizer's learn job on them; there is no pipeline run to learn from this time. Don't commit, and report which guidelines changed and why.
