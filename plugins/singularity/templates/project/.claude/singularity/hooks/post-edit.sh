#!/usr/bin/env bash
# Runs after every Edit/Write. Receives the hook JSON on stdin.
# Example: format the edited file. Exit 2 with a message on stderr to send feedback to Claude.
input="$(cat)"
file="$(printf '%s' "$input" | sed -n 's/.*"file_path" *: *"\([^"]*\)".*/\1/p' | head -n1)"
[ -z "$file" ] && exit 0
case "$file" in
  *.ts|*.tsx|*.js|*.jsx) npx --no-install prettier --write "$file" >/dev/null 2>&1 || true ;;
  *.py) ruff format "$file" >/dev/null 2>&1 || true ;;
esac
exit 0
