#!/usr/bin/env bash
# Tells Claude whether this project is connected to singularity. Stdout is added to the session context.
dir="${CLAUDE_PROJECT_DIR:-$PWD}"
if [ ! -f "$dir/.claude/singularity.md" ]; then
  echo "singularity: this project has no .claude/singularity.md yet. If the user wants to use the singularity workflow here, suggest /singularity:init-project."
fi
exit 0
