# Security policy

## Reporting a vulnerability

Please do not open a public issue for security problems. Use GitHub's private vulnerability reporting on this repository (**Security → Report a vulnerability**). You will get an acknowledgement within 7 days. Please include the plugin version or commit, what you observed, and how to reproduce it.

## What this project runs on your machine

Project Singularity is a Claude Code plugin. Installing it is a trust decision, the same as `claude --plugin-dir`:

- **Hooks** (`plugins/singularity/hooks/hooks.json`) run shell scripts from `plugins/singularity/scripts/` on every session start, before every `Bash` tool call, and after every `Edit`/`Write`. They are short, read-only guards; review them before installing.
- **Project hook extension points**: `project-hook.sh` runs `.claude/singularity/hooks/*.sh` from the *project you are working in*, if present and executable. Treat those files like any other code in that repository.
- **Agents** can run commands through Claude Code's normal permission system. The pipelines never commit, push, or open PRs unless the project config or the user says so. Guardrails block force-pushes to protected branches, `--no-verify`, and recursive deletes of `/` or `$HOME`, but a guardrail is a safety net, not a security boundary: Claude Code's permission modes and sandboxing are.
- **Eval scaffolds** (`plugins/singularity/evals/*/fixture.sh`) run as you, outside the sandbox, and only when you pass `--scaffold`.
- **Trackers**: the Jira adapter uses an Atlassian MCP server that you authenticate once with `/mcp`; GitHub and GitLab use the `gh`/`glab` CLIs with your own credentials. Nothing in this repository stores tokens.
- **The optimizer** reads web pages during its practice scan. It treats their content as untrusted data, never follows instructions found in them, and cannot change guardrails, permissions, eval cases or its own definition (tier 3 in `docs/self-optimization.md`). Nothing it produces is merged without a human.

## What must never be committed

This is a public repository. Keep out of it: credentials and tokens, personal e-mail addresses, internal hostnames and tracker sites, names of private repositories (`optimizer/projects.yaml` is git-ignored for this reason), and any project's experience or eval data. `scripts/check-sensitive.sh` and the `Sensitive information checks` workflow enforce this; install the pre-commit hooks so it runs before you push.

## Supported versions

The default branch only. There are no releases yet.
