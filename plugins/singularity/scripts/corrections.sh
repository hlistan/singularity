#!/usr/bin/env bash
# User corrections for the singularity learn job: the plugin's hooks capture prompts in which the user
# corrects an agent, and the learn job reads and clears the queue.
#
# Hooks (hooks/hooks.json), reading the hook JSON on stdin. They print nothing and always exit 0:
#   corrections.sh remember    Stop, StopFailure: marks the turn ended and keeps the agent's last message,
#                              to pair with a correction
#   corrections.sh capture     UserPromptSubmit: queues a prompt that reads like a correction
# For the learn job:
#   corrections.sh list        one line per waiting record: <path>\t<captured>\t<session>
#   corrections.sh count       the number of waiting records
#   corrections.sh clear <path|name>...  removes processed records
# Options: --root <project root> (default: $CLAUDE_PROJECT_DIR, else the current directory).
#
# The queue is <work_dir>/corrections/ (conventions.work_dir, default .agentic/work). It keeps itself out
# of git with its own .gitignore, because prompts can hold secrets. Nothing is captured unless
# .claude/singularity.md exists and neither learning.enabled nor learning.corrections is false.
# A record's trigger says why it was queued:
#   phrase     the prompt starts with "correction:" or "defect:", or matches a pattern in
#              correction-patterns.txt next to this script or in .claude/singularity/correction-patterns.txt
#              once the agent has had a turn in the session (a first prompt only sets the task, e.g.
#              "don't commit");
#   interrupt  the user stopped the previous turn (it never reached Stop) and typed this prompt;
#   rejection  the user rejected a tool call and typed what to do instead, or typed this prompt after
#              rejecting one. Read from the session transcript, whose format Claude Code doesn't document:
#              best effort, and nothing is queued if the format changes.
# Only text the user typed counts: pasted content, task notifications, other agents' messages and system
# reminders are cut from a prompt before matching, and a bare "continue" or "yes" is never queued.
# Exit status of list, count and clear: 0 ok, 2 usage error.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
root=""
cmd=""
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --root) root="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,29p' "$0"; exit 0 ;;
    *) if [ -z "$cmd" ]; then cmd="$1"; else args+=("$1"); fi; shift ;;
  esac
done
[ -n "$root" ] || root="${CLAUDE_PROJECT_DIR:-$PWD}"
cfg="$root/.claude/singularity.md"

