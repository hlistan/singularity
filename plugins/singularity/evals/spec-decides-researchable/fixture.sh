#!/usr/bin/env bash
# A small Express service set up for singularity. The ticket (in the prompt) leaves open details that the code,
# conventions and public standards settle: the spec writer should decide them, not ask.
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src test .claude/singularity/guidelines
cat > package.json <<'JSON'
{
  "name": "member-portal",
  "private": true,
  "type": "module",
  "scripts": { "start": "node src/server.js", "test": "node --test" },
  "dependencies": { "express": "^4.21.0" }
}
JSON
cat > src/app.js <<'JS'
import express from 'express';
import { checkPassword } from './users.js';

export function createApp({ users }) {
  const app = express();
  app.use(express.json());
  // Signs a member in. Returns 401 on a wrong email or password.
  app.post('/login', async (req, res) => {
    const { email, password } = req.body ?? {};
    const user = await checkPassword(users, email, password);
    if (!user) return res.status(401).json({ error: 'invalid_credentials' });
    res.json({ id: user.id });
  });
  return app;
}
JS
cat > src/users.js <<'JS'
export async function checkPassword(users, email, password) {
  const user = users.find((u) => u.email === email);
  return user && user.password === password ? user : null;
}
JS
cat > test/login.test.js <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
test('placeholder', () => assert.equal(1, 1));
JS
cat > .claude/singularity.md <<'MD'
# singularity project config

```yaml
commands:
  test: npm test
tracker:
  type: none
code_host:
  type: none
```
MD
cat > CLAUDE.md <<'MD'
# Member portal

@.claude/singularity.md

Members of a sports club sign in to book courts. One Express service; the
app is built in `src/app.js` from injected dependencies.
MD
git add -A && git commit -qm "Member portal"
