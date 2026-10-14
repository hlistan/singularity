#!/usr/bin/env bash
# File-based task tracker for Project Singularity.
#
# Each task is a file in a git-ignored directory, named <STATUS>-<ID>-<slug>, optionally ending in
# .md, .txt or .markdown. The status is the file name prefix. Moving a task renames the file; a rename
# is atomic, so moving a task out of TODO also works as a claim that two sessions can't both win.
#
# Usage: tasks.sh [options] <command> [args]
#   list [STATE]                 status, id, slug and path of each task (tab-separated), in queue order
#   get <ID|file>                key=value lines, a '---' line, then the file content
#   next                         the first TODO task by priority then ID, like get, plus remaining=<n>
#   move <ID|file> <STATE> [--from STATE[,STATE...]]
#                                rename the task to STATE's prefix and print the new path;
#                                with --from, refuse unless the task is currently in one of those states
#   comment <ID|file> <TEXT>     append "- <time> <text>" under a "## Log" heading
#   create <slug> [TITLE]        new TODO task with the next free ID; body from stdin; prints the path
#   validate                     check names, duplicate IDs, and that the directory is git-ignored
#
# Every command except validate refuses to run when the directory is inside a git repository but not
# git-ignored (exit 1): task files can hold customer details and must never be committed.
#
# Options (before the command):
#   --dir DIR               task directory (default .tasks)
#   --id-prefix PREFIX      letters in front of new task numbers (default T)
#   --status STATE=PREFIX   rename a status; STATE is todo, in_progress, in_review, blocked or done
#   --extra-status PREFIX   another status the project uses (QA, ON_HOLD, ...); repeatable
#   --now "YYYY-MM-DD HH:MM"  timestamp for comments, instead of the current time
#
# STATE arguments accept a logical state (todo, in_progress, ...) or a status prefix (TODO, PROGRESS, QA, ...).
# Default prefixes: todo=TODO in_progress=PROGRESS in_review=REVIEW blocked=BLOCKED done=DONE.
# States other than todo may share a prefix (in_review=PROGRESS: moving to review then keeps the name).
# todo needs a prefix of its own, because claiming a task relies on renaming it out of the queue.
# Extra statuses have no logical state (get prints state= empty); files with undeclared prefixes are
# ignored, and validate reports them, so a typo such as TOD0 is caught instead of becoming a status.
# A task's priority is an optional "priority: <number>" line in YAML front matter; lower comes first.
#
# Exit codes: 0 ok, 1 validation problems or directory not git-ignored, 2 usage error, 3 not found or empty queue,
#             4 duplicate ID, 5 conflict (the task isn't in the expected state, or was taken).
#
# Compatible with bash 3.2 (macOS /bin/bash): no associative arrays, mapfile or ${var^^}.

set -u

DIR=".tasks"
ID_PREFIX="T"
NOW=""
DEFAULT_TODO="TODO"
DEFAULT_IN_PROGRESS="PROGRESS"
DEFAULT_IN_REVIEW="REVIEW"
DEFAULT_BLOCKED="BLOCKED"
DEFAULT_DONE="DONE"
S_TODO="$DEFAULT_TODO"
S_IN_PROGRESS="$DEFAULT_IN_PROGRESS"
S_IN_REVIEW="$DEFAULT_IN_REVIEW"
S_BLOCKED="$DEFAULT_BLOCKED"
S_DONE="$DEFAULT_DONE"
EXTRA_PREFIXES=""
STATES="todo in_progress in_review blocked done"
NO_PRIORITY=1000
NO_NUMBER=999999999

TAB="$(printf '\t')"
PREFIX_RE='^[A-Z][A-Z0-9_]*$'
ID_RE='^[A-Za-z0-9_]+$'
ID_PREFIX_RE='^[A-Za-z_]*$'
SLUG_RE='^[A-Za-z0-9][A-Za-z0-9._-]*$'
NAME_RE='^([A-Z][A-Z0-9_]*)-([A-Za-z0-9_]+)-(.+)$'
EXT_RE='\.(md|txt|markdown)$'
DIGITS_RE='^[0-9]+$'

die() {
  local code="$1"
  shift
  printf 'tasks: %s\n' "$*" >&2
  exit "$code"
}