config_value() { # <section> <key>: a key's value under a top-level section of the config's YAML
  [ -f "$cfg" ] || return 0
  awk -v sec="$1" -v key="$2" '
    $0 ~ "^" sec ":" { insec = 1; next }
    insec && /^[^[:space:]#]/ { insec = 0 }
    insec && $0 ~ "^[[:space:]]+" key ":" {
      v = $0; sub("^[[:space:]]+" key ":[[:space:]]*", "", v); sub(/[[:space:]]+#.*$/, "", v)
      gsub(/["\047]/, "", v); print v; exit
    }' "$cfg"
}

work_dir="$(config_value conventions work_dir)"
work_dir="${work_dir:-.agentic/work}"
work_dir="${work_dir%/}"
case "$work_dir" in /*) dir="$work_dir/corrections" ;; *) dir="$root/$work_dir/corrections" ;; esac

enabled() { # the project uses singularity, and learning from corrections isn't switched off
  [ -f "$cfg" ] || return 1
  [ "$(config_value learning enabled)" = "false" ] && return 1
  [ "$(config_value learning corrections)" = "false" ] && return 1
  return 0
}

prepare_dir() { # creates the queue, ignored by git whatever the project's .gitignore says
  mkdir -p "$dir/.last" 2>/dev/null || return 1
  [ -f "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null || return 1
}

json_string() { # <json> <key>: a string field's value, still JSON-escaped
  printf '%s' "$1" | sed -nE 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -n 1
}

session_of() { # the hook input's session_id, safe as a file name
  local s
  s="$(printf '%s' "$1" | sed -nE 's/.*"session_id"[[:space:]]*:[[:space:]]*"([A-Za-z0-9_.-]+)".*/\1/p' | head -n 1)"
  printf '%s' "${s:-unknown}"
}

typed_text() { # <prompt>: without what the user didn't type (pasted content, notifications, agent messages)
  printf '%s\n' "$1" | awk 'BEGIN { n = split("pasted_content task-notification agent-message system-reminder", tags, " ") }
    {
      s = $0; out = ""
      for (;;) {
        at = 0
        for (i = 1; i <= n; i++) { p = index(s, "<" tags[i]); if (p && (!at || p < at)) { at = p; tg = tags[i] } }
        if (!at) break
        out = out substr(s, 1, at - 1) " "
        rest = substr(s, at); q = index(rest, "</" tg ">")
        if (!q) { s = ""; break }
        s = substr(rest, q + length(tg) + 3)
      }
      print out s
    }'
}

continuation() { # <text>: nothing typed, or only "continue", "go on", "yes" and the like
  printf '%s' "$1" | tr -d '\n' | grep -E -i -q '^[[:space:]]*((continue|go on|go ahead|proceed|resume|carry on|keep going|ok|okay|yes|y|sure)[[:space:]]*[.!]*)?[[:space:]]*$'
}

write_record() { # <session> <trigger> <prompt input> <rejected call> <feedback>: queues one record
  local sid="$1" trigger="$2" input="$3" call="$4" feedback="$5" stamp name tmp
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  name="C-$stamp-$$-$RANDOM.txt"
  tmp="$dir/.tmp-$name"
  {
    printf 'captured: %s\n' "$(date -u +%FT%TZ)"
    printf 'session: %s\n' "$sid"
    printf 'trigger: %s\n\n' "$trigger"
    if [ -n "$feedback" ]; then
      printf '## Feedback typed when rejecting a tool call (transcript)\n\n%s\n\n' "${feedback:0:20000}"
    fi
    if [ -n "$input" ]; then
      printf '## The prompt (UserPromptSubmit hook input)\n\n%s\n\n' "${input:0:20000}"
    fi
    if [ -n "$call" ]; then
      printf '## The rejected tool call (transcript)\n\n%s\n\n' "${call:0:8000}"
    fi
    printf "## The agent's last message before it (Stop hook input)\n\n"
    [ "$trigger" = interrupt ] && printf '(The user interrupted the turn before this prompt; this is the last message of the turn before that.)\n\n'
    if [ -f "$dir/.last/$sid.json" ]; then cat "$dir/.last/$sid.json"; else printf '(none recorded)\n'; fi
  } > "$tmp" 2>/dev/null && mv "$tmp" "$dir/$name" 2>/dev/null
  rm -f "$tmp" 2>/dev/null
}

scan_transcript() { # <session> <transcript path>: queues feedback typed when rejecting a tool call
  local sid="$1" tp="$2" off size chunk line feedback id call
  [ -n "$tp" ] && [ -f "$tp" ] || return 0
  size="$(wc -c < "$tp" 2>/dev/null | tr -d ' ')"
  case "$size" in ''|*[!0-9]*) return 0 ;; esac
  off="$(cat "$dir/.last/$sid.offset" 2>/dev/null)"
  printf '%s\n' "$size" > "$dir/.last/$sid.offset" 2>/dev/null
  case "$off" in ''|*[!0-9]*) return 0 ;; esac # first sight of this session: start from here
  [ "$off" -le "$size" ] || off=0
  [ "$size" -gt "$off" ] || return 0
  chunk="$dir/.last/$sid.chunk"
  tail -c +"$((off + 1))" "$tp" 2>/dev/null | head -c "$((size - off))" > "$chunk" 2>/dev/null
  grep -E '"toolDenialKind"[[:space:]]*:[[:space:]]*"user-rejected"' "$chunk" 2>/dev/null | while IFS= read -r line; do
    feedback="$(json_string "$line" userFeedback)"
    [ -n "$feedback" ] || feedback="$(printf '%s' "$line" | sed -nE 's/.*the user said:((\\n)|[[:space:]])*(([^"\\]|\\.)*)".*/\3/p' | head -n 1)"
    id="$(json_string "$line" tool_use_id)"
    call=""
    if [ -n "$id" ]; then
      call="$(grep -F "\"$id\"" "$chunk" | grep -F '"tool_use"' | head -n 1)"
      [ -n "$call" ] || call="$(grep -F "\"$id\"" "$tp" | grep -F '"tool_use"' | head -n 1)"
    fi
    if [ -n "$feedback" ]; then
      write_record "$sid" rejection "" "$call" "$feedback"
    else # rejected without a word: the next prompt likely says why
      printf '%s\n' "${call:-(the rejected call was not found)}" > "$dir/.last/$sid.rejected" 2>/dev/null
    fi
  done
  rm -f "$chunk"
}

patterns() { # the active patterns, without comments and blank lines (a blank pattern would match anything)
  cat "$here/correction-patterns.txt" "$root/.claude/singularity/correction-patterns.txt" 2>/dev/null \
    | grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$'
}

