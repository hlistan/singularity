# Security policy

## Reporting a vulnerability

No public issues for security problems: use GitHub's private vulnerability reporting (**Security → Report a vulnerability**); acknowledgement within 7 days. Include the plugin version (`claude plugin list`, or the commit for a `--plugin-dir` checkout), what you observed, how to reproduce.

## What this project runs on your machine

Installing this Claude Code plugin is a trust decision, like `claude --plugin-dir`:

- **Hooks** (`plugins/singularity/hooks/hooks.json`) run shell scripts from `plugins/singularity/scripts/` at session start, before every `Bash` call and after every `Edit`/`Write`: short, read-only guards; review them before installing.
- **Project hook extension points**: `project-hook.sh` runs `.claude/singularity/hooks/*.sh` from the *project you are working in*, if present and executable; treat them as that repository's code.
- **Agents** run commands under Claude Code's normal permission system. Pipelines commit, push or open PRs only when the project config or the user says so. Guardrails block force-pushes to protected branches, `--no-verify`, and recursive deletes of `/` or `$HOME`: a safety net, not a security boundary (Claude Code's permission modes and sandboxing are).
- **Eval scaffolds** (`plugins/singularity/evals/*/fixture.sh`) run as you, outside the sandbox, only with `--scaffold`.
- **Trackers**: Jira via an Atlassian MCP server you authenticate once with `/mcp`; GitHub and GitLab via the `gh`/`glab` CLIs and your credentials. Nothing here stores tokens. The files tracker reads, renames and appends to task files in the configured folder via `skills/tracker/scripts/tasks.sh`, and stops if that folder isn't git-ignored (task files can hold customer details).
- **The optimizer** treats practice-scan web pages as untrusted data, never as instructions. It cannot change guardrails, permissions or eval cases, or edit the plugin, its own definition included (`docs/self-optimization.md`); nothing it produces merges without a human. Plugin problems go into upstream reports in the project, minus anything identifying it; it files one as a public issue here only on the user's yes.

## What must never be committed

Public repository: no credentials or tokens, personal e-mail addresses, internal hostnames or tracker sites, private repository names, or any project's experience or eval data. Upstream reports omit these; check one before pasting it anywhere public. `scripts/check-sensitive.sh` and the `Sensitive information checks` workflow enforce this; install the pre-commit hooks to run it before you push.

## Supported versions

Only the latest release: the newest `singularity--v*` tag, which `stable` points to. Fixes ship as a new release; no backports while 0.x. Unreleased changes on `main` aren't supported.
