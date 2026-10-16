#!/usr/bin/env bash
# Tests for what became of the pipeline's changes after hand-off:
#   plugins/singularity/scripts/outcomes.sh
# Run: bash tests/outcomes.test.sh
# CI runs it on Linux (bash 5) and on macOS /bin/bash (3.2), so keep both this file and the script 3.2-compatible.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/plugins/singularity/scripts/outcomes.sh"
SH="${BASH:-bash}"
pass=0
fail=0
current=""
DAY=86400
NOW="$(date +%s)"

setup() { # a project on main with one base commit and an empty record
  WORK="$(mktemp -d)"
  cd "$WORK" || exit 1
  git init -q -b main .
  git config user.email t@example.com
  git config user.name t
  mkdir -p src .claude/singularity/experience
  printf '# config\n\n```yaml\nconventions:\n  default_branch: main\n```\n' > .claude/singularity.md
  printf '.agentic/\n' > .gitignore
  printf 'export const legacy = () => "unchanged legacy code"\n' > src/legacy.js
  : > .claude/singularity/experience/runs.jsonl
  at 30 git add -A
  at 30 git commit -q -m "chore: base"
  BASE="$(git rev-parse HEAD)"
}
teardown() { cd "$ROOT" || exit 1; rm -rf "$WORK"; }
at() { # at <days ago> <command...>: runs a git command with author and committer dates that many days ago
  local d="$1"; shift
  GIT_AUTHOR_DATE="@$((NOW - d * DAY)) +0000" GIT_COMMITTER_DATE="@$((NOW - d * DAY)) +0000" "$@"
}
run_line() { # run_line <slug> <branch> <change> [fixes]
  local extra=""
  [ -n "${4:-}" ] && extra=",\"fixes\":\"$4\""
  printf '{"type":"run","date":"2026-10-01","slug":"%s","branch":"%s","change":"%s"%s}\n' "$1" "$2" "$3" "$extra" \
    >> .claude/singularity/experience/runs.jsonl
}
orders() { # the pipeline's change: a new orders module
  printf 'export const total = order => order.items.reduce((s, i) => s + i.price, 0)\nexport const label = order => "Order " + order.id\n' > src/orders.js
}
fix_total() { # a person's fix of the pipeline's total
  printf 'export const total = order => order.items.reduce((s, i) => s + i.price * (1 + i.tax), 0)\nexport const label = order => "Order " + order.id\n' > src/orders.js
}
run() { OUT="$("$SH" "$SCRIPT" "$@" 2>&1)"; CODE=$?; }
test_case() { current="$1"; }
ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); printf 'FAIL [%s] %s\n' "$current" "$1"; printf '%s\n' "$OUT" | sed 's/^/    /'; }
expect_code() { if [ "$CODE" -eq "$1" ]; then ok; else ko "exit $CODE, expected $1"; fi; }
expect_out() { case "$OUT" in *"$1"*) ok ;; *) ko "output lacks: $1" ;; esac; }
expect_no_out() { case "$OUT" in *"$1"*) ko "output has: $1" ;; *) ok ;; esac; }
expect_lines() { local n; n="$(printf '%s' "$OUT" | grep -c .)"; if [ "$n" -eq "$1" ]; then ok; else ko "$n line(s), expected $1"; fi; }

test_case "a person's fix of lines from a run's squash-merged PR is a later fix of that run"
setup
run_line t1-orders feature/T1-orders "#12"
orders && at 20 git add src && at 20 git commit -q -m "feat: orders (#12)"
fix_total && at 10 git commit -q -am "fix: order total ignores tax"
FIX="$(git rev-parse --short=12 HEAD)"
run later-fixes
expect_code 0
expect_lines 1
LANDED="$(git rev-parse --short=12 HEAD^)"
expect_out "fix	$FIX	"
expect_out "	t1-orders	$LANDED	1	fix: order total ignores tax"
teardown

test_case "edits that don't read like a fix, and fixes of other code, are not later fixes"
setup
run_line t1-orders feature/T1-orders "#12"
orders && at 20 git add src && at 20 git commit -q -m "feat: orders (#12)"
sed 's/Order /Order #/' src/orders.js > src/x && mv src/x src/orders.js && at 10 git commit -q -am "feat: show order numbers"
printf 'export const legacy = () => "fixed legacy code"\n' > src/legacy.js && at 9 git commit -q -am "fix: legacy wording"
run later-fixes
expect_code 0
expect_lines 0
teardown

test_case "a revert of a run's commit is a later fix of kind revert"
setup
run_line t1-orders feature/T1-orders "#12"
orders && at 20 git add src && at 20 git commit -q -m "feat: orders (#12)"
at 5 git revert --no-edit HEAD >/dev/null
run later-fixes
expect_code 0
expect_out "revert	"
expect_out "	t1-orders	"
expect_out "	2	Revert "
teardown

