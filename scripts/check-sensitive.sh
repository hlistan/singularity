#!/usr/bin/env bash
# Blocks commits/pushes that would publish sensitive or internal information.
# Usage: scripts/check-sensitive.sh [files...]   (no args = all tracked files)
# Exit 1 on any finding. Add legitimate examples to the allowlist below, not to the code.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 1
if [ $# -gt 0 ]; then files=("$@"); else mapfile -t files < <(git ls-files); fi
[ ${#files[@]} -eq 0 ] && exit 0

ALLOWED_EMAILS='noreply@anthropic\.com|@example\.com|@users\.noreply\.github\.com|^[0-9]+:git@'
findings=$(mktemp)
report() { echo "::error file=$1,line=$2::$3" | tee -a "$findings" >&2; }

for f in "${files[@]}"; do
  [ -f "$f" ] || continue
  case "$f" in .git/*|*.png|*.jpg|*.gif|*.ico|*.woff*) continue;; esac
  case "$f" in
    optimizer/projects.yaml|.env|.env.*|.mcp.json|.claude/settings.local.json)
      report "$f" 1 "local-only file must not be committed"; continue;;
  esac
  # credentials and private keys
  grep -nE '(AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20}|sk-ant-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{32,}|xox[abpr]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|-----BEGIN [A-Z ]*PRIVATE KEY-----|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,})' "$f" \
    | while IFS=: read -r ln _; do report "$f" "$ln" "possible credential or private key"; done
  # assignments that look like secrets
  grep -nEi '(password|passwd|secret|api[_-]?key|auth[_-]?token|access[_-]?token)\s*[:=]\s*["'"'"'][^"'"'"']{8,}' "$f" \
    | grep -vEi '(\$\{|TODO|<[^>]+>|example|placeholder|changeme|user_config)' \
    | while IFS=: read -r ln _; do report "$f" "$ln" "hardcoded secret-looking value"; done
  # personal e-mail addresses
  grep -noE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$f" | grep -vE "$ALLOWED_EMAILS" \
    | while IFS=: read -r ln _; do report "$f" "$ln" "e-mail address (use a noreply or example address)"; done
  # internal hosts and tracker sites
  grep -noE '[A-Za-z0-9-]+\.atlassian\.net|https?://[A-Za-z0-9.-]*(internal|corp|intranet|local)\b[^ )"'"'"']*' "$f" \
    | grep -vE 'yourco\.atlassian\.net|example' \
    | while IFS=: read -r ln _; do report "$f" "$ln" "internal host or tracker site"; done
  # private IPs
  grep -noE '\b(10\.[0-9]{1,3}|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9]{1,3}\.[0-9]{1,3}\b' "$f" \
    | while IFS=: read -r ln _; do report "$f" "$ln" "private IP address"; done
done
if [ -s "$findings" ]; then echo "check-sensitive: $(wc -l < "$findings") finding(s)" >&2; rm -f "$findings"; exit 1; fi
rm -f "$findings"; echo "check-sensitive: clean"
