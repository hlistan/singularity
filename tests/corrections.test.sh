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
  printf '{"type":"assistant","message":{"content":[{"type":"text","text":"Done."}]}}\n' > "$WORK/answered.jsonl"
}
teardown() { cd "$ROOT" || exit 1; rm -rf "$WORK"; }
config() { printf '# config\n\n```yaml\n%s\n```\n' "$1" > .claude/singularity.md; }
json() { # json <session> <prompt>: a UserPromptSubmit hook input, in a session the agent has answered in
  printf '{"session_id":"%s","transcript_path":"%s","cwd":"%s","hook_event_name":"UserPromptSubmit","prompt":"%s"}' "$1" "$WORK/answered.jsonl" "$WORK" "$2"
}
first_json() { # first_json <session> <prompt>: the first prompt of a session
  printf '{"session_id":"%s","transcript_path":"%s","cwd":"%s","hook_event_name":"UserPromptSubmit","prompt":"%s"}' "$1" "$WORK/new.jsonl" "$WORK" "$2"
}
stop_json() { # stop_json <session> <message>: a Stop hook input
  printf '{"session_id":"%s","hook_event_name":"Stop","last_assistant_message":"%s"}' "$1" "$2"
}
turn_json() { # turn_json <session> <prompt> <prompt id>: a UserPromptSubmit hook input with a transcript
  printf '{"session_id":"%s","prompt_id":"%s","transcript_path":"%s","hook_event_name":"UserPromptSubmit","prompt":"%s"}' "$1" "$3" "$WORK/t.jsonl" "$2"
}
stopped_json() { # stopped_json <session> <prompt id> <message> [event]: a Stop (or StopFailure) hook input
  printf '{"session_id":"%s","prompt_id":"%s","transcript_path":"%s","hook_event_name":"%s","last_assistant_message":"%s"}' "$1" "$2" "$WORK/t.jsonl" "${4:-Stop}" "$3"
}
tool_call() { # tool_call <id>: an assistant transcript line with an Edit call
  printf '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"%s","name":"Edit","input":{"file_path":"src/report.js","new_string":"moment(d)"}}]}}\n' "$1" >> "$WORK/t.jsonl"
}
rejected() { # rejected <id> [feedback]: the user's rejection of that call, with what they typed
  if [ -n "${2:-}" ]; then
    printf '{"type":"user","message":{"content":[{"type":"tool_result","content":"The user doesn\x27t want to proceed with this tool use. To tell you how to proceed, the user said:\\n%s","is_error":true,"tool_use_id":"%s"}]},"toolDenialKind":"user-rejected","userFeedback":"%s"}\n' "$2" "$1" "$2" >> "$WORK/t.jsonl"
  else
    printf '{"type":"user","message":{"content":[{"type":"tool_result","content":"The user doesn\x27t want to proceed with this tool use. STOP what you are doing.","is_error":true,"tool_use_id":"%s"}]},"toolDenialKind":"user-rejected"}\n' "$1" >> "$WORK/t.jsonl"
  fi
}
hook() { OUT="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$WORK" "$SH" "$SCRIPT" "$1" 2>&1)"; CODE=$?; } # hook CMD INPUT
run() { OUT="$("$SH" "$SCRIPT" --root "$WORK" "$@" 2>&1)"; CODE=$?; }
queued() { find "$Q" -maxdepth 1 -name 'C-*.txt' 2>/dev/null | wc -l | tr -d ' '; }
test_case() { current="$1"; }
ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); printf 'FAIL [%s] %s\n' "$current" "$1"; printf '%s\n' "$OUT" | sed 's/^/    /'; }
expect_code() { if [ "$CODE" -eq "$1" ]; then ok; else ko "exit $CODE, expected $1"; fi; }
expect_out() { case "$OUT" in *"$1"*) ok ;; *) ko "output lacks: $1" ;; esac; }
expect_no_out() { case "$OUT" in *"$1"*) ko "output has: $1" ;; *) ok ;; esac; }
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

test_case "a session's first prompt sets the task: only a marked correction is queued"
setup
printf '{"type":"user","message":{"content":"Fix the export. Don\x27t commit."}}\n' > "$WORK/new.jsonl"
hook capture "$(first_json s9 "Fix the export. Don't commit, and use the Money type instead of floats.")"
expect_code 0
expect_queued 0
hook capture "$(first_json s10 "correction: invoices round half-up")"
expect_queued 1
teardown

