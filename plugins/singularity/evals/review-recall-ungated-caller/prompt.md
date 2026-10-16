---
description: The reviewer finds a second path to a newly gated capability that the change doesn't touch, outside the diff
tags: [review, recall, security, authz]
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Grep, Glob, Agent, Skill, Bash]
---

Review the change on the current branch (feature/paid-pdf-export) against main through the security lens, using our team's reviewer agent. The spec is in spec.md. Report each finding with severity and file:line.