marked() { # <prompt text>: starts with "correction:" or "defect:"
  printf '%s' "$1" | grep -E -i -q '^[[:space:]]*(correction|defect)[[:space:]]*:'
}

phrased() { # <prompt text>: matches a correction-like phrase
  [ -n "$(patterns)" ] || return 1
  grep -E -i -q -f <(patterns) <<< "$1"
}

answered() { # <session> <transcript path>: the agent has had a turn in this session, so a prompt can correct it
  [ -f "$dir/.last/$1.turn" ] || [ -f "$dir/.last/$1.stopped" ] || [ -f "$dir/.last/$1.json" ] && return 0
  [ -n "$2" ] && [ -f "$2" ] && grep -E -q '"type"[[:space:]]*:[[:space:]]*"assistant"' "$2" 2>/dev/null
}

case "$cmd" in
  remember)
    input="$(cat)"
    enabled || exit 0
    prepare_dir || exit 0
    sid="$(session_of "$input")"
    pid="$(json_string "$input" prompt_id)"
    [ -n "$pid" ] && printf '%s\n' "$pid" > "$dir/.last/$sid.stopped" 2>/dev/null
    if [ "$(json_string "$input" hook_event_name)" != "StopFailure" ]; then # StopFailure holds the API error
      printf '%s\n' "${input:0:8000}" > "$dir/.last/$sid.json" 2>/dev/null
    fi
    scan_transcript "$sid" "$(json_string "$input" transcript_path)"
    find "$dir/.last" -type f -mtime +7 -exec rm -f {} + 2>/dev/null
    exit 0
    ;;
  capture)
    input="$(cat)"
    enabled || exit 0
    input="${input:0:200000}"
    prepare_dir || exit 0
    sid="$(session_of "$input")"
    pid="$(json_string "$input" prompt_id)"
    tp="$(json_string "$input" transcript_path)"
    scan_transcript "$sid" "$tp"
    prompt="$(json_string "$input" prompt)"
    [ -n "$prompt" ] || prompt="$input"
    prompt="$(printf '%s' "$prompt" | sed -e 's/\\[nrt]/ /g')"
    typed="$(typed_text "$prompt")"
    trigger=""
    if marked "$typed" || { phrased "$typed" && answered "$sid" "$tp"; }; then
      trigger=phrase
    elif ! continuation "$typed"; then
      prev="$(cat "$dir/.last/$sid.turn" 2>/dev/null)"
      stopped="$(cat "$dir/.last/$sid.stopped" 2>/dev/null)"
      if [ -f "$dir/.last/$sid.rejected" ]; then
        trigger=rejection
      elif [ -n "$pid" ] && [ -n "$prev" ] && [ "$prev" != "$pid" ] && [ "$prev" != "$stopped" ]; then
        trigger=interrupt
      fi
    fi
    [ -n "$pid" ] && printf '%s\n' "$pid" > "$dir/.last/$sid.turn" 2>/dev/null
    call=""
    [ -f "$dir/.last/$sid.rejected" ] && call="$(cat "$dir/.last/$sid.rejected")"
    rm -f "$dir/.last/$sid.rejected"
    [ -n "$trigger" ] || exit 0
    write_record "$sid" "$trigger" "$input" "$call" ""
    exit 0
    ;;
  list)
    for f in "$dir"/C-*.txt; do
      [ -f "$f" ] || continue
      printf '%s\t%s\t%s\n' "$f" "$(sed -n 's/^captured: //p' "$f" | head -n 1)" "$(sed -n 's/^session: //p' "$f" | head -n 1)"
    done
    exit 0
    ;;
  count)
    n=0
    for f in "$dir"/C-*.txt; do [ -f "$f" ] && n=$((n + 1)); done
    echo "$n"
    exit 0
    ;;
  clear)
    [ ${#args[@]} -gt 0 ] || { echo "corrections: clear needs at least one record" >&2; exit 2; }
    status=0
    for a in "${args[@]}"; do
      name="$(basename "$a")"
      case "$name" in
        C-*.txt) ;;
        *) echo "corrections: not a correction record: $a" >&2; status=2; continue ;;
      esac
      if [ -f "$dir/$name" ]; then rm -f "$dir/$name"; else echo "corrections: no such record in $dir: $name" >&2; status=2; fi
    done
    exit "$status"
    ;;
  *)
    echo "corrections: unknown command: ${cmd:-(none)}; use remember, capture, list, count or clear" >&2
    exit 2
    ;;
esac
