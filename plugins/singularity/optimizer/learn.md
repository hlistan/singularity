# Learn: turn a run into current guidelines

The optimizer's playbook for the step at the end of every `/singularity:feature` run (and for the human reviews of earlier runs that the pipeline hands over). It is the fast part of the loop: one run's evidence, turned into **guidelines**, how to do things correctly in this project as it is now. Agents follow guidelines, not history, so a guideline states the current right way and nothing else; what happened, and why, goes into the run digest. This job doesn't change agents, config or protocol: optimizations do, from the record this job leaves. It does no web research and starts no subagents, so it stays cheap enough for every run. Curate strictly.

When a run shows the work drifting from what users need (`goals.md`), such as a spec that missed a constraint the team holds to, the guideline goes to the role that drifted.

## Where things live

| Path | Read by | Holds |
|---|---|---|
| `.claude/singularity/guidelines/project.md` | every session (CLAUDE.md imports it) | guidelines every role needs anywhere in the code |
| `.claude/singularity/guidelines/{spec,plan,implement,review,verify}.md` | the agent bound to that role | guidelines for that role's work |
| `.claude/rules/singularity/<area>.md` | any agent working on files its `paths` match; Claude Code loads it then | guidelines for one part of the code |
| `<learning.dir>/runs.jsonl` (default `.claude/singularity/experience/`) | you, when you optimize | the record: one digest line per run, per human review and per curation |
| `<learning.dir>/upstream.md` | you, for upstream reports | guidelines that would be right in any project, with their evidence |
| `<learning.dir>/optimizations.md` | you, when you optimize | the optimization archive; this job doesn't change it |
| `.claude/singularity/evals/` | you, when you validate | regression eval cases |
| `.claude/singularity/goals.md` | you, the spec writer and the planner | what the project is for. The team's: this job doesn't change it |

In this job, use Bash only for `git diff`, `git log`, `diff`, `date` and the guideline check, `bash "<plugin root>/scripts/check-guidelines.sh"`. If `<learning.dir>` still holds the lesson files from before 0.5.0 (`project.md`, `spec.md` and the other role files), write no guidelines: say so in your report, and migrate them first (`onboard.md`, "Migrating lessons") when you are asked to.

## What changes the guidelines

Use only evidence from the run and the human reviews you were given:

| Evidence | Guideline goes to |
|---|---|
| Confirmed review findings (what the implementer missed) | `implement.md`, `plan.md` if the plan caused it, or the rule for that area |
| Rejected review findings (false positives) | `review.md` or the rule for that area: what is intended there, and why |
| Verification failures, rework rounds | `implement.md` or `verify.md` |
| `spec.draft.md` vs `spec.md` | `spec.md` |
| `plan.draft.md` vs `plan.md` | `plan.md` |
| Human PR/MR review comments (`human-review.md`) | `review.md` (what reviewers missed) and `implement.md`, or the rule for that area |
| The run's own change (`git diff <base>`, the base from the run record or the merge base with `conventions.default_branch`): code it renamed, moved, removed or replaced | every guideline that describes that code |
| Facts every role needs anywhere in the code | `project.md` |

## Guideline format

```markdown
## API

- **G12** Register a new REST endpoint in `api/routes.ts` and describe it
  in `openapi.yaml`, the contract that client teams generate from.
```

Group guidelines under topic headings. Never reuse an id: take the next number above the highest in the guideline files, the rules and `runs.jsonl`. A rule file always starts with frontmatter listing the `paths` it applies to (`paths: ["api/**"]`), so that it loads only there.

## Curation rules

1. **The current right way, in the present tense.** Say what to do, where, and with which command. Don't record what went wrong, when, in which ticket or how often: that goes into the digest. Give a reason only when it is a current fact about the code or the team.
2. **Grounded in the code.** Name the files, commands and symbols a guideline depends on, in backticks, and check that each exists before you write it. Point to files rather than copying code, which goes stale.
3. **One home.** `project.md` only for what every role needs anywhere; a rule for one part of the code; a role file for one role's work. Don't repeat the shared engineering standards, `CLAUDE.md` or the config.
4. **Change with the code.** When this run's change makes a guideline wrong, correct or remove it now, so the PR/MR carries both.
5. **Replace, don't annotate.** When the evidence contradicts a guideline, rewrite it to the new truth, and say so in your report. Never add "no longer", "used to" or "since" notes. Code that is gone takes its guidelines with it, unless agents keep reaching for it: then keep one guideline that states the current way and names the old one, once, as the one not to use (list the old name in `check-ignore.txt`, below).
6. **A check beats a guideline.** If a lint rule, a type, a test, a hook or a config setting could enforce it, write the guideline and propose the check (`proposed_checks` in the digest; an optimization implements it). A guideline is only context; a check is enforced. The change that adds the check removes the guideline.
7. **Edit, don't rewrite.** Change individual guidelines. Never regenerate a whole file: wholesale rewrites lose detail.
8. **Stay within limits.** `learning.max_lines_per_file` (default 60; 40 for `project.md`) counts guidelines, however many lines each wraps over. When a file is full, merge and generalize, and move guidelines about one part of the code into rules. Don't drop a guideline that is still true; list the file under `full` in the digest.
9. **Wrap at 80 columns.** Projects lint these files with markdownlint. Continue a guideline on lines indented by two spaces, as above, and never break inside a code span or a URL. The same goes for eval cases (`case.md`).
10. **Never record** secrets, credentials, personal or customer data, or blame.

