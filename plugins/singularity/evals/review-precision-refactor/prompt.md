---
description: The reviewer does not invent blocking issues in a behaviour-preserving refactor
tags: [review, precision]
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Grep, Glob, Agent, Skill, Bash]
---

Review the change on the current branch (refactor/total) against main for correctness, using our team's reviewer agent. Report each finding with severity and file:line.
