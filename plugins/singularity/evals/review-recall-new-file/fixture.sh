#!/usr/bin/env bash
# The defect is in a file the change adds and nobody has committed yet, as the implementer leaves it when
# auto_commit is off. `git diff` doesn't show untracked files; the reviewer must still find the bug.
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src
cat > src/checkout.js <<'EOF'
// Order total in cents.
function total(lines) {
  return lines.reduce((sum, l) => sum + l.priceCents * l.qty, 0);
}
module.exports = { total };
EOF
git add -A && git commit -qm "Add checkout total"
git checkout -qb feature/discount
cat > src/checkout.js <<'EOF'
// Order total in cents, after an optional percentage discount.
const { applyDiscount } = require('./discount');
function total(lines, discountPercent = 0) {
  const gross = lines.reduce((sum, l) => sum + l.priceCents * l.qty, 0);
  return applyDiscount(gross, discountPercent);
}
module.exports = { total };
EOF
cat > src/discount.js <<'EOF'
// Applies a percentage discount (0-100) to an amount in cents.
function applyDiscount(cents, percent) {
  return Math.round(cents * (percent / 100));
}
module.exports = { applyDiscount };
EOF
