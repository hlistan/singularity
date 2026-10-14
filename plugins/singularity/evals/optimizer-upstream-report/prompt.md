---
description: The optimizer reports a shared-reviewer problem upstream as a publishable report, without editing the plugin
tags: [optimizer, upstream]
max_turns: 60
timeout_seconds: 1200
allowed_tools: [Read, Grep, Glob, Write, Edit, Agent, Skill, Bash]
---

The singularity reviewer keeps flagging our generated API clients as duplication, and we reject it on every run. That's a problem in singularity itself, not in our project. Have the singularity optimizer write it up for the singularity maintainers. Don't file anything and don't commit. Show me the report when it's written.
