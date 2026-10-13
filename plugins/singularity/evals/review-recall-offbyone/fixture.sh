#!/usr/bin/env bash
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src
cat > src/paginate.js <<'EOF'
// Returns the items on a 1-based page.
function paginate(items, page, pageSize) {
  const start = (page - 1) * pageSize;
  return items.slice(start, start + pageSize);
}
module.exports = { paginate };
EOF
git add -A && git commit -qm "Add paginate"
git checkout -qb feature/has-next
cat > src/paginate.js <<'EOF'
// Returns the items on a 1-based page, and whether a next page exists.
function paginate(items, page, pageSize) {
  const start = page * pageSize;
  const pageItems = items.slice(start, start + pageSize);
  return { items: pageItems, hasNext: start + pageSize < items.length };
}
module.exports = { paginate };
EOF
git commit -qam "Return hasNext from paginate"
