#!/usr/bin/env bash
# Tests for the file-based task tracker script:
#   plugins/singularity/skills/tracker/scripts/tasks.sh
# Run: bash tests/tracker-files.test.sh
# CI runs it on Linux (bash 5) and on macOS /bin/bash (3.2), so keep both this file and the script 3.2-compatible.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/plugins/singularity/skills/tracker/scripts/tasks.sh"
SH="${BASH:-bash}"
NOW="2026-10-14 10:00"
TAB="$(printf '\t')"
pass=0
fail=0
current=""

# ---------- harness ----------
setup() { # fresh git repo whose .tasks/ is git-ignored
  WORK="$(mktemp -d)"
  cd "$WORK" || exit 1
  git init -q .
  printf '.tasks/\n' > .gitignore
  mkdir .tasks
}
teardown() { cd "$ROOT" || exit 1; rm -rf "$WORK"; }
task() { printf '%s\n' "${2:-# $1}" > ".tasks/$1"; }  # task FILENAME [CONTENT]
run() {                                                # sets OUT, ERR, CODE
  OUT="$("$SH" "$SCRIPT" --now "$NOW" ${1+"$@"} 2>"$WORK/.stderr")"
  CODE=$?
  ERR="$(cat "$WORK/.stderr")"
}
run_stdin() { # run_stdin INPUT ARGS...
  local input="$1"; shift
  OUT="$(printf '%s\n' "$input" | "$SH" "$SCRIPT" --now "$NOW" "$@" 2>"$WORK/.stderr")"
  CODE=$?
  ERR="$(cat "$WORK/.stderr")"
}
test_case() { current="$1"; }
ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); printf 'FAIL [%s] %s\n' "$current" "$1"; }
expect_code() { if [ "$CODE" -eq "$1" ]; then ok; else ko "exit $CODE, expected $1. stderr: $ERR"; fi; }
expect_out() { if [ "$OUT" = "$1" ]; then ok; else ko "output:
$OUT
expected:
$1"; fi; }
expect_line() { if printf '%s\n' "$OUT" | grep -qxF -- "$1"; then ok; else ko "no line '$1' in output:
$OUT"; fi; }
expect_err() { case "$ERR" in *"$1"*) ok ;; *) ko "stderr lacks '$1': $ERR" ;; esac; }
expect_file() { if [ -f "$1" ]; then ok; else ko "missing file $1"; fi; }
expect_absent() { if [ ! -e "$1" ]; then ok; else ko "unexpected file $1"; fi; }
expect_content() { # expect_content FILE EXPECTED
  local got; got="$(cat "$1")"
  if [ "$got" = "$2" ]; then ok; else ko "content of $1:
$got
expected:
$2"; fi
}

# ---------- list ----------
test_case "list parses names with and without extensions and ignores everything else"
setup
task TODO-T3-add-search.md
task PROGRESS-T2-refactor-auth
task DONE-T1-setup-ci.txt
task README.md
task .hidden
task notes.md
task TOD0-T4-typo.md
mkdir .tasks/TODO-T5-a-directory
run list
expect_code 0
expect_out "DONE${TAB}T1${TAB}setup-ci${TAB}.tasks/DONE-T1-setup-ci.txt
PROGRESS${TAB}T2${TAB}refactor-auth${TAB}.tasks/PROGRESS-T2-refactor-auth
TODO${TAB}T3${TAB}add-search${TAB}.tasks/TODO-T3-add-search.md"
teardown

test_case "list filters by logical state or by raw prefix"
setup
task TODO-T3-add-search.md
task PROGRESS-T2-refactor-auth
run list in_progress
expect_code 0
expect_out "PROGRESS${TAB}T2${TAB}refactor-auth${TAB}.tasks/PROGRESS-T2-refactor-auth"
run list PROGRESS
expect_out "PROGRESS${TAB}T2${TAB}refactor-auth${TAB}.tasks/PROGRESS-T2-refactor-auth"
run list nonsense
expect_code 2
expect_err "unknown state"
teardown

test_case "list on a missing directory fails clearly"
setup
rmdir .tasks
run list
expect_code 3
expect_err "not found"
teardown