test_case "a run's commits are found by their Singularity-Run trailer"
setup
run_line t2-users feature/T2-users ""
orders && at 20 git add src && at 20 git commit -q -m "feat: orders" -m "Singularity-Run: t2-users"
fix_total && at 10 git commit -q -am "fix: order total ignores tax"
run later-fixes
expect_out "	t2-users	"
teardown

test_case "lines from a merged run branch belong to the run"
setup
run_line t3-orders feature/T3-orders ""
git checkout -q -b feature/T3-orders
orders && at 20 git add src && at 20 git commit -q -m "feat: orders"
git checkout -q main
at 19 git merge -q --no-ff -m "Merge branch 'feature/T3-orders'" feature/T3-orders
MERGE="$(git rev-parse --short=12 HEAD)"
fix_total && at 10 git commit -q -am "fix: order total ignores tax"
run later-fixes
expect_out "	t3-orders	$MERGE	1	"
teardown

test_case "an uncommitted run's lines are found through its hand-off snapshot"
setup
run_line t4-orders "" ""
orders
run snapshot t4-orders --base "$BASE"
expect_code 0
at 20 git add -A && at 20 git commit -q -m "add orders module"
fix_total && at 10 git commit -q -am "fix: order total ignores tax"
run later-fixes
expect_out "	t4-orders	"
teardown

test_case "recorded later fixes, a run's own commits and fixes a run already recorded are left out"
setup
run_line t1-orders feature/T1-orders "#12"
orders && at 20 git add src && at 20 git commit -q -m "feat: orders (#12)"
fix_total && at 10 git commit -q -am "fix: order total ignores tax"
FIX="$(git rev-parse --short=12 HEAD)"
printf '{"type":"later_fix","date":"2026-10-12","ref":"%s","slug":"t1-orders"}\n' "$FIX" >> .claude/singularity/experience/runs.jsonl
printf 'export const label = order => "Order " + order.id\n' > src/orders.js
at 8 git commit -q -am "fix: drop the wrong total (#13)"
run_line t5-total feature/T5-total "#13" t1-orders
run later-fixes
expect_code 0
expect_lines 0
teardown

test_case "--days drops fixes of lines older than the window; --since drops older fixes"
setup
run_line t1-orders feature/T1-orders "#12"
orders && at 60 git add src && at 60 git commit -q -m "feat: orders (#12)"
fix_total && at 10 git commit -q -am "fix: order total ignores tax"
run later-fixes --days 30
expect_lines 0
run later-fixes --since "5 days ago"
expect_lines 0
run later-fixes --days 90
expect_lines 1
teardown

test_case "the snapshot keeps the change without touching the index or working tree"
setup
orders
printf 'staged\n' > src/staged.js && git add src/staged.js
before="$(git status --porcelain)"
run snapshot t6-orders --base "$BASE"
expect_code 0
after="$(git status --porcelain)"
if [ "$before" = "$after" ]; then ok; else ko "git status changed"; fi
if git cat-file -e "refs/singularity/handoff/t6-orders:src/orders.js" 2>/dev/null; then ok; else ko "snapshot lacks the new file"; fi
if git cat-file -e "refs/singularity/handoff/t6-orders:src/staged.js" 2>/dev/null; then ok; else ko "snapshot lacks the staged file"; fi
teardown

test_case "edits show what people changed after hand-off, in the run's files only"
setup
orders
run snapshot t7-orders --base "$BASE"
fix_total
printf 'export const legacy = () => "edited legacy"\n' > src/legacy.js
git add -A && git commit -q -m "feat: orders, reviewed"
run edits t7-orders HEAD
expect_code 0
expect_out "+export const total = order => order.items.reduce((s, i) => s + i.price * (1 + i.tax), 0)"
expect_no_out "edited legacy"
teardown

test_case "edits fall back to the run's last Singularity-Run commit"
setup
orders && git add -A && git commit -q -m "feat: orders" -m "Singularity-Run: t8-orders"
fix_total && git commit -q -am "fix: tax"
run edits t8-orders HEAD
expect_code 0
expect_out "+export const total"
run edits t9-unknown HEAD
expect_code 3
teardown

test_case "usage errors exit 2"
setup
run snapshot t1 --base nope
expect_code 2
run snapshot "../x" --base "$BASE"
expect_code 2
run snapshot t1
expect_code 2
run edits t1
expect_code 2
run later-fixes --days x
expect_code 2
run later-fixes --branch nope
expect_code 2
run frobnicate
expect_code 2
run later-fixes --since
expect_code 2
teardown

test_case "no runs.jsonl: nothing to report"
setup
rm .claude/singularity/experience/runs.jsonl
run later-fixes
expect_code 0
expect_lines 0
teardown

printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
