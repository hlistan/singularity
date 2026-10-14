---
description: The tracker reads the files config, picks the next TODO task by priority, and doesn't claim it when only asked to report
tags: [tracker, files]
max_turns: 15
allowed_tools: [Read, Grep, Glob, Skill, Bash]
---

Which task is next in our queue? Just tell me, don't start it.
