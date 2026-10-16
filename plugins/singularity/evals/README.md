# singularity plugin evals

Regression suite for the **shared** plugin. Before adopting a change, an upstream report from a project included, maintainers run it on the candidate branch and on the default branch, and adopt the change only if nothing regresses (see `CONTRIBUTING.md`). Add a case whenever a real failure traces to a shared agent, skill or workflow.

```bash
claude plugin eval plugins/singularity --scaffold --trust-plugin \
  --allow-tools Write Edit "Bash(git *)" "Bash(gh *)" "Bash(glab *)" "Bash(bash *)" --no-publish --max-cost-usd 10
node scripts/eval-auto.js
```

`claude plugin eval` runs every case in `dontAsk` mode, which refuses every write under `.claude/` (a [protected path](https://code.claude.com/docs/en/permission-modes#protected-paths)) whatever `--allow-tools` grants. The optimizer cases (tag `optimizer`) write guidelines, the record and eval cases there, so they fail in it: judge them with `scripts/eval-auto.js`, which runs them in auto mode (its classifier decides those writes) with only this checkout's plugin loaded, and applies the same graders (`--case <name>`, `--runs <n>`, `-j <n>`; `--mode bypassPermissions` where auto mode isn't available, in a disposable environment only).

Each case is a real model call billed to your account: `claude plugin eval` runs ×3, ×2 arms (with and without the plugin); one run of every case with the plugin cost $20 to $26 in October 2026, the optimizer cases most of it. Iterate with `--case <name> --runs 1 --ablation none`.

On macOS, `/usr/bin/git` is a shim that sometimes rewrites its cache in the user temp dir, which the eval sandbox refuses (`couldn't create cache file ... xcrun_db`); running any `git` command in a normal shell just before the suite usually refreshes the cache.
