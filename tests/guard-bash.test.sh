#!/usr/bin/env bash
# Tests for the shared command guard:
#   plugins/singularity/scripts/guard-bash.sh
# Run: bash tests/guard-bash.test.sh
# CI runs it on Linux (bash 5, mawk) and on macOS /bin/bash (3.2, BSD awk), so keep both this file and the
# script 3.2-compatible and the awk POSIX.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/plugins/singularity/scripts/guard-bash.sh"
SH="${BASH:-bash}"
pass=0
fail=0
current=""

setup() { # a repository on branch $1
  WORK="$(mktemp -d)"
  cd "$WORK" || exit 1
  git init -q -b "$1" .
}
teardown() { cd "$ROOT" || exit 1; rm -rf "$WORK"; }
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\n'/\\n}"
  printf '%s' "$s"
}
guard() { # guard <command>: runs the hook as Claude Code would
  OUT="$(printf '{"session_id":"s","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s","description":"Run a command"}}' \
    "$WORK" "$(json_escape "$1")" | CLAUDE_PROJECT_DIR="$WORK" HOME="/home/tester" "$SH" "$SCRIPT" 2>&1)"
  CODE=$?
}
test_case() { current="$1"; }
ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); printf 'FAIL [%s] %s\n' "$current" "$1"; printf '%s\n' "$OUT" | sed 's/^/    /'; }
blocked() { guard "$1"; if [ "$CODE" -eq 2 ]; then ok; else ko "not blocked: $1"; fi; }
allowed() { guard "$1"; if [ "$CODE" -eq 0 ]; then ok; else ko "blocked: $1"; fi; }

test_case "force-pushes to protected branches are blocked, however they are written"
setup feature/x
blocked 'git push --force origin main'
blocked 'git push --force origin "main"'
blocked "git push -f origin 'master'"
blocked 'git push origin +main'
blocked 'git push origin +HEAD:refs/heads/main'
blocked 'git push -f origin HEAD:main'
blocked 'git push --force-with-lease origin develop'
blocked 'git push -uf origin main'
blocked 'git -C . push --force origin main'
blocked 'git -c color.ui=never push -f origin main'
blocked 'cd sub && git push -f origin main'
blocked 'git push --force origin release/2.0'
blocked 'git push --mirror'
blocked 'git push --all --force origin'
blocked 'bash -c "git push --force origin main"'
blocked "sh -c 'git push -f origin main'"
blocked 'eval git push -f origin main'
blocked 'echo start; git push -f origin main 2>&1 | tee log'
blocked 'sudo git push -f origin main'
blocked 'git push origin --delete main'
blocked 'git push origin :main'
OUT="" ; guard 'git push --force origin main'
case "$OUT" in *"protected branch main"*) ok ;; *) ko "the reason doesn't name the branch" ;; esac
teardown

test_case "force-pushing the current branch without a refspec depends on the branch"
setup main
blocked 'git push -f'
blocked 'git push --force origin'
blocked 'git push origin HEAD --force'
teardown
setup feature/login
allowed 'git push -f'
allowed 'git push --force origin HEAD'
teardown

test_case "the project's default branch is protected too"
setup feature/x
mkdir -p .claude
printf '# config\n\n```yaml\nconventions:\n  default_branch: "stable"   # ours\n```\n' > .claude/singularity.md
blocked 'git push -f origin stable'
allowed 'git push -f origin feature/x'
teardown

test_case "ordinary pushes, and force-pushes to other branches, are allowed"
setup feature/x
allowed 'git push origin main'
allowed 'git push -u origin feature/x'
allowed 'git push origin fix-format-main'
allowed 'git push --force origin feature/main-menu'
allowed 'git push --force-with-lease origin feature/x'
allowed 'git push origin +feature/x'
allowed 'git push --all origin'
allowed 'git push --tags --force origin'
allowed 'git push origin v1.2.0'
teardown

test_case "text that only mentions these commands is allowed"
setup feature/x
allowed 'echo "git push --force origin main"'
allowed "git commit -m 'docs: never use git push --force origin main or --no-verify'"
allowed 'git commit -m "$(cat <<'"'"'EOF'"'"'
fix: explain why --no-verify and rm -rf / are blocked

git push --force origin main
EOF
)"'
allowed 'cat > notes.md <<EOF
git push --force origin main
rm -rf ~/
EOF
git status'
allowed 'grep -rn "rm -rf /" docs/'
allowed 'printf "%s\n" "git commit -n"'
allowed '# git push -f origin main
git status'
allowed 'git log --oneline -n 5'
allowed 'gh pr create --title "Block git push --force to main"'
teardown

test_case "skipping git hooks is blocked"
setup feature/x
blocked 'git commit --no-verify -m "x"'
blocked 'git commit -n -m x'
blocked 'git commit -anm "msg"'
blocked 'git commit -m x -n'
blocked 'git push --no-verify origin feature/x'
blocked 'git -c core.hooksPath=/dev/null commit -m x'
blocked 'HUSKY=0 git commit -m x'
blocked 'env HUSKY=0 git push origin feature/x'
allowed 'git commit -m "no hooks were skipped"'
allowed 'git commit -am "-n is just text here"'
allowed 'git commit -F msg.txt'
allowed 'git commit -m -n'
teardown

test_case "recursive deletes of / or home are blocked"
setup feature/x
blocked 'rm -rf /'
blocked 'rm -rf /*'
blocked 'rm -r -f /'
blocked 'rm -fr ~'
blocked 'rm -rf ~/'
blocked 'rm -rf ~/*'
blocked 'rm --recursive --force ~'
blocked 'rm -rf "$HOME"'
blocked 'rm -rf $HOME/'
blocked 'rm -rf "${HOME}/"'
blocked 'rm -rf /home/tester'
blocked 'rm -rf -- /'
blocked 'sudo rm -rf --no-preserve-root /'
blocked 'cd /tmp && rm -Rf ~/.'
teardown

test_case "other deletes are allowed"
setup feature/x
allowed 'rm -rf build'
allowed 'rm -rf ./node_modules /tmp/cache'
allowed 'rm -rf ~/project/build'
allowed 'rm -rf "$HOME/.cache/tool"'
allowed 'rm -f /'
allowed 'rm ~/notes.txt'
allowed 'rm -rf /home/tester-other'
teardown

test_case "input without a command, and odd input, is allowed"
setup feature/x
OUT="$(printf '%s' '{"tool_name":"Bash","tool_input":{}}' | "$SH" "$SCRIPT" 2>&1)"; CODE=$?
if [ "$CODE" -eq 0 ]; then ok; else ko "blocked an empty command"; fi
OUT="$(printf '%s' 'not json' | "$SH" "$SCRIPT" 2>&1)"; CODE=$?
if [ "$CODE" -eq 0 ]; then ok; else ko "blocked garbage"; fi
allowed 'echo "unterminated'
allowed "echo 'unterminated"
teardown

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
