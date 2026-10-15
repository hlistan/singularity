#!/usr/bin/env bash
# Tests for the test-integrity guard:
#   plugins/singularity/scripts/test-guard.sh
# Run: bash tests/test-guard.test.sh
# CI runs it on Linux (bash 5) and on macOS /bin/bash (3.2), so keep both this file and the script 3.2-compatible.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/plugins/singularity/scripts/test-guard.sh"
SH="${BASH:-bash}"
pass=0
fail=0
current=""

setup() { # a project with code and tests at a base commit, on a feature branch
  WORK="$(mktemp -d)"
  cd "$WORK" || exit 1
  git init -q -b main .
  git config user.email t@example.com
  git config user.name t
  mkdir -p .claude src tests
  printf '# config\n\n```yaml\nconventions:\n  work_dir: .agentic/work\n```\n' > .claude/singularity.md
  printf 'export const total = () => 0\n' > src/total.js
  printf 'test("total", () => {})\n' > tests/total.test.js
  printf 'test("old", () => {})\n' > tests/old.test.js
  git add -A && git commit -q -m base
  BASE="$(git rev-parse HEAD)"
  git checkout -q -b feature
}
teardown() { cd "$ROOT" || exit 1; rm -rf "$WORK"; }
run() { OUT="$("$SH" "$SCRIPT" --root "$WORK" "$@" 2>&1)"; CODE=$?; }
edit_hook() { # edit_hook <tool> <path field> <path>
  OUT="$(printf '{"session_id":"s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":{"%s":"%s","content":"x"}}' "$1" "$2" "$3" \
    | CLAUDE_PROJECT_DIR="$WORK" "$SH" "$SCRIPT" pre-edit 2>&1)"
  CODE=$?
}
test_case() { current="$1"; }
ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); printf 'FAIL [%s] %s\n' "$current" "$1"; printf '%s\n' "$OUT" | sed 's/^/    /'; }
expect_code() { if [ "$CODE" -eq "$1" ]; then ok; else ko "exit $CODE, expected $1"; fi; }
expect_out() { case "$OUT" in *"$1"*) ok ;; *) ko "output lacks: $1" ;; esac; }
expect_no_out() { case "$OUT" in *"$1"*) ko "output has: $1" ;; *) ok ;; esac; }

test_case "test files are recognised in common layouts"
setup
run is-test tests/a.js src/__tests__/b.js spec/c_spec.rb pkg/x_test.go src/d.test.ts src/e.spec.js \
  test_f.py app/src/test/java/GTest.java src/HTests.cs src/main.js src/latest.js src/contest/x.js
expect_out "tests/a.js"
expect_out "src/__tests__/b.js"
expect_out "spec/c_spec.rb"
expect_out "pkg/x_test.go"
expect_out "src/d.test.ts"
expect_out "src/e.spec.js"
expect_out "test_f.py"
expect_out "GTest.java"
expect_out "HTests.cs"
expect_no_out "src/main.js"
expect_no_out "latest.js"
expect_no_out "contest"
teardown

test_case "a frozen test can't be edited, by absolute or relative path, and other files can"
setup
printf 'test("new", () => { expect(total()).toBe(3) })\n' > tests/new.test.js
run freeze tests/new.test.js
expect_code 0
expect_out "frozen tests/new.test.js"
edit_hook Edit file_path "$WORK/tests/new.test.js"
expect_code 2
expect_out "tests/new.test.js is a frozen test"
expect_out "stop and say so"
edit_hook Write file_path "$WORK/src/total.js"
expect_code 0
edit_hook Write file_path "$WORK/tests/total.test.js"
expect_code 0
edit_hook NotebookEdit notebook_path "$WORK/tests/new.test.js"
expect_code 2
OUT="$(git status --porcelain --untracked-files=all)"
case "$OUT" in *.agentic*) ko "the frozen list is visible to git" ;; *) ok ;; esac
teardown

test_case "without frozen tests, every edit passes"
setup
edit_hook Edit file_path "$WORK/tests/total.test.js"
expect_code 0
teardown

test_case "check: a frozen test changed or deleted after freezing is reported"
setup
printf 'test("a", () => {})\n' > tests/a.test.js
printf 'test("b", () => {})\n' > tests/b.test.js
run freeze tests/a.test.js tests/b.test.js
run check --base "$BASE"
expect_code 0
expect_out "tests intact"
printf 'test.skip("a", () => {})\n' > tests/a.test.js
rm tests/b.test.js
run check --base "$BASE"
expect_code 1
expect_out "tests/a.test.js: a frozen test was changed after it was frozen"
expect_out "tests/b.test.js: a frozen test was deleted"
teardown

test_case "check: an existing test changed or deleted is reported unless the plan names it"
setup
printf 'test("total", () => { /* weakened */ })\n' > tests/total.test.js
git rm -q tests/old.test.js
printf 'export const total = () => 3\n' > src/total.js
run check --base "$BASE"
expect_code 1
expect_out "tests/total.test.js: an existing test was changed"
expect_out "tests/old.test.js: an existing test was deleted"
expect_no_out "src/total.js"
printf '# Plan\n\n- [ ] 1. Replace `tests/old.test.js`, which covers the removed API.\n' > plan.md
run check --base "$BASE" --plan plan.md
expect_code 1
expect_no_out "old.test.js"
expect_out "tests/total.test.js"
teardown

test_case "check: committed changes count, and new tests are fine"
setup
printf 'test("total", () => { expect(1).toBe(1) })\n' > tests/total.test.js
git commit -q -am "weaken"
printf 'test("brand new", () => {})\n' > tests/brand.test.js
run check --base "$BASE"
expect_code 1
expect_out "tests/total.test.js: an existing test was changed"
expect_no_out "brand.test.js"
teardown

test_case "a project's own test pattern"
setup
printf '# config\n\n```yaml\nconventions:\n  work_dir: .agentic/work\nchecks:\n  test_pattern: "(^|/)checks/"\n```\n' > .claude/singularity.md
run is-test checks/a.js tests/b.test.js
expect_out "checks/a.js"
expect_no_out "tests/b.test.js"
teardown

test_case "freezing again replaces the entry, and reset forgets everything"
setup
printf 'test("n", () => {})\n' > tests/n.test.js
run freeze tests/n.test.js
printf 'test("n", () => { expect(1).toBe(2) })\n' > tests/n.test.js
run freeze "$WORK/tests/n.test.js"
run check --base "$BASE"
expect_code 0
run reset
edit_hook Edit file_path "$WORK/tests/n.test.js"
expect_code 0
teardown

test_case "usage errors"
setup
run freeze
expect_code 2
run freeze tests/missing.test.js
expect_code 2
run check
expect_code 2
run check --base nope
expect_code 2
run bogus
expect_code 2
OUT="$(printf 'not json' | CLAUDE_PROJECT_DIR="$WORK" "$SH" "$SCRIPT" pre-edit 2>&1)"; CODE=$?
expect_code 0
teardown

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