test_case "a directory path containing spaces works"
setup
printf 'my tasks/\n' >> .gitignore
mkdir "my tasks"
printf '# x\n' > "my tasks/TODO-T1-x.md"
run --dir "my tasks" list
expect_code 0
expect_out "TODO${TAB}T1${TAB}x${TAB}my tasks/TODO-T1-x.md"
teardown

# ---------- get ----------
test_case "get returns metadata then content"
setup
task TODO-T7-fix-login.md "---
priority: 1
---
# Fix the login redirect

Users land on /home instead of the page they asked for."
run get T7
expect_code 0
expect_line "status=TODO"
expect_line "state=todo"
expect_line "id=T7"
expect_line "slug=fix-login"
expect_line "title=Fix the login redirect"
expect_line "priority=1"
expect_line "path=.tasks/TODO-T7-fix-login.md"
expect_line "---"
expect_line "Users land on /home instead of the page they asked for."
teardown

test_case "get accepts a file name or path, and falls back to the slug for the title"
setup
task PROGRESS-T8-update-docs "no heading here"
run get .tasks/PROGRESS-T8-update-docs
expect_code 0
expect_line "id=T8"
expect_line "title=update docs"
expect_line "priority="
run get PROGRESS-T8-update-docs
expect_line "state=in_progress"
teardown

test_case "get matches the exact ID, never a prefix or a slug fragment"
setup
task TODO-T4-alpha.md
task TODO-T42-beta.md
task TODO-X1-mentions-T4-in-slug.md
run get T4
expect_code 0
expect_line "slug=alpha"
run get T42
expect_line "slug=beta"
teardown

test_case "get reports missing, invalid and duplicate IDs with distinct exit codes"
setup
task TODO-T5-first.md
task DONE-T5-second.md
run get T99
expect_code 3
expect_err "no task T99"
run get T-4
expect_code 2
run get "../etc"
expect_code 2
run get T5
expect_code 4
expect_err "TODO-T5-first.md"
expect_err "DONE-T5-second.md"
teardown

# ---------- next ----------
test_case "next orders the TODO queue by priority, then by numeric ID"
setup
task TODO-T3-add-search.md "---
priority: 2
---
# Add search"
task TODO-T7-fix-login.md "---
priority: 1
---
# Fix login"
task TODO-T9-update-docs "# Update docs"
task PROGRESS-T1-in-flight.md "---
priority: 0
---
# Already started"
run next
expect_code 0
expect_line "id=T7"
expect_line "remaining=2"
teardown

test_case "next compares IDs numerically, not as text"
setup
task TODO-T10-later.md
task TODO-T9-sooner.md
run next
expect_line "id=T9"
teardown

test_case "next on an empty queue exits 3"
setup
task DONE-T1-finished.md
run next
expect_code 3
expect_err "queue is empty"
teardown

# ---------- move ----------
test_case "move renames by logical state or raw prefix and keeps content and extension"
setup
task TODO-T3-add-search.md "# Add search
body"
task TODO-T4-no-extension
run move T3 in_progress
expect_code 0
expect_out ".tasks/PROGRESS-T3-add-search.md"
expect_file .tasks/PROGRESS-T3-add-search.md
expect_absent .tasks/TODO-T3-add-search.md
expect_content .tasks/PROGRESS-T3-add-search.md "# Add search
body"
run move T4 DONE
expect_out ".tasks/DONE-T4-no-extension"
teardown

test_case "move --from refuses a task that is no longer in the expected state"
setup
task PROGRESS-T3-add-search.md
run move T3 in_progress --from todo
expect_code 5
expect_err "is PROGRESS"
expect_err "is PROGRESS, expected TODO (taken"
expect_file .tasks/PROGRESS-T3-add-search.md
teardown

test_case "claiming the same task twice: the second claim loses"
setup
task TODO-T3-add-search.md
run move T3 in_progress --from todo
expect_code 0
run move T3 in_progress --from todo
expect_code 5
teardown

test_case "move to the current state is a no-op; an unknown state is a usage error"
setup
task TODO-T3-add-search.md
run move T3 todo
expect_code 0
expect_out ".tasks/TODO-T3-add-search.md"
run move T3 finished
expect_code 2
expect_file .tasks/TODO-T3-add-search.md
teardown

