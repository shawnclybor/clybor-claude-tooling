// Target-repo tests for the forked git-safety guard.  Run: node --test test/
// Builds two throwaway repos (one on main, one on a side branch) and checks that each
// branch-sensitive git call is judged by the repo it actually runs in.
const test = require('node:test');
const assert = require('node:assert');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const gs = require('../lib/git-safety.js');
const pack = require('../guard-pack.js');

const root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'gs-target-')));
function repo(name, branch) {
  const d = path.join(root, name);
  fs.mkdirSync(d);
  const g = (...a) => execFileSync('git', ['-C', d, ...a], { stdio: 'ignore' });
  g('init', '-q', '-b', 'main');
  g('-c', 'user.email=t@t', '-c', 'user.name=t', 'commit', '-q', '--allow-empty', '-m', 'init');
  if (branch !== 'main') g('switch', '-q', '-c', branch);
  return d;
}
const M = repo('on-main', 'main');
const F = repo('on-feat', 'feat');
const blocked = (cmd, cwd) => gs.checkCommand(cmd, null, 'high', cwd).blocked;

test('today #1: session on a side branch, command commits in a repo on main -> BLOCK', () => {
  assert.equal(blocked(`cd ${M} && git commit -m x`, F), true);
});
test('today #2: session on main, command commits in a repo on a side branch -> ALLOW', () => {
  assert.equal(blocked(`cd ${F} && git commit -m x`, M), false);
});
test('git -C <repo on main> commit (upstream regex missed this entirely) -> BLOCK', () => {
  assert.equal(blocked(`git -C ${M} commit -m x`, F), true);
});
test('git -C <side-branch repo> push from a session on main -> ALLOW', () => {
  assert.equal(blocked(`git -C ${F} push -u origin feat`, M), false);
});
test('commit message containing "reset" and "push" on a side branch -> ALLOW', () => {
  assert.equal(blocked(`git commit -m "reset the push counter; merge later"`, F), false);
});
test('plain commit in the session repo on main -> BLOCK (baseline unchanged)', () => {
  assert.equal(blocked('git commit -m x', M), true);
});
test('switch to main then commit, in one command -> BLOCK', () => {
  assert.equal(blocked('git switch main && git commit -m x', F), true);
});
test('create a branch then commit, from main -> ALLOW', () => {
  assert.equal(blocked('git switch -c new-work && git commit -m x', M), false);
});
test('path checkout then commit on a side branch -> ALLOW', () => {
  assert.equal(blocked('git checkout -- README.md && git commit -m x', F), false);
});
test('unresolvable target ($(...)) -> BLOCK, fail closed', () => {
  const r = gs.checkCommand('cd "$(find-the-repo --somehow)" && git commit -m x', null, 'high', F);
  assert.equal(r.blocked, true);
  assert.match(r.reason, /Cannot tell which repo/);
});
test('read-only self-substitutions resolve (no false block)', () => {
  assert.equal(blocked('cd "$(git rev-parse --show-toplevel)" && git commit -m x', F), false);
  assert.equal(blocked('cd "$(git rev-parse --show-toplevel)" && git commit -m x', M), true);
  assert.equal(blocked('git push -u origin "$(git branch --show-current)"', F), false);
});
test('cd - -> BLOCK, fail closed', () => {
  assert.equal(blocked('cd - && git commit -m x', F), true);
});
test('variable set in the same command is followed', () => {
  assert.equal(blocked(`D=${M}; cd "$D" && git commit -m x`, F), true);
  assert.equal(blocked(`D=${F}; cd $D && git commit -m x`, M), false);
});
test('unknown variable -> BLOCK, fail closed', () => {
  assert.equal(blocked('cd "$NOPE_NOT_SET_X" && git commit -m x', F), true);
});
test('bash -c wrapper is parsed', () => {
  assert.equal(blocked(`bash -c "cd ${M} && git commit -m x"`, F), true);
  assert.equal(blocked(`bash -c "cd ${F} && git commit -m x"`, M), false);
});
test('relative cd resolves from the session directory', () => {
  assert.equal(blocked('cd on-main && git commit -m x', root), true);
  assert.equal(blocked('cd on-feat && git commit -m x', root), false);
});
test('second commit lands back on main -> BLOCK', () => {
  assert.equal(blocked(`cd ${F} && git commit -m a && cd ${M} && git commit -m b`, F), true);
});
test('read-only git in a repo on main -> ALLOW', () => {
  assert.equal(blocked(`cd ${M} && git status && git log --oneline -3`, F), false);
});
test('git -c option before the subcommand is skipped', () => {
  assert.equal(blocked(`git -C ${F} -c user.name=x commit -m y`, M), false);
  assert.equal(blocked(`git -c user.name=x -C ${M} commit -m y`, F), true);
});
test('GIT_DIR override -> BLOCK, fail closed', () => {
  assert.equal(blocked(`GIT_DIR=${M}/.git git commit -m x`, F), true);
});
test('non-branch rules unchanged: push to main by name, gh pr close; gh pr merge allowed', () => {
  assert.equal(blocked('git push origin main', F), true);
  assert.equal(blocked('gh pr close 3', F), true);
  assert.equal(blocked('gh pr merge 3 --merge', M), false);
});
test('explicit-branch API keeps upstream behaviour', () => {
  assert.equal(gs.checkCommand('git commit -m x', 'main').blocked, true);
  assert.equal(gs.checkCommand('git commit -m x', 'feat').blocked, false);
});
test('a directory that is not a repo -> ALLOW (git itself would fail)', () => {
  assert.equal(blocked(`cd ${root} && git commit -m x`, F), false);
});
test('heredoc body with an apostrophe does not hide a later commit (replay finding) -> BLOCK on main', () => {
  const cmd = `cat >> notes.md <<'EOF'\nCory's kit, round 3\nEOF\ngit add -A && git commit -q -m "log"`;
  assert.equal(blocked(cmd, M), true);
  assert.equal(blocked(cmd, F), false);
});
test('unquoted and <<- heredocs are skipped too', () => {
  assert.equal(blocked(`cat <<EOF > x\nit's data\nEOF\ngit commit -m y`, M), true);
  assert.equal(blocked(`cat <<-END\n\tit's data\n\tEND\ngit commit -m y`, M), true);
});
test('quoted heredoc text is data; unquoted heredoc text is read conservatively', () => {
  // <<'EOF' bodies are literal and never run: dropped. <<EOF bodies can run $( ): kept, so with a
  // main-branch repo in play, prose that names the verb is blocked (as upstream did).
  const C = 'comm' + 'it';
  assert.equal(blocked(`cat > howto.md <<'EOF'\nthen run git ${C} and more\nEOF\necho done`, M), false);
  assert.equal(blocked(`cat > howto.md <<EOF\nthen run git ${C} and more\nEOF\necho done`, M), true);
  assert.equal(blocked(`cat > howto.md <<EOF\nthen run git ${C} and more\nEOF\necho done`, F), false);
});
test('commit message passed by heredoc on a side branch -> ALLOW', () => {
  assert.equal(blocked(`git commit -q -F - <<'EOF'\nReset the push logic; Shawn's fix\nEOF\ngit log -1`, F), false);
});
test('unclosed quote: judged on the raw text -> BLOCK on main, ALLOW on a side branch', () => {
  // A command with an unclosed quote is a shell syntax error and does not run; the raw-text
  // reading still blocks it wherever a real commit would land on main.
  assert.equal(blocked(`echo "oops && git commit -m x`, M), true);
  assert.equal(blocked(`echo "oops && git commit -m x`, F), false);
});
test('git call hidden in a quoted command substitution -> BLOCK on main', () => {
  assert.equal(blocked(`echo "done: $(git commit -m x)"`, M), true);
  assert.equal(blocked('echo "done: `git commit -m x`"', M), true);
  assert.equal(blocked(`echo "on main? $(git merge-base --is-ancestor abc origin/main && echo yes)"`, M), false);
});
test('switch to main and pull after a PR merge stays allowed (normal routine)', () => {
  assert.equal(blocked('git checkout -q main && git pull -q && git log --oneline -1', F), false);
  assert.equal(blocked(`git -C ${M} pull --ff-only`, F), false);
});
test('other ways of creating commits or moving main are blocked', () => {
  assert.equal(blocked(`git -C ${M} cherry-pick abc123`, F), true);
  assert.equal(blocked(`git -C ${M} revert HEAD`, F), true);
  assert.equal(blocked('git branch -f main HEAD', F), true);
  assert.equal(blocked('git update-ref refs/heads/main HEAD', F), true);
  assert.equal(blocked('git push --all origin', F), true);
  assert.equal(blocked('git fetch origin main:main', F), false);
});
test('guard-pack passes the session cwd through to git-safety', () => {
  const deny = pack.evaluate('Bash', { command: `cd ${M} && git commit -m x` }, F, {});
  assert.ok(deny && deny.guard === 'git-safety' || (deny && /protected|main/.test(deny.reason)), 'expected a git-safety deny');
  const allow = pack.evaluate('Bash', { command: `cd ${F} && git commit -m x` }, M, {});
  assert.ok(!allow || allow.guard !== 'git-safety', 'expected no git-safety deny');
});
