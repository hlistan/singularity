#!/usr/bin/env bash
# Tests for the guideline staleness check:
#   plugins/singularity/scripts/check-guidelines.sh
# Run: bash tests/check-guidelines.test.sh
# CI runs it on Linux (bash 5) and on macOS /bin/bash (3.2), so keep both this file and the script 3.2-compatible.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/plugins/singularity/scripts/check-guidelines.sh"
SH="${BASH:-bash}"
pass=0
fail=0
current=""

setup() { # a small repository with code, a nested package and docs
  WORK="$(mktemp -d)"
  cd "$WORK" || exit 1
  git init -q .
  mkdir -p src/api src/gen docs packages/billing/src .claude/singularity/guidelines .claude/rules/singularity
  printf 'x\n' > src/api/routes.ts
  printf 'x\n' > src/gen/client.ts
  printf 'x\n' > docs/openapi.yaml
  printf 'x\n' > packages/billing/src/index.ts
  printf 'x\n' > Makefile
  git add -A
}
teardown() { cd "$ROOT" || exit 1; rm -rf "$WORK"; }
guideline() { printf '%s\n' "$2" > ".claude/singularity/guidelines/$1"; } # guideline FILE CONTENT
rule() { printf '%s\n' "$2" > ".claude/rules/singularity/$1"; }           # rule FILE CONTENT
run() { OUT="$("$SH" "$SCRIPT" "$@" 2>&1)"; CODE=$?; }                    # sets OUT, CODE
test_case() { current="$1"; }
ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); printf 'FAIL [%s] %s\n' "$current" "$1"; printf '%s\n' "$OUT" | sed 's/^/    /'; }
expect_code() { if [ "$CODE" -eq "$1" ]; then ok; else ko "exit $CODE, expected $1"; fi; }
expect_out() { case "$OUT" in *"$1"*) ok ;; *) ko "output lacks: $1" ;; esac; }
expect_no_out() { case "$OUT" in *"$1"*) ko "output has: $1" ;; *) ok ;; esac; }

test_case "current paths, globs, line refs, nested and bare names pass"
setup
guideline project.md '# Project guidelines

## API

- **G1** Register endpoints in `src/api/routes.ts` (see `src/api/routes.ts:12`
  and `routes.ts#L10`), and describe them in `openapi.yaml`.
- **G2** Never edit `src/gen/`; regenerate with `make gen`.
- **G3** Tests live next to the code: `src/**/*.ts`.
- **G4** In the billing package, start from `src/index.ts`.'
run
expect_code 0
expect_out "check-guidelines: clean"
teardown

test_case "spans that aren't repository paths are left alone"
setup
guideline implement.md '# Implementation guidelines

- **G5** Compare with `origin/main`; responses are `application/json`; read
  `process.env` and call `res.json`; round with `Math.floor`; call
  `res.json()`; run `npm test -- <file>`; serve `/api/admin`; name files
  `.ts`; import `github.com/pkg/errors`; branch as `feature/ABC-1-name`.
1. **G6** Numbered guidelines are checked too: `src/api/routes.ts`.'
run
expect_code 0
teardown

test_case "a path that is gone is reported with file and line"
setup
guideline implement.md '# Implementation guidelines

- **G7** Start the server from `server/app.ts`.'
run
expect_code 1
expect_out '.claude/singularity/guidelines/implement.md:3: `server/app.ts` doesn'"'"'t exist'
expect_out "1 finding(s)"
teardown

test_case "numbered list items are checked"
setup
guideline plan.md '# Plan guidelines

1. **G8** Put migrations in `db/migrations/`.'
run
expect_code 1
expect_out 'plan.md:3: `db/migrations/` doesn'"'"'t exist'
teardown

test_case "a file deleted in the working tree is reported"
setup
guideline project.md '- **G1** Routes are in `src/api/routes.ts`.'
rm src/api/routes.ts
run
expect_code 1
expect_out '`src/api/routes.ts` doesn'"'"'t exist'
teardown

test_case "a nested file added in this change, not yet committed, passes"
setup
printf 'x\n' > packages/billing/src/invoices.ts
guideline project.md '- **G1** In the billing package, invoices are in `src/invoices.ts`.'
run
expect_code 0
teardown

test_case "a literal path with brackets passes"
setup
mkdir -p "app/[slug]"
printf 'x\n' > "app/[slug]/page.tsx"
guideline project.md '- **G1** The page is `app/[slug]/page.tsx`.'
run
expect_code 0
teardown

test_case "a git-ignored path that isn't on disk passes"
setup
printf 'dist/\n' > .gitignore
guideline verify.md '- **G1** The bundle is written to `dist/bundle.js`.'
run
expect_code 0
teardown

