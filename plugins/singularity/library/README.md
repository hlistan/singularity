# Agent and skill library

Shared building blocks a project selects at onboarding, and the place to contribute new ones. The pipeline's roles (spec, plan, implement, review, verify, optimize) always run; library entries add to them:

- **Agents** run as project stages (`stages.*`), extra reviewers (`review.extra_reviewers`) or a role's replacement (`roles.<role>.agent`). They live in the plugin's `agents/` folder and are spawned as `singularity:<name>`.
- **Skills** are know-how an agent reads first, given per role or per agent in the config's `skills` map (`singularity:<name>`). They live here, in `skills/<name>/SKILL.md`, and are not registered Claude Code skills: a skill costs context only in the agents a project gives it to, never in other sessions.

Onboarding (`optimizer/onboard.md`, "Select the team") matches each entry's signals against its survey of the project, proposes the matches at its gate and writes the team's choice into `.claude/singularity.md`. Each choice ships as a canary, checked after 10 runs; the optimizer keeps or drops it on the record.

## Catalog

| Entry | Kind | Attaches to | Select when the project shows | Model · effort |
|---|---|---|---|---|
| `researcher` | agent | `stages.before_spec` | specs that rest on outside facts: third-party APIs, standards or regulations, fast-moving libraries; tickets that often stop for "how is this usually done" | sonnet · high |
| `qa-browser` | agent | `stages.before_handoff` | a web UI, with trying the change in a browser part of done, and a browser MCP server (`chrome-devtools` or `playwright`) | sonnet · high |
| `zero-downtime-migrations` | skill | `plan`, `implement`, `review` | schema migrations on a database that serves traffic while a deploy rolls out | |
| `accessibility` | skill | `spec`, `implement`, `review`, `qa-browser` | a user-facing web UI | |

## Contributing an entry

1. **Generic.** Right for any project that shows its signal. Project facts (commands, URLs, test accounts, domain rules) stay in the project's guidelines; the entry tells its agent where to read them.
2. **Narrow.** One job or one topic. Curated, focused skills help agents; broad and self-written ones mostly don't, and some make results worse (SkillsBench, 2026: <https://arxiv.org/abs/2602.12670>).
3. **Grounded.** Each rule cites its standard or source; the pull request names the failure the entry prevents.
4. **No bundled scripts in skills.** Marketplace skills that bundle scripts were about twice as likely to carry a vulnerability (*Agent Skills in the Wild*, 2026: <https://arxiv.org/abs/2601.10338>). A skill folder holds Markdown only.
5. **Agents**: frontmatter with `name`, a `description` naming where it attaches, the fewest `tools` the job needs, `model` and `effort` chosen by [docs/models-and-effort.md](../../../docs/models-and-effort.md); the report comes back in the final message; read-only unless the job is a role's.
6. **Skills**: `skills/<name>/SKILL.md` with `name` and `description` frontmatter, under about 80 lines, rules a reviewer can check.
7. **Record**: a catalog row above (`node scripts/check-library.js` checks rows against files, in CI), a line in `CHANGELOG.md`, and an eval case under `plugins/singularity/evals/` when the entry changes what agents do.

A project's optimizer finds library candidates among the project's own agents and skills and proposes them through upstream reports; maintainers adopt them as `CONTRIBUTING.md` describes.
