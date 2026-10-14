#!/usr/bin/env bash
# A project on the files tracker. By ID alone T3 would come first; by priority it's T7.
set -e
git init -q -b main .
printf '.tasks/\n' > .gitignore
mkdir -p .claude .tasks
cat > .claude/singularity.md <<'EOF'
# singularity project config

```yaml
tracker:
  type: files
  files: { dir: .tasks, id_prefix: T }
code_host:
  type: none
```
EOF
printf -- '---\npriority: 2\n---\n# Add search to the catalogue\n' > .tasks/TODO-T3-add-search.md
printf -- '---\npriority: 1\n---\n# Fix the login redirect\n' > .tasks/TODO-T7-fix-login.md
printf '# Update the docs\n' > .tasks/TODO-T9-update-docs
printf -- '---\npriority: 0\n---\n# Refactor auth\n' > .tasks/PROGRESS-T2-refactor-auth.md
printf '# Set up CI\n' > .tasks/DONE-T1-setup-ci.md
