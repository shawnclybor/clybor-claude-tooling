// Chaos-review rounds 2 and 3 (2026-11-04), kept as a regression. Every probe must give its
// expected answer, except the two accepted on purpose:
//   - clone-then-commit: the new repo does not exist when the guard runs, so it denies (safe side).
//   - awk system(): a command built inside an interpreter is out of scope by design.
const test = require('node:test');
const assert = require('node:assert');
const { execFileSync } = require('node:child_process');
const path = require('node:path');
const ACCEPTED = [/clone then checkout -b then commit/, /awk system/];
const run = (f) => execFileSync(process.execPath, [path.join(__dirname, f)], { encoding: 'utf-8' });
test('chaos round 2 probes: no unexpected mismatches', () => {
  const bad = run('chaos-round2.js').split('\n').filter(l => l.includes('MISMATCH') && !ACCEPTED.some(a => a.test(l)));
  assert.deepEqual(bad, []);
});
test('chaos round 3 probes: no unexpected failures', () => {
  for (const f of ['chaos-round3-a.js', 'chaos-round3-c.js']) {
    const bad = run(f).split('\n').filter(l => l.startsWith('FAIL') && !ACCEPTED.some(a => a.test(l)));
    assert.deepEqual(bad, [], f);
  }
});
test('chaos round 3 timing probes: every case under 1 second', () => {
  const slow = run('chaos-round3-b.js').split('\n').filter(l => { const m = l.match(/(\d+) ms/); return m && +m[1] > 1000; });
  assert.deepEqual(slow, []);
});
