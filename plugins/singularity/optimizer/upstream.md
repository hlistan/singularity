# Report upstream: improve the singularity plugin

The optimizer's playbook for upstream reports. The plugin (its agents, this optimizer included, its skills, workflows, standards, templates and defaults) is shared by every project, and only its maintainers change it: a fix that is right for one project can break the others, and a release is how a change reaches them all. So when the evidence says the plugin itself holds this project back, you don't edit it. You write an **upstream report**: the problem, the evidence and the fix you propose, in a form the maintainers can adopt.

## When the cause is upstream

A failure belongs upstream when the same fix would be right in any project:

- a shared agent's instructions cause it, such as the reviewer flagging a pattern that is fine anywhere, or the planner never asking for a rollback step;
- the pipeline protocol causes it: a missing stage, the wrong order, a gate without what the human needs to decide;
- a shared default doesn't fit the work: a role's model or effort, a lens description;
- a shared standard is wrong, missing or ambiguous;
- a template, or the onboarding, leaves a gap that every project has to fill;
- a bug in a workflow, script or hook;
- a Claude Code feature or model that the plugin should use, from the practice scan;
- a candidate in `experience/upstream.md` that isn't specific to this project, with evidence from at least two runs;
- a problem the user reports with singularity itself. Their account is evidence; find the cause in the plugin's files before you write.

If the fix would be right only for this project's stack or domain, it is a project change (`optimize.md`), not a report.

## Before you write

1. Find the cause in the plugin's files under `<plugin root>`, at the installed version (`version` in `<plugin root>/.claude-plugin/plugin.json`), and quote the lines.
2. Check that it isn't known already: read the reports in `.claude/singularity/upstream/`, and, if the plugin's repository (`repository` in `plugin.json`) is on GitHub and `gh` is signed in, search its issues, read-only: `gh issue list --repo <owner/repo> --state all --search "<keywords>"`. If it is known, add your evidence to the existing report, or tell the user which issue to add it to.
3. Decide whether the project needs a **local workaround** until a release fixes it: the smallest project change that helps, such as a guideline in a role's file, a lens or a role override. It is an ordinary proposal with its own contract, marked as the report's workaround.

## The report

One file per report, `.claude/singularity/upstream/U-<YYYY-MM-DD>-<n>-<slug>.md`, in the format in that directory's `README.md` and wrapped at 80 columns:

- **status**, **plugin version** and **component** (the file, and the section in it);
- **Problem**: what goes wrong, in which stage, and why the cause is in the plugin rather than in the project;
- **Evidence**: counts and categories;
- **Proposed fix**: the exact change, as file, current text and proposed text;
- **Contract**: what it should fix, what it might break, and how to validate it, ideally with the sketch of a plugin eval case (prompt and grader);
- **Workaround**: what the project does until the fix ships, and when to remove it.

## Keep it publishable

The singularity repository is public, and a report has to be safe to paste there unchanged:

- no names of the project, company, product, repositories, branches, hosts, tracker sites or people, and no ticket keys;
- no code from the project: describe the pattern, or write a minimal generic example;
- evidence as counts and categories ("4 of 23 runs; category 'missing authz check'; 2 escaped to human review"), not run refs;
- no secrets, personal or customer data.

These rules cover the whole report, its Workaround section included: describe the workaround in general terms ("a project guideline tells the reviewer to skip generated files"). The refs behind each number stay in the project: in `proposals.md` in the run directory, and in the PR/MR description.

## Deliver and file

- Reports are tier 1. A new report has status `draft`. One written in an optimization is committed on the optimizer's branch, and the team reviews it in the PR/MR with everything else; a single report the user asked for is written in their checkout, uncommitted, for them to review and commit. Before that, the challenger (`singularity:reviewer`, Task C) checks each one: is the cause really in the plugin, would the fix hold for projects unlike this one, is there a smaller fix, and is the report free of anything that identifies the project?
- **Approved** means the team merged it: a `draft` report on the default branch is approved and waiting to be filed. A user who wants to file a report before the merge can say so explicitly.
- **Filing.** For each approved report, offer to file it as an issue in the plugin's repository. Show the exact title and body first, and file only on the user's explicit yes, because the issue is public and leaves the project: `gh issue create --repo <owner/repo> --title "[upstream] <title>" --body-file <report>`. Then set the report's status to `filed <issue URL>`, in your worktree, so the change goes through the next PR/MR. Without `gh`, or for a repository on another host, give the user the file to send to the maintainers.
- Unattended: never file, and leave reports at `draft`.

## Follow up

At each run, check each report with status `filed`, read-only: `gh issue view <number> --repo <owner/repo> --json state,stateReason,comments`.

- **Fixed in a release that the project runs** (`plugin_version` in `runs.jsonl`): check the failure category against the report's contract, set the status to `adopted <version>`, and propose removing the local workaround as an ordinary proposal.
- **Declined**: record the maintainers' reason, and set the status to `declined`. Keep the workaround only while its own contract holds.