Before you finish, run the guideline check and fix each finding. A span it reports that isn't a path at all goes into `.claude/singularity/guidelines/check-ignore.txt`, one per line, rather than changing a true guideline.

**Upstream candidates.** A guideline that would be right in any project, not just this one, also goes into `upstream.md` with its evidence (counts and refs). They become upstream reports in an optimization (`upstream.md`).

## Run digest (append one line to runs.jsonl)

After a pipeline run, using the run record you were given:

```json
{"type":"run","date":"2026-10-13","ticket":"ABC-123","slug":"abc-123-health","pipeline":"feature","plugin_version":"0.1.0",
 "branch":"feature/ABC-123-health","change":"!123","kind":"feature","goal":"faster checkout",
 "lead_s":5400,"active_s":1225,"fix_rounds":1,
 "models":{"implement":"sonnet","review":"fable"},
 "stages":{"spec":{"s":95,"tokens":31000},"plan":{"s":140},"implement":{"s":610,"tokens":220000},"review":{"s":300},"verify":{"s":80}},
 "gate_edits":{"spec":false,"plan":true},"gate_edit_kinds":["missing rollback step"],"gate_wait_s":{"spec":420,"plan":95},
 "review_rounds":1,"verify_first_pass":true,
 "findings":[{"lens":"security","severity":"blocking","category":"missing authz check","stage":"plan","path":"src/api/orders.ts","confirmed":true,"guideline":"G12","covered_by":"G4"}],
 "guidelines":{"added":["G12"],"changed":["G3"],"removed":["G7"]},"proposed_checks":["lint: forbid floats in money code"],"full":["project.md"],
 "proposals":["the security lens misses ownership checks in api/: add an authz lens"]}
```

`branch` and `change` (the PR/MR, if one was opened) let the pipeline find the human review later. `kind` (feature, defect or refactoring) and `goal`, the goal in `goals.md` that the spec says the work serves (or `maintenance`), show where the effort goes. The flow fields come from the run record: `lead_s` from start to hand-off, `active_s` the time the stages worked, `gate_wait_s` the wait at each gate, and `fix_rounds`; a run that stopped early gets its digest too, with `stopped` and the reason, and a stopped run that is later resumed gets another one when it ends, with `resumed: true`. Leave out a time the run record doesn't have; never estimate one. If this run fixes a defect in code that an earlier pipeline run changed (the spec's root cause names the code, and `git log` on it shows a commit from a branch in `runs.jsonl`, or a merge or squash commit naming that run's PR/MR, such as `#123` or `!123`), set `fixes` to that run's `slug`: it is the pipeline's change-failure signal. `proposals` are changes to config, agents or the flow that the evidence suggests; this job doesn't make them, an optimization weighs them. `findings` lists confirmed **and** rejected findings (`confirmed:false`), each with a short reusable `category`, the stage at fault and the `path` of the file it is in. Reuse category names already in runs.jsonl so that optimizations can count them. Give a finding the `guideline` you added or changed for it, and `covered_by` an existing guideline that already said how to avoid it, which means that guideline isn't working. List every guideline you added, changed or removed under `guidelines`: this is where their history lives, so that an optimization can tell whether a guideline works. Leave out fields you don't have; never invent numbers.

After a human review, one line per change the pipeline gives you, with the `ref` and the run's `slug` it gives you (the pipeline uses them to avoid learning the same review twice), `outcome` (merged or closed) and `review_s`, the time from opening the PR/MR to merging or closing it, and an empty `escaped` list when the reviewers found nothing the agents missed:

```json
{"type":"human_review","date":"2026-10-14","ref":"!123","slug":"abc-123-health","outcome":"merged","review_s":86400,"escaped":[{"category":"missing authz check","severity":"blocking","stage":"review","path":"src/api/orders.ts","guideline":"G15","covered_by":"G4"}],"guidelines":{"added":["G15"]}}
```

Other jobs record the guidelines they write in a curation line:

```json
{"type":"curation","date":"2026-10-20","by":"optimizer","ref":"O-2026-10-20-onboard","guidelines":{"added":["G1","G2"]}}
```

## Regression eval cases from escaped defects

Every real defect that human reviewers found and the agents missed becomes an eval case, so that an optimization can prove a fix works:

- `.claude/singularity/evals/<id>/change.patch`: `git diff <base> <reviewed-commit>`, the change as the humans saw it (before the fix).
- `.claude/singularity/evals/<id>/case.md`, in this format:

```yaml
---
kind: recall              # recall = must be found; precision = known false positive that must NOT be flagged
lens: security
base: <commit sha on the default branch>
expect: "Endpoint /orders/:id returns other users' orders: no ownership check"
location: src/api/orders.ts:42
holdout: false
source: "!123 human review, 2026-10-14"
---
Short note on why it matters.
```

- Mark every 5th case `holdout: true` (count the existing cases) so that optimizations have a held-out set.
- When the team rejected a finding, you may create a `precision` case the same way.
- Never edit or delete existing cases, and don't create a second case for a defect that an existing case's `source` already names.

## Return

Per file: guidelines added, changed and removed, one line each with its id; what the guideline check reported and what you fixed. Then: eval cases created, checks and other changes proposed for the next optimization, `stopped` or `fixes` if the digest has them, upstream candidates added.
