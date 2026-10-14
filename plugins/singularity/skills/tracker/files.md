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

Each task is one file in `files.dir`, named `<STATUS>-<ID>-<slug>`, with an optional `.md`, `.txt` or `.markdown` extension. The status is the file name prefix:

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

**Custom statuses.** A team can use any other statuses it needs (for example `QA`, `DESIGN`, `ON_HOLD`) by listing them in `extra_statuses`: upper-case letters, digits and `_`. They work everywhere a status does (`list QA`, `move T4 QA`, `move T4 done --from QA`), and `get` prints an empty `state=` for them because they have no meaning to the pipeline. The pipeline never moves a task into a custom status on its own; do it when the user asks. Files whose prefix isn't declared are ignored, and `validate` reports them, so a typo such as `TOD0-T4-…` doesn't silently drop a task from the queue. To make the pipeline use a custom status for one of its own steps, map it in `statuses` instead, for example `{ in_review: QA }`.

The ID is letters, digits and `_` (no `-`). The file content is the ticket: free text or Markdown, whose first level-1 heading (`# Title`) is the title. Optional front matter sets the queue order (lower `priority` first, then the lowest ID number) and can say what kind of work it is:

```markdown
---
priority: 1
type: bug
---
# Fix the login redirect

Users land on /home instead of the page they asked for.
```

## Access

Always go through the tasks script; its path is in the tracker's `SKILL.md`. Run it from the project root as `bash "<path>" [options] <command>`. Never rename, create or edit task files by hand: the script keeps names valid, IDs unique and claims atomic.

Options, built from the config:

- `--dir <files.dir>` if set;
- `--id-prefix <files.id_prefix>` if set;
- `--status <state>=<PREFIX>` for each entry in `files.statuses`;
- `--extra-status <PREFIX>` for each entry in `files.extra_statuses`.

Before the first operation in a session, run `validate`:

- If it reports that the directory is **not git-ignored**, stop and tell the user to add it to `.gitignore`. Task files can hold customer details and must never be committed, so every other command refuses to run (exit `1`) until it is ignored.
- For other problems (undeclared status prefixes, malformed names, duplicate IDs), report them to the user and carry on with the valid tasks. An undeclared prefix the team uses on purpose belongs in `extra_statuses`; suggest adding it.

Exit codes: `1` validation problems or directory not git-ignored, `2` usage error, `3` not found or empty queue, `4` duplicate ID, `5` conflict.

## Operations

- **get**: `get <ID>`. A file name or path works too. Output: `key=value` lines (`status`, `state`, `id`, `slug`, `title`, `priority`, `path`), a `---` line, then the file content. Exit `4` means two files share the ID: ask the user which one is meant.
- **next**: `next` prints the first `TODO` task in queue order the same way, plus `remaining=<n>`. Exit `3` means the queue is empty: tell the user.
- **move**: `move <ID> <state>`. When work **starts** on a task, always claim it with `move <ID> in_progress --from todo`. Exit `5` means another session took it first: after `next`, run `next` again; for an ID the user gave, tell them.
- **comment**: `comment <ID> "<text>"` appends a timestamped line under a `## Log` heading in the task file. One line, no secrets.
- **link**: `comment <ID> "Link: <url>"`.
- **create**: `create <slug> "<title>"`, with the body on standard input. Only on the user's explicit request.
- **open_change**, **review_comments**: not part of this adapter; they come from `code_host` (GitHub or GitLab), or are skipped when `code_host.type` is `none`.

## Done

No merge event closes a task file. The pipeline moves the task to `in_review` at hand-off, and to `done` only when the user says so. In unattended runs it stays in review.
