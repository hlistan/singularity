#!/usr/bin/env bash
set -e
git init -q -b main .
mkdir -p .claude
cat > .claude/singularity.md <<'EOF'
# singularity project config

```yaml
tracker:
  type: github
  github: { repo: acme/shop }
code_host:
  type: github
  github: { repo: acme/shop }
```
EOF
