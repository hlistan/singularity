#!/usr/bin/env bash
# Project-specific command guard, runs after the shared singularity guard.
# Exit 2 with a message on stderr to block the command.
input="$(cat)"  # hook JSON; used by the example below
: "$input"
# Example: block commands against production
# if echo "$input" | grep -q 'prod'; then echo "Ask before touching production" >&2; exit 2; fi
exit 0
