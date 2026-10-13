#!/usr/bin/env bash
# Extension point: runs .claude/singularity/hooks/<name>.sh from the project if it exists,
# passing the hook JSON on stdin and propagating its exit code (2 = block / send feedback to Claude).
name="$1"
script="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/singularity/hooks/${name}.sh"
if [ -x "$script" ]; then
  "$script"
  exit $?
fi
cat >/dev/null
exit 0
