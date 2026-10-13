#!/usr/bin/env bash
# Shared guardrail for every project. Exit 2 blocks the command and shows stderr to Claude.
input="$(cat)"

block() { echo "Blocked by singularity guardrail: $1" >&2; exit 2; }

# Force-push to protected branches
if echo "$input" | grep -Eq 'git push[^"]*(--force|-f)([^"]*)(main|master|develop|release)'; then
  block "force-push to a protected branch"
fi
# Bypassing git hooks
if echo "$input" | grep -Eq 'git (commit|push)[^"]*--no-verify'; then
  block "--no-verify bypasses the project's checks"
fi
# Recursive delete of root/home
if echo "$input" | grep -Eq 'rm -[a-zA-Z]*r[a-zA-Z]*f?[a-zA-Z]* +(/|~|\$HOME)( |"|$)'; then
  block "recursive delete of / or home"
fi
exit 0
