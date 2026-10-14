#!/usr/bin/env bash
# Tests for the git-ignore check in /singularity:init-project (skills/init-project/SKILL.md, step
# "Check that the shared files will be committed") and the exceptions it appends:
#   plugins/singularity/templates/project/gitignore-claude.txt
# Run: bash tests/init-gitignore.test.sh   (bash 3.2 compatible, like tracker-files.test.sh)
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BLOCK="$ROOT/plugins/singularity/templates/project/gitignore-claude.txt"
SHARED="CLAUDE.md .claude/singularity.md .claude/settings.json .claude/singularity/goals.md .claude/singularity/guidelines/project.md .claude/singularity/experience/runs.jsonl .claude/singularity/evals/README.md .claude/rules/singularity/api.md .claude/singularity/upstream/README.md .claude/agents/review-domain.md"
LOCAL=".claude/settings.local.json .claude/agent-memory-local/reviewer/MEMORY.md"
pass=0
fail=0
current=""

setup() { # a project after init-project created its files, before any ignore fix
  WORK="$(mktemp -d)"
  cd "$WORK" || exit 1
  git init -q .
  git config core.excludesFile "$WORK/no-global-excludes"
  local f
  for f in $SHARED $LOCAL; do
    mkdir -p "$(dirname "$f")"
    printf 'x\n' > "$f"
  done
}
teardown() { cd "$ROOT" || exit 1; rm -rf "$WORK"; }
test_case() { current="$1"; }
ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); printf 'FAIL [%s] %s\n' "$current" "$1"; }

# What `git add -A` would pick up. Authoritative, including paths inside an ignored directory.
addable() { git ls-files --others --exclude-standard; }

# The procedure exactly as init-project describes it.
apply_procedure() {
  local ignored p
  # shellcheck disable=SC2086 # paths are space-free by construction
  ignored="$(git check-ignore -- $SHARED)"           # prints each ignored path; -q takes only one path
  [ -n "$ignored" ] || return 0                      # nothing shared is ignored
  if git check-ignore -q -- .claude/; then
    cat "$BLOCK" >> .gitignore                       # the whole directory is ignored
  else
    for p in $ignored; do printf '!/%s\n' "$p" >> .gitignore; done
  fi
}

expect_shared_committed() {
  local f
  for f in $SHARED; do
    if addable | grep -qxF -- "$f"; then ok; else ko "$f would not be committed"; fi
  done
}
expect_local_ignored() {
  local f
  for f in $LOCAL; do
    if addable | grep -qxF -- "$f"; then ko "$f would be committed"; else ok; fi
  done
}

for rule in ".claude" ".claude/" "/.claude/" ".claude/*" "**/.claude"; do
  test_case "the repository's .gitignore ignores the whole directory with '$rule'"
  setup
  printf 'node_modules/\n%s\n' "$rule" > .gitignore
  apply_procedure
  expect_shared_committed
  expect_local_ignored
  teardown
done

test_case "the directory is ignored in .git/info/exclude"
setup
printf '.claude/\n' >> .git/info/exclude
apply_procedure
expect_shared_committed
expect_local_ignored
teardown

test_case "the directory is ignored by a global excludes file"
setup
printf '.claude\n' > "$WORK/global-excludes"
git config core.excludesFile "$WORK/global-excludes"
apply_procedure
expect_shared_committed
expect_local_ignored
teardown

test_case "a narrower rule gets single exceptions and keeps applying elsewhere"
setup
printf '*.json\nCLAUDE.md\n' > .gitignore
printf '{}\n' > other.json
apply_procedure
expect_shared_committed
if addable | grep -qxF other.json; then ko "other.json is no longer ignored"; else ok; fi
if grep -qxF '/.claude/*' .gitignore; then ko "used the directory block for a narrow rule"; else ok; fi
teardown

test_case "nothing ignored: .gitignore is left alone"
setup
printf 'node_modules/\n' > .gitignore
apply_procedure
if [ "$(cat .gitignore)" = "node_modules/" ]; then ok; else ko ".gitignore changed: $(cat .gitignore)"; fi
expect_shared_committed
teardown

test_case "running the procedure twice changes nothing the second time"
setup
printf '.claude\n' > .gitignore
apply_procedure
before="$(cat .gitignore)"
apply_procedure
if [ "$(cat .gitignore)" = "$before" ]; then ok; else ko "second run changed .gitignore"; fi
teardown

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
