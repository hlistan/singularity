#!/usr/bin/env bash
# Tests for the whole-change diff the reviewers read:
#   plugins/singularity/scripts/change-diff.sh
# Run: bash tests/change-diff.test.sh
# CI runs it on Linux (bash 5) and on macOS /bin/bash (3.2), so keep both this file and the script 3.2-compatible.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/plugins/singularity/scripts/change-diff.sh"
SH="${BASH:-bash}"
pass=0
fail=0
current=""

setup() { # a repository with a base commit and a feature branch
  WORK="$(mktemp -d)"
  cd "$WORK" || exit 1
  git init -q -b main .
  git config user.email t@example.com
  git config user.name t
  mkdir -p src
  printf 'one\n' > src/a.js
  printf 'build/\n' > .gitignore
  git add -A && git commit -q -m base
  BASE="$(git rev-parse HEAD)"
  git checkout -q -b feature
}
teardown() { cd "$ROOT" || exit 1; rm -rf "$WORK"; }
run() { OUT="$("$SH" "$SCRIPT" "$@" 2>&1)"; CODE=$?; }
test_case() { current="$1"; }
ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); printf 'FAIL [%s] %s\n' "$current" "$1"; printf '%s\n' "$OUT" | sed 's/^/    /'; }
expect_code() { if [ "$CODE" -eq "$1" ]; then ok; else ko "exit $CODE, expected $1"; fi; }
expect_out() { case "$OUT" in *"$1"*) ok ;; *) ko "output lacks: $1" ;; esac; }
expect_no_out() { case "$OUT" in *"$1"*) ko "output has: $1" ;; *) ok ;; esac; }

test_case "committed, staged, modified and new files are all in the change"
setup
printf 'two\n' > src/committed.js && git add -A && git commit -q -m c1
printf 'three\n' > src/staged.js && git add src/staged.js
printf 'one\nmore\n' > src/a.js
mkdir -p src/new && printf 'brand new\n' > src/new/module.js
mkdir -p build && printf 'artifact\n' > build/out.js
run "$BASE"
expect_code 0
expect_out "+two"
expect_out "+three"
expect_out "+more"
expect_out "+++ b/src/new/module.js"
expect_out "+brand new"
expect_no_out "artifact"
teardown

test_case "--stat lists new files with their line counts"
setup
printf 'x\ny\n' > src/fresh.js
printf 'one\nmore\n' > src/a.js
run "$BASE" --stat
expect_code 0
expect_out "src/a.js"
expect_out "src/fresh.js (new, 2 lines)"
teardown

test_case "runs from a subdirectory, and with --root"
setup
printf 'x\n' > src/fresh.js
cd src || exit 1
run "$BASE"
expect_out "+++ b/src/fresh.js"
cd "$ROOT" || exit 1
run "$BASE" --root "$WORK"
expect_out "+++ b/src/fresh.js"
teardown

test_case "a file name with spaces"
setup
printf 'x\n' > "src/with space.js"
run "$BASE"
expect_out "with space.js"
teardown

test_case "no change prints nothing"
setup
run "$BASE"
expect_code 0
if [ -z "$OUT" ]; then ok; else ko "printed something"; fi
teardown

test_case "--hash changes with every write, staging change and commit, and only then"
setup
printf 'one\nmore\n' > src/a.js
printf 'x\n' > src/fresh.js
run "$BASE" --hash
expect_code 0
case "$OUT" in *[!0-9a-f]*|'') ko "not a hash" ;; *) ok ;; esac
H0="$OUT"
run "$BASE" --hash
[ "$OUT" = "$H0" ] && ok || ko "same state, different hash"
printf 'y\n' > src/fresh.js
run "$BASE" --hash
[ "$OUT" != "$H0" ] && ok || ko "a new file's write kept the hash"
H1="$OUT"
printf 'one\nother\n' > src/a.js
run "$BASE" --hash
[ "$OUT" != "$H1" ] && ok || ko "a tracked file's write kept the hash"
H2="$OUT"
git add src/a.js
run "$BASE" --hash
[ "$OUT" != "$H2" ] && ok || ko "staging kept the hash"
H3="$OUT"
git commit -q -m wip
run "$BASE" --hash
[ "$OUT" != "$H3" ] && ok || ko "a commit kept the hash"
H4="$OUT"
mkdir -p build && printf 'artifact\n' > build/out.js
run "$BASE" --hash
[ "$OUT" = "$H4" ] && ok || ko "an ignored file changed the hash"
teardown

test_case "usage errors"
setup
run
expect_code 2
run not-a-commit
expect_code 2
expect_out "unknown base"
run "$BASE" --bogus
expect_code 2
run "$BASE" --stat --hash
expect_code 2
NOGIT="$(mktemp -d)"
run "$BASE" --root "$NOGIT"
expect_code 2
rm -rf "$NOGIT"
teardown

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