usage() { awk '/^# Usage:/ { p = 1 } /^# Compatible/ { exit } p' "$0" | sed 's/^# \{0,1\}//'; }

# ---------- statuses ----------

prefix_of_state() {
  case "$1" in
    todo) printf '%s' "$S_TODO" ;;
    in_progress) printf '%s' "$S_IN_PROGRESS" ;;
    in_review) printf '%s' "$S_IN_REVIEW" ;;
    blocked) printf '%s' "$S_BLOCKED" ;;
    done) printf '%s' "$S_DONE" ;;
  esac
}

default_prefix_of_state() {
  case "$1" in
    todo) printf '%s' "$DEFAULT_TODO" ;;
    in_progress) printf '%s' "$DEFAULT_IN_PROGRESS" ;;
    in_review) printf '%s' "$DEFAULT_IN_REVIEW" ;;
    blocked) printf '%s' "$DEFAULT_BLOCKED" ;;
    done) printf '%s' "$DEFAULT_DONE" ;;
  esac
}

# prefix -> logical state. When states share a prefix, the state whose default prefix it is wins
# (PROGRESS stays in_progress under in_review=PROGRESS); otherwise the first state in $STATES order.
state_of_prefix() {
  local s
  for s in $STATES; do
    if [ "$(prefix_of_state "$s")" = "$1" ] && [ "$(default_prefix_of_state "$s")" = "$1" ]; then
      printf '%s' "$s"
      return 0
    fi
  done
  for s in $STATES; do
    if [ "$(prefix_of_state "$s")" = "$1" ]; then
      printf '%s' "$s"
      return 0
    fi
  done
  return 1
}

# Distinct status prefixes: the five states' (shared ones once), then the extra statuses.
all_prefixes() {
  local s p out=" "
  for s in $STATES; do
    p="$(prefix_of_state "$s")"
    case "$out" in *" $p "*) ;; *) out="$out$p " ;; esac
  done
  out="$out$EXTRA_PREFIXES"
  out="${out# }"
  printf '%s' "${out% }"
}

# True for the five configured prefixes and the extra statuses.
is_status() {
  [ -n "$1" ] || return 1
  state_of_prefix "$1" >/dev/null && return 0
  case " $EXTRA_PREFIXES " in *" $1 "*) return 0 ;; esac
  return 1
}

# STATE (logical or raw prefix) -> prefix; exits 2 if unknown.
resolve_prefix() {
  local p
  p="$(prefix_of_state "$1")"
  if [ -n "$p" ]; then
    printf '%s' "$p"
  elif is_status "$1"; then
    printf '%s' "$1"
  else
    die 2 "unknown state '$1' (use one of: $STATES, or a prefix: $(all_prefixes))"
  fi
}

set_status() {
  local state="${1%%=*}" prefix="${1#*=}"
  [ "$state" != "$1" ] || die 2 "--status needs STATE=PREFIX, got '$1'"
  [[ $prefix =~ $PREFIX_RE ]] || die 2 "status prefix '$prefix' must be upper-case letters, digits or _, starting with a letter"
  case "$state" in
    todo) S_TODO="$prefix" ;;
    in_progress) S_IN_PROGRESS="$prefix" ;;
    in_review) S_IN_REVIEW="$prefix" ;;
    blocked) S_BLOCKED="$prefix" ;;
    done) S_DONE="$prefix" ;;
    *) die 2 "unknown state '$state' in --status (use one of: $STATES)" ;;
  esac
}

add_extra_status() {
  [[ $1 =~ $PREFIX_RE ]] || die 2 "extra status '$1' must be upper-case letters, digits or _, starting with a letter"
  EXTRA_PREFIXES="${EXTRA_PREFIXES:+$EXTRA_PREFIXES }$1"
}

check_prefixes() {
  local s p seen=" "
  for s in in_progress in_review blocked "done"; do
    if [ "$(prefix_of_state "$s")" = "$S_TODO" ]; then
      die 2 "todo's prefix $S_TODO can't be shared with $s: claiming a task renames it out of $S_TODO, so the queue needs a prefix of its own"
    fi
  done
  for s in $STATES; do seen="$seen$(prefix_of_state "$s") "; done
  for p in $EXTRA_PREFIXES; do
    case "$seen" in *" $p "*) die 2 "status prefix $p used twice: an extra status must differ from the others and from the five states' prefixes" ;; esac
    seen="$seen$p "
  done
}

