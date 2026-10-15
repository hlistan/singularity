#!/usr/bin/env bash
# Tests for the mechanical checks and the implementer's stop gate:
#   plugins/singularity/scripts/run-checks.sh
#   plugins/singularity/scripts/subagent-stop.sh
# Run: bash tests/run-checks.test.sh
# CI runs it on Linux (bash 5) and on macOS /bin/bash (3.2), so keep both this file and the scripts 3.2-compatible.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKS="$ROOT/plugins/singularity/scripts/run-checks.sh"
GATE="$ROOT/plugins/singularity/scripts/subagent-stop.sh"
SH="${BASH:-bash}"
pass=0
fail=0
current=""

setup() { # a project whose commands are set in .claude/singularity.md
  WORK="$(mktemp -d)"
  cd "$WORK" || exit 1
  git init -q .
  mkdir -p .claude/singularity
}
teardown() { cd "$ROOT" || exit 1; rm -rf "$WORK"; }
config() { printf '# config\n\n```yaml\n%s\n```\n' "$1" > .claude/singularity.md; }
run() { OUT="$("$SH" "$CHECKS" --root "$WORK" "$@" 2>&1)"; CODE=$?; }
gate() { # gate <agent_type> [agent_id]
  OUT="$(printf '{"session_id":"s1","agent_id":"%s","agent_type":"%s","hook_event_name":"SubagentStop","stop_hook_active":false}' "${2:-a1}" "$1" \
    | CLAUDE_PROJECT_DIR="$WORK" "$SH" "$GATE" 2>&1)"
  CODE=$?
}
test_case() { current="$1"; }
ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); printf 'FAIL [%s] %s\n' "$current" "$1"; printf '%s\n' "$OUT" | sed 's/^/    /'; }
expect_code() { if [ "$CODE" -eq "$1" ]; then ok; else ko "exit $CODE, expected $1"; fi; }
expect_out() { case "$OUT" in *"$1"*) ok ;; *) ko "output lacks: $1" ;; esac; }
expect_no_out() { case "$OUT" in *"$1"*) ko "output has: $1" ;; *) ok ;; esac; }

test_case "passing checks print one line"
setup
config 'commands:
  install: npm ci
  build: "echo building"   # quoted
  lint: echo linting
  typecheck: TODO
  test: echo testing && echo "noisy output"
  test_one: echo {file}'
run
expect_code 0
expect_out "run-checks: passed (build, lint, test)"
expect_no_out "noisy output"
expect_no_out "npm ci"
teardown

test_case "a failing check prints its command, exit status and output tail, and fails the run"
setup
config 'commands:
  build: echo ok
  test: echo "expected 10.10, got 10.099999"; exit 3'
run
expect_code 1
expect_out "FAIL test (exit 3"
expect_out "expected 10.10, got 10.099999"
expect_out "1 check(s) failed of: build, test"
teardown

test_case "checks.run picks the checks, and --only overrides it"
setup
config 'commands:
  build: echo b
  lint: exit 1
  test: echo t
checks:
  run: [build, test]'
run
expect_code 0
expect_out "passed (build, test)"
run --only lint
expect_code 1
teardown

test_case "the verify hook runs when it is executable"
setup
config 'commands:
  test: echo t'
mkdir -p .claude/singularity/hooks
printf '#!/usr/bin/env bash\necho contract-tests; exit 4\n' > .claude/singularity/hooks/verify.sh
run
expect_code 0
chmod +x .claude/singularity/hooks/verify.sh
run
expect_code 1
expect_out "FAIL verify_hook"
expect_out "contract-tests"
teardown

test_case "commands run from the project root, with CI set and no input"
setup
mkdir -p sub
config 'commands:
  test: test -d sub && test "$CI" = true && ! read -r line'
cd sub || exit 1
OUT="$(CLAUDE_PROJECT_DIR="$WORK" "$SH" "$CHECKS" 2>&1)"; CODE=$?
expect_code 0
teardown

