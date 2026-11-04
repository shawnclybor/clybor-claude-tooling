const { execFileSync } = require('child_process');
const fs = require('fs'), os = require('os'), path = require('path');
const gs = require('../lib/git-safety.js');
const root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'chaos-')));
function repo(name, branch) {
  const d = path.join(root, name); fs.mkdirSync(d);
  const g = (...a) => execFileSync('git', ['-C', d, ...a], { stdio: 'ignore' });
  g('init', '-q', '-b', 'main');
  g('-c', 'user.email=t@t', '-c', 'user.name=t', 'commit', '-q', '--allow-empty', '-m', 'init');
  if (branch !== 'main') g('switch', '-q', '-c', branch);
  return d;
}
const M = repo('onmain', 'main'), F = repo('onfeat', 'feat');
fs.symlinkSync(M, path.join(root, 'lnk'));
const L = path.join(root, 'lnk');
fs.mkdirSync(path.join(root, 'plain'));
const C = 'comm' + 'it', P = 'pus' + 'h', R = 'res' + 'et';
// [label, cmd, sessionCwd, expectBlocked]
const cases = [
  ['env -C', `env -C ${M} git ${C} -m x`, F, true],
  ['env bash -c', `env X=1 bash -c "cd ${M} && git ${C} -m x"`, F, true],
  ['nohup bash -c', `nohup bash -c "cd ${M} && git ${C} -m x"`, F, true],
  ['timeout bash -c', `timeout 5 bash -c 'cd ${M} && git ${C} -m x'`, F, true],
  ['bash heredoc', `bash <<'EOF'\ncd ${M}\ngit ${C} -m x\nEOF`, F, true],
  ['bash -s heredoc pipe', `cat <<'EOF' | bash\ncd ${M}\ngit ${C} -m x\nEOF`, F, true],
  ['brace group', `{ cd ${M}; git ${C} -m x; }`, F, true],
  ['if-then cd', `if true; then cd ${M}; git ${C} -m x; fi`, F, true],
  ['for-do cd', `for d in a; do cd ${M}; git ${C} -m x; done`, F, true],
  ['cd -- dir', `cd -- ${M} && git ${C} -m x`, F, true],
  ['cd glob', `cd ${root}/onma* && git ${C} -m x`, F, true],
  ['git -C glob', `git -C ${root}/onma* ${C} -m x`, F, true],
  ['cd brace', `cd ${root}/{onmain,x} && git ${C} -m x`, F, true],
  ['var as git', `G=git; $G -C ${M} ${C} -m x`, F, true],
  ['eval var', `X="git -C ${M} ${C} -m x"; eval "$X"`, F, true],
  ['bare $var exec', `X="git -C ${M} ${C} -m x"; $X`, F, true],
  ['export GIT_DIR', `export GIT_DIR=${M}/.git; git ${C} -m x`, F, true],
  ['backslash-nl between git and sub', `git \\\n ${C} -m x`, M, true],
  ['backslash-nl after &&', `cd ${M} && \\\ngit ${C} -m x`, F, true],
  ['git -C \\nl', `git -C ${M} \\\n  ${C} -m x`, F, true],
  ['subshell cd leak (session main)', `(cd ${F} && ls); git ${C} -m x`, M, true],
  ['cmdsubst cd leak (session main)', `V=$(cd ${F} && pwd); git ${C} -m x`, M, true],
  ['subshell cd elsewhere: over-approximated, by design', `(cd ${M} && ls); git ${C} -m x`, F, true],
  ['backtick unquoted cd', `echo \`cd ${M} && git ${C} -m x\``, F, true],
  ['switch - ', `git switch -; git ${C} -m x`, F, 'n/a'],
  ['checkout @{-1}', `git checkout @{-1} && git ${C} -m x`, F, 'n/a'],
  ['switch fail then commit (;)', `git switch feat2; git ${C} -m x`, M, true],
  ['switch main || switch -c', `git switch main || git switch -c f3; git ${C} -m x`, F, true],
  ['clone then commit', `git clone -q ${M} ${root}/cl1 && cd ${root}/cl1 && git ${C} -m x`, F, true],
  ['init -b main then commit', `git init -q -b main ${root}/n1 && cd ${root}/n1 && git ${C} -m x`, F, true],
  ['git -C link/.. ', `git -C ${L}/.. ${C} -m x`, F, 'n/a'],
  ['pull on main', `git -C ${M} pull`, F, 'n/a'],
  ['cherry-pick on main', `git -C ${M} cherry-pick abc`, F, 'n/a'],
  ['revert on main', `git -C ${M} revert HEAD`, F, 'n/a'],
  ['fetch . HEAD:main', `git fetch . HEAD:main`, F, 'n/a'],
  ['branch -f main', `git branch -f main HEAD`, F, 'n/a'],
  ['update-ref main', `git update-ref refs/heads/main HEAD`, F, 'n/a'],
  ['checkout -B main', `git checkout -B main`, F, 'n/a'],
  ['branch -M main', `git branch -M main`, F, 'n/a'],
  ['push HEAD:$B', `B=ma; B=\${B}in; git ${P} origin HEAD:$B`, F, true],
  ['push --all', `git ${P} --all origin`, F, 'n/a'],
  ['push :main delete', `git ${P} origin :main`, F, true],
  ['gh api PUT contents main', `gh api -X PUT repos/o/r/contents/a.txt -f branch=main -f message=x -f content=eA==`, F, 'n/a'],
  ['gh api PATCH ref main', `gh api -X PATCH repos/o/r/git/refs/heads/main -f sha=abc`, F, 'n/a'],
  ['submodule foreach', `git submodule foreach 'git ${C} -am x'`, M, 'n/a'],
  ['ANSI-C quote', `git $'${C}' -m x`, M, true],
  ['/usr/bin/git', `/usr/bin/git ${C} -m x`, M, true],
  ['command git', `command git ${C} -m x`, M, true],
  ['xargs', `echo ${M} | xargs -I{} git -C {} ${C} -m x`, F, true],
  ['hub', `hub ${C} -m x`, M, true],
  // false blocks
  ['FB: echo git commit', `echo git ${C}`, M, false],
  ['FB: commit msg mentions push to main (feat)', `git ${C} -m "docs: never git ${P} origin main"`, F, false],
  ['FB: grep push main', `grep -rn "git ${P} origin main" docs/`, F, false],
  ['FB: push branch feat/main-nav', `git ${P} -u origin feat/main-nav`, F, false],
  ['FB: cd $(toplevel) && commit (feat)', `cd $(git rev-parse --show-toplevel) && git ${C} -m x`, F, false],
  ['FB: pushd/popd', `pushd ${F} >/dev/null && ls && popd && git ${C} -m x`, F, false],
  ['FB: for d in; git -C $d', `for d in ${F}; do git -C $d ${C} -m x; done`, F, false],
  ['FB: ${VAR:-x}', `cd \${D:-${F}} && git ${C} -m x`, F, false],
  ['FB: heredoc msg w/ quotes+apostrophe', `git ${C} -m "$(cat <<'EOF'\nFix the "dirty isn't" check\nEOF\n)"`, F, false],
  ['FB: heredoc msg plain', `git ${C} -m "$(cat <<'EOF'\nFix the dirty check\n\nCo-Authored-By: x\nEOF\n)"`, F, false],
  ['FB: 5 nested $()', `echo $(a $(b $(c $(d $(e)))))`, F, false],
  ['FB: ssh host git', `ssh host git ${C} -m x`, M, false],
  ['FB: tilde path/git', `ls ${root}/git ${C}`, M, false],
  ['FB: commit --dry-run on main', `git ${C} --dry-run`, M, false],
  ['CRLF heredoc swallow', `cat <<EOF\r\nhello\r\nEOF\r\ncd ${M}\r\ngit ${C} -m x\r\n`, F, true],
  ['CRLF plain', `cd ${M}\r\ngit ${C} -m x\r\n`, F, true],
  ['control: baseline', `cd ${M} && git ${C} -m x`, F, true],
  ['control: bash -c', `bash -c "cd ${M} && git ${C} -m x"`, F, true],
];
for (const [label, cmd, cwd, exp] of cases) {
  let got, ms, err = '';
  const t = process.hrtime.bigint();
  try { const r = gs.checkCommand(cmd, null, 'high', cwd); got = r.blocked; } catch (e) { got = 'THROW'; err = e.message.slice(0, 60); }
  ms = Number(process.hrtime.bigint() - t) / 1e6;
  const verdict = exp === 'n/a' ? (got ? 'blocked' : 'ALLOWED') : (got === exp ? 'ok' : '*** MISMATCH');
  console.log(`${verdict.padEnd(13)} got=${String(got).padEnd(6)} exp=${String(exp).padEnd(5)} ${ms.toFixed(0).padStart(4)}ms  ${label} ${err}`);
}
console.log('root', root);