# ---------- names and files ----------

# parse_name BASENAME -> sets P_STATUS P_ID P_SLUG P_EXT; returns 1 if not STATUS-ID-slug.
parse_name() {
  local base="$1" ext=""
  case "$base" in .*) return 1 ;; esac
  if [[ $base =~ $EXT_RE ]]; then
    ext="${BASH_REMATCH[0]}"
    base="${base%"$ext"}"
  fi
  [[ $base =~ $NAME_RE ]] || return 1
  P_STATUS="${BASH_REMATCH[1]}"
  P_ID="${BASH_REMATCH[2]}"
  P_SLUG="${BASH_REMATCH[3]}"
  P_EXT="$ext"
}

# Every file named STATUS-ID-slug, whatever the status: status<TAB>id<TAB>slug<TAB>path
each_named() {
  local f
  for f in "$DIR"/*; do
    [ -f "$f" ] || continue
    parse_name "${f##*/}" || continue
    printf '%s\t%s\t%s\t%s\n' "$P_STATUS" "$P_ID" "$P_SLUG" "$f"
  done
}

# Only tasks whose prefix is a configured status.
each_task() {
  local st id slug path
  each_named | while IFS="$TAB" read -r st id slug path; do
    if is_status "$st"; then
      printf '%s\t%s\t%s\t%s\n' "$st" "$id" "$slug" "$path"
    fi
  done
}

priority_of() {
  awk '{ sub(/\r$/, "") }
       NR == 1 { if ($0 != "---") exit; next }
       /^---[[:space:]]*$/ { exit }
       /^priority:[[:space:]]*[0-9]+[[:space:]]*$/ { sub(/^priority:[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); print; exit }' "$1"
}

title_of() {
  awk '{ sub(/\r$/, "") }
       NR == 1 && $0 == "---" { fm = 1; next }
       fm { if ($0 ~ /^---[[:space:]]*$/) fm = 0; next }
       /^# / { sub(/^# +/, ""); print; exit }' "$1"
}

# Tasks in queue order (priority, then the number in the ID, then file name), optionally one prefix only.
sorted_tasks() {
  local filter="${1:-}" st id slug path pr num
  each_task | while IFS="$TAB" read -r st id slug path; do
    if [ -n "$filter" ] && [ "$st" != "$filter" ]; then continue; fi
    pr="$(priority_of "$path")"
    [ -n "$pr" ] || pr="$NO_PRIORITY"
    num="${id//[!0-9]/}"
    [ -n "$num" ] || num="$NO_NUMBER"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$pr" "$num" "$st" "$id" "$slug" "$path"
  done | sort -t "$TAB" -k1,1n -k2,2n -k6,6 | cut -f3-
}

require_dir() {
  [ -d "$DIR" ] || die 3 "task directory $DIR not found (create it, or set tracker.files.dir in .claude/singularity.md)"
}

# find_task ID-or-file -> sets F_PATH F_STATUS F_ID F_SLUG F_EXT; exits 2, 3 or 4.
find_task() {
  local arg="$1" id st i slug path count=0 names=""
  if parse_name "${arg##*/}"; then id="$P_ID"; else id="$arg"; fi
  [[ $id =~ $ID_RE ]] || die 2 "invalid task ID '$arg' (letters, digits and _ only)"
  while IFS="$TAB" read -r st i slug path; do
    [ "$i" = "$id" ] || continue
    count=$((count + 1))
    names="${names:+$names; }${path##*/}"
    F_PATH="$path"
    F_STATUS="$st"
    F_ID="$i"
    F_SLUG="$slug"
  done < <(each_task)
  [ "$count" -gt 0 ] || die 3 "no task $id in $DIR"
  [ "$count" -eq 1 ] || die 4 "duplicate ID $id: $names"
  parse_name "${F_PATH##*/}"
  F_EXT="$P_EXT"
}

# 0 ignored, 1 not ignored, 2 can't tell (not a git repository, or the directory is outside it).
ignore_status() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 2
  git check-ignore -q -- "$DIR/probe" 2>/dev/null
  case $? in
    0) return 0 ;;
    1) return 1 ;;
    *) return 2 ;;
  esac
}

