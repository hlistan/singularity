---
name: tracker
description: Read and update this project's issue tracker and code host (Jira, GitHub Issues or GitLab Issues; GitHub PRs or GitLab MRs) as configured in .claude/singularity.md. Use whenever a task needs to fetch a ticket, comment on it, move its status, or open a PR/MR.
---

# Tracker and code host

Every project declares its tracker and code host in `.claude/singularity.md` (the `tracker:` and `code_host:` keys). Never assume one: read the config, then load **only** the matching adapter file:

| `tracker.type` / `code_host.type` | Adapter |
|---|---|
| `jira` | [jira.md](jira.md) |
| `github` | [github.md](github.md) |
| `gitlab` | [gitlab.md](gitlab.md) |
| `none` | Use the text the user gave as the ticket; skip all tracker updates |

Tracker and code host can differ (for example Jira issues with GitLab merge requests). Load one adapter for each.

## Operations

Every adapter implements the same operations, so pipelines only ever ask for these:

| Operation | Meaning |
|---|---|
| `get(ticket)` | Title, description, type (story/bug/task), acceptance criteria if present, labels, linked issues, recent comments, URL |
| `comment(ticket, text)` | Add a comment. Keep it short; link to the PR/MR rather than pasting diffs |
| `move(ticket, state)` | `state` is a **logical** state: `in_progress`, `in_review`, `done`. Map it through `tracker.states` in the config |
| `link(ticket, url)` | Associate a branch, PR or MR with the ticket |
| `create(title, body, type)` | Create a follow-up ticket. Only when the user asks |
| `open_change(branch, title, body)` | Open a PR/MR on the code host as a draft, referencing the ticket |
| `review_comments(change)` | Fetch human review comments on a PR/MR (used by `/singularity:learn`) |

## Rules

- Accept a ticket as an ID (`ABC-123`, `#123`), a URL, or plain text. Plain text means no tracker updates.
- Read-only operations (`get`, `review_comments`) need no confirmation.
- `comment`, `move` and `link` are allowed when a pipeline stage calls for them and `tracker.updates` is not `false` in the config.
- `create`, closing a ticket, and anything that deletes require the user's explicit request.
- Never paste secrets, tokens, stack traces with credentials, or customer data into a tracker.
- If the needed CLI or MCP tools are missing or unauthenticated, say exactly what is missing (for example "`glab` is not authenticated: run `glab auth login`") and continue without the tracker instead of failing the pipeline.
