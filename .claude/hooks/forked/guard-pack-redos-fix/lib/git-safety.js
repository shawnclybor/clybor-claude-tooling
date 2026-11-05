#!/usr/bin/env node
/**
 * Git Safety - PreToolUse Hook for Bash
 * Blocks destructive git and gh CLI operations. Logs to: ~/.claude/hooks-logs/
 *
 * SAFETY_LEVEL: 'critical' | 'high' | 'strict' (default 'high')
 *   Override via the HOOK_SAFETY_LEVEL env var; invalid values fall back to the default.
 *   critical - this hook adds nothing (defer entirely to block-dangerous-commands.js)
 *   high     - branch-aware guardrails, protected-branch moves/deletes/pushes by name,
 *              and destructive gh CLI operations
 *   strict   - + force-push, so this hook is self-sufficient standalone
 *
 * FORK CHANGE (2026-11-04) - judge every repo the command could touch.
 *   Upstream asked `git branch --show-current` in the hook's own directory, so
 *   `cd /other/repo && git commit` was judged by the session's repo. Measured 2026-11-04:
 *   a commit onto main in one repo was allowed (session on a side branch elsewhere), and
 *   a commit on a side branch was denied (session on main).
 *
 *   Design: over-approximate. Three chaos rounds shaped it.
 *   1. Commands are read twice and the results UNIONED: once quote-aware (paths with
 *      spaces, `-C "$(...)"`), and once with every quote treated as a separator, so a git
 *      verb inside any string (bash -c, eval, an unclosed quote) is still seen. Quoted
 *      strings are also re-read as commands. Quoted heredoc bodies (<<'EOF') are data.
 *   2. CANDIDATES = the session directory plus every cd / pushd / git -C / env -C target
 *      (a variable with several possible values contributes each). The session directory
 *      is dropped only when the command starts with `cd <path> &&`, or every verb call
 *      names its repo with -C.
 *   3. DENY if any candidate is on main/master (or the command switches to main first),
 *      if a target cannot be resolved or does not exist yet, or if there are more than
 *      50 candidates. From ANY branch: moving, deleting, renaming or pushing to main/master.
 *   4. `git pull` is allowed: switching to main and pulling after a PR merge is the norm.
 *   Accepted costs: with a main-branch repo in play, text that merely names a verb (an
 *   echo, an unquoted heredoc) is blocked, as upstream did. Out of scope: deliberately
 *   disguised commands (a verb assembled from pieces, interpreters building strings),
 *   config-defined git aliases, ssh, scripts in files. A backstop, not an adversary boundary.
 *   checkCommand(cmd, branch) with an explicit branch keeps the upstream behaviour.
 */

const { execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const DEFAULT_SAFETY_LEVEL = 'high';
const SAFETY_LEVEL = ['critical', 'high', 'strict'].includes(process.env.HOOK_SAFETY_LEVEL)
  ? process.env.HOOK_SAFETY_LEVEL
  : DEFAULT_SAFETY_LEVEL;

const PROTECTED_BRANCHES = ['main', 'master'];
const PROT = '(?:main|master)';
const isProtected = (b) => PROTECTED_BRANCHES.includes(String(b).replace(/^\+/, '').replace(/^refs\/heads\//, ''));

const PATTERNS = [
  { level: 'strict', id: 'force-push',              regex: /\bgit\s+push\b.*(?:--force(?!-with-lease)|-f)\b/, reason: 'Force-pushing is not allowed' },
  { level: 'high', id: 'push-main',                 regex: /\bgit\s+push\b[^;&|\n]*\bmain\b/,                 reason: 'Pushing to main is not allowed' },
  { level: 'high', id: 'push-master',               regex: /\bgit\s+push\b[^;&|\n]*\bmaster\b/,               reason: 'Pushing to master is not allowed' },
  { level: 'high', id: 'branch-delete-protected',   regex: /\bgit\s+branch\s+.*(?:-[dD]|--delete)\s+(?:main|master)\b/, reason: 'Deleting a protected branch is not allowed' },
  { level: 'high', id: 'commit-on-protected',       regex: /\bgit\s+commit\b/,      sub: 'commit',      reason: 'Committing directly on {branch} is not allowed', branchOnly: true },
  { level: 'high', id: 'merge-on-protected',        regex: /\bgit\s+merge\b/,       sub: 'merge',       reason: 'Merging into {branch} is not allowed', branchOnly: true },
  { level: 'high', id: 'rebase-on-protected',       regex: /\bgit\s+rebase\b/,      sub: 'rebase',      reason: 'Rebasing {branch} is not allowed', branchOnly: true },
  { level: 'high', id: 'reset-on-protected',        regex: /\bgit\s+reset\b/,       sub: 'reset',       reason: 'Resetting {branch} is not allowed', branchOnly: true },
  { level: 'high', id: 'push-on-protected',         regex: /\bgit\s+push\b/,        sub: 'push',        reason: 'Pushing from {branch} is not allowed', branchOnly: true },
  { level: 'high', id: 'cherry-pick-on-protected',  regex: /\bgit\s+cherry-pick\b/, sub: 'cherry-pick', reason: 'Cherry-picking onto {branch} is not allowed', branchOnly: true },
  { level: 'high', id: 'revert-on-protected',       regex: /\bgit\s+revert\b/,      sub: 'revert',      reason: 'Reverting on {branch} is not allowed', branchOnly: true },
  { level: 'high', id: 'am-on-protected',           regex: /\bgit\s+am\b/,          sub: 'am',          reason: 'Applying patches onto {branch} is not allowed', branchOnly: true },
  { level: 'high', id: 'move-protected-ref',        regex: /(?!)/, reason: 'Moving, renaming, deleting or overwriting main/master is not allowed' },
  { level: 'high', id: 'gh-api-protected',          regex: /(?!)/, reason: 'Writing to main/master through gh api is not allowed' },
  { level: 'high', id: 'unresolved-target',         regex: /(?!)/, reason: 'unresolved' },
  // gh: `gh pr merge` is deliberately allowed (Shawn, 2026-10-15).
  { level: 'high', id: 'gh-pr-close',               regex: /\bgh\s+pr\s+close\b/,                             reason: 'Closing PRs via gh CLI is not allowed' },
  { level: 'high', id: 'gh-issue-close',            regex: /\bgh\s+issue\s+close\b/,                          reason: 'Closing issues via gh CLI is not allowed' },
  { level: 'high', id: 'gh-release-delete',         regex: /\bgh\s+release\s+delete\b/,                       reason: 'Deleting releases via gh CLI is not allowed' },
  { level: 'high', id: 'gh-repo-delete',            regex: /\bgh\s+repo\s+delete\b/,                          reason: 'Deleting repos via gh CLI is not allowed' },
];
const PAT = Object.fromEntries(PATTERNS.map(p => [p.id, p]));
const VERB_PAT = new Map(PATTERNS.filter(p => p.sub).map(p => [p.sub, p]));

const LEVELS = { critical: 1, high: 2, strict: 3 };
const EMOJIS = { critical: '🚨', high: '⛔', strict: '⚠️' };
const HOME = process.env.HOME || os.homedir();
const LOG_DIR = path.join(HOME, '.claude', 'hooks-logs');

function log(data) {
  try {
    if (!fs.existsSync(LOG_DIR)) fs.mkdirSync(LOG_DIR, { recursive: true });
    const file = path.join(LOG_DIR, `${new Date().toISOString().slice(0, 10)}.jsonl`);
    fs.appendFileSync(file, JSON.stringify({ ts: new Date().toISOString(), ...data }) + '\n');
  } catch {}
}

const branchCache = new Map();
function getCurrentBranch(dir) {
  if (branchCache.has(dir)) return branchCache.get(dir);
  let b = '';
  try {
    b = execFileSync('git', ['-C', dir, 'branch', '--show-current'],
      { encoding: 'utf-8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 2000 }).trim();
  } catch {}
  branchCache.set(dir, b);
  return b;
}

// ---- limits and vocab ---------------------------------------------------------------

const MAX_LEN = 200000;
const MAX_WORD = 4096;      // longer words are not resolved (regex cost): treated as unknown
const MAX_DIRS = 50;        // each candidate costs a git spawn
const MAX_COMBOS = 32;
const MAX_DEPTH = 3;
const UNRESOLVED = Symbol('unresolved');

const VERBS = new Set(['commit', 'merge', 'rebase', 'reset', 'push', 'cherry-pick', 'revert', 'am']);
const VERB_WORD_RE = /\b(commit|merge|rebase|reset|push|cherry-pick|revert)\b/;
const GIT_BINS = new Set(['git', 'hub']);
const GIT_WORD_RE = /(^|[\s;&|(`"'])(git|hub)(?=[\s;&|)`"']|$)/;
const KEYWORDS = new Set(['then', 'do', 'else', 'elif', 'if', 'while', 'until', '!', '{', '}', 'time']);
// Words that run the command that follows them.
const PRECMD = new Set(['eval', 'builtin', 'command', 'exec', 'sudo', 'doas', 'nohup', 'nice', 'timeout', 'env', 'xargs', 'stdbuf', 'caffeinate', 'unbuffer', 'chronic']);
// Commands that only print, search or run remotely: such a segment, with no substitution
// in it, does not run git here.
const NONEXEC = new Set(['echo', 'printf', 'grep', 'egrep', 'fgrep', 'rg', 'ag', 'ls', 'cat', 'head', 'tail', 'wc', 'sed', 'awk',
  'man', 'which', 'type', 'file', 'stat', 'less', 'more', 'diff', 'ssh', 'scp', 'jq', 'tr', 'cut', 'sort', 'uniq',
  'basename', 'dirname', 'realpath', 'test', '[', '[[']);
const ASSIGN_RE = /^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/s;
const isRedirect = (w) => /^\d*(?:>>?|<)/.test(w) || /^&?>/.test(w);
const baseName = (w) => String(w).slice(String(w).lastIndexOf('/') + 1);
const refDst = (x) => x.slice(x.lastIndexOf(':') + 1);

// ---- text normalisation ----------------------------------------------------------

function normalise(cmd) {
  return cmd.replace(/\r\n?/g, '\n')
    .replace(/(^|[^\\])((?:\\\\)*)\\\n/g, '$1$2 ')   // line continuation (an escaped backslash is not one)
    .replace(/\d*>&(?:\d+|-)/g, ' ')                 // 2>&1, >&2: no target word
    .replace(/&>>?/g, ' > ');                        // &> file: a redirect with a target
}

/** Quoted heredoc bodies (<<'EOF', <<"EOF", <<\EOF) are literal data: drop them. */
function dropQuotedHeredocs(text) {
  const out = [];
  const pending = [];
  for (const line of text.split('\n')) {
    if (pending.length) {
      const d = pending[0];
      if ((d.strip ? line.replace(/^\t+/, '') : line) === d.delim) pending.shift();
      continue;
    }
    out.push(line);
    for (const m of line.matchAll(/(?<!<)<<(?!<)(-?)\s*(?:'([^'\n]+)'|"([^"\n]+)"|\\([A-Za-z_][\w]*))/g)) {
      pending.push({ strip: m[1] === '-', delim: m[2] || m[3] || m[4] });
    }
  }
  return out.join('\n');
}

// ---- quote-aware segments -----------------------------------------------------------

function matchParen(text, open) {
  let depth = 0;
  for (let k = open; k < text.length; k++) {
    const c = text[k];
    if (c === '\\') { k++; continue; }
    if (c === "'") { const e = text.indexOf("'", k + 1); if (e === -1) return -1; k = e; continue; }
    if (c === '"') {
      let j = k + 1;
      for (; j < text.length; j++) { if (text[j] === '\\') { j++; continue; } if (text[j] === '"') break; }
      if (j >= text.length) return -1;
      k = j; continue;
    }
    if (c === '(') depth++;
    else if (c === ')' && --depth === 0) return k;
  }
  return -1;
}

/** [{ toks: [{ t, dyn, q }], sep }]. t has quotes removed; dyn = holds $( ) or backticks; q = was quoted. */
function shellSegments(text) {
  const segs = [];
  let toks = [], tok = '', inTok = false, dyn = false, q = false;
  const pushTok = () => { if (inTok) toks.push({ t: tok, dyn, q }); tok = ''; inTok = false; dyn = false; q = false; };
  const pushSeg = (sep) => { pushTok(); if (toks.length) segs.push({ toks, sep }); toks = []; };
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (c === "'") {
      const e = text.indexOf("'", i + 1);
      q = true; inTok = true;
      if (e === -1) { tok += text.slice(i + 1); dyn = true; break; }
      tok += text.slice(i + 1, e); i = e; continue;
    }
    if (c === '"') {
      q = true; inTok = true;
      let k = i + 1;
      for (; k < text.length; k++) {
        const d = text[k];
        if (d === '\\' && k + 1 < text.length) { tok += text[++k]; continue; }
        if (d === '$' && text[k + 1] === '(') {
          const e = matchParen(text, k + 1);
          if (e === -1) { tok += text.slice(k); k = text.length; break; }
          tok += text.slice(k, e + 1); dyn = true; k = e; continue;
        }
        if (d === '`') { const e = text.indexOf('`', k + 1); if (e === -1) { tok += text.slice(k); k = text.length; break; } tok += text.slice(k, e + 1); dyn = true; k = e; continue; }
        if (d === '"') break;
        tok += d;
      }
      if (k >= text.length) { dyn = true; break; }
      i = k; continue;
    }
    if (c === '\\' && i + 1 < text.length) { tok += text[++i]; inTok = true; continue; }
    if ((c === '$' || c === '<' || c === '>') && text[i + 1] === '(') {
      const e = matchParen(text, i + 1);
      if (c !== '$') pushTok();
      inTok = true; dyn = true;
      if (e === -1) { tok += text.slice(i); break; }
      tok += text.slice(i, e + 1); i = e; continue;
    }
    if (c === '`') {
      const e = text.indexOf('`', i + 1);
      inTok = true; dyn = true;
      if (e === -1) { tok += text.slice(i); break; }
      tok += text.slice(i, e + 1); i = e; continue;
    }
    if (c === '&' && text[i + 1] === '&') { pushSeg('&&'); i++; continue; }
    if (c === '|' && text[i + 1] === '|') { pushSeg('||'); i++; continue; }
    if (c === '(' || c === ')') { segs.parens = true; pushSeg(c); continue; }
    if (c === '\n' || c === ';' || c === '&' || c === '|') { pushSeg(c); continue; }
    if (/\s/.test(c)) { pushTok(); continue; }
    tok += c; inTok = true;
  }
  pushSeg(';');
  return segs;
}

/** Bodies of $( ) and backticks inside a token's raw text. */
function substitutions(s) {
  const out = [];
  for (let i = 0; i < s.length; i++) {
    if ((s[i] === '$' || s[i] === '<' || s[i] === '>') && s[i + 1] === '(') {
      const e = matchParen(s, i + 1);
      out.push(s.slice(i + 2, e === -1 ? s.length : e)); if (e === -1) break; i = e;
    } else if (s[i] === '`') {
      const e = s.indexOf('`', i + 1);
      out.push(s.slice(i + 1, e === -1 ? s.length : e)); if (e === -1) break; i = e;
    }
  }
  return out;
}

// ---- variables ----------------------------------------------------------------------

/** Every value a word can take (array), or UNRESOLVED. vars: name -> array | UNRESOLVED. */
function expandAll(raw, vars) {
  if (raw === undefined || raw === null || raw.length > MAX_WORD) return UNRESOLVED;
  const re = /\$\{([A-Za-z_][A-Za-z0-9_]*)(?::?-([^}]*))?\}|\$([A-Za-z_][A-Za-z0-9_]*)/g;
  let outs = [''], last = 0, m;
  while ((m = re.exec(raw))) {
    const lit = raw.slice(last, m.index); last = re.lastIndex;
    const name = m[1] || m[3];
    let vals = Object.prototype.hasOwnProperty.call(vars, name) ? vars[name]
      : (process.env[name] !== undefined ? [process.env[name]] : undefined);
    if (m[2] !== undefined && (vals === undefined || (Array.isArray(vals) && vals.every(v => v === '')))) vals = [m[2]];
    if (vals === undefined || vals === UNRESOLVED) return UNRESOLVED;
    const next = [];
    for (const o of outs) for (const v of vals) next.push(o + lit + v);
    if (next.length > MAX_COMBOS) return UNRESOLVED;
    outs = next;
  }
  outs = outs.map(o => o + raw.slice(last));
  if (outs.some(o => o.includes('$') || o.includes('`'))) return UNRESOLVED;
  return [...new Set(outs)];
}

function assignments(text, segs, cwd) {
  const vars = {};
  const put = (name, vals) => {
    if (vals === UNRESOLVED || vars[name] === UNRESOLVED) { vars[name] = UNRESOLVED; return; }
    vars[name] = [...new Set([...(vars[name] || []), ...vals])];
  };
  for (const m of text.matchAll(/\bfor\s+([A-Za-z_][A-Za-z0-9_]*)\s+in\s+([^;\n]*?)\s*(?:;|\n|\bdo\b)/g)) {
    const vals = m[2].trim().split(/\s+/).filter(Boolean).map(v => v.replace(/^["']|["']$/g, ''));
    if (!vals.length || vals.some(v => /[*?[`]|\$\(/.test(v))) { put(m[1], UNRESOLVED); continue; }
    const all = [];
    let bad = false;
    for (const v of vals) { const e = expandAll(v, vars); if (e === UNRESOLVED) { bad = true; break; } all.push(...e); }
    put(m[1], bad ? UNRESOLVED : all);
  }
  for (const { toks } of segs) for (const x of toks) {
    const m = x.t.match(ASSIGN_RE);
    if (m) put(m[1], x.dyn ? UNRESOLVED : expandAll(m[2], vars));
  }
  if (!Object.prototype.hasOwnProperty.call(vars, 'PWD')) vars.PWD = [cwd];
  return vars;
}

// ---- scanning -------------------------------------------------------------------

const DATA_FLAGS = new Set(['-m', '--message', '--body', '--title', '-b', '-t', '--notes', '-F']);
const SELF_BRANCH_RE = /^\$\(\s*git\s+(?:branch\s+--show-current|rev-parse\s+--abbrev-ref\s+HEAD)\s*\)$/;
const SELF_DIR_RE = /^\$\(\s*(?:git\s+rev-parse\s+--show-toplevel|pwd)\s*\)$/;

/**
 * Quote-aware scan. Returns:
 *   uses: [{ verb, cTargets: [tok], args: [string] }]   cds: [tok]   envC: [tok]
 *   ref: a pattern hit from the ANY-branch rules (or UNRESOLVED)
 *   toMain, dynamic, alias, gitDir, firstCdExempt, creates: { seg, name }, segs
 */
function scan(text, vars, threshold, depth = 0, topSegs = null) {
  const r = { uses: [], cds: [], envC: [], ref: null, toMain: false, dynamic: false, alias: false, gitDir: false, firstCdExempt: false, creates: null, segs: [] };
  const merge = (o) => {
    r.uses.push(...o.uses); r.cds.push(...o.cds); r.envC.push(...o.envC);
    r.ref = r.ref || o.ref; r.toMain = r.toMain || o.toMain; r.dynamic = r.dynamic || o.dynamic;
    r.alias = r.alias || o.alias; r.gitDir = r.gitDir || o.gitDir;
  };
  const segs = topSegs || shellSegments(text);
  r.segs = segs;
  let onlyAssignBefore = true;
  segs.forEach((seg, si) => {
    const toks = seg.toks;
    const t = toks.map(x => x.t);
    const assignsBefore = onlyAssignBefore;
    onlyAssignBefore = onlyAssignBefore && t.every(x => ASSIGN_RE.test(x));
    let k = 0;
    while (k < t.length && (ASSIGN_RE.test(t[k]) || KEYWORDS.has(t[k]))) k++;
    if (t.some(x => /^GIT_(DIR|WORK_TREE)=/.test(x))) r.gitDir = true;
    // Pre-command words (eval, sudo, env -C dir, timeout 5, xargs -I{} ...).
    while (k < t.length && PRECMD.has(baseName(t[k]))) {
      const w = baseName(t[k]); k++;
      while (k < t.length && (t[k].startsWith('-') || (w === 'env' && ASSIGN_RE.test(t[k])))) {
        if (w === 'env' && (t[k] === '-C' || t[k] === '--chdir')) { r.envC.push(toks[k + 1]); k += 2; continue; }
        if (w === 'env' && t[k].startsWith('--chdir=')) { r.envC.push({ t: t[k].slice(8) }); k++; continue; }
        if (w === 'env' && /^GIT_(DIR|WORK_TREE)=/.test(t[k])) r.gitDir = true;
        if (w === 'xargs' && /^-[IJ]/.test(t[k])) r.envC.push({ t: '{}' });
        k += (['-u', '-g', '-n', '-s', '-k', '-I', '-J', '-P', '-L', '-d'].includes(t[k])) ? 2 : 1;
      }
      if (w === 'timeout' && k < t.length) k++;          // the duration
    }
    const head = t[k] === undefined ? '' : baseName(t[k]);
    let gi = -1;
    for (let j = k; j < t.length; j++) if (!ASSIGN_RE.test(t[j]) && GIT_BINS.has(baseName(t[j]))) { gi = j; break; }
    let gitSub = null;
    if (gi !== -1) {
      let s = gi + 1;
      while (s < t.length && (t[s].startsWith('-') || isRedirect(t[s]))) { if (['-C', '-c'].includes(t[s])) s++; s++; }
      gitSub = t[s];
    }
    const dataSeg = head === 'gh' || ['commit', 'merge', 'tag', 'notes'].includes(gitSub);

    // Re-read quoted strings and substitution bodies as commands (bash -c "...", eval "...").
    if (depth < MAX_DEPTH) {
      toks.forEach((x, xi) => {
        const isData = dataSeg && xi > 0 && DATA_FLAGS.has(t[xi - 1]) && !x.dyn;
        if (x.dyn) { for (const body of substitutions(x.t)) merge(scan(body, vars, threshold, depth + 1)); }
        else if (x.q && /\s/.test(x.t) && !isData && !NONEXEC.has(head) && x.t.length <= MAX_WORD * 4) {
          const inner = scan(x.t, vars, threshold, depth + 1);
          merge(inner);
          if (assignsBefore && xi === k + 2 && /^(ba|z|da|k)?sh$/.test(head) && /^-[a-z]*c$/.test(t[k + 1]) && inner.firstCdExempt) r.firstCdExempt = true;
        }
      });
    }

    if (head === 'cd' || head === 'pushd') {
      let j = k + 1;
      while (j < t.length && (/^-[LPe@]+$/.test(t[j]) || t[j] === '--')) j++;
      r.cds.push(j < t.length ? toks[j] : { t: '~' });
      if (assignsBefore && seg.sep === '&&' && !segs.parens) r.firstCdExempt = true;
      return;
    }
    if (NONEXEC.has(head) && !toks.some(x => x.dyn)) return;
    if (head === 'gh') {
      if (t[k + 1] === 'api') { const g = ghApi(t.slice(k)); if (g) r.ref = r.ref || g; }
      return;
    }
    // `$G commit`: the command is a variable. Known to be git -> read on; unknown before a verb -> unreadable.
    if (/^\$[A-Za-z_{]/.test(t[k] || '')) {
      const e = expandAll(t[k], vars);
      if (e !== UNRESOLVED && e.length && e.every(v => GIT_BINS.has(baseName(v)))) { t[k] = 'git'; gi = k; }
      else if (t.slice(k + 1, k + 6).some(v => VERBS.has(v))) { r.dynamic = true; return; }
    }
    if (/^[^=]*\{[^}]*,/.test(t[k] || '') && /(^|[{,/])(git|hub)([,}]|$)/.test(t[k])) { r.dynamic = true; return; }
    if (gi === -1) {
      for (let j = k; j < t.length; j++) if (/[*?[]/.test(baseName(t[j])) && /^[gi*?[\]]+t?$/.test(baseName(t[j]))) { gi = j; break; }
    }
    if (gi === -1) return;
    const cT = [];
    let hasC = false;
    let j = gi + 1;
    for (; j < t.length; j++) {
      const v = t[j];
      if (v === '-C') { cT.push(toks[j + 1]); hasC = true; j++; continue; }
      if (v === '-c') { if (/^alias\./.test(t[j + 1] || '')) r.alias = true; j++; continue; }
      if (v === '--git-dir' || v === '--work-tree') { r.gitDir = true; j++; continue; }
      if (/^--(git-dir|work-tree)=/.test(v)) { r.gitDir = true; continue; }
      if (['--namespace', '--exec-path', '--config-env'].includes(v)) { j++; continue; }
      if (/^\d*(?:>>?|<)$/.test(v)) { j++; continue; }
      if (v.startsWith('-') || isRedirect(v)) continue;
      break;
    }
    if (j >= t.length) return;
    let sub = t[j];
    if (toks[j].dyn || /^\$/.test(sub)) {
      const e = toks[j].dyn ? UNRESOLVED : expandAll(sub, vars);
      if (e === UNRESOLVED || e.length !== 1) { r.dynamic = true; return; }
      sub = e[0];
    }
    const aT = toks.slice(j + 1);
    const a = aT.map(x => (x.dyn && SELF_BRANCH_RE.test(x.t) && !hasC ? 'HEAD' : x.t));
    if (VERBS.has(sub)) r.uses.push({ verb: sub, cTargets: cT, args: a });
    const creating = a.findIndex(v => ['-c', '-C', '-b', '-B', '--create', '--force-create', '--orphan'].includes(v));
    if ((sub === 'switch' || sub === 'checkout') && creating !== -1 && isProtected(a[creating + 1] || '')) r.toMain = true;
    const swPos = [];
    for (let k2 = 0; k2 < a.length; k2++) {
      const v = a[k2];
      if (v.startsWith('#') && !aT[k2].q) break;                   // comment
      if (/^\d*(?:>>?|<)$/.test(v)) { k2++; continue; }           // `> file`
      if (isRedirect(v)) continue;                                 // `>/dev/null`, `2>/dev/null`
      if (!v.startsWith('-') || v === '-') swPos.push(v);
    }
    if ((sub === 'switch' || sub === 'checkout') && creating === -1 && !a.includes('--') && (sub === 'switch' || swPos.length === 1)) {
      for (const v of swPos) {
        if (v === '-' || v.startsWith('@{-') || /(^|\/)(main|master)$/.test(v)) { r.toMain = true; break; }
        if (v.includes('$')) { const e = expandAll(v, vars); if (e === UNRESOLVED || e.some(isProtected)) { r.toMain = true; break; } }
      }
    }
    if ((sub === 'switch' || sub === 'checkout') && !r.creates) {
      const ci = a.findIndex(v => ['-c', '--create', '-b'].includes(v));
      if (ci !== -1) r.creates = { seg: si, name: a[ci + 1] };
    }
    const rr = refRule(sub, a, aT, vars, threshold);
    if (rr) r.ref = r.ref || rr;
  });
  return r;
}

/** Rules from ANY branch: moving, deleting, renaming or pushing to main/master. */
function refRule(sub, a, aT, vars, threshold) {
  const pos = [], flags = [];
  a.forEach((x, i) => { if (x.startsWith('-') && !aT[i].q) flags.push(x); else if (!isRedirect(x)) pos.push(x); });
  const shortHas = (ch) => flags.some(f => /^-[a-zA-Z]+$/.test(f) && f.includes(ch));
  const expandPos = (from) => {
    for (let k = from; k < pos.length; k++) {
      if (pos[k].startsWith('$(') || pos[k].includes('`')) return UNRESOLVED;
      if (pos[k].includes('$')) {
        const e = expandAll(pos[k], vars);
        if (e === UNRESOLVED) return UNRESOLVED;
        pos[k] = e.find(v => isProtected(refDst(v))) || e[0];
      }
    }
    return null;
  };
  const prot = () => pos.find(isProtected);
  switch (sub) {
    case 'push': {
      if (expandPos(1) === UNRESOLVED) return UNRESOLVED;
      if (LEVELS.strict <= threshold && (shortHas('f') || flags.includes('--force') || pos.slice(1).some(x => x.startsWith('+')))) return PAT['force-push'];
      if (flags.includes('--all') || flags.includes('--mirror')) return PAT['push-main'];
      if ((shortHas('d') || flags.includes('--delete')) && prot()) return PAT['push-main'];
      for (const x of pos.slice(1)) {
        const dst = refDst(x);
        if (isProtected(dst) || dst.includes('*')) return /master/.test(dst) ? PAT['push-master'] : PAT['push-main'];
      }
      return null;
    }
    case 'pull': {
      if (expandPos(1) === UNRESOLVED) return null;  // pull itself is allowed; only a ref write into main is not
      for (const x of pos.slice(1)) if (x.includes(':') && (isProtected(refDst(x)) || refDst(x).includes('*'))) return PAT['move-protected-ref'];
      return null;
    }
    case 'branch':
      if (expandPos(0) === UNRESOLVED) return UNRESOLVED;
      if (!prot()) return null;
      if (shortHas('d') || shortHas('D') || flags.includes('--delete')) return PAT['branch-delete-protected'];
      if (shortHas('f') || shortHas('M') || shortHas('m') || shortHas('C') || flags.some(f => ['--force', '--move'].includes(f))) return PAT['move-protected-ref'];
      if ((shortHas('c') || flags.includes('--copy')) && isProtected(pos[pos.length - 1])) return PAT['move-protected-ref'];
      return null;
    case 'update-ref': case 'symbolic-ref':
      if (expandPos(0) === UNRESOLVED) return UNRESOLVED;
      return pos.some(x => isProtected(x) || new RegExp(`refs/heads/${PROT}$`).test(x)) ? PAT['move-protected-ref'] : null;
    case 'checkout': case 'switch':
      for (let k = 0; k < a.length; k++) if (['-B', '-C', '--force-create'].includes(a[k]) && isProtected(a[k + 1])) return PAT['move-protected-ref'];
      return null;
    case 'fetch': {
      if (expandPos(1) === UNRESOLVED) return UNRESOLVED;
      const forced = shortHas('f') || flags.includes('--force');
      for (const x of pos.slice(1)) {
        if (!x.includes(':')) continue;
        const dst = refDst(x);
        if ((isProtected(dst) || dst.includes('*')) && (pos[0] === '.' || forced || x.startsWith('+'))) return PAT['move-protected-ref'];
      }
      return null;
    }
    case 'rebase':
      if (pos.length >= 2 && isProtected(pos[pos.length - 1])) return PAT['move-protected-ref'];
      return null;
    default: return null;
  }
}

function ghApi(s) {
  let method = null, hasFields = false;
  for (let k = 2; k < s.length; k++) {
    if (s[k] === '-X' || s[k] === '--method') method = String(s[k + 1] || '').toUpperCase();
    else if (/^--method=/.test(s[k])) method = s[k].slice(9).toUpperCase();
    else if (['-f', '-F', '--field', '--raw-field', '--input'].includes(s[k])) hasFields = true;
  }
  const endpoint = s.slice(2).find(x => !x.startsWith('-') && x.includes('/')) || s[2] || '';
  if (endpoint === 'graphql') return null;
  if (!method) method = hasFields ? 'POST' : 'GET';
  if (method === 'GET') return null;
  const refEndpoint = new RegExp(`git/refs/heads/${PROT}\\b`).test(endpoint) || new RegExp(`branches/${PROT}\\b`).test(endpoint);
  const field = s.some(x => new RegExp(`^(branch|ref)=(refs/heads/)?${PROT}$`).test(x)) ||
               (/\/merges\b/.test(endpoint) && s.some(x => new RegExp(`^base=${PROT}$`).test(x)));
  if (refEndpoint || (/\/(contents|merges|git\/refs)\b/.test(endpoint) && field)) return PAT['gh-api-protected'];
  return null;
}

/** Second reading: every quote is a separator. Finds git verbs inside any string. */
function rawVerbUses(text) {
  const w = text.split(/[\s;&|()"'`]+/).filter(Boolean);
  const uses = [];
  for (let i = 0; i < w.length; i++) {
    if (ASSIGN_RE.test(w[i]) || !GIT_BINS.has(baseName(w[i]))) continue;
    const cT = [];
    let j = i + 1;
    for (; j < w.length && j < i + 40; j++) {
      const v = w[j];
      if (v === '-C') { cT.push({ t: w[j + 1] }); j++; continue; }
      if (v === '-c' || ['--git-dir', '--work-tree', '--namespace', '--exec-path', '--config-env'].includes(v)) { j++; continue; }
      if (/^\d*(?:>>?|<)$/.test(v)) { j++; continue; }
      if (v.startsWith('-') || isRedirect(v)) continue;
      break;
    }
    if (j < w.length && VERBS.has(w[j])) uses.push({ verb: w[j], cTargets: cT, args: w.slice(j + 1, j + 30) });
    i = Math.max(i, j - 1);
  }
  return uses;
}

/** Drop segments headed by a print/search/remote command (unless they hold a substitution). */
function execOnly(text) {
  return text.split(/[;&|\n]+/).filter(seg => {
    const w = seg.split(/[\s()"'`]+/).filter(Boolean);
    let k = 0; while (k < w.length && (ASSIGN_RE.test(w[k]) || KEYWORDS.has(w[k]))) k++;
    const head = w[k] === undefined ? '' : baseName(w[k]);
    return !NONEXEC.has(head) || /\$\(|`|<\(/.test(seg);
  }).join('\n');
}

/** Strip the values of --body/--title/-m... from git commit/merge/tag and gh lines, for the raw reading. */
function stripDataArgs(text) {
  return text.split('\n').map(line => {
    if (!/\bgh\s|\bgit\b[^;&|]*\b(commit|merge|tag|notes)\b/.test(line)) return line;
    return line.replace(/(\s(?:--body|--title|--message|--notes|-m|-b|-t))(?:\s+|=)("(?:[^"\\]|\\.)*"|'[^']*')/g,
      (m, flag, val) => (/\$\(|`/.test(val) ? m : `${flag} ""`));
  }).join('\n');
}

// ---- main check ---------------------------------------------------------------------

function legacyCheck(cmd, branch, threshold) {
  for (const p of PATTERNS) {
    if (LEVELS[p.level] > threshold) continue;
    if (!p.regex.test(cmd)) continue;
    if (p.branchOnly && !PROTECTED_BRANCHES.includes(branch)) continue;
    return { blocked: true, pattern: p, reason: p.reason.replace('{branch}', branch || '') };
  }
  return { blocked: false };
}

function resolveDirs(tok, vars, cwd) {
  if (!tok || tok.t === undefined) return UNRESOLVED;
  if (tok.dyn) return SELF_DIR_RE.test(String(tok.t).trim()) ? [cwd] : UNRESOLVED;
  if (tok.t === '-' || tok.t === '{}') return UNRESOLVED;
  const vals = expandAll(tok.t, vars);
  if (vals === UNRESOLVED) return UNRESOLVED;
  const out = [];
  for (let s of vals) {
    if (s === '~' || s.startsWith('~/')) s = HOME + s.slice(1);
    if (s === '' || (!tok.q && /[*?[\]{}]/.test(s))) return UNRESOLVED;
    out.push(path.isAbsolute(s) ? path.resolve(s) : path.resolve(cwd, s));
  }
  return out;
}

// `git push <remote> --delete <name>...` (or `<remote> :<name>...`) writes only the named remote
// branches, never the current one, so the current branch being main does not matter.
// refRule has already denied protected names. Only plain literal names and a short flag list qualify:
// HEAD and @ name the current branch, so they, and anything unreadable, fall back to the main check.
const DELETE_PUSH_FLAGS = /^(?:--delete|--quiet|--verbose|--porcelain|-[dqv]+)$/;
function pushOnlyDeletes(args) {
  const flags = args.filter(x => x.startsWith('-'));
  const pos = args.filter(x => !x.startsWith('-'));
  if (!flags.every(f => DELETE_PUSH_FLAGS.test(f)) || pos.length < 2) return false;
  const delFlag = flags.some(f => f === '--delete' || /^-[qv]*d[dqv]*$/.test(f));
  const names = pos.slice(1).map(x => (delFlag ? x : (x.startsWith(':') ? x.slice(1) : null)));
  // `n &&` matters: a null name would coerce to "null" and pass the charset. `@` fails the charset.
  return names.every(n => n && /^\w[\w./-]*$/.test(n) && !/(^|\/)HEAD$/.test(n) &&
    !isProtected(n) && !/^refs\/(?!heads\/)/.test(n));
}

function checkCommand(cmd, branch = null, safetyLevel = SAFETY_LEVEL, cwd = null) {
  const threshold = LEVELS[safetyLevel] || LEVELS.high;
  cmd = typeof cmd === 'string' ? cmd : String(cmd == null ? '' : cmd);
  if (threshold < LEVELS.high) return { blocked: false };
  if (branch) return legacyCheck(cmd, branch, threshold);
  const deny = (p, reason) => ({ blocked: true, pattern: p, reason: reason || p.reason });
  const raw = normalise(cmd);
  try {
    if (raw.length > MAX_LEN) {
      if (GIT_WORD_RE.test(raw)) return deny(PAT['unresolved-target'], `Command is too long to check (${raw.length} chars) and mentions git`);
      return { blocked: false };
    }
    // A script fed to a shell cannot be read here.
    // Paths are [\w./-] only, so long runs of other characters cannot make these slow.
    const shellFed = /(?:^|\s)\|\s*(?:\/[\w.-]+)*\/?(?:bash|sh|zsh|dash|ksh)(?=$|[\s;&])/m.test(raw) ||
      /\b(?:source|\.)\s+\/dev\/stdin\b/.test(raw) ||
      /(?:^|[\s;&|(])(?:\/[\w.-]+)*\/?(?:bash|sh|zsh|dash|ksh)[ \t]+(?:-[a-z]+[ \t]+)*<</m.test(raw);
    if (shellFed && GIT_WORD_RE.test(raw)) {
      return deny(PAT['unresolved-target'], 'Cannot tell what this runs: it feeds text that mentions git to a shell. Run the git command directly');
    }
    const text = dropQuotedHeredocs(raw);
    const stripped = stripDataArgs(text);
    for (const p of PATTERNS.filter(p => p.id.startsWith('gh-'))) {
      if (p.regex.test(stripped)) return deny(p);
    }
    const baseDir = cwd ? path.resolve(cwd) : process.cwd();
    const topSegs = shellSegments(text);
    const vars = assignments(text, topSegs, baseDir);
    const s = scan(text, vars, threshold, 0, topSegs);
    if (s.ref === UNRESOLVED) return deny(PAT['unresolved-target'], 'Cannot tell which branch this git command writes: a branch or refspec comes from text it cannot read. Spell the branch out');
    if (s.ref) return deny(s.ref);

    // Union with the quote-blind reading: a verb it finds that the quote-aware one missed counts too.
    const uses = [...s.uses];
    for (const u of rawVerbUses(execOnly(stripped))) if (!uses.some(x => x.verb === u.verb)) uses.push(u);
    const mentionsVerb = VERB_WORD_RE.test(text);
    if (!uses.length && !((s.dynamic || s.alias) && mentionsVerb)) return { blocked: false };

    const firstVerb = uses.length ? uses[0].verb : null;
    const unresolved = (why) => deny(PAT['unresolved-target'],
      `Cannot tell which repo this${firstVerb ? ` \`git ${firstVerb}\`` : ' git command'} runs in: ${why}. Use a plain absolute path with cd or git -C`);
    if (s.alias) return unresolved('it defines a git alias with -c alias.');
    if (s.dynamic) return unresolved('the git command or subcommand comes from a variable, substitution or brace expansion');
    if (s.gitDir) return unresolved('GIT_DIR, GIT_WORK_TREE, --git-dir or --work-tree points git somewhere else');

    const real = uses.filter(u => !(['commit', 'push', 'merge'].includes(u.verb) &&
      u.args.some(x => x === '--dry-run' || (u.verb === 'push' && x === '-n'))) &&
      !(u.verb === 'push' && pushOnlyDeletes(u.args)));
    if (!real.length) return { blocked: false };

    // Candidate repos.
    const dirs = new Set();
    for (const tok of [...s.cds, ...s.envC, ...real.flatMap(u => u.cTargets)]) {
      const r = resolveDirs(tok, vars, baseDir);
      if (r === UNRESOLVED) return unresolved(`a directory (${tok && tok.t !== undefined ? String(tok.t).slice(0, 80) : 'missing'}) cannot be resolved`);
      for (const d of r) dirs.add(d);
    }
    const allHaveC = real.every(u => u.cTargets.length > 0) && !s.cds.length;
    if (!s.firstCdExempt && !allHaveC) dirs.add(baseDir);
    if (dirs.size > MAX_DIRS) return unresolved(`it touches ${dirs.size} directories (limit ${MAX_DIRS})`);

    // `git switch -c <new> && ...` first, all joined by &&, one repo, no way back to main.
    const segs = s.segs;
    const firstGit = segs.findIndex(sg => sg.toks.some(x => GIT_BINS.has(baseName(x.t))));
    const createsFirst = dirs.size === 1 && !s.toMain && s.creates && s.creates.seg === firstGit &&
      segs.slice(0, segs.length - 1).every(sg => sg.sep === '&&') && !isProtected(s.creates.name || '');

    for (const d of dirs) {
      if (!fs.existsSync(d)) return unresolved(`the directory ${d} does not exist yet (created earlier in this command?)`);
      let b = getCurrentBranch(d);
      if (s.toMain && !isProtected(b)) b = 'main';
      if (!isProtected(b) || createsFirst) continue;
      const p = VERB_PAT.get(real[0].verb);
      const where = d === baseDir ? '' : ` (in ${d})`;
      return deny(p, p.reason.replace('{branch}', b) + where);
    }
    return { blocked: false };
  } catch (e) {
    log({ level: 'ERROR', hook: 'git-safety', error: e.message });
    if (GIT_WORD_RE.test(raw) && VERB_WORD_RE.test(raw)) {
      return deny(PAT['unresolved-target'], `git-safety could not read this command (${e.message}); denying because it names a branch-changing git command`);
    }
    return { blocked: false };
  }
}

async function main() {
  let input = '';
  for await (const chunk of process.stdin) input += chunk;
  try {
    const data = JSON.parse(input);
    const { tool_name, tool_input, session_id, cwd, permission_mode } = data;
    if (tool_name !== 'Bash') return console.log('{}');
    const cmd = tool_input?.command || '';
    const result = checkCommand(cmd, null, SAFETY_LEVEL, cwd);
    if (result.blocked) {
      const p = result.pattern;
      log({ level: 'BLOCKED', id: p.id, priority: p.level, cmd, session_id, cwd, permission_mode });
      return console.log(JSON.stringify({
        hookSpecificOutput: {
          hookEventName: 'PreToolUse',
          permissionDecision: 'deny',
          permissionDecisionReason: `${EMOJIS[p.level]} [${p.id}] ${result.reason}`
        }
      }));
    }
    console.log('{}');
  } catch (e) {
    log({ level: 'ERROR', error: e.message });
    console.log('{}');
  }
}

if (require.main === module) {
  main();
} else {
  module.exports = { checkCommand, PATTERNS };
}
