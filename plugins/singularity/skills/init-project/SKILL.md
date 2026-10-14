---
name: init-project
description: Set up the current project repository to use the shared singularity setup by creating its per-project config, experience files and settings. Use when the user wants to onboard or connect a project to singularity.
disable-model-invocation: true
---

# Onboard this project to singularity

Templates are in `${CLAUDE_PLUGIN_ROOT}/templates/`. Create the following in the project root and **never overwrite an existing file**: if one exists, show the user what you would add and merge only with their approval.

1. **`.claude/singularity.md`** from `project/.claude/singularity.md`. Fill it in by inspecting the repo:
   - `commands`: read package.json / pyproject.toml / Makefile / build.gradle / go.mod / CI config and fill in the real commands. Run each once to confirm it works; mark failures.
   - `conventions`: infer branch naming and commit style from `git log` and `git branch -a`.
   - `code_host`: from `git remote -v` (github.com means github; a gitlab host means gitlab, with its host and project path).
   - `tracker`: look for Jira keys (`ABC-123`) in recent branch names and commit messages, for `.github/ISSUE_TEMPLATE` or `.gitlab/issue_templates`, and for a folder of files named like `TODO-T1-short-name` (for example `.tasks/`), which means the files tracker. If the team uses no external tracker, offer the files tracker. Propose a tracker and **confirm it with the user**, including the Jira site and project key, the label names used as states, or the task folder.
   - Leave `roles`, `review`, `stages` empty: they're for overrides only.
   - Leave anything you can't determine as `TODO` and list it for the user.
2. **Jira only**: if the session has no Atlassian MCP tools, add the server from `mcp/jira.mcp.json` to the project's `.mcp.json` (merge if the file exists), and tell the user each person authenticates once with `/mcp`.
3. **Files tracker only**: create the task folder (`tracker.files.dir`, default `.tasks/`) and add it to `.gitignore`, then run `bash "${CLAUDE_PLUGIN_ROOT}/skills/tracker/scripts/tasks.sh" --dir <folder> validate` and fix what it reports. Tell the user how to add a task: a file named `TODO-T1-short-name.md` in that folder, or ask Claude to create one. Set `code_host.type` to `none` if the project has no GitHub or GitLab remote.
4. **`.claude/settings.json`**: merge in `extraKnownMarketplaces` and `enabledPlugins` from `project/.claude/settings.json`. The source URL points at the public repository; change it if you use a fork. Its `ref: stable` follows releases; to hold the project on one release, set `ref` to that release's tag (for example `singularity--v0.1.0`) only if the user asks.
5. **`CLAUDE.md`**: if missing, create it from the template. If present, add the two `@` import lines near the top if they aren't there already.
6. **Experience and evals**: copy `project/.claude/singularity/experience/` and `project/.claude/singularity/evals/` as-is. Both must be committed: they hold the project's shared agent experience and the regression cases the optimizer validates against.
7. **Optional**, only if the user wants them: the hook scripts in `project/.claude/singularity/hooks/` (make them executable), and the examples `custom-implementer.md.example`, `review-domain.md.example` and `dependency-upgrade.js.example`.
8. Add `work_dir` (default `.agentic/work/`) to `.gitignore` unless the user wants specs and plans committed.

Finish by listing the files created, the TODOs left, and telling the user to commit them so the whole team gets the setup.
