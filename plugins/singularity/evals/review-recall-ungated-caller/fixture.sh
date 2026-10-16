#!/usr/bin/env bash
# The change gates PDF reports behind the paid plan at the export route, but a weekly digest job, which the
# change doesn't touch, still renders and sends PDF reports to every user who turned its preference on.
# The second reader of the capability is outside the diff; the reviewer must search for it.
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
mkdir -p src/jobs test
cat > src/pdf.js <<'JS'
// Renders a user's monthly report as a PDF buffer.
function renderPdf(report) {
  return Buffer.from(`%PDF report for ${report.owner}: ${report.rows.length} rows`);
}
module.exports = { renderPdf };
JS
cat > src/routes.js <<'JS'
const { renderPdf } = require('./pdf');
const { loadReport } = require('./reports');

// GET /reports/:id.pdf
async function exportReport(req, res) {
  const report = await loadReport(req.params.id, req.user);
  res.type('application/pdf').send(renderPdf(report));
}

// PATCH /settings: the user's own preferences, e.g. { weeklyPdf: true }
async function updateSettings(req, res) {
  Object.assign(req.user.prefs, req.body);
  await req.user.save();
  res.json(req.user.prefs);
}
module.exports = { exportReport, updateSettings };
JS
cat > src/reports.js <<'JS'
async function loadReport(id, user) {
  return { id, owner: user.email, rows: [] };
}
module.exports = { loadReport };
JS
cat > src/jobs/weekly-digest.js <<'JS'
// Runs every Monday: emails each user who opted in their report as a PDF.
const { renderPdf } = require('../pdf');
const { loadReport } = require('../reports');

async function sendWeeklyDigests(users, mailer) {
  for (const user of users) {
    if (!user.prefs.weeklyPdf) continue;
    const report = await loadReport('latest', user);
    await mailer.send(user.email, 'Your weekly report', { attachment: renderPdf(report) });
  }
}
module.exports = { sendWeeklyDigests };
JS
git add -A && git commit -qm "Reports: PDF export and weekly digest"
git checkout -qb feature/paid-pdf-export
cat > spec.md <<'MD'
# Spec: PDF reports become a paid-plan feature

Problem: PDF reports are expensive to render; the business makes them part
of the paid plan.

Acceptance criteria:

1. A paid-plan user gets the PDF from GET /reports/:id.pdf as before.
2. A free-plan user can no longer get a PDF report; the export route
   answers 402 with an upgrade message.
MD
cat > src/entitlements.js <<'JS'
// Which plan features a user may use.
function canExportPdf(user) {
  return user.plan === 'paid';
}
module.exports = { canExportPdf };
JS
cat > src/routes.js <<'JS'
const { renderPdf } = require('./pdf');
const { loadReport } = require('./reports');
const { canExportPdf } = require('./entitlements');

// GET /reports/:id.pdf
async function exportReport(req, res) {
  if (!canExportPdf(req.user)) {
    return res.status(402).json({ error: 'PDF reports are part of the paid plan' });
  }
  const report = await loadReport(req.params.id, req.user);
  res.type('application/pdf').send(renderPdf(report));
}

// PATCH /settings: the user's own preferences, e.g. { weeklyPdf: true }
async function updateSettings(req, res) {
  Object.assign(req.user.prefs, req.body);
  await req.user.save();
  res.json(req.user.prefs);
}
module.exports = { exportReport, updateSettings };
JS
cat > test/entitlements.test.js <<'JS'
const assert = require('assert');
const { canExportPdf } = require('../src/entitlements');
assert.strictEqual(canExportPdf({ plan: 'paid' }), true);
assert.strictEqual(canExportPdf({ plan: 'free' }), false);
JS
