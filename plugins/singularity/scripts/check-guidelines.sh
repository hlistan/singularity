#!/usr/bin/env bash
# Checks a project's agent guidelines against the repository as it is now, so that agents aren't
# told about code that is gone.
# Usage: check-guidelines.sh [--root <repository root>]
# Reads .claude/singularity/guidelines/*.md and .claude/rules/singularity/**/*.md. Checks each
# guideline (a list item, with its continuation lines; prose and code blocks are skipped) and
# prints one finding per line as <file>:<line>: <problem>:
#   - a path in backticks that doesn't exist, relative to the root or to any directory (for a
#     monorepo package); git-ignored paths count as existing;
#   - a rule without `paths` (it loads in every session), an unquoted pattern YAML can't parse,
#     or a `paths` pattern that matches no file, with Claude Code's glob rules;
#   - a guideline id (**G<n>**) used twice; wording from the old lesson log.
# Spans listed in .claude/singularity/guidelines/check-ignore.txt, one per line, are not paths.
# Exit status: 0 clean, 1 findings, 2 usage error or no git repository.
set -u
set -f # globs in this script are patterns, never file names

root=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) root="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "check-guidelines: unknown argument: $1" >&2; exit 2 ;;
  esac
done
if [ -z "$root" ]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "check-guidelines: not in a git repository; pass --root" >&2; exit 2; }
fi
cd "$root" 2>/dev/null || { echo "check-guidelines: cannot enter $root" >&2; exit 2; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "check-guidelines: $root is not a git repository" >&2; exit 2; }

files="$(find .claude/singularity/guidelines .claude/rules/singularity -name '*.md' -type f 2>/dev/null | sed 's|^\./||' | sort)"
if [ -z "$files" ]; then
  echo "check-guidelines: no guideline files"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
known="$tmp/known"
# Every file in the working tree, tracked or new: a guideline about code added in this change
# passes, and one about code deleted in it doesn't.
git -c core.quotePath=false ls-files --deleted 2>/dev/null | sort > "$tmp/deleted"
{ git -c core.quotePath=false ls-files; git -c core.quotePath=false ls-files --others --exclude-standard; } 2>/dev/null \
  | sort -u | comm -23 - "$tmp/deleted" > "$known"
