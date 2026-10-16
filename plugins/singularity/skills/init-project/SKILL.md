---
name: init-project
description: Set up the current repository for singularity (config, guideline and experience files, settings), then onboard the agents. Use when the user wants to onboard or connect a project to singularity.
disable-model-invocation: true
---

# Onboard this project to singularity

Templates are in `${CLAUDE_PLUGIN_ROOT}/templates/`. Create these in the project root; **never overwrite an existing file**: show the user what you'd add; merge only with their approval.

1. **`.claude/singularity.md`** from `project/.claude/singularity.md`, filled in from the repo:
   - `commands`: the real commands from package.json / pyproject.toml / Makefile / build.gradle / go.mod / CI config. Run each once; mark failures.
   - `conventions`: branch naming and commit style from `git log` and `git branch -a`.
   - `code_host`: from `git remote -v` (github.com → github; a gitlab host → gitlab, with its host and project path).
   - `tracker`: look for Jira keys (`ABC-123`) in recent branches and commits, `.github/ISSUE_TEMPLATE` or `.gitlab/issue_templates`, and a folder of files named like `TODO-T1-short-name` (e.g. `.tasks/`: the files tracker). No external tracker → offer the files tracker. **Confirm the tracker with the user**, with its Jira site and project key, state labels, or task folder.
   - Leave `roles`, `review`, `stages` empty: overrides only.
   - Anything undeterminable → `TODO`, listed for the user.
2. **Jira only**: session lacks Atlassian MCP tools → add the server from `mcp/jira.mcp.json` to the project's `.mcp.json` (merge if it exists); tell the user each person authenticates once with `/mcp`.
3. **Files tracker only**: create the task folder (`tracker.files.dir`, default `.tasks/`), add it to `.gitignore`, run `bash "${CLAUDE_PLUGIN_ROOT}/skills/tracker/scripts/tasks.sh" --dir <folder> validate` and fix what it reports. Other status prefixes the folder's tasks use on purpose (such as `QA-…`) → add them to `tracker.files.extra_statuses`. Tell the user a task is a `TODO-T1-short-name.md` file there, or Claude can create one. No GitHub or GitLab remote → set `code_host.type` to `none`.
4. **`.claude/settings.json`**: merge in `extraKnownMarketplaces` and `enabledPlugins` from `project/.claude/settings.json`. For a fork, change the source URL (the public repository). `ref: stable` follows releases; set `ref` to a release tag (e.g. `singularity--v0.1.0`) only if the user asks. Explain that Claude Code's auto memory keeps corrections per machine, outside the shared guidelines; offer `"autoMemoryEnabled": false` (add only on yes).
5. **`CLAUDE.md`**: missing → create from the template; present → add the two `@` import lines near the top if absent.
6. **Goals, guidelines, experience, evals and upstream reports**: copy `project/.claude/singularity/goals.md`, `guidelines/`, `experience/`, `evals/` and `upstream/` as-is. All must be committed.
7. **Optional**, if the user wants them: the hook scripts in `project/.claude/singularity/hooks/` (make them executable), and the examples `custom-implementer.md.example`, `review-domain.md.example` and `dependency-upgrade.js.example`.
8. Add `work_dir` (default `.agentic/work/`) to `.gitignore` unless the user wants specs and plans committed.
9. **Onboard the agents.** Spawn the **optimize** role (`roles.optimize.agent`, default `singularity:optimizer`; `model` and `effort` only if the config sets them) with `onboard, started by init-project`. It drafts `goals.md` for the user to confirm, fills the project sections of `CLAUDE.md` and writes the first guidelines. Each **Decision needed** block → show the user; restart the role with their answer until it reports done. Skippable: the user can ask for the optimizer later.

10. **Check that the shared files will be committed.** Many repositories ignore `.claude`.
    1. Run `git check-ignore -- <paths>` on every shared file: `CLAUDE.md`, `.claude/singularity.md`, `.claude/settings.json`, `.claude/singularity/goals.md`, one file each in `.claude/singularity/guidelines/`, `experience/`, `evals/` and `upstream/`, any rule in `.claude/rules/singularity/`, and any agent, skill, workflow or hook script you or the optimizer created. It prints each ignored path (no `-q`: it takes only one path); nothing printed → done.
    2. Run `git check-ignore -v -- <the printed paths>` for each one's rule (`source:line:pattern`).
    3. `git check-ignore -q -- .claude/` succeeds → the whole directory is ignored and no single `!` exception can re-include a file in it: append `${CLAUDE_PLUGIN_ROOT}/templates/project/gitignore-claude.txt` to `.gitignore`. It re-includes the directory, ignores its contents and re-includes only the shared paths (personal files such as `settings.local.json` stay local), whether the rule is in `.gitignore`, `.git/info/exclude` or a global excludes file.
    4. Otherwise a narrower rule matched: append one exception per printed path, `!/<path>`.
    5. Before writing, show the user the `.gitignore` change and the rule it works around. Then re-run sub-step 1: it must print nothing. Confirm `work_dir`, the task folder (files tracker) and `.claude/settings.local.json` are ignored; add any that isn't.

    `tests/init-gitignore.test.sh` in the singularity repository tests this procedure against every way to ignore `.claude`.

Finish: list the files created, TODOs and open questions; tell the user to commit it all. Committed settings enable the plugin for teammates without installing it: each runs `claude plugin install singularity@singularity --scope project` once. Also say: the configured `commands` must be right (the pipeline won't let the implementer finish while they fail), and the code host should protect the default branch (the plugin's command guard is a seatbelt, not a security boundary).
