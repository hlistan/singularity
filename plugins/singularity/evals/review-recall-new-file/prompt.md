---
description: The reviewer finds a defect in a new file that isn't committed yet, which plain git diff leaves out
tags: [review, recall, diff]
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Grep, Glob, Agent, Skill, Bash]
---

Review the change on the current branch (feature/discount) against main for correctness, including the work that isn't committed yet, using our team's reviewer agent. Report each finding with severity and file:line.
