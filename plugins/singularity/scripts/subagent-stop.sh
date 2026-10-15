#!/usr/bin/env bash
# SubagentStop hook: the implementer can't finish while the project's checks fail. When the agent bound to
# the implement role (singularity:implementer, or roles.implement.agent) stops, this runs run-checks.sh;
# on a failure it exits 2, and Claude Code keeps the implementer working with the failures as its next
# instruction. After checks.stop_retries blocks in a row (default 3) it lets the agent stop, and the
# pipeline's own checks stage reports what still fails. Checks listed in <work_dir>/.state/baseline-failures,
# which the pipeline writes before implementing, were failing before the change and don't block.
# Off with checks.implement_gate: false.
# Every other agent, and any project without .claude/singularity.md, passes straight through.
set -u
input="$(cat)"
here="$(cd "$(dirname "$0")" && pwd)"
root="${CLAUDE_PROJECT_DIR:-$PWD}"
cfg="$root/.claude/singularity.md"
[ -f "$cfg" ] || exit 0

json_string() { printf '%s' "$input" | sed -nE 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -n 1; }
value() { # <section> <key>
  awk -v sec="$1" -v key="$2" '
    $0 ~ "^" sec ":" { insec = 1; next }
    insec && /^[^[:space:]#]/ { insec = 0 }
    insec && $0 ~ "^[[:space:]]+" key ":" {
      v = $0; sub("^[[:space:]]+" key ":[[:space:]]*", "", v); sub(/[[:space:]]+#.*$/, "", v)
      gsub(/["\047]/, "", v); print v; exit
    }' "$cfg"
}
bound_implementer() { # roles.implement.agent, inline ({ agent: x }) or nested
  awk '
    /^roles:/ { insec = 1; next }
    insec && /^[^[:space:]#]/ { insec = 0 }
    insec && /^[[:space:]]+implement:/ {
      if (match($0, /agent:[[:space:]]*[A-Za-z0-9_.:-]+/)) { v = substr($0, RSTART, RLENGTH); sub(/agent:[[:space:]]*/, "", v); print v; exit }
      inimpl = 1; next
    }
    inimpl && /^[[:space:]]+agent:/ { v = $0; sub(/^[[:space:]]+agent:[[:space:]]*/, "", v); sub(/[[:space:]]+#.*$/, "", v); gsub(/["\047]/, "", v); print v; exit }
    inimpl && /^[[:space:]]+[A-Za-z_]+:/ && !/^[[:space:]]+(agent|model|effort):/ { inimpl = 0 }' "$cfg"
}

agent="$(json_string agent_type)"
[ -n "$agent" ] || exit 0
[ "$(value checks implement_gate)" = "false" ] && exit 0
bound="$(bound_implementer)"
case "$agent" in
  singularity:implementer) ;;
  *) [ -n "$bound" ] && { [ "$agent" = "$bound" ] || [ "${agent##*:}" = "$bound" ]; } || exit 0 ;;
esac

retries="$(value checks stop_retries)"
case "$retries" in ''|*[!0-9]*) retries=3 ;; esac
work_dir="$(value conventions work_dir)"
work_dir="${work_dir:-.agentic/work}"
case "$work_dir" in /*) state="${work_dir%/}/.state" ;; *) state="$root/${work_dir%/}/.state" ;; esac
mkdir -p "$state" 2>/dev/null && { [ -f "$state/.gitignore" ] || printf '*\n' > "$state/.gitignore"; }
id="$(json_string agent_id)"
id="$(printf '%s' "${id:-$(json_string session_id)}" | tr -c 'A-Za-z0-9_.-' '_')"
counter="$state/stop-${id:-unknown}.count"
count="$(cat "$counter" 2>/dev/null)"
case "$count" in ''|*[!0-9]*) count=0 ;; esac

if [ "$count" -ge "$retries" ]; then
  rm -f "$counter"
  exit 0
fi

known=()
[ -f "$state/baseline-failures" ] && known=(--known-failures "$state/baseline-failures")
out="$(bash "$here/run-checks.sh" --root "$root" --tail 30 "${known[@]+"${known[@]}"}" 2>&1)"
code=$?
if [ "$code" -eq 1 ]; then
  count=$((count + 1))
  printf '%s\n' "$count" > "$counter" 2>/dev/null
  {
    printf "singularity: you can't finish yet: the project's checks fail (block %s of %s).\n" "$count" "$retries"
    printf 'Fix the cause in the code. Never weaken, skip or delete a test or a check to get green, and never edit a test you froze.\n'
    printf "If the failure isn't caused by your change, or the plan can't work, stop and say so in your final answer instead.\n\n"
    printf '%s\n' "$out"
  } >&2
  exit 2
fi
rm -f "$counter"
exit 0
