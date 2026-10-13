#!/usr/bin/env bash
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src
cat > src/cart.js <<'EOF'
function total(cart) {
  let t = 0;
  for (const line of cart.lines) {
    t += line.price * line.qty;
  }
  return Math.round(t * 100) / 100;
}
module.exports = { total };
EOF
git add -A && git commit -qm "Add cart total"
git checkout -qb refactor/total
cat > src/cart.js <<'EOF'
const lineTotal = line => line.price * line.qty;

function total(cart) {
  const sum = cart.lines.reduce((acc, line) => acc + lineTotal(line), 0);
  return Math.round(sum * 100) / 100;
}
module.exports = { total, lineTotal };
EOF
git commit -qam "Extract lineTotal"
