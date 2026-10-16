# GitHub adapter (issues and pull requests)

Config: `tracker: { type: github, github: { repo: org/repo }, states: {...} }` and/or `code_host: { type: github, github: { repo: org/repo } }`

## Access

Use the `gh` CLI. Check `gh auth status` first; unauthenticated -> tell the user to run `gh auth login`. Always pass `--repo <repo>` from the config.

## Operations

- **get**: `gh issue view <n> --repo <repo> --json number,title,body,labels,state,url,comments`
- **comment**: write the text to a temp file, then `gh issue comment <n> --repo <repo> --body-file <file>`
- **move**: issues are only open or closed, so logical states map to **labels** (`tracker.states`, e.g. `in_progress: "status: in progress"`): `gh issue edit <n> --repo <repo> --add-label "<new>" --remove-label "<old>"`. `done` normally comes from `Closes #<n>` when the PR merges; never close issues directly.
- **link**: put `Closes #<n>` (or `Refs #<n>` for partial work) in the PR body.
- **create**: `gh issue create --repo <repo> --title ... --body-file ...` (only on explicit request).
- **open_change**: `gh pr create --repo <repo> --base <default_branch> --head <branch> --draft --title "<title>" --body-file <file>`
- **find_change**: `gh pr list --repo <repo> --head <branch> --state all --json number,url,state,baseRefOid,headRefOid,createdAt,mergedAt,closedAt --limit 1` (`state` is `OPEN`, `MERGED` or `CLOSED`)
- **list_changes**: `gh pr list --repo <repo> --state <state> --limit <n> --json number,url,headRefName,baseRefOid,headRefOid`
- **review_comments**: `gh pr view <n> --repo <repo> --json reviews,comments` plus inline comments via `gh api repos/<repo>/pulls/<n>/comments`