ignore="$tmp/ignore"
{ grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' .claude/singularity/guidelines/check-ignore.txt 2>/dev/null || true; } > "$ignore"

# Emits <kind>\t<line>\t<value> records: path, glob (a rule's `paths` pattern), unquoted, nopaths,
# id and log.
IFS= read -r -d '' extract <<'AWK' || true
function ispath(s) {
  sub(/#.*$/, "", s); sub(/:[0-9][0-9:-]*$/, "", s)
  if (s == "" || s == "/" || s == "./") return 0
  if (s ~ /[[:space:]]/ || s ~ /:\/\//) return 0
  if (s ~ /^[\/.$@#~!%^&+-]/ && s !~ /^\.\//) return 0
  if (s ~ /[(){}<>=|;,'"\\]/) return 0
  if (s ~ /^[A-Za-z0-9-]+\.[A-Za-z][A-Za-z]+\//) return 0
  if (s ~ /^(origin|upstream|refs|heads|feature|bugfix|hotfix|application|text|image|audio|video|multipart|font|model)\//) return 0
  if (s ~ /\//) return 1
  if (s ~ /^[A-Za-z0-9_-][A-Za-z0-9_.-]*\.(md|ts|tsx|js|jsx|mjs|cjs|yaml|yml|toml|ini|cfg|conf|py|rb|go|rs|java|kt|kts|gradle|swift|cs|php|sql|sh|bash|ps1|vue|svelte|scss|xml|proto|graphql|tf|lock|txt|example)$/) return 1
  return 0
}
function emit(kind, value) { printf "%s\t%d\t%s\n", kind, FNR, value }
function pattern(raw,   p) { # one `paths` pattern as written: quoted or bare, maybe with a comment
  p = raw; sub(/^[[:space:]]+/, "", p)
  if (p ~ /^"/) { sub(/^"/, "", p); sub(/".*$/, "", p); return p }
  if (p ~ /^'/) { sub(/^'/, "", p); sub(/'.*$/, "", p); return p }
  sub(/[[:space:]]+#.*$/, "", p); sub(/[[:space:]]+$/, "", p)
  if (p ~ /^[*{&!|>]/) emit("unquoted", p)
  return p
}
function patterns(v,   i, c, depth, q, cur, p) { # a comma-separated list, commas in braces kept
  depth = 0; q = ""; cur = ""
  for (i = 1; i <= length(v); i++) {
    c = substr(v, i, 1)
    if (q != "") { if (c == q) q = ""; cur = cur c; continue }
    if (c == "\"" || c == "'") q = c
    if (c == "{") depth++
    if (c == "}") depth--
    if (c == "," && depth == 0) { p = pattern(cur); if (p != "") emit("glob", p); cur = ""; continue }
    cur = cur c
  }
  p = pattern(cur); if (p != "") emit("glob", p)
}
function scalar(v,   i, c, depth, cur) { # a comma-separated string of patterns
  depth = 0; cur = ""
  for (i = 1; i <= length(v); i++) {
    c = substr(v, i, 1)
    if (c == "{") depth++
    if (c == "}") depth--
    if (c == "," && depth == 0) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", cur); if (cur != "") emit("glob", cur); cur = ""; continue }
    cur = cur c
  }
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", cur); if (cur != "") emit("glob", cur)
}
FNR == 1 { fm = ($0 == "---"); inpaths = 0; haspaths = 0; fence = 0; item = 0; if (fm) next; if (rule) emit("nopaths", "") }
fm {
  if ($0 == "---") { fm = 0; if (rule && !haspaths) emit("nopaths", ""); next }
  if ($0 ~ /^paths:/) {
    inpaths = 1; haspaths = 1
    v = $0; sub(/^paths:[[:space:]]*/, "", v); sub(/[[:space:]]+#.*$/, "", v)
    if (v ~ /^\[/) { sub(/^\[/, "", v); sub(/\][[:space:]]*$/, "", v); patterns(v) }
    else if (v != "") scalar(pattern(v))
    next
  }
  if (inpaths && $0 ~ /^[[:space:]]*-/) {
    v = $0; sub(/^[[:space:]]*-[[:space:]]*/, "", v)
    p = pattern(v); if (p != "") emit("glob", p)
    next
  }
  if ($0 ~ /^[A-Za-z_]+:/) inpaths = 0
  next
}
/^[[:space:]]*(```|~~~)/ { fence = !fence; item = 0; next }
fence { next }
/^[[:space:]]*([-*+]|[0-9]+[.)])[[:space:]]/ { item = 1 }
/^[[:space:]]*$/ || /^#/ || /^[^[:space:]*+0-9-]/ { item = 0 }
item {
  if ($0 ~ /_Seen:_|_Last:_|_Refs:_|_Why:_/) emit("log", "lesson-log fields (_Seen:_, _Last:_, _Refs:_, _Why:_): state the current way, and keep history in the run digest")
  if ($0 ~ /\*\*L[0-9]+\*\*/) emit("log", "an old lesson id (**L<n>**); guidelines use **G<n>**")
  line = $0
  while (match(line, /\*\*G[0-9]+\*\*/)) { emit("id", substr(line, RSTART + 2, RLENGTH - 4)); line = substr(line, RSTART + RLENGTH) }
  line = $0
  while (match(line, /`[^`]+`/)) {
    span = substr(line, RSTART + 1, RLENGTH - 2)
    line = substr(line, RSTART + RLENGTH)
    if (ispath(span)) emit("path", span)
  }
}
AWK

expand_braces() { # prints each expansion of a pattern's {a,b} groups
  local s="$1" pre inner post item
  case "$s" in *'{'*'}'*) ;; *) printf '%s\n' "$s"; return ;; esac
  pre="$(printf '%s' "$s" | sed 's/^\([^{]*\){.*$/\1/')"
  inner="$(printf '%s' "$s" | sed 's/^[^{]*{\([^}]*\)}.*$/\1/')"
  post="$(printf '%s' "$s" | sed 's/^[^{]*{[^}]*}//')"
  local IFS=,
  for item in $inner; do expand_braces "$pre$item$post"; done
}

git_glob() { # true if a pathspec glob (Claude Code's rules: * stays within a directory, **/ spans them) matches a file
  [ -n "$(git -c core.quotePath=false ls-files --cached --others --exclude-standard -- ":(glob)$1" 2>/dev/null | head -n 1)" ]
}

rule_glob_matches() { # $1: a rule's `paths` pattern, relative to the project root
  local e
  while IFS= read -r e; do
    git_glob "${e%/}" && return 0
    git_glob "${e%/}/**" && return 0
  done <<EOF
$(expand_braces "$1")
EOF
  return 1
}

path_exists() { # $1: a path as written in a guideline
  local p="$1"
  grep -F -x -q -e "$p" "$ignore" && return 0
  p="${p%%#*}"
  p="$(printf '%s' "$p" | sed 's/:[0-9][0-9:-]*$//')"
  p="${p#./}"
  p="${p%/}"
  [ -e "$p" ] && return 0
  git check-ignore -q -- "$p" 2>/dev/null && return 0
  awk -v p="$p" '
    BEGIN { s = "/" p; d = "/" p "/" }
    $0 == p || index($0, p "/") == 1 || index($0, d) || (length($0) > length(s) && substr($0, length($0) - length(s) + 1) == s) { found = 1; exit }
    END { exit !found }' "$known" && return 0
  case "$p" in
    *[*?[]*) git_glob "$p" || git_glob "**/$p" ;;
    *) return 1 ;;
  esac
}

count=0
found() { echo "$1"; count=$((count + 1)); }
: > "$tmp/ids"
while IFS= read -r file; do
  case "$file" in .claude/rules/*) rule=1 ;; *) rule=0 ;; esac
  while IFS=$'\t' read -r kind ln value; do
    case "$kind" in
      path) path_exists "$value" || found "$file:$ln: \`$value\` doesn't exist (if it isn't a path, add it to .claude/singularity/guidelines/check-ignore.txt)" ;;
      glob) rule_glob_matches "$value" || found "$file:$ln: paths pattern \"$value\" matches no file" ;;
      unquoted) found "$file:$ln: quote the paths pattern $value: unquoted, YAML can't parse it, and the rule then loads in every session" ;;
      nopaths) found "$file:1: no paths frontmatter, so the rule loads in every session: add paths, or move its guidelines to .claude/singularity/guidelines/project.md" ;;
      id) printf '%s\t%s:%s\n' "$value" "$file" "$ln" >> "$tmp/ids" ;;
      log) found "$file:$ln: $value" ;;
    esac
  done < <(awk -v rule="$rule" "$extract" "$file")
done <<EOF
$files
EOF

while IFS= read -r id; do
  [ -n "$id" ] || continue
  where="$(awk -F'\t' -v id="$id" '$1 == id { printf "%s%s", sep, $2; sep = ", " }' "$tmp/ids")"
  found "${where%%,*}: guideline id $id is used more than once: $where"
done <<EOF
$(cut -f1 "$tmp/ids" | sort | uniq -d)
EOF

if [ "$count" -gt 0 ]; then
  echo "check-guidelines: $count finding(s)"
  exit 1
fi
echo "check-guidelines: clean"
