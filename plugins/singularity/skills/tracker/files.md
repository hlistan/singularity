# Files adapter (local task files)

Config:

```yaml
tracker:
  type: files
  files:
    dir: .tasks                          # default .tasks; must be git-ignored
    id_prefix: T                         # new tasks get T1, T2, ...
    statuses: { in_review: PROGRESS }    # optional: rename statuses
    extra_statuses: [QA, ON_HOLD]        # optional: any other statuses the team uses
```

One file per task in `files.dir`, named `<STATUS>-<ID>-<slug>` (prefix = status), optional `.md`, `.txt` or `.markdown` extension:

```text
.tasks/
  TODO-T7-fix-login.md
  TODO-T9-update-docs
  PROGRESS-T3-add-search.md
  DONE-T1-setup-ci.md
```

| Logical state | Default prefix |
|---|---|
| `todo` | `TODO` |
| `in_progress` | `PROGRESS` |
| `in_review` | `REVIEW` |
| `blocked` | `BLOCKED` |
| `done` | `DONE` |

States can share a prefix (`{ in_review: PROGRESS }`: moving to review keeps the name). Only `todo` needs its own: claiming renames a task out of the queue.

**Custom statuses.** `extra_statuses` declares other statuses (e.g. `QA`, `ON_HOLD`): upper-case letters, digits, `_`. They work wherever a status does (`list QA`, `move T4 QA`, `move T4 done --from QA`); `get` prints an empty `state=` for them. Tasks enter one only on user request. Undeclared prefix -> file ignored, reported by `validate` (so a typo like `TOD0-T4-…` can't hide a task). To use one for a pipeline step, map it in `statuses` (e.g. `{ in_review: QA }`).

IDs: letters, digits, `_` (no `-`). Content: the ticket, free text or Markdown; title = first level-1 heading (`# Title`). Optional front matter: `priority` (queue order: lower first, then lowest ID number) and `type`:

```markdown
---
priority: 1
type: bug
---
# Fix the login redirect

Users land on /home instead of the page they asked for.
```

## Access

Only through the tasks script (path in the tracker's `SKILL.md`), from the project root: `bash "<path>" [options] <command>`. Never rename, create or edit task files by hand: the script keeps names valid, IDs unique, claims atomic.

**In a worktree** (e.g. `claude --worktree`) the git-ignored task folder is absent; a copy wouldn't share claims. `git rev-parse --git-dir` differs from `git rev-parse --git-common-dir` -> run the script in the main checkout: `(cd "$(git rev-parse --path-format=absolute --git-common-dir)/.." && bash "<path>" [options] <command>)`; claims stay atomic across worktrees.

Options from the config:

- `--dir <files.dir>` if set;
- `--id-prefix <files.id_prefix>` if set;
- `--status <state>=<PREFIX>` per `files.statuses` entry;
- `--extra-status <PREFIX>` per `files.extra_statuses` entry.

Run `validate` before a session's first command:

- Directory **not git-ignored** -> stop; tell the user to add it to `.gitignore` (task files may hold customer details and must never be committed). Until then every other command exits `1`.
- Other problems (undeclared status prefixes, malformed names, duplicate IDs) -> report, continue with the valid tasks; for a deliberate undeclared prefix, suggest `extra_statuses`.

Exit codes: `1` validation problems or unignored directory, `2` usage error, `3` not found or empty queue, `4` duplicate ID, `5` conflict.

## Operations

- **get**: `get <ID>` (or a file name or path). Output: `key=value` lines (`status`, `state`, `id`, `slug`, `title`, `priority`, `path`), a `---` line, the file content. Exit `4` (duplicate ID) -> ask the user which file.
- **next**: `next` prints the first `TODO` task in queue order, same format, plus `remaining=<n>`. Exit `3` (empty queue) -> tell the user.
- **move**: `move <ID> <state>`. Work **starts** -> always claim: `move <ID> in_progress --from todo`. Exit `5` (another session claimed it) -> after `next`: `next` again; for a user-given ID: tell the user.
- **resume**: user confirms resuming a task already `in_progress`, `blocked` or `in_review` -> `move <ID> in_progress --from in_progress,blocked,in_review`. Refuses a task that has since moved to another state.
- **comment**: `comment <ID> "<text>"` appends a timestamped line under `## Log`; one line, no secrets.
- **link**: `comment <ID> "Link: <url>"`.
- **create**: `create <slug> "<title>"`, body on stdin; only on explicit user request.
- **open_change**, **find_change**, **list_changes**, **review_comments**: from `code_host` (GitHub or GitLab); skipped when `code_host.type` is `none`.

## Done

No merge closes a task file: the pipeline moves it to `in_review` at hand-off, to `done` only when the user says so (unattended: stays in review).
