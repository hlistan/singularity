#!/usr/bin/env bash
# What became of the pipeline's changes after hand-off, for the singularity learn job: the edits people
# made before merging, and the later commits that fix or revert lines a run wrote.
# Usage:
#   outcomes.sh snapshot <slug> --base <commit>
#       At hand-off: keeps the run's change, committed or not, as the commit refs/singularity/handoff/<slug>
#       and prints it; the index and working tree stay as they are. Snapshots older than 180 days go.
#   outcomes.sh edits <slug> <reviewed commit>
#       What people changed after hand-off: the diff from the run's snapshot (else from its last commit
#       with the trailer `Singularity-Run: <slug>`) to the reviewed commit, in the files the run changed.
#   outcomes.sh later-fixes [--since <date>] [--days <n>]
#       Commits on the default branch since <date> (default: 90 days ago) whose message reads like a fix
#       or a revert and that change or delete lines a pipeline run wrote at most <n> days (default 90)
#       earlier; one line per commit and run, oldest first:
#       <revert|fix>\t<commit>\t<date>\t<run slug>\t<landed>\t<lines>\t<subject>, where <landed> is the
#       commit that brought the run's lines to the branch (its squash commit or merge) and <lines> how many
#       of them the commit changed. Leaves out commits a "later_fix" line in runs.jsonl records, and a
#       run's own commits.
# Options: --root <repository root> (default: the current repository); --branch <ref> (default:
#   origin/<conventions.default_branch> if it exists, else the local branch; default branch main).
# A line belongs to a run when `git blame -w -M -C` at the fix's parent names a commit with the run's
# `Singularity-Run: <slug>` trailer, the squash commit or merge of its PR/MR (`change` in its run line in
# runs.jsonl), a merge of its `branch`, or a commit such a merge brought in; or, on the machine that ran
# it, when the run's snapshot added that line (the pipeline left the change uncommitted).
# Exit status: 0 printed (possibly nothing), 2 usage error or no git repository, 3 (edits) neither a
# snapshot nor a commit of that run.
set -u

cmd=""
root=""
base=""
branch=""
since=""
days=90
args=()
need() { [ "$1" -ge 2 ] || { echo "outcomes: $2 needs a value" >&2; exit 2; }; }
while [ $# -gt 0 ]; do
  case "$1" in
    --root) need $# "$1"; root="$2"; shift 2 ;;
    --base) need $# "$1"; base="$2"; shift 2 ;;
    --branch) need $# "$1"; branch="$2"; shift 2 ;;
    --since) need $# "$1"; since="$2"; shift 2 ;;
    --days) need $# "$1"; days="$2"; shift 2 ;;
    -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
    -*) echo "outcomes: unknown option: $1" >&2; exit 2 ;;
    *) if [ -z "$cmd" ]; then cmd="$1"; else args+=("$1"); fi; shift ;;
  esac
done
usage() { echo "outcomes: usage: outcomes.sh snapshot <slug> --base <commit> | edits <slug> <commit> | later-fixes [--since <date>] [--days <n>]" >&2; exit 2; }
[ -n "$cmd" ] || usage
if [ -n "$root" ]; then cd "$root" 2>/dev/null || { echo "outcomes: cannot enter $root" >&2; exit 2; }; fi
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "outcomes: not in a git repository" >&2; exit 2; }
cd "$(git rev-parse --show-toplevel)" || exit 2
cfg=".claude/singularity.md"

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
json_field() { # <json line> <key>: a top-level string field's value
  printf '%s' "$1" | sed -nE 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' | head -n 1
}
valid_slug() { case "$1" in ''|*[!A-Za-z0-9._-]*) echo "outcomes: not a run slug: $1" >&2; exit 2 ;; esac; }
commit_of() { git rev-parse --verify -q "$1^{commit}"; }

tab="$(printf '\t')"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

