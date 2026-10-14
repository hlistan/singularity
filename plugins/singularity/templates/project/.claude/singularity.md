# singularity project config

Read by the shared singularity agents and pipelines, and imported into every
session through CLAUDE.md, so keep it short.

**Only write overrides.** Anything you leave out uses the shared default from
the singularity repo, so improvements there keep reaching this project.

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

# Rebind a role to another agent, or change its model or effort. Leave a role
# out to keep the shared default:
#   spec, plan, learn: opus high     implement: sonnet medium (fixes: high)
#   review: fable high               verify: sonnet medium
#   optimize: fable xhigh
# Choosing model and effort for your own agents:
#   https://github.com/hlistan/singularity/blob/main/docs/models-and-effort.md
roles: {}
  # implement: { agent: android-implementer }   # agent in .claude/agents/
  # review:    { model: opus, effort: high }    # if Fable isn't enabled

review:
  # The shared lenses. Drop one here only with a reason.
  lenses: [correctness, security, maintainability, testability]
  # - { name: performance, description: "N+1 queries, missing pagination" }
  extra_lenses: []
  extra_reviewers: []       # project agents, e.g. [review-domain]

stages:                     # project agents inserted into the shared pipeline
  after_plan: []
  after_implement: []
  before_handoff: []

learning:
  enabled: true
  dir: .claude/singularity/experience
  max_lines_per_file: 60    # per file; a wrapped lesson counts once

optimization:
  # Suggest /singularity:optimize after this many pipeline runs; 0: never.
  every_runs: 10
  # Let the optimizer check new Claude Code features, models and research.
  web_scan: true
  max_eval_cost_usd: 10     # spending ceiling for validation runs
```

## Do not touch

<!-- Paths agents must not modify without asking: generated code, vendored
libraries, released migrations. -->