NOT_IGNORED_MSG="is not git-ignored: add it to .gitignore so tasks never reach the repository"

require_ignored() {
  ignore_status
  if [ $? -eq 1 ]; then die 1 "$DIR $NOT_IGNORED_MSG"; fi
}

print_task() { # path status id slug
  local title pr state
  title="$(title_of "$1")"
  [ -n "$title" ] || title="${4//-/ }"
  pr="$(priority_of "$1")"
  state="$(state_of_prefix "$2")"
  printf 'status=%s\nstate=%s\nid=%s\nslug=%s\ntitle=%s\npriority=%s\npath=%s\n' "$2" "$state" "$3" "$4" "$title" "$pr" "$1"
}

# ---------- commands ----------

cmd_list() {
  local filter=""
  if [ $# -ge 1 ]; then filter="$(resolve_prefix "$1")" || exit $?; fi
  require_dir
  sorted_tasks "$filter"
}

cmd_get() {
  [ $# -eq 1 ] || die 2 "usage: get <ID|file>"
  require_dir
  find_task "$1"
  print_task "$F_PATH" "$F_STATUS" "$F_ID" "$F_SLUG"
  printf -- '---\n'
  cat "$F_PATH"
}

cmd_next() {
  [ $# -eq 0 ] || die 2 "usage: next"
  require_dir
  local queue first count st id slug path
  queue="$(sorted_tasks "$S_TODO")"
  [ -n "$queue" ] || die 3 "queue is empty: no $S_TODO tasks in $DIR"
  first="$(printf '%s\n' "$queue" | head -n 1)"
  count="$(printf '%s\n' "$queue" | wc -l | tr -d ' ')"
  IFS="$TAB" read -r st id slug path <<< "$first"
  print_task "$path" "$st" "$id" "$slug"
  printf 'remaining=%s\n---\n' "$((count - 1))"
  cat "$path"
}

cmd_move() {
  [ $# -ge 2 ] || die 2 "usage: move <ID|file> <STATE> [--from STATE[,STATE...]]"
  local ref="$1" to from="" target state p
  to="$(resolve_prefix "$2")" || exit $?
  shift 2
  while [ $# -gt 0 ]; do
    case "$1" in
      --from)
        [ $# -ge 2 ] || die 2 "--from needs a state"
        [ -n "$2" ] || die 2 "--from needs a state"
        from=""
        for state in $(printf '%s' "$2" | tr ',' ' '); do
          p="$(resolve_prefix "$state")" || exit $?
          from="${from:+$from }$p"
        done
        [ -n "$from" ] || die 2 "--from needs a state"
        shift 2
        ;;
      *) die 2 "unexpected argument '$1'" ;;
    esac
  done
  require_dir
  find_task "$ref"
  if [ -n "$from" ]; then
    case " $from " in
      *" $F_STATUS "*) ;;
      *)
        case "$from" in
          *" "*) die 5 "$F_ID is $F_STATUS, expected one of $from (taken by another session?)" ;;
          *) die 5 "$F_ID is $F_STATUS, expected $from (taken by another session?)" ;;
        esac
        ;;
    esac
  fi
  target="$DIR/$to-$F_ID-$F_SLUG$F_EXT"
  if [ "$F_PATH" != "$target" ]; then
    [ ! -e "$target" ] || die 5 "$target already exists"
    mv "$F_PATH" "$target" 2>/dev/null || die 5 "could not move $F_PATH (taken by another session?)"
  fi
  printf '%s\n' "$target"
}

