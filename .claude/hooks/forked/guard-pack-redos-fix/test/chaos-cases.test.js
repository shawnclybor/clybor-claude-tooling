// Chaos-review probes (2026-11-04), kept as a regression: every case with an expectation must match.
const test = require('node:test');
const assert = require('node:assert');
const { execFileSync } = require('node:child_process');
const path = require('node:path');
test('chaos probes: no expectation mismatches', () => {
  const out = execFileSync(process.execPath, [path.join(__dirname, 'chaos-cases.js')], { encoding: 'utf-8' });
  const bad = out.split('\n').filter(l => l.includes('MISMATCH'));
  assert.deepEqual(bad, []);
});
