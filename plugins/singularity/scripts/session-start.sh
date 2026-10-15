#!/usr/bin/env bash
# Tells Claude whether this project is connected to singularity, and whether user corrections are waiting
# for the learn job. Stdout is added to the session context, so it stays to a line or two.
dir="${CLAUDE_PROJECT_DIR:-$PWD}"
if [ ! -f "$dir/.claude/singularity.md" ]; then
  echo "singularity: this project has no .claude/singularity.md yet. If the user wants to use the singularity workflow here, suggest /singularity:init-project."
  exit 0
fi
n="$(bash "$(dirname "$0")/corrections.sh" --root "$dir" count 2>/dev/null)"
case "$n" in
  ''|0|*[!0-9]*) ;;
  *) echo "singularity: $n user correction(s) are waiting to become guidelines. The next /singularity:feature run learns from them; to do it now, ask for the singularity optimizer's learn job (\"@agent-singularity:optimizer learn from corrections\")." ;;
esac
exit 0