cmd_comment() {
  [ $# -eq 2 ] || die 2 "usage: comment <ID|file> <TEXT>"
  local text now
  text="$(printf '%s' "$2" | tr '\r\n' '  ' | sed -e 's/  */ /g' -e 's/^ //' -e 's/ $//')"
  [ -n "$text" ] || die 2 "comment text is empty"
  require_dir
  find_task "$1"
  now="$NOW"
  [ -n "$now" ] || now="$(date '+%Y-%m-%d %H:%M')"
  [ -z "$(tail -c 1 "$F_PATH")" ] || printf '\n' >> "$F_PATH"
  grep -qx '## Log' "$F_PATH" || printf '\n## Log\n\n' >> "$F_PATH"
  printf -- '- %s %s\n' "$now" "$text" >> "$F_PATH"
}

cmd_create() {
  [ $# -ge 1 ] && [ $# -le 2 ] || die 2 "usage: create <slug> [TITLE] < body"
  local slug="$1" title="${2:-}" body="" max=0 num st id rest path
  [[ $slug =~ $SLUG_RE ]] || die 2 "invalid slug '$slug' (letters, digits, '.', '_' and '-')"
  [[ $ID_PREFIX =~ $ID_PREFIX_RE ]] || die 2 "invalid --id-prefix '$ID_PREFIX' (letters and _ only)"
  mkdir -p "$DIR" || die 2 "cannot create $DIR"
  # Every STATUS-ID-slug name counts, even with an unknown status, so an ID is never reused.
  while IFS="$TAB" read -r st id rest; do
    case "$id" in
      "$ID_PREFIX"*)
        num="${id#"$ID_PREFIX"}"
        if [[ $num =~ $DIGITS_RE ]] && [ "$((10#$num))" -gt "$max" ]; then max="$((10#$num))"; fi
        ;;
    esac
  done < <(each_named)
  [ -n "$title" ] || title="${slug//-/ }"
  if [ ! -t 0 ]; then body="$(cat)"; fi
  path="$DIR/$S_TODO-$ID_PREFIX$((max + 1))-$slug.md"
  [ ! -e "$path" ] || die 5 "$path already exists"
  {
    printf '# %s\n' "$title"
    if [ -n "$body" ]; then printf '\n%s\n' "$body"; fi
  } > "$path"
  printf '%s\n' "$path"
}

cmd_validate() {
  [ $# -eq 0 ] || die 2 "usage: validate"
  require_dir
  local problems=0 f base dupes total
  ignore_status
  if [ $? -eq 1 ]; then
    printf 'tasks: %s %s\n' "$DIR" "$NOT_IGNORED_MSG" >&2
    problems=$((problems + 1))
  fi
  for f in "$DIR"/*; do
    [ -f "$f" ] || continue
    base="${f##*/}"
    if parse_name "$base"; then
      if ! is_status "$P_STATUS"; then
        printf 'tasks: %s: unknown status %s (expected one of: %s; declare other statuses in tracker.files.extra_statuses)\n' "$base" "$P_STATUS" "$(all_prefixes)" >&2
        problems=$((problems + 1))
      fi
    elif is_status "${base%%-*}"; then
      printf 'tasks: %s: expected STATUS-ID-slug, e.g. %s-T1-short-name.md\n' "$base" "$S_TODO" >&2
      problems=$((problems + 1))
    fi
  done
  dupes="$(each_task | cut -f2 | sort | uniq -d)"
  for f in $dupes; do
    printf 'tasks: duplicate ID %s\n' "$f" >&2
    problems=$((problems + 1))
  done
  [ "$problems" -eq 0 ] || exit 1
  total="$(each_task | wc -l | tr -d ' ')"
  printf 'ok: %s task(s) in %s\n' "$total" "$DIR"
}

# ---------- main ----------

need_value() { [ $# -ge 2 ] || die 2 "$1 needs a value"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dir) need_value "$@"; DIR="$2"; shift 2 ;;
    --id-prefix) need_value "$@"; ID_PREFIX="$2"; shift 2 ;;
    --status) need_value "$@"; set_status "$2"; shift 2 ;;
    --extra-status) need_value "$@"; add_extra_status "$2"; shift 2 ;;
    --now) need_value "$@"; NOW="$2"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    --) shift; break ;;
    -*) die 2 "unknown option '$1'" ;;
    *) break ;;
  esac
done
[ "$DIR" = "/" ] || DIR="${DIR%/}"
check_prefixes

[ $# -ge 1 ] || { usage >&2; exit 2; }
command="$1"
shift
[ "$command" = "validate" ] || require_ignored
case "$command" in
  list) cmd_list ${1+"$@"} ;;
  get) cmd_get ${1+"$@"} ;;
  next) cmd_next ${1+"$@"} ;;
  move) cmd_move ${1+"$@"} ;;
  comment) cmd_comment ${1+"$@"} ;;
  create) cmd_create ${1+"$@"} ;;
  validate) cmd_validate ${1+"$@"} ;;
  *) die 2 "unknown command '$command' (list, get, next, move, comment, create, validate)" ;;
esac
