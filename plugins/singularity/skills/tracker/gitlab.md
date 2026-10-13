# GitLab adapter (issues and merge requests)

Config: `tracker: { type: gitlab, gitlab: { host: gitlab.com, project: group/repo }, states: {...} }` and/or `code_host: { type: gitlab, gitlab: {...} }`

## Access

Use the `glab` CLI. Check `glab auth status` first; if it isn't authenticated for the host, tell the user to run `glab auth login --hostname <host>`. Pass `--repo <host>/<project>` (or run inside the repo). Flags vary a little between glab versions; check `glab <cmd> --help` if one is rejected.

## Operations

- **get**: `glab issue view <n> --repo <project> --comments` (add `--output json` when supported)
- **comment**: `glab issue note <n> --repo <project> --message "<text>"`
- **move**: GitLab issues map logical states to **scoped labels** (`tracker.states`, e.g. `in_progress: "workflow::in progress"`). Setting a new scoped label replaces the old one: `glab issue update <n> --repo <project> --label "<new>"`. `done` normally happens through `Closes #<n>` when the MR merges.
- **link**: put `Closes #<n>` in the MR description. For a Jira tracker with a GitLab code host, put the Jira key in the branch name and MR title instead.
- **create**: `glab issue create --repo <project> --title ... --description ...` (only on explicit request).
- **open_change**: `glab mr create --repo <project> --source-branch <branch> --target-branch <default_branch> --draft --title "<title>" --description "<body>"`
- **review_comments**: `glab mr view <n> --repo <project> --comments`, or `glab api projects/:id/merge_requests/<n>/discussions` for inline threads