test_case "spans in check-ignore.txt are not paths"
setup
guideline review.md '- **G1** Don'"'"'t bring back `lib/legacy-retry.js`; use `src/api/routes.ts`.'
printf '# not paths\nlib/legacy-retry.js\n' > .claude/singularity/guidelines/check-ignore.txt
run
expect_code 0
teardown

test_case "rule paths: list, inline and comma forms, braces, comments"
setup
rule api.md '---
paths:
  - "src/api/**"   # the API layer
  - src/**/*.{ts,tsx}
  - "server/**"
---
# API guidelines

- **G9** Validate input in `src/api/routes.ts`.'
rule gen.md '---
paths: ["src/gen/**", "src/{gen,api}/*.ts", "legacy/**"]
---
# Generated code

- **G10** Regenerate, never edit.'
rule docs.md '---
paths: "docs/*.yaml, *.yaml"
---
# Docs

- **G11** Keep the spec in `openapi.yaml`.'
run
expect_code 1
expect_out '.claude/rules/singularity/api.md:5: paths pattern "server/**" matches no file'
expect_out '.claude/rules/singularity/gen.md:2: paths pattern "legacy/**" matches no file'
expect_out '.claude/rules/singularity/docs.md:2: paths pattern "*.yaml" matches no file'
expect_no_out '"src/api/**" matches'
expect_no_out 'src/**/*.{ts,tsx}" matches'
expect_no_out '"src/gen/**" matches'
expect_no_out 'src/{gen,api}/*.ts" matches'
expect_no_out '"docs/*.yaml" matches'
expect_out "3 finding(s)"
teardown

test_case "**/ also matches at the root"
setup
printf 'x\n' > index.ts
rule ts.md '---
paths: ["**/*.ts"]
---
- **G12** Use strict TypeScript.'
run
expect_code 0
teardown

test_case "rules without paths, and unquoted patterns, are reported"
setup
rule everywhere.md '# Everywhere

- **G13** Always loaded.'
rule broken.md '---
paths:
  - *.ts
---
- **G14** Broken pattern.'
run
expect_code 1
expect_out 'everywhere.md:1: no paths frontmatter'
expect_out 'broken.md:3: quote the paths pattern *.ts'
teardown

test_case "a guideline id used twice is reported"
setup
guideline implement.md '- **G20** Build with `make build`.'
guideline verify.md '- **G20** Run the smoke test.'
run
expect_code 1
expect_out 'guideline id G20 is used more than once: .claude/singularity/guidelines/implement.md:1, .claude/singularity/guidelines/verify.md:1'
teardown

test_case "lesson-log wording is reported, ordinary prose isn't"
setup
guideline review.md '# Review guidelines

- **L3** Do not flag `src/gen/`. _Why:_ rejected in review.
  _Seen:_ 9 · _Last:_ 2026-10-10 · _Refs:_ KB-101
- **G4** An order is no longer editable once it has shipped.'
run
expect_code 1
expect_out "review.md:3: an old lesson id"
expect_out "review.md:3: lesson-log fields"
expect_out "review.md:4: lesson-log fields"
expect_no_out "review.md:5"
teardown

test_case "fenced code blocks and prose are skipped"
setup
guideline plan.md '# Plan guidelines

Written by the optimizer; format: singularity `optimizer/learn.md`. Rules
live in `.claude/rules/singularity/`.

```text
`server/app.ts` _Seen:_ 1
```

- **G2** Plans name the files they change, such as `src/api/routes.ts`, and
  the fixtures in `test/fixtures/orders.json`.'
run
expect_code 1
expect_no_out 'optimizer/learn.md'
expect_no_out 'server/app.ts'
expect_out 'plan.md:11: `test/fixtures/orders.json` doesn'"'"'t exist'
teardown

test_case "the project templates are clean"
setup
rm -rf .claude
cp -R "$ROOT/plugins/singularity/templates/project/." .
run
expect_code 0
teardown

test_case "no guideline files"
setup
rm -rf .claude
run
expect_code 0
expect_out "no guideline files"
teardown

test_case "--root, outside git, and usage errors"
setup
guideline project.md '- **G1** Routes are in `src/api/routes.ts`.'
cd "$ROOT" || exit 1
run --root "$WORK"
expect_code 0
NOGIT="$(mktemp -d)"
run --root "$NOGIT"
expect_code 2
expect_out "is not a git repository"
rm -rf "$NOGIT"
run --bogus
expect_code 2
cd "$WORK" || exit 1
teardown

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
