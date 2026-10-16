# singularity project config

Read by the shared singularity agents and pipelines and imported into every
session through CLAUDE.md: keep it short.

**Only write overrides.** Anything left out uses the shared singularity
default, so improvements there keep reaching this project.

```yaml
commands:
  install: TODO
  build: TODO
  lint: TODO
  typecheck: TODO
  test: TODO
  test_one: TODO            # one test file, e.g. "npm test -- {file}"
  test_unit: TODO           # optional: the unit layer only
  test_integration: TODO    # optional: integration / contract tests
  test_e2e: TODO            # optional: end-to-end
  format: TODO

conventions:
  default_branch: main
  branch: "feature/{ticket}-{slug}"
  commits: conventional
  work_dir: .agentic/work
  auto_commit: false
  auto_pr: false
  # allowed: a refactor may drop backward compatibility when that improves
  # the codebase (client contracts are still tested). forbidden: keep it.
  breaking_changes: forbidden

tracker:
  type: none                # jira | github | gitlab | files | none
  # jira:   { site: yourco.atlassian.net, project: ABC }
  # github: { repo: org/repo }
  # gitlab: { host: gitlab.com, project: group/repo }
  # Local task files named STATUS-ID-slug, e.g. TODO-T7-fix-login.md, in a
  # git-ignored folder. Statuses default to TODO PROGRESS REVIEW BLOCKED
  # DONE; rename them in statuses, add others in extra_statuses.
  # files:
  #   dir: .tasks
  #   id_prefix: T
  #   statuses: { in_review: PROGRESS }
  #   extra_statuses: [QA, ON_HOLD]
  # Logical state -> Jira status, or label for GitHub/GitLab. Task files use
  # their own statuses (above).
  states:
    in_progress: "In Progress"
    in_review: "In Review"
    done: "Done"
  updates: true             # false: read tickets, never comment or move them

code_host:
  type: github              # github | gitlab | none
  # gitlab: { host: gitlab.com, project: group/repo }

# Agents decide what evidence settles (the code, the goals, the guidelines,
# web research) and record each decision with its grounding. A person is
# asked only at the design gate and gets the finished change at hand-off.
gates:
  # auto: stop at the design gate only for decisions the team must make.
  # always: show every spec and plan. never: go on the agents' advice.
  design: auto
autonomy:
  web_research: true        # false: decide from the repository only

# Rebind a role to another agent, or change its model or effort. Leave a role
# out to keep the shared default:
#   spec, plan: opus high            implement: sonnet medium (fixes: high)
#   review: fable high               verify: sonnet medium
#   optimize: fable xhigh
#   learn: opus high (the optimizer's after-run job: model and effort only)
# Choosing model and effort for your own agents:
#   https://github.com/hlistan/singularity/blob/main/docs/models-and-effort.md
roles: {}
  # implement: { agent: android-implementer }   # agent in .claude/agents/
  # review:    { model: opus, effort: high }    # if Fable isn't enabled

# Skills each agent reads first, by role or agent name. singularity:<name>
# is a library skill (the plugin's library/README.md lists them); another
# name is a project skill in .claude/skills/<name>/SKILL.md.
skills: {}
  # implement: [singularity:zero-downtime-migrations]
  # qa-browser: [singularity:accessibility]

review:
  # The shared lenses. Drop one here only with a reason.
  lenses: [correctness, security, maintainability, testability]
  # - { name: performance, description: "N+1 queries, missing pagination" }
  extra_lenses: []
  extra_reviewers: []       # project agents, e.g. [review-domain]; can block
  # Only these lenses can block a change; the others advise, reporting at
  # most should-fix, on a cheaper model.
  blocking_lenses: [correctness, security]
  # advisory: { model: sonnet, effort: high }

# Checks the pipeline runs itself; pass and fail come from exit codes.
checks:
  run: [build, lint, typecheck, test]   # names from `commands`
  implement_gate: true      # the implementer can't finish while checks fail
  stop_retries: 3           # ...for at most this many attempts
  # test_pattern: "(^|/)tests/"   # paths of tests, if the defaults miss
  #                                # yours (frozen and existing tests)

stages:                     # library or project agents in the pipeline
  before_spec: []           # e.g. singularity:researcher
  after_plan: []
  after_implement: []
  before_handoff: []        # e.g. singularity:qa-browser

# Guidelines change only for defects caused by a weak guideline, and for
# user corrections: prompts, interrupts and rejected tool calls (hooks),
# gate edits, and people's edits before merge.
learning:
  enabled: true
  dir: .claude/singularity/experience   # the record: run digests, archive
  max_lines_per_file: 60    # guidelines per file; a wrapped one counts once
  corrections: true         # false: don't capture corrections from prompts
  later_fixes: true         # false: don't trace later fixes and reverts
  pr_reviews: false         # true: learn from PR/MR comments and edits

optimization:
  # Run the optimizer after this many pipeline runs; 0: never.
  every_runs: 10
  auto_start: true          # false: only say it is due
  # Let the optimizer check new Claude Code features, models and research.
  web_scan: true
  max_eval_cost_usd: 10     # spending ceiling for validation runs
```

## Do not touch

<!-- Paths agents must not modify without asking: generated code, vendored
libraries, released migrations. -->
