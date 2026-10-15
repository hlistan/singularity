#!/usr/bin/env bash
# Keeps tests honest while an agent makes them pass. Agents under pressure to get green edit, weaken or
# delete the tests instead of fixing the code, so:
#   test-guard.sh freeze <file>...   records tests that now fail for the right reason (the red step)
#   test-guard.sh pre-edit           PreToolUse hook on Edit|Write|NotebookEdit: blocks an edit to a frozen
#                                    test, and says to stop and report if the test itself is wrong
#   test-guard.sh check --base <base> [--plan <plan.md>]
#                                    reports frozen tests changed or deleted since they were frozen, and
#                                    tests that existed at <base> but were changed or deleted without the
#                                    plan naming them; exit 1 if there are any
#   test-guard.sh reset              forgets the frozen tests (the pipeline does this at each implement
#                                    stage and at hand-off)
#   test-guard.sh is-test <path>...  prints the paths that look like tests
# Options: --root <project root> (default: $CLAUDE_PROJECT_DIR, else the current directory).
# Tests are matched by checks.test_pattern in .claude/singularity.md (an extended regular expression on
# the path), or by common layouts: test/, tests/, __tests__/, spec/, *_test.*, *.test.*, *.spec.*,
# test_*.py, *Test.java and the like. The frozen list is <work_dir>/.state/frozen-tests.txt, never committed.
# Exit status: 0 ok, 1 problems found (check), 2 blocked edit (pre-edit) or usage error.
set -u

root=""
cmd=""
args=()
base=""
plan=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) root="${2:-}"; shift 2 ;;
    --base) base="${2:-}"; shift 2 ;;
    --plan) plan="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
    *) if [ -z "$cmd" ]; then cmd="$1"; else args+=("$1"); fi; shift ;;
  esac
done
[ -n "$root" ] || root="${CLAUDE_PROJECT_DIR:-$PWD}"
root="$(cd "$root" 2>/dev/null && pwd -P)" || { [ "$cmd" = "pre-edit" ] && exit 0; echo "test-guard: cannot enter the project root" >&2; exit 2; }
cfg="$root/.claude/singularity.md"

