# singularity project config

Read by the shared singularity agents and pipelines, and imported into every session through CLAUDE.md, so keep it short.
**Only write overrides.** Anything you leave out uses the shared default from the singularity repo, so improvements there keep reaching this project.

```yaml
commands:
  install: TODO
  build: TODO
  lint: TODO
  typecheck: TODO
  test: TODO
  test_one: TODO            # run one test file, e.g. "npm test -- {file}"
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
  breaking_changes: forbidden   # allowed = no backward compatibility required when a refactor improves the codebase (contracts still tested)

tracker:
  type: none                # jira | github | gitlab | none
  # jira:   { site: yourco.atlassian.net, project: ABC }
  # github: { repo: org/repo }
  # gitlab: { host: gitlab.com, project: group/repo }
  states:                   # logical state -> Jira status, or label for GitHub/GitLab
    in_progress: "In Progress"
    in_review: "In Review"
    done: "Done"
  updates: true             # false = read tickets but never comment or move them

code_host:
  type: github              # github | gitlab
  # gitlab: { host: gitlab.com, project: group/repo }

# Rebind a role to another agent, or change its model/effort. Omit to keep the shared default.
# Shared defaults: spec/plan/learn = opus high, implement = sonnet medium, review = fable high,
#                  verify = sonnet low, optimize = fable xhigh
roles: {}
  # implement: { agent: android-implementer }     # a project agent in .claude/agents/
  # review:    { model: opus, effort: xhigh }     # e.g. if Fable isn't enabled for your org

review:
  lenses: [correctness, security, maintainability, testability]   # the shared lenses; drop one here only with a reason
  extra_lenses: []          # - { name: performance, description: "N+1 queries, missing pagination" }
  extra_reviewers: []       # project agents in .claude/agents/, e.g. [review-domain]

stages:                     # project agents inserted into the shared pipeline
  after_plan: []
  after_implement: []
  before_handoff: []

learning:
  enabled: true
  dir: .claude/singularity/experience
  max_lines_per_file: 60

optimization:
  every_runs: 10            # suggest /singularity:optimize after this many pipeline runs
  web_scan: true            # optimizer checks new Claude Code features, models and research
  max_eval_cost_usd: 10     # spending ceiling for validation runs
```

## Do not touch
<!-- Paths agents must not modify without asking: generated code, vendored libs, released migrations -->