test_case "--json writes the results"
setup
config 'commands:
  build: echo "quoted \"arg\""
  test: exit 2'
run --json "$WORK/r.json"
OUT="$(cat "$WORK/r.json")"
expect_out '"name":"build"'
expect_out '"exit":2'
expect_out '"command":"echo \"quoted \\\"arg\\\"\""'
if command -v node >/dev/null 2>&1; then
  if node -e "JSON.parse(require('fs').readFileSync('$WORK/r.json','utf8'))" 2>/dev/null; then ok; else ko "invalid JSON"; fi
fi
teardown

test_case "a baseline of failures taken before the change, and checks known to fail"
setup
config 'commands:
  build: echo b
  lint: echo "lint was already broken"; exit 1
  test: echo t'
run --save-failures "$WORK/.agentic/work/.state/baseline-failures"
expect_code 1
OUT="$(cat "$WORK/.agentic/work/.state/baseline-failures")"
expect_out "lint"
expect_no_out "build"
run --known-failures "$WORK/.agentic/work/.state/baseline-failures"
expect_code 0
expect_out "KNOWN FAIL lint"
expect_out "except checks that already failed before the change: lint"
config 'commands:
  build: echo b
  lint: exit 1
  test: exit 1'
run --known-failures "$WORK/.agentic/work/.state/baseline-failures"
expect_code 1
expect_out "FAIL test"
expect_out "already failing before the change: lint"
run --known-failures "$WORK/missing-file"
expect_code 1
teardown

test_case "the stop gate doesn't block on checks that failed before the change"
setup
config 'conventions:
  work_dir: .agentic/work
commands:
  lint: exit 1
  test: exit 0'
mkdir -p .agentic/work/.state && printf 'lint\n' > .agentic/work/.state/baseline-failures
gate singularity:implementer
expect_code 0
config 'conventions:
  work_dir: .agentic/work
commands:
  lint: exit 1
  test: exit 1'
gate singularity:implementer
expect_code 2
expect_out "FAIL test"
teardown

test_case "nothing to run, no config, usage errors"
setup
config 'commands:
  build: TODO
  test: TODO'
run
expect_code 3
rm .claude/singularity.md
run
expect_code 2
config 'commands:
  test: echo t'
run --bogus
expect_code 2
run --tail x
expect_code 2
teardown

test_case "the stop gate keeps the implementer working while checks fail, then lets go"
setup
config 'conventions:
  work_dir: .agentic/work
commands:
  test: exit 1
checks:
  stop_retries: 2'
gate singularity:implementer a7
expect_code 2
expect_out "you can't finish yet"
expect_out "block 1 of 2"
expect_out "FAIL test"
gate singularity:implementer a7
expect_code 2
expect_out "block 2 of 2"
gate singularity:implementer a7
expect_code 0
gate singularity:implementer a7
expect_code 2
OUT="$(git status --porcelain --untracked-files=all)"
case "$OUT" in *.agentic*) ko "the gate's state is visible to git" ;; *) ok ;; esac
teardown

test_case "the stop gate passes when checks pass, for other agents, and when switched off"
setup
config 'commands:
  test: exit 0'
gate singularity:implementer
expect_code 0
config 'commands:
  test: exit 1'
gate singularity:reviewer
expect_code 0
gate Explore
expect_code 0
config 'commands:
  test: exit 1
checks:
  implement_gate: false'
gate singularity:implementer
expect_code 0
rm .claude/singularity.md
gate singularity:implementer
expect_code 0
teardown

test_case "the stop gate follows a project agent bound to the implement role"
setup
config 'commands:
  test: exit 1
roles:
  implement: { agent: android-implementer, model: sonnet }'
gate android-implementer
expect_code 2
config 'commands:
  test: exit 1
roles:
  implement:
    model: sonnet
    agent: "android-implementer"'
gate android-implementer
expect_code 2
gate other-agent
expect_code 0
teardown

test_case "the stop gate lets go when nothing is configured"
setup
config 'commands:
  test: TODO'
gate singularity:implementer
expect_code 0
teardown

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
