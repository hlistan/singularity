# Security policy

## Reporting a vulnerability

Please do not open a public issue for security problems. Use GitHub's private vulnerability reporting on this repository (**Security → Report a vulnerability**). You will get an acknowledgement within 7 days. Please include the plugin version (from `claude plugin list`, or the commit for a `--plugin-dir` checkout), what you observed, and how to reproduce it.

## What this project runs on your machine

Project Singularity is a Claude Code plugin. Installing it is a trust decision, the same as `claude --plugin-dir`:

- **Hooks** (`plugins/singularity/hooks/hooks.json`) run shell scripts from `plugins/singularity/scripts/` on every session start, before every `Bash` tool call, and after every `Edit`/`Write`. They are short, read-only guards; review them before installing.
- **Project hook extension points**: `project-hook.sh` runs `.claude/singularity/hooks/*.sh` from the *project you are working in*, if present and executable. Treat those files like any other code in that repository.
- **Agents** can run commands through Claude Code's normal permission system. The pipelines never commit, push, or open PRs unless the project config or the user says so. Guardrails block force-pushes to protected branches, `--no-verify`, and recursive deletes of `/` or `$HOME`, but a guardrail is a safety net, not a security boundary: Claude Code's permission modes and sandboxing are.
- **Eval scaffolds** (`plugins/singularity/evals/*/fixture.sh`) run as you, outside the sandbox, and only when you pass `--scaffold`.
- **Trackers**: the Jira adapter uses an Atlassian MCP server that you authenticate once with `/mcp`; GitHub and GitLab use the `gh`/`glab` CLIs with your own credentials. Nothing in this repository stores tokens. The files tracker reads, renames and appends to task files in the folder the project configures, through `skills/tracker/scripts/tasks.sh`, and stops if that folder isn't git-ignored, because task files can hold customer details.
- **The optimizer** reads web pages during its practice scan. It treats their content as untrusted data, never follows instructions found in them, and cannot change guardrails, permissions or eval cases, or edit the plugin, its own definition included (`docs/self-optimization.md`). Nothing it produces is merged without a human. Problems it finds in the plugin go into upstream reports in the project, written to leave out anything that identifies the project, and it files one as a public issue in this repository only when the user says yes.

## What must never be committed

This is a public repository. Keep out of it: credentials and tokens, personal e-mail addresses, internal hostnames and tracker sites, names of private repositories, and any project's experience or eval data. Upstream reports from projects are written to leave all of these out; check one before you paste it anywhere public. `scripts/check-sensitive.sh` and the `Sensitive information checks` workflow enforce this; install the pre-commit hooks so it runs before you push.

## Supported versions

Only the latest release (the newest `singularity--v*` tag, which the `stable` branch points to). Security fixes ship as a new release; while the plugin is 0.x, older releases don't get backports. Changes merged to `main` but not yet released aren't supported versions.