test_case "--from accepts several states, so a task can be resumed from progress, blocked or review"
setup
task BLOCKED-T3-add-search.md
run move T3 in_progress --from in_progress,blocked,in_review
expect_code 0
expect_out ".tasks/PROGRESS-T3-add-search.md"
run move T3 in_progress --from in_progress,blocked,in_review
expect_code 0
expect_out ".tasks/PROGRESS-T3-add-search.md"
run move T3 in_progress --from todo,blocked
expect_code 5
expect_err "expected one of TODO BLOCKED"
expect_file .tasks/PROGRESS-T3-add-search.md
run move T3 in_progress --from todo,nonsense
expect_code 2
run move T3 in_progress --from ""
expect_code 2
teardown

# ---------- comment ----------
test_case "comment adds one Log section and appends single-line entries"
setup
task TODO-T3-add-search.md "# Add search"
run comment T3 "Started by singularity"
expect_code 0
run comment T3 "line one
line two"
expect_content .tasks/TODO-T3-add-search.md "# Add search

## Log

- 2026-10-14 10:00 Started by singularity
- 2026-10-14 10:00 line one line two"
run comment T3 ""
expect_code 2
teardown

# ---------- create ----------
test_case "create picks the next ID for the prefix and writes the body"
setup
task DONE-T8-old.md
task TODO-T2-older.md
task TODO-X100-other-prefix.md
run_stdin "Body text" create add-export "Add CSV export"
expect_code 0
expect_out ".tasks/TODO-T9-add-export.md"
expect_content .tasks/TODO-T9-add-export.md "# Add CSV export

Body text"
teardown

test_case "create honours --id-prefix, validates the slug, and creates the directory"
setup
rmdir .tasks
run --id-prefix FT create first-task < /dev/null
expect_code 0
expect_out ".tasks/TODO-FT1-first-task.md"
expect_content .tasks/TODO-FT1-first-task.md "# first task"
run create "bad slug" < /dev/null
expect_code 2
teardown

# ---------- configurable statuses ----------
test_case "--status renames prefixes; invalid or duplicate prefixes are rejected"
setup
task WIP-T1-alpha.md
run --status in_progress=WIP --status in_review=PROGRESS list in_progress
expect_code 0
expect_out "WIP${TAB}T1${TAB}alpha${TAB}.tasks/WIP-T1-alpha.md"
run --status in_progress=WIP --status in_review=PROGRESS move T1 in_review
expect_out ".tasks/PROGRESS-T1-alpha.md"
run --status done=done list
expect_code 2
run --status done=TODO list
expect_code 2
expect_err "can't be shared"
teardown

test_case "states other than todo can share a prefix: the documented in_review=PROGRESS works"
setup
task PROGRESS-T1-alpha.md
run --status in_review=PROGRESS validate
expect_code 0
run --status in_review=PROGRESS get T1
expect_line "state=in_progress"
run --status in_review=PROGRESS move T1 in_review
expect_code 0
expect_out ".tasks/PROGRESS-T1-alpha.md"
run --status in_review=PROGRESS move T1 "done" --from in_review
expect_code 0
expect_out ".tasks/DONE-T1-alpha.md"
teardown

test_case "a shared prefix reports the state whose default it is, else the first state mapped to it"
setup
task DONE-T1-alpha.md
task QA-T2-beta.md
run --status in_review=DONE get T1
expect_line "state=done"
run --status in_review=QA get T2
expect_line "state=in_review"
teardown

test_case "todo needs a prefix of its own, because claiming a task relies on the rename"
setup
run --status in_progress=TODO list
expect_code 2
expect_err "can't be shared"
run --status blocked=TODO list
expect_code 2
run --status todo=PROGRESS list
expect_code 2
run --status todo=QUEUE list
expect_code 0
teardown

