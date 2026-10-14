# singularity plugin evals

Regression suite for the **shared** plugin. Maintainers run it on a candidate branch and on the default branch before adopting a change, including an upstream report from a project, and adopt it only if nothing regresses (see `CONTRIBUTING.md`). Add a case whenever a real failure is traced to a shared agent, skill or workflow.

```bash
claude plugin eval plugins/singularity --scaffold --trust-plugin \
  --allow-tools "Bash(git *)" "Bash(gh *)" "Bash(glab *)" "Bash(bash *)" --no-publish --max-cost-usd 10
```

Each case is a real model call billed to your account, ×3 runs, ×2 arms (with and without the plugin). Use `--case <name> --runs 1 --ablation none` while iterating.
