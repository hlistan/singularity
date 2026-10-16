#!/usr/bin/env bash
# Tests for the run record's clock and drafts:
#   plugins/singularity/scripts/run-record.sh
# Run: bash tests/run-record.test.sh
# CI runs it on Linux (bash 5) and on macOS /bin/bash (3.2), so keep both this file and the script 3.2-compatible.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/plugins/singularity/scripts/run-record.sh"
SH="${BASH:-bash}"
pass=0
fail=0
current=""
TAB="$(printf '\t')"

setup() { WORK="$(mktemp -d)"; }
teardown() { chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"; }
run() { OUT="$("$SH" "$SCRIPT" "$@" 2>&1)"; CODE=$?; }
test_case() { current="$1"; }
ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); printf 'FAIL [%s] %s\n' "$current" "$1"; printf '%s\n' "$OUT" | sed 's/^/    /'; }
expect_code() { if [ "$CODE" -eq "$1" ]; then ok; else ko "exit $CODE, expected $1"; fi; }
expect_out() { case "$OUT" in *"$1"*) ok ;; *) ko "output lacks: $1" ;; esac; }
expect_no_out() { case "$OUT" in *"$1"*) ko "output has: $1" ;; *) ok ;; esac; }
stamp_at() { # <epoch> <span> <event>: a line as stamp writes it, at a chosen time
  printf '%s\t2026-10-16T00:00:00Z\t%s\t%s\n' "$1" "$2" "$3" >> "$WORK/clock.log"
}

test_case "stamp appends a clock line and prints the UTC time"
setup
run stamp "$WORK" spec start
expect_code 0
case "$OUT" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ok ;; *) ko "not a UTC time" ;; esac
run stamp "$WORK" spec end
LINE="$(tail -n 1 "$WORK/clock.log")"
case "$LINE" in [0-9]*"${TAB}"*"Z${TAB}spec${TAB}end") ok ;; *) ko "bad line: $LINE" ;; esac
[ "$(wc -l < "$WORK/clock.log" | tr -d ' ')" = 2 ] && ok || ko "expected two lines"
run times "$WORK"
expect_code 0
expect_out '"spec":{"s":'
teardown

test_case "times sums repeats, counts gates as waiting and overlaps once"
setup
stamp_at 1000 run start
stamp_at 1000 spec start
stamp_at 1095 spec end
stamp_at 1095 gate-spec start
stamp_at 1515 gate-spec end
stamp_at 1515 implement start
stamp_at 2115 implement end
stamp_at 2115 checks start
stamp_at 2135 checks end
stamp_at 2135 review start
stamp_at 2200 fix-1 start
stamp_at 2300 fix-1 end
stamp_at 2400 review end
stamp_at 2400 checks start
stamp_at 2410 checks end
stamp_at 2410 run end
run times "$WORK"
expect_code 0
expect_out '"lead_s":1410'
expect_out '"active_s":990'
expect_out '"gate_wait_s":{"spec":420}'
expect_out '"checks":{"s":30,"n":2}'
expect_out '"fix-1":{"s":100,"n":1}'
expect_out '"open":[]'
teardown

test_case "a span still open is listed, not counted"
setup
stamp_at 1000 run start
stamp_at 1000 learn start
run times "$WORK"
expect_code 0
expect_out '"open":["run","learn"]'
expect_no_out '"lead_s"'
expect_out '"active_s":0'
teardown

test_case "a hand-written line out of time order fails"
setup
stamp_at 2000 run start
stamp_at 1990 spec start
stamp_at 2100 spec end
run times "$WORK"
expect_code 1
expect_out "line 2: earlier than the line before it"
expect_out '"spec":{"s":110,"n":1}'
teardown

test_case "an end without a start and a span started twice fail"
setup
stamp_at 1000 review end
stamp_at 1000 plan start
stamp_at 1100 plan start
stamp_at 1200 plan end
run times "$WORK"
expect_code 1
expect_out '"review" ended without a start'
expect_out '"plan" started again before it ended'
expect_out '"plan":{"s":200,"n":1}'
teardown

test_case "a line that isn't a stamp fails"
setup
stamp_at 1000 spec start
printf 'spec took about 2 minutes\n' >> "$WORK/clock.log"
run times "$WORK"
expect_code 1
expect_out "line 2: not a stamp"
teardown

test_case "draft copies once, read-only, and keeps an existing draft"
setup
printf 'first\n' > "$WORK/plan.md"
run draft "$WORK/plan.md" "$WORK/plan.draft.md"
expect_code 0
[ "$(cat "$WORK/plan.draft.md")" = first ] && ok || ko "draft not copied"
[ -w "$WORK/plan.draft.md" ] && ko "draft is writable" || ok
printf 'revised after the gate\n' > "$WORK/plan.md"
run draft "$WORK/plan.md" "$WORK/plan.draft.md"
expect_code 0
expect_out "kept the existing draft"
[ "$(cat "$WORK/plan.draft.md")" = first ] && ok || ko "draft overwritten"
teardown

test_case "usage errors"
setup
run
expect_code 2
run stamp "$WORK" "spec stage" start
expect_code 2
run stamp "$WORK" spec begin
expect_code 2
run stamp "$WORK/missing" spec start
expect_code 2
run times "$WORK"
expect_code 3
run draft "$WORK/none.md" "$WORK/none.draft.md"
expect_code 2
teardown

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
