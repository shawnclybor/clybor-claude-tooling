const { execFileSync } = require('child_process');
const fs = require('fs'), os = require('os'), path = require('path');
const gs = require('../lib/git-safety.js');
const root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'chaos2-')));
function repo(name, branch) {
  const d = path.join(root, name); fs.mkdirSync(d);
  const g = (...a) => execFileSync('git', ['-C', d, ...a], { stdio: 'ignore' });
  g('init', '-q', '-b', 'main');
  fs.writeFileSync(path.join(d, 'notes.txt'), 'x');
  g('add', '.');
  g('-c', 'user.email=t@t', '-c', 'user.name=t', 'commit', '-q', '-m', 'init');
  if (branch !== 'main') g('switch', '-q', '-c', branch);
  return d;
}
const M = repo('onmain', 'main'), F = repo('onfeat', 'feat');
const C = 'comm' + 'it', P = 'pus' + 'h', R = 'res' + 'et', RB = 'reba' + 'se';
const G = 'g' + 'it';
// [label, cmd, sessionCwd, expectBlocked]
const cases = [
  // --- comments
  ['comment apostrophes swallow commit (main)', `# it's here\n${G} ${C} -m x\n# that's all`, M, true],
  ['comment apostrophe single (feat) false block', `# don't forget\n${G} add -A && ${G} ${C} -m x`, F, false],
  ['comment with << swallows', `echo hi # see <<EOF\n${G} ${C} -m x\n`, M, true],
  ['comment paren pop trick', `cd ${F}\necho hi # (\ncd ${M}\necho # )\n${G} ${C} -m x`, F, true],
  // --- here-string
  ['here-string swallows next lines', `cat <<< "hi"\n${G} ${C} -m x`, M, true],
  ['here-string unquoted', `read a <<< hi\n${G} ${C} -m x`, M, true],
  ['bash here-string', `bash <<< "cd ${M} && ${G} ${C} -m x"`, F, true],
  ['arith (( 1<<3 ))', `(( n = 1<<3 ))\n${G} ${C} -m x`, M, true],
  // --- heredoc cmd subst
  ['unquoted heredoc runs $()', `cat <<EOF\n$(${G} ${C} -m x)\nEOF`, M, true],
  ['source /dev/stdin heredoc', `source /dev/stdin <<EOF\n${G} ${C} -m x\nEOF`, M, true],
  // --- head dyn / globs / braces
  ['$(which git) commit', `$(which ${G}) ${C} -m x`, M, true],
  ['backtick which git', `\`which ${G}\` ${C} -m x`, M, true],
  ['env $G commit', `G=${G}; env $G ${C} -m x`, M, true],
  ['sudo $G', `G=${G}; sudo $G ${C} -m x`, M, true],
  ['brace expansion cmd', `{${G},${C},-m,x}`, M, true],
  ['glob cmd name', `/usr/bin/gi? ${C} -m x`, M, true],
  ['env -S', `env -S '${G} ${C} -m x'`, M, true],
  ['busybox sh -c', `busybox sh -c '${G} ${C} -m x'`, M, true],
  ['python -c', `python3 -c "import os; os.system('${G} ${C} -m x')"`, M, true],
  ['su -c', `su -c '${G} ${C} -m x' nobody`, M, true],
  ['bash -c -- ', `bash -c -- '${G} ${C} -m x'`, M, true],
  ['bash -c $(cat f)', `bash -c "$(cat /tmp/x.sh)"`, M, 'n/a'],
  // --- redirects before subcommand
  ['git >/dev/null commit', `${G} >/dev/null ${C} -m x`, M, true],
  ['git 2>&1 commit', `${G} 2>&1 ${C} -m x`, M, true],
  ['git 2>/dev/null commit', `${G} 2>/dev/null ${C} -m x`, M, true],
  // --- line continuation edge
  ['echo \\\\ newline git commit', `echo a\\\\\n${G} ${C} -m x`, M, true],
  // --- cd semantics
  ['cd A || cd B', `cd ${M} || cd ${F}; ${G} ${C} -m x`, F, true],
  ['cd in pipe leaks', `cd ${F} | cat; ${G} ${C} -m x`, M, true],
  ['cd in background', `cd ${F} & ${G} ${C} -m x`, M, true],
  ['function def then call', `f() { ${G} ${C} -m x; }; cd ${M}; f`, F, true],
  ['function cd never called', `f() { cd ${F}; }; ${G} ${C} -m x`, M, true],
  // --- switch prediction
  ['checkout file && commit', `${G} checkout notes.txt && ${G} ${C} -m x`, M, true],
  ['switch --create=feat && commit (false block)', `${G} switch --create=zzz && ${G} ${C} -m x`, M, 'n/a'],
  ['symbolic-ref HEAD main', `${G} symbolic-ref HEAD refs/heads/main && ${G} ${C} -m x`, F, true],
  ['checkout main file', `${G} checkout main notes.txt && ${G} ${C} -m x`, F, false],
  // --- refRule
  ['fetch -f origin feat:main', `${G} fetch -f origin feat:main`, F, true],
  ['fetch --force', `${G} fetch --force origin feat:main`, F, true],
  ['fetch +refs/heads/*:refs/heads/*', `${G} fetch origin '+refs/heads/*:refs/heads/*'`, F, true],
  ['push glob refspec', `${G} ${P} origin 'refs/heads/*:refs/heads/*'`, F, true],
  ['push --prune glob', `${G} ${P} --prune origin 'refs/heads/*:refs/heads/*'`, F, true],
  ['rebase feat main', `${G} ${RB} feat main`, F, true],
  ['rebase --onto x y main', `${G} ${RB} --onto feat HEAD main`, F, true],
  ['branch -fM bundle', `${G} branch -fM main`, F, true],
  ['branch -df main', `${G} branch -df main`, F, true],
  ['branch -Df main', `${G} branch -Df main`, F, true],
  ['branch -fm', `${G} branch -fm main`, F, true],
  ['push alias via -c', `${G} -c alias.zz=${P} zz origin main`, F, true],
  ['alias commit via -c', `${G} -c alias.zz=${C} zz -m x`, M, true],
  ['push self-subst different -C', `${G} -C ${F} ${P} origin "$(${G} branch --show-current)"`, M, true],
  ['push $(git branch --show-current) on feat', `${G} ${P} origin "$(${G} branch --show-current)"`, F, false],
  ['branch -c main new (false block)', `${G} branch -c main main-copy`, F, 'n/a'],
  ['update-ref read-ish', `${G} update-ref -d refs/heads/main`, F, true],
  ['fetch origin main:main ff', `${G} fetch origin main:main`, F, 'n/a'],
  // --- gh false blocks
  ['gh api graphql read refs/heads/main', `gh api graphql -f query='{ repository(owner:"o",name:"r"){ ref(qualifiedName:"refs/heads/main"){ name } } }'`, F, false],
  ['gh api create PR base=main', `gh api repos/o/r/pulls -f title=t -f head=feat -f base=main`, F, false],
  ['gh api -X GET -f base=main', `gh api -X GET repos/o/r/pulls -f base=main`, F, false],
  // --- NONEXEC
  ['echo $(cd; commit)', `echo "$(cd ${M} && ${G} ${C} -m x)"`, F, true],
  ['sed e', `sed -n '1e ${G} ${C} -m x' /etc/hosts`, M, 'n/a'],
  ['printf split | sh', `printf '${G} co%s' mmit | sh`, M, true],
  ['echo split | bash', `echo "${G} comm""it -m x" | bash`, M, true],
  ['echo | sh normal', `echo '${G} ${C} -m x' | sh`, M, true],
  ['find -exec', `find . -maxdepth 0 -exec ${G} ${C} --allow-empty -m x \\;`, M, true],
  ['ls then commit', `ls; ${G} ${C} -m x`, M, true],
  // --- false blocks everyday
  ['FB: heredoc commit msg w/ ) and apostrophes feat', `${G} ${C} -m "$(cat <<'EOF'\nfix: don't break (parens) ) here\n\nBody's text\nEOF\n)"`, F, false],
  ['FB: -F - heredoc feat', `${G} ${C} -F - <<'EOF'\nmsg's\nEOF`, F, false],
  ['FB: multi-line add/commit feat', `${G} add -A\n${G} ${C} -m "x"\n${G} ${P} -u origin feat`, F, false],
  ['FB: here-string then push feat', `jq . <<< '{}'\n${G} ${P} origin feat`, F, false],
  ['FB: [[ =~ ( ) ]]', `[[ $x =~ (a|b) ]] && ${G} ${C} -m x`, F, false],
  ['FB: case stmt feat', `case $1 in a) ${G} ${C} -m x;; esac`, F, false],
  ['FB: while read', `while read d; do ${G} -C "$d" status; done < list`, F, false],
  ['FB: mkdir cd init commit', `mkdir -p ${root}/new1 && cd ${root}/new1 && ${G} init -q && ${G} ${C} -q --allow-empty -m x`, F, 'n/a'],
  ['FB: clone then checkout -b then commit', `cd ${root} && ${G} clone -q ${M} cl2 && cd cl2 && ${G} checkout -b w && ${G} ${C} --allow-empty -m x`, F, false],
  ['FB: stash/switch/pull on main ok', `${G} switch main && ${G} pull --ff-only && ${G} switch -c n1`, F, false],
  ['FB: commit amend feat w/ $VAR', `${G} ${C} --amend -m "v $VERSION"`, F, false],
  ['FB: git log --grep', `${G} log --grep='push' --oneline`, M, false],
  ['FB: npm test && commit feat', `npm test 2>&1 | tail -5 && ${G} ${C} -am x`, F, false],
  ['FB: gh pr create body', `gh pr create --title t --body "merge main later; ${G} ${P} origin main"`, F, false],
  ['FB: cd $OLDPWD', `cd $OLDPWD && ${G} ${C} -m x`, F, 'n/a'],
];
for (const [label, cmd, cwd, exp] of cases) {
  let got, err = '', why = '';
  const t = process.hrtime.bigint();
  try { const r = gs.checkCommand(cmd, null, 'high', cwd); got = r.blocked; why = r.reason ? r.reason.slice(0, 60) : ''; } catch (e) { got = 'THROW'; err = e.message.slice(0, 60); }
  const ms = Number(process.hrtime.bigint() - t) / 1e6;
  const verdict = exp === 'n/a' ? (got ? 'blocked' : 'ALLOWED') : (got === exp ? 'ok' : '*** MISMATCH');
  console.log(`${verdict.padEnd(13)} got=${String(got).padEnd(6)} exp=${String(exp).padEnd(5)} ${ms.toFixed(0).padStart(4)}ms ${label} ${err} | ${why}`);
}
console.log('root', root);
