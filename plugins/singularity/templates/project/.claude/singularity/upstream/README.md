# Upstream reports

Problems this project found in the shared singularity plugin, each with a
proposed fix, for the singularity maintainers to adopt. The singularity
optimizer writes them; the team reviews them in the optimizer's PR/MR, and
files the ones it approves as issues in the singularity repository.

Guidelines the optimizer thinks would be right in every project collect
first in `../experience/upstream.md`. The optimizer turns the ones with enough
evidence into reports here.

Reports are written to be published, every section of them. They leave
out the names of this project, its repositories, hosts, tracker and people,
ticket keys, and code from it. The refs behind the evidence stay in the
optimizer's PR/MR.

One file per report, `U-<date>-<n>-<slug>.md`:

````markdown
# U-2026-10-14-1 · Reviewer flags generated clients as duplication

- Status: draft
- Plugin version: 0.5.0
- Component: `agents/reviewer.md`, maintainability lens

## Problem

What goes wrong, in which stage, and why the cause is in the shared
plugin rather than in this project.

## Evidence

Counts and categories, for example: 6 of 31 findings in 14 runs were
rejected as false positives, category "duplication in generated code".

## Proposed fix

The exact change: the file, the current text and the proposed text.

## Contract

- Should fix: …
- Might break: …
- How to validate: a plugin eval case (prompt and grader sketch), or a
  canary.

## Workaround

What this project does until the fix is released (`O-…` in
`../experience/optimizations.md`), and when to remove it.
````

Statuses: `draft` (under review, or approved once it is on the default
branch) → `filed <issue URL>` → `adopted <version>` or `declined`.
