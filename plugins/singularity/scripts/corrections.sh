#!/usr/bin/env bash
# User corrections for the singularity learn job: the plugin's hooks capture prompts in which the user
# corrects an agent, and the learn job reads and clears the queue.
#
# Hooks (hooks/hooks.json), reading the hook JSON on stdin. They print nothing and always exit 0:
#   corrections.sh remember    Stop: keeps the agent's last message in this session, to pair with a correction
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
# A prompt is queued when it starts with "correction:" or "defect:", or matches a pattern in
# correction-patterns.txt next to this script or in .claude/singularity/correction-patterns.txt.
# Exit status of list, count and clear: 0 ok, 2 usage error.
set -u

here="$(cd "$(dirname "$0")" && pwd)"
root=""
cmd=""
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --root) root="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
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

session_of() { # the hook input's session_id, safe as a file name
  local s
  s="$(printf '%s' "$1" | sed -nE 's/.*"session_id"[[:space:]]*:[[:space:]]*"([A-Za-z0-9_.-]+)".*/\1/p' | head -n 1)"
  printf '%s' "${s:-unknown}"
}

patterns() { # the active patterns, without comments and blank lines (a blank pattern would match anything)
  cat "$here/correction-patterns.txt" "$root/.claude/singularity/correction-patterns.txt" 2>/dev/null \
    | grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$'
}

is_correction() { # <prompt text>
  local text="$1"
  printf '%s' "$text" | grep -E -i -q '^[[:space:]]*(correction|defect)[[:space:]]*:' && return 0
  [ -n "$(patterns)" ] || return 1
  grep -E -i -q -f <(patterns) <<< "$text"
}

case "$cmd" in
  remember)
    input="$(cat)"
    enabled || exit 0
    prepare_dir || exit 0
    sid="$(session_of "$input")"
    printf '%s\n' "${input:0:8000}" > "$dir/.last/$sid.json" 2>/dev/null
    find "$dir/.last" -type f -mtime +7 -exec rm -f {} + 2>/dev/null
    exit 0
    ;;
  capture)
    input="$(cat)"
    enabled || exit 0
    input="${input:0:200000}"
    prompt="$(printf '%s' "$input" | sed -nE 's/.*"prompt"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -n 1)"
    [ -n "$prompt" ] || prompt="$input"
    prompt="$(printf '%s' "$prompt" | sed -e 's/\\[nrt]/ /g')"
    is_correction "$prompt" || exit 0
    prepare_dir || exit 0
    sid="$(session_of "$input")"
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    name="C-$stamp-$$-$RANDOM.txt"
    tmp="$dir/.tmp-$name"
    {
      printf 'captured: %s\n' "$(date -u +%FT%TZ)"
      printf 'session: %s\n\n' "$sid"
      printf '## The prompt (UserPromptSubmit hook input)\n\n%s\n\n' "${input:0:20000}"
      printf "## The agent's last message before it (Stop hook input)\n\n"
      if [ -f "$dir/.last/$sid.json" ]; then cat "$dir/.last/$sid.json"; else printf '(none recorded)\n'; fi
    } > "$tmp" 2>/dev/null && mv "$tmp" "$dir/$name" 2>/dev/null
    rm -f "$tmp" 2>/dev/null
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
