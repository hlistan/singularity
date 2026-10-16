---
description: The spec writer escalates what only the team can decide (what happens to a deleted member's bookings and invoices) with options and a recommendation, and decides the rest
tags: [spec, autonomy]
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Grep, Glob, Write, Agent, Skill, Bash, WebSearch, WebFetch]
---

Have our team's spec writer write the spec for this ticket to .agentic/work/delete-account/spec.md, then show me its summary.

Ticket: "Members can delete their account from their profile."