value() { # <section> <key>
  [ -f "$cfg" ] || return 0
  awk -v sec="$1" -v key="$2" '
    $0 ~ "^" sec ":" { insec = 1; next }
    insec && /^[^[:space:]#]/ { insec = 0 }
    insec && $0 ~ "^[[:space:]]+" key ":" {
      v = $0; sub("^[[:space:]]+" key ":[[:space:]]*", "", v)
      if (v ~ /^"/) { sub(/^"/, "", v); sub(/"[[:space:]]*(#.*)?$/, "", v); gsub(/\\\\/, "\\", v) }
      else if (v ~ /^\047/) { sub(/^\047/, "", v); sub(/\047[[:space:]]*(#.*)?$/, "", v) }
      else { sub(/[[:space:]]+#.*$/, "", v); sub(/[[:space:]]+$/, "", v) }
      print v; exit
    }' "$cfg"
}

pattern="$(value checks test_pattern)"
[ -n "$pattern" ] || pattern='(^|/)(tests?|__tests__|specs?|testing|e2e)/|(^|/)test_[^/]*\.py$|_test\.[A-Za-z0-9]+$|\.(test|spec)\.[A-Za-z0-9]+$|(Tests?|IT)\.(java|kt|kts|scala|cs|swift|groovy)$|_spec\.rb$|Test\.php$|_test\.exs$'
work_dir="$(value conventions work_dir)"
work_dir="${work_dir:-.agentic/work}"
case "$work_dir" in /*) state="${work_dir%/}/.state" ;; *) state="$root/${work_dir%/}/.state" ;; esac
frozen="$state/frozen-tests.txt"

is_test() { printf '%s\n' "$1" | grep -E -q -- "$pattern"; }
relative() { # an absolute or relative path, relative to the root
  local p="$1" d
  case "$p" in
    /*) d="$(cd "$(dirname "$p")" 2>/dev/null && pwd -P)" && p="$d/$(basename "$p")"
        case "$p" in "$root"/*) p="${p#"$root"/}" ;; esac ;;
    ./*) p="${p#./}" ;;
  esac
  printf '%s' "$p"
}
hash_of() { git -C "$root" hash-object -- "$1" 2>/dev/null; }

case "$cmd" in
  freeze)
    [ ${#args[@]} -gt 0 ] || { echo "test-guard: freeze needs at least one file" >&2; exit 2; }
    mkdir -p "$state" && { [ -f "$state/.gitignore" ] || printf '*\n' > "$state/.gitignore"; }
    status=0
    for f in "${args[@]}"; do
      rel="$(relative "$f")"
      if [ ! -f "$root/$rel" ]; then echo "test-guard: no such file: $f" >&2; status=2; continue; fi
      is_test "$rel" || echo "test-guard: $rel doesn't look like a test; freezing it anyway" >&2
      h="$(hash_of "$root/$rel")"
      awk -F '\t' -v p="$rel" '$2 != p' "$frozen" 2>/dev/null > "$frozen.tmp" || true
      printf '%s\t%s\n' "$h" "$rel" >> "$frozen.tmp"
      mv "$frozen.tmp" "$frozen"
      echo "test-guard: frozen $rel"
    done
    exit "$status"
    ;;
  pre-edit)
    input="$(cat)"
    [ -s "$frozen" ] || exit 0
    path="$(printf '%s' "$input" | sed -nE 's/.*"(file_path|notebook_path)"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\2/p' | head -n 1)"
    [ -n "$path" ] || exit 0
    rel="$(relative "$path")"
    if cut -f2 "$frozen" | grep -F -x -q -e "$rel"; then
      {
        echo "Blocked by singularity: $rel is a frozen test. It failed for the right reason before the code"
        echo "existed, and making it pass means changing the code, not the test."
        echo "If the test itself is wrong, or the plan can't work, stop and say so in your final answer."
        echo "(A person can unfreeze all tests with: test-guard.sh reset, in the singularity plugin's scripts.)"
      } >&2
      exit 2
    fi
    exit 0
    ;;
  check)
    [ -n "$base" ] || { echo "test-guard: check needs --base <commit>" >&2; exit 2; }
    git -C "$root" rev-parse --verify --quiet "$base^{commit}" >/dev/null || { echo "test-guard: unknown base: $base" >&2; exit 2; }
    problems=0
    if [ -s "$frozen" ]; then
      while IFS="$(printf '\t')" read -r h rel; do
        [ -n "$rel" ] || continue
        if [ ! -f "$root/$rel" ]; then echo "$rel: a frozen test was deleted"; problems=$((problems + 1))
        elif [ "$(hash_of "$root/$rel")" != "$h" ]; then echo "$rel: a frozen test was changed after it was frozen"; problems=$((problems + 1)); fi
      done < "$frozen"
    fi
    while IFS="$(printf '\t')" read -r st p1 p2; do
      old="$p1"
      [ -n "$old" ] || continue
      is_test "$old" || continue
      git -C "$root" cat-file -e "$base:$old" 2>/dev/null || continue
      if [ -n "$plan" ] && [ -f "$plan" ] && grep -F -q -e "$old" "$plan"; then continue; fi
      case "$st" in
        D*) what="deleted" ;;
        R*) what="renamed to $p2" ;;
        *) what="changed" ;;
      esac
      cut -f2 "$frozen" 2>/dev/null | grep -F -x -q -e "$old" && continue
      echo "$old: an existing test was $what, and the plan doesn't name it"
      problems=$((problems + 1))
    done < <(git -C "$root" -c core.quotePath=false diff --name-status -M "$base" --)
    [ "$problems" -eq 0 ] && { echo "test-guard: tests intact"; exit 0; }
    exit 1
    ;;
  reset)
    rm -f "$frozen"
    exit 0
    ;;
  is-test)
    for p in "${args[@]+"${args[@]}"}"; do is_test "$p" && printf '%s\n' "$p"; done
    exit 0
    ;;
  *)
    echo "test-guard: unknown command: ${cmd:-(none)}; use freeze, pre-edit, check, reset or is-test" >&2
    exit 2
    ;;
esac
