// timing probes (each in a child with a hard timeout)
const { spawnSync } = require('child_process');
const fs = require('fs'), os = require('os'), path = require('path');
const lib = path.resolve(__dirname, '../guard-pack-redos-fix/lib/git-safety.js');
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'chaos3t-'));
fs.mkdirSync(path.join(root, 'S')); require('child_process').execFileSync('git', ['-C', path.join(root, 'S'), 'init', '-q', '-b', 'feat']);
const GC = 'com' + 'mit';
function run(label, cmdExpr) {
  const code = `const G=require(${JSON.stringify(lib)});const t=Date.now();const r=G.checkCommand(${cmdExpr},null,'high',${JSON.stringify(path.join(root, 'S'))});console.log(r.blocked?'DENY':'ALLOW',Date.now()-t,'ms')`;
  const t0 = Date.now();
  const p = spawnSync('node', ['-e', code], { timeout: 8000, encoding: 'utf8' });
  console.log(label, '=>', p.error ? 'TIMEOUT(>8s)' : p.stdout.trim(), p.status);
}
for (const gap of [2, 3, 5]) for (const k of [6, 10, 14]) {
  run(`startsWithCd assigns k=${k} gap=${gap}`, `${JSON.stringify(Array.from({ length: k }, (_, i) => `A${i}=1`).join(' '.repeat(gap)) + ' '.repeat(gap) + ' echo hi ; git ' + GC + ' -m x')}`);
}
run('newline-indented assigns', JSON.stringify(Array.from({ length: 12 }, (_, i) => `A${i}=1`).join('\n    ') + '\n    git ' + GC + ' -m x'));
// many distinct dirs
const dirs = []; for (let i = 0; i < 600; i++) { const d = path.join(root, 'd' + i); fs.mkdirSync(d); dirs.push(d); }
run('600 distinct -C dirs', JSON.stringify(dirs.map(d => `git -C ${d} ${GC} -m x`).join('\n')));
run('150 distinct -C dirs', JSON.stringify(dirs.slice(0, 150).map(d => `git -C ${d} ${GC} -m x`).join('\n')));