snapshot() {
  slug="${args[0]:-}"
  valid_slug "$slug"
  [ -n "$base" ] || usage
  base_sha="$(commit_of "$base")" || { echo "outcomes: unknown base: $base" >&2; exit 2; }
  index="$(git rev-parse --git-path index)"
  [ -f "$index" ] && cp "$index" "$tmp/index"
  GIT_INDEX_FILE="$tmp/index" git add -A -- . >/dev/null 2>&1 || { echo "outcomes: cannot read the working tree" >&2; exit 2; }
  tree="$(GIT_INDEX_FILE="$tmp/index" git write-tree)" || exit 2
  parent=()
  head="$(commit_of HEAD)" && parent=(-p "$head")
  commit="$(printf 'singularity hand-off: %s\n\nbase: %s\n' "$slug" "$base_sha" |
    GIT_AUTHOR_NAME=singularity GIT_AUTHOR_EMAIL=singularity@localhost \
    GIT_COMMITTER_NAME=singularity GIT_COMMITTER_EMAIL=singularity@localhost \
    git commit-tree "$tree" "${parent[@]+"${parent[@]}"}")" || exit 2
  git update-ref "refs/singularity/handoff/$slug" "$commit" || exit 2
  now="$(date +%s)"
  git for-each-ref --format='%(refname) %(committerdate:unix)' refs/singularity/handoff |
    while read -r ref t; do
      [ $((now - t)) -gt $((180 * 86400)) ] && git update-ref -d "$ref"
    done
  echo "$commit"
}

