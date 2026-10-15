#!/usr/bin/env bash
# Runs the project's checks the way a CI job would, so that pass and fail come from exit codes, never from
# a model's reading of the output. The checks are the `commands` named in `checks.run` in
# .claude/singularity.md (default: build, lint, typecheck, test), each only if it is set and isn't TODO,
# then .claude/singularity/hooks/verify.sh if it is executable. Commands run from the project root with
# CI=true and no input. Success prints one line; each failure prints the command, its exit status and the
# end of its output.
# Usage: run-checks.sh [--only <name,name,...>] [--json <file>] [--tail <lines>]
#                      [--save-failures <file>] [--known-failures <file>] [--root <dir>]
#   --only            run these instead (names from `commands`, or verify_hook)
#   --json            also write the results as JSON: [{"name","command","exit","seconds"}]
#   --tail            lines of a failing check's output to print (default 40)
#   --save-failures   write the names of the checks that failed to this file, one per line (a baseline,
#                     taken before a change)
#   --known-failures  checks named in this file were already failing before the change: they are still
#                     run and reported, but don't fail the run
# Exit status: 0 every check passed (or failed only where known), 1 a check failed, 2 usage error or no
# config, 3 nothing to run.
set -u

root=""
only=""
json=""
tail_lines=40
save_failures=""
known_failures=""
while [ $# -gt 0 ]; do
  case "$1" in
    --only) only="${2:-}"; shift 2 ;;
    --json) json="${2:-}"; shift 2 ;;
    --tail) tail_lines="${2:-40}"; shift 2 ;;
    --save-failures) save_failures="${2:-}"; shift 2 ;;
    --known-failures) known_failures="${2:-}"; shift 2 ;;
    --root) root="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) echo "run-checks: unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$root" ] || root="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$root" 2>/dev/null || { echo "run-checks: cannot enter $root" >&2; exit 2; }
root="$PWD"
cfg="$root/.claude/singularity.md"
[ -f "$cfg" ] || { echo "run-checks: no .claude/singularity.md in $root" >&2; exit 2; }
case "$tail_lines" in ''|*[!0-9]*) echo "run-checks: --tail needs a number" >&2; exit 2 ;; esac

value() { # <section> <key>: a scalar under a top-level section of the config's YAML, unquoted, without comment
  awk -v sec="$1" -v key="$2" '
    $0 ~ "^" sec ":" { insec = 1; next }
    insec && /^[^[:space:]#]/ { insec = 0 }
    insec && $0 ~ "^[[:space:]]+" key ":" {
      v = $0; sub("^[[:space:]]+" key ":[[:space:]]*", "", v)
      if (v ~ /^"/) { sub(/^"/, "", v); sub(/"[[:space:]]*(#.*)?$/, "", v); gsub(/\\"/, "\"", v) }
      else if (v ~ /^\047/) { sub(/^\047/, "", v); sub(/\047[[:space:]]*(#.*)?$/, "", v) }
      else { sub(/[[:space:]]+#.*$/, "", v); sub(/[[:space:]]+$/, "", v) }
      print v; exit
    }' "$cfg"
}

if [ -n "$only" ]; then
  names="$(printf '%s' "$only" | tr ',' ' ')"
else
  names="$(value checks run | tr -d '[]' | tr ',' ' ')"
  [ -n "$(printf '%s' "$names" | tr -d ' ')" ] || names="build lint typecheck test"
  names="$names verify_hook"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
results="$tmp/results"
: > "$results"
ran=""
failed=0
known=""
failed_names=""
total_start="$(date +%s)"

is_known() { [ -n "$known_failures" ] && [ -f "$known_failures" ] && grep -F -x -q -e "$1" "$known_failures"; }

run_one() { # <name> <command>
  local name="$1" cmd="$2" start code secs log="$tmp/$1.log"
  start="$(date +%s)"
  CI=true bash -c "$cmd" > "$log" 2>&1 < /dev/null
  code=$?
  secs=$(( $(date +%s) - start ))
  printf '%s\t%s\t%s\t%s\n' "$name" "$code" "$secs" "$cmd" >> "$results"
  ran="$ran${ran:+, }$name"
  [ "$code" -eq 0 ] && return
  failed_names="$failed_names$name
"
  if is_known "$name"; then
    known="$known${known:+, }$name"
    printf 'run-checks: KNOWN FAIL %s (exit %s; it already failed before this change): %s\n' "$name" "$code" "$cmd"
    tail -n 5 "$log" | sed 's/^/  | /'
    return
  fi
  failed=$((failed + 1))
  printf 'run-checks: FAIL %s (exit %s, %ss): %s\n' "$name" "$code" "$secs" "$cmd"
  tail -n "$tail_lines" "$log" | sed 's/^/  | /'
}

for name in $names; do
  if [ "$name" = "verify_hook" ]; then
    hook="$root/.claude/singularity/hooks/verify.sh"
    [ -x "$hook" ] && run_one verify_hook "\"$hook\""
    continue
  fi
  cmd="$(value commands "$name")"
  case "$cmd" in ''|TODO|TODO\ *|todo) continue ;; esac
  run_one "$name" "$cmd"
done

if [ -n "$json" ]; then
  awk -F '\t' '
    function esc(s,   out, i, c) {
      out = ""
      for (i = 1; i <= length(s); i++) { c = substr(s, i, 1); if (c == "\\" || c == "\"") out = out "\\" c; else out = out c }
      return out
    }
    BEGIN { printf "[" }
    { printf "%s{\"name\":\"%s\",\"command\":\"%s\",\"exit\":%d,\"seconds\":%d}", (NR > 1 ? "," : ""), esc($1), esc($4), $2, $3 }
    END { print "]" }' "$results" > "$json"
fi

if [ -n "$save_failures" ]; then
  mkdir -p "$(dirname "$save_failures")" 2>/dev/null
  printf '%s' "$failed_names" > "$save_failures"
fi

if [ -z "$ran" ]; then
  echo "run-checks: nothing to run: set commands (build, lint, typecheck, test) in .claude/singularity.md"
  exit 3
fi
if [ "$failed" -gt 0 ]; then
  echo "run-checks: $failed check(s) failed of: $ran${known:+ (already failing before the change: $known)}"
  exit 1
fi
if [ -n "$known" ]; then
  echo "run-checks: passed ($ran), except checks that already failed before the change: $known"
  exit 0
fi
echo "run-checks: passed ($ran) in $(( $(date +%s) - total_start ))s"
exit 0
