---
name: tracker
description: Read and update this project's issue tracker and code host (Jira, GitHub Issues, GitLab Issues or local task files; GitHub PRs or GitLab MRs) as configured in .claude/singularity.md. Use whenever a task needs to fetch a ticket, pick the next task, comment on it, move its status, or open a PR/MR.
---

# Tracker and code host

Every project declares its tracker and code host in `.claude/singularity.md` (the `tracker:` and `code_host:` keys). Never assume one: read the config, then load **only** the matching adapter file:

| `tracker.type` / `code_host.type` | Adapter |
|---|---|
| `jira` | [jira.md](jira.md) |
| `github` | [github.md](github.md) |
| `gitlab` | [gitlab.md](gitlab.md) |
| `files` | [files.md](files.md): tasks are files in a git-ignored folder, managed with the script `bash "${CLAUDE_PLUGIN_ROOT}/skills/tracker/scripts/tasks.sh"` |
| `none` | Use the text the user gave as the ticket; skip all tracker updates |

Tracker and code host can differ (for example Jira issues with GitLab merge requests). Load one adapter for each.

## Operations

Every adapter implements the same operations, so pipelines only ever ask for these:

| Operation | Meaning |
|---|---|
| `next()` | Pick the next task waiting to be worked on. Only the files tracker supports it; with other trackers, ask the user which ticket to take |
| `get(ticket)` | Title, description, type (story/bug/task), acceptance criteria if present, labels, linked issues, recent comments, URL |
| `comment(ticket, text)` | Add a comment. Keep it short; link to the PR/MR rather than pasting diffs |
| `move(ticket, state)` | `state` is a **logical** state: `todo`, `in_progress`, `in_review`, `blocked`, `done`. Map it through `tracker.states` in the config (the files tracker has its own statuses). If a tracker has no mapping for a state, skip that move |
| `link(ticket, url)` | Associate a branch, PR or MR with the ticket |
| `create(title, body, type)` | Create a follow-up ticket. Only when the user asks |
| `open_change(branch, title, body)` | Open a PR/MR on the code host as a draft, referencing the ticket |
| `find_change(branch)` | Find the PR/MR for a branch: its number, URL, state (`open`, `merged` or `closed`), base commit and head commit, and when it was opened and merged or closed. None if there isn't one |
| `list_changes(state, limit)` | The latest PRs/MRs in a state (`merged`, say), each with its number, URL, branch, base commit and head commit |
| `review_comments(change)` | Fetch human review comments on a PR/MR, with the commit each was made on (the feature pipeline learns from them) |

## Rules

- Accept a ticket as an ID (`ABC-123`, `#123`, `T42` for task files), a URL, or plain text. Plain text means no tracker updates.
- Read-only operations (`get`, `find_change`, `list_changes`, `review_comments`) need no confirmation.
- `comment`, `move` and `link` are allowed when a pipeline stage calls for them and `tracker.updates` is not `false` in the config.
- `create`, closing a ticket, and anything that deletes require the user's explicit request.
- Never paste secrets, tokens, stack traces with credentials, or customer data into a tracker.
- If the needed CLI or MCP tools are missing or unauthenticated, say exactly what is missing (for example "`glab` is not authenticated: run `glab auth login`") and continue without the tracker instead of failing the pipeline.
