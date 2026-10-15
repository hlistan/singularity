#!/usr/bin/env bash
# Prints the whole change in a checkout against a base, the way a reviewer has to see it: every change to
# tracked files, committed, staged or not (`git diff <base>`), followed by every new file that git doesn't
# ignore, as a diff against nothing. `git diff` alone leaves untracked files out, and they often hold most
# of a change: new modules, new tests.
# Usage: change-diff.sh <base> [--stat] [--root <dir>]
#   --stat  a summary instead: changed tracked files, then new files with their line counts
# Exit status: 0 printed (possibly nothing), 2 usage error, no git repository or unknown base.
set -u

base=""
stat=0
root=""
while [ $# -gt 0 ]; do
  case "$1" in
    --stat) stat=1; shift ;;
    --root) root="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    -*) echo "change-diff: unknown option: $1" >&2; exit 2 ;;
    *) if [ -z "$base" ]; then base="$1"; shift; else echo "change-diff: one base only" >&2; exit 2; fi ;;
  esac
done
[ -n "$base" ] || { echo "change-diff: usage: change-diff.sh <base> [--stat] [--root <dir>]" >&2; exit 2; }
if [ -n "$root" ]; then cd "$root" 2>/dev/null || { echo "change-diff: cannot enter $root" >&2; exit 2; }; fi
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "change-diff: not in a git repository" >&2; exit 2; }
git rev-parse --verify --quiet "$base^{commit}" >/dev/null || { echo "change-diff: unknown base: $base" >&2; exit 2; }
cd "$(git rev-parse --show-toplevel)" || exit 2

if [ "$stat" -eq 1 ]; then
  git -c core.quotePath=false diff --stat "$base" --
  git -c core.quotePath=false ls-files --others --exclude-standard -z | while IFS= read -r -d '' f; do
    printf ' %s (new, %s lines)\n' "$f" "$(wc -l < "$f" 2>/dev/null | tr -d ' ')"
  done
  exit 0
fi

git -c core.quotePath=false diff --binary "$base" --
git -c core.quotePath=false ls-files --others --exclude-standard -z | while IFS= read -r -d '' f; do
  git -c core.quotePath=false diff --binary --no-index -- /dev/null "$f"
done
exit 0
