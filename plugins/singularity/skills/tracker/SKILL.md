---
name: tracker
description: Read and update this project's issue tracker and code host (Jira, GitHub Issues, GitLab Issues or local task files; GitHub PRs or GitLab MRs) as configured in .claude/singularity.md. Use whenever a task needs to fetch a ticket, pick the next task, comment on it, move its status, or open a PR/MR.
---

# Tracker and code host

`.claude/singularity.md` declares both (`tracker:`, `code_host:`); never assume one. Load **only** the matching adapter:

| `tracker.type` / `code_host.type` | Adapter |
|---|---|
| `jira` | [jira.md](jira.md) |
| `github` | [github.md](github.md) |
| `gitlab` | [gitlab.md](gitlab.md) |
| `files` | [files.md](files.md): task files in a git-ignored folder, via `bash "${CLAUDE_PLUGIN_ROOT}/skills/tracker/scripts/tasks.sh"` |
| `none` | The user's text is the ticket; no tracker updates |

They can differ (e.g. Jira and GitLab): load an adapter for each.

## Operations

Every adapter implements these; pipelines ask only for them:

| Operation | Meaning |
|---|---|
| `next()` | Next waiting task (files tracker only; elsewhere ask the user) |
| `get(ticket)` | Title, description, type (story/bug/task), acceptance criteria if present, labels, linked issues, recent comments, URL |
| `comment(ticket, text)` | Short; link the PR/MR, don't paste diffs |
| `move(ticket, state)` | **Logical** `state` (`todo`, `in_progress`, `in_review`, `blocked`, `done`), mapped through `tracker.states` (files tracker: own statuses). Unmapped -> skip |
| `link(ticket, url)` | Attach a branch, PR or MR to the ticket |
| `create(title, body, type)` | Follow-up ticket |
| `open_change(branch, title, body)` | Draft PR/MR referencing the ticket |
| `find_change(branch)` | Branch's PR/MR: number, URL, state (`open`, `merged` or `closed`), base and head commits, opened and merged/closed times; none if absent |
| `list_changes(state, limit)` | Latest PRs/MRs in a state (e.g. `merged`): number, URL, branch, base and head commits |
| `review_comments(change)` | Human review comments on a PR/MR, with commits (the feature pipeline learns from them) |

## Rules

- Ticket: an ID (`ABC-123`, `#123`, `T42` for task files), a URL, or plain text. Plain text -> no tracker updates.
- Read-only `get`, `find_change`, `list_changes`, `review_comments`: no confirmation.
- `comment`, `move`, `link`: when a pipeline stage calls for them and `tracker.updates` isn't `false`.
- `create`, closing a ticket, anything that deletes: only on explicit user request.
- Never paste secrets, tokens, credential-bearing stack traces or customer data into a tracker.
- CLI or MCP tools missing or unauthenticated -> say exactly what is missing (e.g. "`glab` is not authenticated: run `glab auth login`"), continue without the tracker.