edits() {
  slug="${args[0]:-}"
  valid_slug "$slug"
  [ -n "${args[1]:-}" ] || usage
  reviewed="$(commit_of "${args[1]}")" || { echo "outcomes: unknown commit: ${args[1]}" >&2; exit 2; }
  trailer="^Singularity-Run: ${slug}[[:space:]]*\$"
  if snap="$(commit_of "refs/singularity/handoff/$slug")"; then
    from="$snap"
    [ -n "$base" ] || base="$(git log -1 --format=%B "$snap" | sed -n 's/^base: //p' | head -n 1)"
    git -c core.quotePath=false diff --name-only "$base" "$snap" -- > "$tmp/files" 2>/dev/null || { echo "outcomes: unknown base: $base" >&2; exit 2; }
  else
    from="$(git log -1 --format=%H -E --grep="$trailer" "$reviewed")"
    [ -n "$from" ] || { echo "outcomes: no hand-off snapshot or Singularity-Run commit for $slug" >&2; exit 3; }
    git -c core.quotePath=false log --format= --name-only -E --grep="$trailer" "$reviewed" | sed '/^$/d' | sort -u > "$tmp/files"
  fi
  files=()
  while IFS= read -r f; do files+=("$f"); done < "$tmp/files"
  [ ${#files[@]} -gt 0 ] || exit 0
  git -c core.quotePath=false diff --no-color --no-ext-diff "$from" "$reviewed" -- "${files[@]}"
}

later_fixes() {
  case "$days" in ''|*[!0-9]*) echo "outcomes: --days needs a number" >&2; exit 2 ;; esac
  if [ -z "$branch" ]; then
    b="$(config_value conventions default_branch)"
    b="${b:-main}"
    if commit_of "refs/remotes/origin/$b" >/dev/null; then branch="origin/$b"; else branch="$b"; fi
  fi
  commit_of "$branch" >/dev/null || { echo "outcomes: unknown branch: $branch" >&2; exit 2; }
  dir="$(config_value learning dir)"
  runs="${dir:-.claude/singularity/experience}"
  runs="${runs%/}/runs.jsonl"
  [ -f "$runs" ] || exit 0

  # The runs (slug, branch, PR/MR), the fix commits already recorded, and which run fixed which.
  : > "$tmp/runs"
  : > "$tmp/fixed"
  grep -E '"type"[[:space:]]*:[[:space:]]*"run"' "$runs" | while IFS= read -r line; do
    s="$(json_field "$line" slug)"
    [ -n "$s" ] || continue
    printf '%s\t%s\t%s\n' "$s" "$(json_field "$line" branch)" "$(json_field "$line" change)" >> "$tmp/runs"
    f="$(json_field "$line" fixes)"
    [ -n "$f" ] && printf '%s\t%s\n' "$s" "$f" >> "$tmp/fixed"
  done
  grep -E '"type"[[:space:]]*:[[:space:]]*"later_fix"' "$runs" |
    sed -nE 's/.*"ref"[[:space:]]*:[[:space:]]*"([0-9a-f]+)".*/\1/p' > "$tmp/recorded"

  # Commits that belong to a run: trailer, squash commit or merge of its PR/MR, merge of its branch.
  git log --first-parent --max-count=5000 --format='%x1e%H %P%x1f%B' "$branch" > "$tmp/log"
  awk -v runs="$tmp/runs" '
    function ends(s, t) { return length(s) >= length(t) && substr(s, length(s) - length(t) + 1) == t }
    function has_ref(s, r,    i, rest, nx) { # r (e.g. #12) in s, not followed by another digit
      rest = s
      while ((i = index(rest, r)) > 0) {
        nx = substr(rest, i + length(r), 1)
        if (nx !~ /[0-9]/) return 1
        rest = substr(rest, i + length(r))
      }
      return 0
    }
    BEGIN { while ((getline l < runs) > 0) { split(l, f, "\t"); n++; rs[n] = f[1]; rb[n] = f[2]; rc[n] = f[3] }; RS = "\036"; FS = "\037" }
    NF >= 2 {
      split($1, h, " "); body = $2
      nl = index(body, "\n"); first = nl ? substr(body, 1, nl - 1) : body
      for (i = 1; i <= n; i++) {
        hit = index("\n" body "\n", "\nSingularity-Run: " rs[i] "\n") > 0
        if (!hit && rc[i] != "") {
          if (h[3] == "") hit = ends(first, "(" rc[i] ")")
          else hit = has_ref(body, rc[i])
        }
        if (!hit && rb[i] != "" && h[3] != "")
          hit = index(first, "\047" rb[i] "\047") > 0 || ends(first, "/" rb[i]) || ends(first, " " rb[i])
        if (hit) { print h[1] "\t" rs[i] "\t" h[2] "\t" h[3]; break }
      }
    }' "$tmp/log" > "$tmp/owned"
  : > "$tmp/map"
  while IFS="$tab" read -r sha s p1 p2; do
    printf '%s\t%s\t%s\n' "$sha" "$s" "$sha" >> "$tmp/map"
    [ -n "$p2" ] && git rev-list "$p1..$p2" 2>/dev/null | sed "s/\$/$tab$s$tab$sha/" >> "$tmp/map"
  done < "$tmp/owned"

  # Lines each local snapshot added: <slug>\t<base time>\t<path>\t<line>.
  : > "$tmp/added"
  git for-each-ref --format='%(refname)' refs/singularity/handoff | while IFS= read -r ref; do
    s="${ref##*/}"
    sbase="$(git log -1 --format=%B "$ref" | sed -n 's/^base: //p' | head -n 1)"
    t="$(git log -1 --format=%ct "$sbase" 2>/dev/null)" || continue
    [ -n "$t" ] || continue
    git -c core.quotePath=false diff -U0 --no-color --no-ext-diff -w "$sbase" "$ref" 2>/dev/null |
      awk -v s="$s" -v t="$t" '
        /^diff --git / { hdr = 1; next }
        hdr && /^\+\+\+ / { path = substr($0, 5); sub(/^b\//, "", path); next }
        /^@@/ { hdr = 0; next }
        !hdr && /^\+/ { print s "\t" t "\t" path "\t" substr($0, 2) }' >> "$tmp/added"
  done

  # Candidate fixes: fix-like or revert messages, not yet recorded.
  git log --first-parent --since="${since:-90 days ago}" --date=short \
    --format='%x1e%H%x1f%ct%x1f%cd%x1f%s%x1f%B' "$branch" |
    awk -v recorded="$tmp/recorded" '
      BEGIN { while ((getline r < recorded) > 0) if (r != "") rec[++nr] = r; RS = "\036"; FS = "\037" }
      NF >= 5 {
        for (i = 1; i <= nr; i++) if (substr($1, 1, length(rec[i])) == rec[i]) next
        msg = tolower($4 "\n" $5)
        kind = ""
        if ($4 ~ /^Revert / || index($5, "This reverts commit ") > 0) kind = "revert"
        else if (msg ~ /(^|[^a-z0-9_])(fix|fixes|fixed|bug|bugfix|hotfix|regression|broken|crash|crashes|incorrect|wrong)([^a-z0-9_]|$)/) kind = "fix"
        if (kind == "") next
        subj = $4; gsub(/\t/, " ", subj)
        print $1 "\t" $2 "\t" $3 "\t" kind "\t" subj
      }' > "$tmp/cands"

  : > "$tmp/out"
  while IFS="$tab" read -r fix ct day kind subj; do
    p1="$(commit_of "$fix^1")" || continue
    own="$(awk -F'\t' -v c="$fix" '$1 == c { print $2; exit }' "$tmp/map")"
    git -c core.quotePath=false diff -U0 --no-color --no-ext-diff -w "$p1" "$fix" |
      awk '
        /^diff --git / { hdr = 1; next }
        hdr && /^--- / { path = substr($0, 5); sub(/^a\//, "", path); next }
        /^@@ / {
          hdr = 0; split($2, o, ","); start = substr(o[1], 2); cnt = (2 in o) ? o[2] : 1
          if (path != "/dev/null" && cnt > 0 && ++hunks <= 50) print path "\t" start "\t" cnt
        }' > "$tmp/hunks"
    : > "$tmp/blamed"
    while IFS="$tab" read -r path start cnt; do
      git blame -w -M -C --line-porcelain -L "$start,+$cnt" "$p1" -- "$path" 2>/dev/null |
        awk -v path="$path" '
          (length($1) == 40 || length($1) == 64) && $1 ~ /^[0-9a-f]+$/ { sha = $1; next }
          /^author-time / { t = $2; next }
          /^\t/ { print sha "\t" t "\t" path "\t" substr($0, 2) }' >> "$tmp/blamed"
    done < "$tmp/hunks"
    awk -v ct="$ct" -v days="$days" -v own="$own" -v map="$tmp/map" -v added="$tmp/added" '
      function after3(l,    i, k) { for (k = 0; k < 3; k++) { i = index(l, "\t"); l = substr(l, i + 1) } return l }
      BEGIN {
        while ((getline l < map) > 0) { split(l, f, "\t"); if (!(f[1] in m)) { m[f[1]] = f[2]; land[f[1]] = f[3] } }
        while ((getline l < added) > 0) { split(l, f, "\t"); a[f[3] SUBSEP after3(l)] = a[f[3] SUBSEP after3(l)] " " f[1] ":" f[2] }
      }
      {
        split($0, f, "\t"); sha = f[1]; t = f[2] + 0; path = f[3]; line = after3($0)
        if (ct - t > days * 86400) next
        s = (sha in m) ? m[sha] : ""; ld = (sha in m) ? land[sha] : sha
        if (s == "") {
          trimmed = line; gsub(/[[:space:]]/, "", trimmed)
          if (length(trimmed) >= 10 && ((path SUBSEP line) in a)) {
            k = split(a[path SUBSEP line], c, " ")
            for (j = 1; j <= k; j++) { split(c[j], st, ":"); if (t >= st[2] + 0) { s = st[1]; break } }
          }
        }
        if (s != "" && s != own) { n[s]++; if (!(s in last) || t > lt[s]) { last[s] = ld; lt[s] = t } }
      }
      END { for (s in n) print s "\t" last[s] "\t" n[s] }' "$tmp/blamed" |
      while IFS="$tab" read -r s landed lines; do
        if [ -n "$own" ] && grep -q -x "$own$tab$s" "$tmp/fixed"; then continue; fi
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$ct" "$kind" "${fix:0:12}" "$day" "$s" "${landed:0:12}" "$lines" "$subj" >> "$tmp/out"
      done
  done < "$tmp/cands"
  sort -n "$tmp/out" | cut -f2-
}

case "$cmd" in
  snapshot) snapshot ;;
  edits) edits ;;
  later-fixes) later_fixes ;;
  *) echo "outcomes: unknown command: $cmd; use snapshot, edits or later-fixes" >&2; exit 2 ;;
esac