# Every tracker.files example in the docs must work as written.
doc_options() { # FILE -> one script option per line, built from its statuses / extra_statuses examples
  sed -n -E 's/^[[:space:]#]*statuses:[[:space:]]*\{([^}]*)\}.*/\1/p' "$1" | tr ',' '\n' \
    | sed -n -E 's/^[[:space:]]*([a-z_]+):[[:space:]]*([A-Z][A-Z0-9_]*)[[:space:]]*$/--status \1=\2/p'
  sed -n -E 's/^[[:space:]#]*extra_statuses:[[:space:]]*\[([^]]*)\].*/\1/p' "$1" | tr ',' '\n' \
    | sed -n -E 's/^[[:space:]]*([A-Z][A-Z0-9_]*)[[:space:]]*$/--extra-status \1/p'
}
for doc in plugins/singularity/skills/tracker/files.md plugins/singularity/templates/project/.claude/singularity.md; do
  test_case "the config examples in $doc are accepted"
  opts="$(doc_options "$ROOT/$doc" | tr '\n' ' ')"
  case "$opts" in
    *--status*--extra-status*) ok ;;
    *) ko "found no statuses and extra_statuses examples in $doc (did the format change?): '$opts'" ;;
  esac
  setup
  task TODO-T1-a.md
  # shellcheck disable=SC2086 # one option per word, by design
  run $opts validate
  expect_code 0
  teardown
done

# ---------- git-ignore guard ----------
test_case "every command except validate refuses a directory that isn't git-ignored"
setup
rm .gitignore
task TODO-T1-a.md
run list
expect_code 1
expect_err "not git-ignored"
run next
expect_code 1
run move T1 in_progress
expect_code 1
expect_file .tasks/TODO-T1-a.md
run create b < /dev/null
expect_code 1
expect_absent .tasks/TODO-T2-b.md
teardown

test_case "a directory outside any git repository is allowed"
WORK="$(mktemp -d)"
cd "$WORK" || exit 1
mkdir .tasks
task TODO-T1-a.md
run next
expect_code 0
expect_line "id=T1"
teardown

# ---------- custom statuses ----------
test_case "--extra-status adds statuses that list, get and move understand"
setup
task QA-T4-check-export.md
task ON_HOLD-T5-waiting-on-vendor
task TODO-T6-next-up.md
run --extra-status QA --extra-status ON_HOLD list
expect_code 0
expect_out "QA${TAB}T4${TAB}check-export${TAB}.tasks/QA-T4-check-export.md
ON_HOLD${TAB}T5${TAB}waiting-on-vendor${TAB}.tasks/ON_HOLD-T5-waiting-on-vendor
TODO${TAB}T6${TAB}next-up${TAB}.tasks/TODO-T6-next-up.md"
run --extra-status QA list QA
expect_out "QA${TAB}T4${TAB}check-export${TAB}.tasks/QA-T4-check-export.md"
run --extra-status QA get T4
expect_line "status=QA"
expect_line "state="
run --extra-status QA move T6 QA
expect_out ".tasks/QA-T6-next-up.md"
run --extra-status QA move T6 "done" --from QA
expect_out ".tasks/DONE-T6-next-up.md"
teardown

test_case "next ignores tasks in custom statuses"
setup
task QA-T1-a.md
task TODO-T2-b.md
run --extra-status QA next
expect_line "id=T2"
expect_line "remaining=0"
teardown

test_case "undeclared statuses are ignored by list and flagged by validate with a hint"
setup
task QA-T4-check-export.md
run list
expect_code 0
expect_out ""
run validate
expect_code 1
expect_err "unknown status QA"
expect_err "extra_statuses"
run --extra-status QA validate
expect_code 0
teardown

test_case "invalid, clashing or repeated custom statuses are usage errors"
setup
run --extra-status qa list
expect_code 2
run --extra-status TODO list
expect_code 2
expect_err "used twice"
run --extra-status QA --extra-status QA list
expect_code 2
expect_err "used twice"
teardown

# ---------- validate ----------
test_case "validate passes a clean, git-ignored directory"
setup
task TODO-T1-a.md
run validate
expect_code 0
teardown

test_case "validate flags an un-ignored directory, bad names and duplicate IDs"
setup
rm .gitignore
task TODO-T1-a.md
task DONE-T1-b.md
task TOD0-T2-typo.md
run validate
expect_code 1
expect_err "not git-ignored"
expect_err "TOD0-T2-typo.md"
expect_err "duplicate ID T1"
teardown

test_case "validate outside a git repository skips the ignore check"
WORK="$(mktemp -d)"
cd "$WORK" || exit 1
mkdir .tasks
task TODO-T1-a.md
run validate
expect_code 0
teardown

# ---------- usage ----------
test_case "missing or unknown commands are usage errors"
setup
run
expect_code 2
run frobnicate
expect_code 2
teardown

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
