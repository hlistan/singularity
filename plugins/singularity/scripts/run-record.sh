#!/usr/bin/env bash
# The mechanical parts of a pipeline run's record: times come from the clock, never typed or estimated, and
# the spec and plan drafts stay as the agents wrote them, for the learn job to compare with the finals.
# Usage:
#   run-record.sh stamp <run dir> <span> start|end
#       appends "<epoch>\t<UTC time>\t<span>\t<start|end>" to <run dir>/clock.log; prints the UTC time.
#       A span is a stage, project stage, fix round or gate: spec, gate-spec, plan, implement, fix-1, ...;
#       the span "run" goes from the start to the hand-off or early stop.
#   run-record.sh times <run dir>
#       prints the times in clock.log as one JSON line: lead_s (the span "run"); active_s (seconds any other
#       span not named gate-* was open, overlaps counted once); gate_wait_s (per gate-<name> span); spans
#       (per span: seconds, summed over repeats, and count); open (spans started and not ended).
#   run-record.sh draft <file> <draft>
#       copies an agent's output to its draft once, read-only; an existing draft is kept.
# Exit status: 0 done; 1 (times) the log was edited or misused: a line out of time order, an end without a
# start, a span started twice, each reported on stderr, times still printed for the rest; 2 usage error;
# 3 (times) no clock.log.
set -u

usage() { echo "run-record: usage: run-record.sh stamp <run dir> <span> start|end | times <run dir> | draft <file> <draft>" >&2; exit 2; }

case "${1:-}" in
  -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
  stamp)
    [ $# -eq 4 ] || usage
    dir="$2"; span="$3"; event="$4"
    [ -d "$dir" ] || { echo "run-record: no run dir: $dir" >&2; exit 2; }
    case "$span" in ''|*[!A-Za-z0-9_.-]*) echo "run-record: span names use letters, digits, '.', '_' and '-': $span" >&2; exit 2 ;; esac
    case "$event" in start|end) ;; *) usage ;; esac
    now="$(date -u '+%s %Y-%m-%dT%H:%M:%SZ')"
    printf '%s\t%s\t%s\t%s\n' "${now%% *}" "${now#* }" "$span" "$event" >> "$dir/clock.log" || exit 2
    printf '%s\n' "${now#* }"
    ;;
  times)
    [ $# -eq 2 ] || usage
    log="$2/clock.log"
    [ -f "$log" ] || { echo "run-record: no clock.log in $2" >&2; exit 3; }
    awk -F '\t' '
      BEGIN { bad = 0 }
      function problem(m) { printf "run-record: clock.log line %d: %s\n", NR, m > "/dev/stderr"; bad = 1 }
      NF != 4 || $1 !~ /^[0-9]+$/ || ($4 != "start" && $4 != "end") { problem("not a stamp"); next }
      {
        t = $1 + 0; span = $3
        if (NR > 1 && t < last) problem("earlier than the line before it (written by hand?)")
        if (t > last) last = t
        if (!(span in seen)) { seen[span] = 1; order[++nspans] = span }
        if ($4 == "start") {
          if (span in open) { problem("\"" span "\" started again before it ended"); next }
          open[span] = t; next
        }
        if (!(span in open)) { problem("\"" span "\" ended without a start"); next }
        total[span] += t - open[span]; count[span]++
        if (span != "run" && span !~ /^gate-/) { n++; from[n] = open[span]; to[n] = t }
        delete open[span]
      }
      END {
        for (i = 2; i <= n; i++) { # sort the working intervals by start (few of them)
          f = from[i]; e = to[i]
          for (j = i - 1; j >= 1 && from[j] > f; j--) { from[j + 1] = from[j]; to[j + 1] = to[j] }
          from[j + 1] = f; to[j + 1] = e
        }
        active = 0
        for (i = 1; i <= n; i++) {
          if (i == 1 || from[i] > end) { if (i > 1) active += end - begin; begin = from[i]; end = to[i] }
          else if (to[i] > end) end = to[i]
        }
        if (n > 0) active += end - begin
        out = "{"
        if ("run" in count) out = out "\"lead_s\":" total["run"] ","
        out = out "\"active_s\":" active ",\"gate_wait_s\":{"
        sep = ""
        for (i = 1; i <= nspans; i++) {
          s = order[i]
          if (s ~ /^gate-/ && (s in count)) { out = out sep "\"" substr(s, 6) "\":" total[s]; sep = "," }
        }
        out = out "},\"spans\":{"
        sep = ""
        for (i = 1; i <= nspans; i++) {
          s = order[i]
          if (s in count) { out = out sep "\"" s "\":{\"s\":" total[s] ",\"n\":" count[s] "}"; sep = "," }
        }
        out = out "},\"open\":["
        sep = ""
        for (i = 1; i <= nspans; i++) if (order[i] in open) { out = out sep "\"" order[i] "\""; sep = "," }
        print out "]}"
        exit bad
      }' "$log"
    ;;
  draft)
    [ $# -eq 3 ] || usage
    [ -f "$2" ] || { echo "run-record: no such file: $2" >&2; exit 2; }
    if [ -e "$3" ]; then echo "run-record: kept the existing draft $3"; exit 0; fi
    cp "$2" "$3" && chmod a-w "$3" || exit 2
    echo "run-record: draft $3"
    ;;
  *) usage ;;
esac
