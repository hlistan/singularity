# Report upstream: improve the singularity plugin

The plugin (agents, this optimizer included; skills, workflows, standards, templates, defaults) is shared, and only its maintainers change it: a fix right for one project can break others. Don't edit it; write an **upstream report** (problem, evidence, proposed fix).

## When the cause is upstream

Upstream causes (the same fix would be right in any project):

- a shared agent's instructions (e.g. the reviewer flagging a pattern that is fine anywhere);
- the pipeline protocol: a missing stage, wrong order, a gate lacking what the human needs;
- a shared default that doesn't fit (a role's model or effort, a lens description);
- a wrong, missing or ambiguous shared standard;
- a template or the onboarding leaving a gap every project must fill;
- a bug in a workflow, script or hook;
- a Claude Code feature or model the plugin should use (practice scan);
- an `experience/upstream.md` candidate not specific to this project, with evidence from at least two runs;
- a problem the user reports with singularity itself: their account is evidence; find the cause in the plugin.

Fix right only for this project's stack or domain -> project change (`optimize.md`).

## Before you write

1. Find the cause under `<plugin root>` at the installed version (`version` in `<plugin root>/.claude-plugin/plugin.json`); quote the lines.
2. Check it isn't known: `.claude/singularity/upstream/` reports and, if the plugin's `repository` (`plugin.json`) is on GitHub and `gh` is signed in, its issues, read-only: `gh issue list --repo <owner/repo> --state all --search "<keywords>"`. Known -> add your evidence to that report, or tell the user which issue to add it to.
3. Needs a **local workaround** until a release? The smallest helpful project change, as an ordinary proposal with its own contract, marked as the report's workaround.

## The report

One file per report, `.claude/singularity/upstream/U-<YYYY-MM-DD>-<n>-<slug>.md`, in that directory's `README.md` format, wrapped at 80 columns:

- **status**, **plugin version** and **component** (file and section);
- **Problem**: what goes wrong, in which stage, why the cause is in the plugin, not the project;
- **Evidence**: counts and categories;
- **Proposed fix**: the exact change (file, current text, proposed text);
- **Contract**: what it should fix and might break, how to validate it, ideally with a sketched plugin eval case (prompt and grader);
- **Workaround**: what the project does until the fix ships; when to remove it.

## Keep it publishable

The singularity repository is public; the whole report, Workaround included, must be pasteable there unchanged:

- no names of the project, company, product, repositories, branches, hosts, tracker sites or people; no ticket keys;
- no project code: describe the pattern or give a minimal generic example;
- evidence as counts and categories ("4 of 23 runs; category 'missing authz check'; 2 escaped to human review"), not run refs;
- no secrets, personal or customer data;
- the workaround in general terms ("a project guideline tells the reviewer to skip generated files").

Run refs stay in the project (`proposals.md` in the run directory, the PR/MR description).

## Deliver and file

- Reports are tier 1; new ones have status `draft`. From an optimization -> committed on the optimizer's branch, reviewed in its PR/MR. A single report the user asked for -> their checkout, uncommitted, for their review and commit. First the challenger (`singularity:reviewer`, Task C) checks each: cause really in the plugin? fix holds for unlike projects? no smaller fix? nothing identifying the project?
- **Approved** means merged: a `draft` report on the default branch awaits filing. The user may explicitly ask to file before the merge.
- **Filing.** Offer to file each approved report as a plugin-repository issue; show the exact title and body; file only on the user's explicit yes (public, leaves the project): `gh issue create --repo <owner/repo> --title "[upstream] <title>" --body-file <report>`. Then set its status to `filed <issue URL>` in your worktree, for the next PR/MR. No `gh`, or another host -> give the user the file for the maintainers.
- Unattended: never file; leave reports at `draft`.

## Follow up

Each run, check `filed` reports read-only: `gh issue view <number> --repo <owner/repo> --json state,stateReason,comments`.

- **Fixed in a release that the project runs** (`plugin_version` in `runs.jsonl`): check the failure category against the report's contract, set status `adopted <version>`, and propose removing the local workaround.
- **Declined**: record the maintainers' reason; set status `declined`. Keep the workaround only while its contract holds.
