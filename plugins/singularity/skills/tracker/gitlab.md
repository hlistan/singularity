# GitLab adapter (issues and merge requests)

Config: `tracker: { type: gitlab, gitlab: { host: gitlab.com, project: group/repo }, states: {...} }` and/or `code_host: { type: gitlab, gitlab: {...} }`

## Access

Use the `glab` CLI. Check `glab auth status` first; unauthenticated for the host -> tell the user to run `glab auth login --hostname <host>`. Pass `--repo <host>/<project>` (or run inside the repo). Flags vary between glab versions; one rejected -> check `glab <cmd> --help`.

## Operations

- **get**: `glab issue view <n> --repo <project> --comments` (add `--output json` when supported)
- **comment**: `glab issue note <n> --repo <project> --message "<text>"`
- **move**: logical states map to **scoped labels** (`tracker.states`, e.g. `in_progress: "workflow::in progress"`); a new scoped label replaces the old one: `glab issue update <n> --repo <project> --label "<new>"`. `done` normally comes from `Closes #<n>` when the MR merges.
- **link**: put `Closes #<n>` in the MR description. Jira tracker with a GitLab code host -> the Jira key goes in the branch name and MR title instead.
- **create**: `glab issue create --repo <project> --title ... --description ...` (only on explicit request).
- **open_change**: `glab mr create --repo <project> --source-branch <branch> --target-branch <default_branch> --draft --title "<title>" --description "<body>"`
- **find_change**: `glab api "projects/:id/merge_requests?source_branch=<branch>&state=all&per_page=1"`, giving `iid`, `web_url`, `state` (`opened`, `merged` or `closed`), `diff_refs.base_sha`, `sha`, `created_at`, `merged_at` and `closed_at`
- **list_changes**: `glab api "projects/:id/merge_requests?state=<state>&per_page=<n>"`, with `source_branch` for the branch
- **review_comments**: `glab mr view <n> --repo <project> --comments`, or `glab api projects/:id/merge_requests/<n>/discussions` for inline threads
