#!/usr/bin/env bash
# Tests for the user-correction capture and queue:
#   plugins/singularity/scripts/corrections.sh
# Run: bash tests/corrections.test.sh
# CI runs it on Linux (bash 5) and on macOS /bin/bash (3.2), so keep both this file and the script 3.2-compatible.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/plugins/singularity/scripts/corrections.sh"
SH="${BASH:-bash}"
pass=0
fail=0
current=""

setup() { # a project connected to singularity, with the default work dir
  WORK="$(mktemp -d)"
  cd "$WORK" || exit 1
  git init -q .
  mkdir -p .claude/singularity
  config 'conventions:
  work_dir: .agentic/work
learning:
  enabled: true'
  Q="$WORK/.agentic/work/corrections"
}
teardown() { cd "$ROOT" || exit 1; rm -rf "$WORK"; }
config() { printf '# config\n\n```yaml\n%s\n```\n' "$1" > .claude/singularity.md; }
json() { # json <session> <prompt>: a UserPromptSubmit hook input
  printf '{"session_id":"%s","transcript_path":"/tmp/t.jsonl","cwd":"%s","hook_event_name":"UserPromptSubmit","prompt":"%s"}' "$1" "$WORK" "$2"
}
stop_json() { # stop_json <session> <message>: a Stop hook input
  printf '{"session_id":"%s","hook_event_name":"Stop","last_assistant_message":"%s"}' "$1" "$2"
}
hook() { OUT="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$WORK" "$SH" "$SCRIPT" "$1" 2>&1)"; CODE=$?; } # hook CMD INPUT
run() { OUT="$("$SH" "$SCRIPT" --root "$WORK" "$@" 2>&1)"; CODE=$?; }
queued() { find "$Q" -maxdepth 1 -name 'C-*.txt' 2>/dev/null | wc -l | tr -d ' '; }
test_case() { current="$1"; }
ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); printf 'FAIL [%s] %s\n' "$current" "$1"; printf '%s\n' "$OUT" | sed 's/^/    /'; }
expect_code() { if [ "$CODE" -eq "$1" ]; then ok; else ko "exit $CODE, expected $1"; fi; }
expect_out() { case "$OUT" in *"$1"*) ok ;; *) ko "output lacks: $1" ;; esac; }
expect_queued() { local n; n="$(queued)"; if [ "$n" -eq "$1" ]; then ok; else ko "$n record(s) queued, expected $1"; fi; }
expect_silent() { if [ -z "$OUT" ]; then ok; else ko "the hook printed something"; fi; }

test_case "corrections are queued, silently, with exit 0"
setup
for p in "No, use date-fns here." \
         "that's wrong, the total must include tax" \
         "This is not what I asked for" \
         "You broke the login page" \
         "why did you delete the migration?" \
         "Don't use moment in src/" \
         "do not touch the generated client" \
         "We never commit to main directly" \
         "use the Money type instead" \
         "Revert that change to the router" \
         "the build is still failing" \
         "You shouldn't have mocked the database" \
         "Stop." \
         "correction: invoices round half-up" \
         "Defect: the export ignores the date filter"; do
  hook capture "$(json s1 "$p")"
  expect_code 0
  expect_silent
done
expect_queued 15
teardown

test_case "ordinary prompts are not queued"
setup
for p in "Add a CSV export to the orders page" \
         "No need to hurry, also add pagination" \
         "Why is the build slow?" \
         "Don't forget to update the changelog" \
         "Never mind, let's look at the API next" \
         "Implement T7" \
         "/singularity:feature ABC-123"; do
  hook capture "$(json s1 "$p")"
  expect_code 0
done
expect_queued 0
teardown

test_case "a record pairs the prompt with the agent's last message"
setup
hook remember "$(stop_json s2 "I added the report date with moment in src/report.js")"
expect_code 0
expect_silent
hook capture "$(json s2 "No, we don't use moment: dates go through src/lib/dates.js")"
expect_queued 1
OUT="$(cat "$Q"/C-*.txt)"
expect_out "session: s2"
expect_out "dates go through src/lib/dates.js"
expect_out "I added the report date with moment"
teardown

test_case "a correction without a remembered message says so"
setup
hook capture "$(json s3 "that is wrong")"
OUT="$(cat "$Q"/C-*.txt)"
expect_out "(none recorded)"
teardown

test_case "the queue keeps itself out of git"
setup
hook capture "$(json s1 "that is wrong")"
OUT="$(git status --porcelain --untracked-files=all)"
case "$OUT" in *.agentic*) ko "git sees the queue" ;; *) ok ;; esac
OUT="$(cat "$Q/.gitignore")"
expect_out "*"
teardown

test_case "a path in the hook input doesn't make a correction"
setup
hook capture '{"session_id":"s1","cwd":"/work/that-is-wrong/you-broke-it","prompt":"Add a button"}'
expect_queued 0
teardown

test_case "escaped quotes and newlines in the prompt"
setup
hook capture '{"session_id":"s1","prompt":"Looks fine.\nBut \"total\" is wrong: it skips tax","prompt_id":"p1"}'
expect_queued 1
teardown

test_case "the project's own patterns are added"
setup
printf '# Russian\n(^|[^[:alnum:]_])не надо\n' > .claude/singularity/correction-patterns.txt
hook capture "$(json s1 "Не надо трогать миграции")"
hook capture "$(json s1 "не надо трогать миграции")"
OUT="$(queued)"
case "$OUT" in 0) ko "the project pattern didn't match" ;; *) ok ;; esac
teardown

test_case "nothing is captured when learning or corrections are off, or the project isn't connected"
setup
config 'learning:
  enabled: false'
hook capture "$(json s1 "that is wrong")"
expect_queued 0
config 'learning:
  enabled: true
  corrections: false   # privacy'
hook capture "$(json s1 "that is wrong")"
hook remember "$(stop_json s1 "done")"
expect_queued 0
if [ -d "$Q" ]; then ko "the queue was created"; else ok; fi
rm .claude/singularity.md
hook capture "$(json s1 "that is wrong")"
expect_code 0
expect_queued 0
teardown

test_case "a custom work dir is used"
setup
config 'conventions:
  work_dir: "tmp/agents/"   # trailing slash
learning:
  enabled: true'
hook capture "$(json s1 "that is wrong")"
OUT="$(find tmp/agents/corrections -name 'C-*.txt' | wc -l | tr -d ' ')"
expect_out "1"
teardown

test_case "list, count and clear"
setup
hook capture "$(json s1 "that is wrong")"
hook capture "$(json s4 "you forgot the tests")"
run count
expect_code 0
expect_out "2"
run list
expect_code 0
expect_out "$Q/C-"
expect_out "s4"
first="$(find "$Q" -maxdepth 1 -name 'C-*.txt' | head -n 1)"
run clear "$first"
expect_code 0
expect_queued 1
second="$(basename "$(find "$Q" -maxdepth 1 -name 'C-*.txt' | head -n 1)")"
run clear "$second"
expect_code 0
expect_queued 0
run count
expect_out "0"
teardown

test_case "clear refuses what isn't a record in the queue, and usage errors"
setup
run clear
expect_code 2
run clear "$WORK/.claude/singularity.md"
expect_code 2
expect_out "not a correction record"
run clear "C-missing.txt"
expect_code 2
expect_out "no such record"
run bogus
expect_code 2
teardown

test_case "garbage input never fails a hook"
setup
hook capture "not json at all"
expect_code 0
hook remember ""
expect_code 0
hook capture ""
expect_code 0
teardown

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