test_case "after the agent's first turn, a phrase is queued"
setup
hook capture "$(turn_json s11 "Add a CSV export" p1)"
hook remember "$(stopped_json s11 p1 "Added the export with moment")"
hook capture "$(turn_json s11 "No, we don't use moment here" p2)"
expect_queued 1
OUT="$(cat "$Q"/C-*.txt)"
expect_out "trigger: phrase"
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

test_case "a prompt typed after an interrupted turn is queued as an interrupt"
setup
: > "$WORK/t.jsonl"
hook capture "$(turn_json s5 "Add a CSV export" p1)"
hook remember "$(stopped_json s5 p1 "Added the export with moment")"
hook capture "$(turn_json s5 "Rename the column" p2)"
expect_queued 0
hook capture "$(turn_json s5 "Keep the old parser in src/parse.js" p3)"
expect_code 0
expect_silent
expect_queued 1
OUT="$(cat "$Q"/C-*.txt)"
expect_out "trigger: interrupt"
expect_out "Keep the old parser"
expect_out "The user interrupted the turn"
teardown

test_case "continue after an interrupt, and the first prompt of a session, are not queued"
setup
: > "$WORK/t.jsonl"
hook capture "$(turn_json s6 "Add a CSV export" p1)"
hook capture "$(turn_json s6 "continue" p2)"
hook capture "$(turn_json s6 "  Yes. " p3)"
expect_queued 0
teardown

test_case "StopFailure ends a turn but keeps the agent's last message"
setup
: > "$WORK/t.jsonl"
hook capture "$(turn_json s7 "Add a CSV export" p1)"
hook remember "$(stopped_json s7 p1 "Added the export")"
hook capture "$(turn_json s7 "Add paging" p2)"
hook remember "$(stopped_json s7 p2 "rate_limit" StopFailure)"
expect_code 0
hook capture "$(turn_json s7 "Retry the paging" p3)"
expect_queued 0
hook capture "$(turn_json s7 "that is wrong" p4)"
OUT="$(cat "$Q"/C-*.txt)"
expect_out "Added the export"
expect_no_out "rate_limit"
teardown

test_case "feedback typed when rejecting a tool call is queued with the call"
setup
tool_call toolu_0 && rejected toolu_0 "old rejection before the first hook"
hook capture "$(turn_json s8 "Add the report date" p1)"
tool_call toolu_1 && rejected toolu_1 "use formatDate from src/lib/dates.js"
hook remember "$(stopped_json s8 p1 "Added the date with formatDate")"
expect_code 0
expect_silent
expect_queued 1
OUT="$(cat "$Q"/C-*.txt)"
expect_out "trigger: rejection"
expect_out "use formatDate from src/lib/dates.js"
expect_out '"id":"toolu_1"'
expect_no_out "old rejection"
hook capture "$(turn_json s8 "thanks" p2)"
expect_queued 1
teardown

test_case "a prompt after a rejection without feedback is queued with the rejected call"
setup
: > "$WORK/t.jsonl"
hook capture "$(turn_json s9 "Add the report date" p1)"
tool_call toolu_2 && rejected toolu_2
hook remember "$(stopped_json s9 p1 "Stopped as asked")"
expect_queued 0
hook capture "$(turn_json s9 "Dates go through src/lib/dates.js here" p2)"
expect_queued 1
OUT="$(cat "$Q"/C-*.txt)"
expect_out "trigger: rejection"
expect_out "Dates go through src/lib/dates.js"
expect_out '"id":"toolu_2"'
hook remember "$(stopped_json s9 p2 "Switched to formatDate")"
hook capture "$(turn_json s9 "Now add paging" p3)"
hook remember "$(stopped_json s9 p3 "Added paging")"
hook capture "$(turn_json s9 "Now add sorting" p4)"
expect_queued 1
teardown

test_case "pasted text, notifications and other agents' messages don't make a correction"
setup
hook capture "$(json s1 "<pasted_content id=\\\"a1\\\">ERROR: that is wrong, you broke the build</pasted_content> Summarize this log")"
hook capture "$(json s1 "<task-notification>The test is still failing</task-notification>")"
hook capture "$(json s1 "<agent-message from=\\\"x\\\">Don't use moment</agent-message>")"
expect_queued 0
hook capture "$(json s1 "<pasted_content id=\\\"a2\\\">a log</pasted_content> No, that is wrong")"
expect_queued 1
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
hook remember "$(stop_json s1 "Added the total")"
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
