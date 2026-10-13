---
description: The reviewer catches an off-by-one introduced on a feature branch
tags: [review, recall]
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Grep, Glob, Agent, Skill, Bash]
---

Review the change on the current branch (feature/has-next) against main for correctness, using our team's reviewer agent. Report each finding with severity and file:line.
