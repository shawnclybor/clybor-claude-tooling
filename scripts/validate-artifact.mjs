#!/usr/bin/env node
/**
 * validate-artifact.mjs — refuse to publish a self-contained HTML page that does not run.
 *
 * Why: a generated dashboard page once shipped with its data array emitted as a bare
 * object literal (no `const DATA =` in front). That is a SyntaxError, so the whole
 * <script> block failed and every panel rendered empty, while the publish step reported
 * success for days. Nothing checked that the shipped page executed.
 *
 * Two gates, cheapest first:
 *   1. Syntax: `node --check` every inline JavaScript <script> block (~50ms).
 *      Classic scripts are checked as CommonJS (sloppy mode), type="module" as ESM.
 *      Non-JS blocks (application/json, ld+json, text/template, ...) are skipped.
 *   2. Runtime: load the page in headless Chromium and assert zero uncaught errors,
 *      enough rendered text, and that every --require selector matches something.
 *      Catches what parses fine but breaks at run time (a null deref, DATA.items
 *      undefined, a renderer writing to an element that no longer exists).
 *
 * Usage:
 *   node validate-artifact.mjs <page.html> [--require <css>]... [--min-text N]
 *                                          [--syntax-only] [--keep-tmp]
 *
 *   --require <css>  a selector that must match at least one element after load;
 *                    repeat it for every region the page must render
 *   --min-text N     minimum rendered body text, in characters (default 200)
 *   --syntax-only    run gate 1 only (for machines with no browser; says so loudly)
 *
 * Browser: needs the `playwright` package and a Chromium build. Set PLAYWRIGHT_PKG to a
 * playwright install path, or CHROMIUM_PATH to a Chromium binary, if neither is found.
 *
 * Exit 0 = safe to publish. 1 = DO NOT PUBLISH. 2 = usage error. 3 = no browser.
 */
import { readFileSync, writeFileSync, mkdtempSync, rmSync, readdirSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir, homedir } from 'node:os';
import { join } from 'node:path';
import { createRequire } from 'node:module';

const args = process.argv.slice(2);
const flag = f => args.includes(f);
const values = f => args.flatMap((a, i) => (a === f && args[i + 1] ? [args[i + 1]] : []));
const file = args.find((a, i) => !a.startsWith('--') && !['--require', '--min-text'].includes(args[i - 1]));
const required = values('--require');
const minText = Number(values('--min-text')[0] ?? 200);
const syntaxOnly = flag('--syntax-only');
const keepTmp = flag('--keep-tmp');

if (!file || Number.isNaN(minText)) {
  console.error('usage: validate-artifact.mjs <page.html> [--require <css>]... [--min-text N] [--syntax-only]');
  process.exit(2);
}

const fail = [];
const note = [];
const html = readFileSync(file, 'utf8');
const tmp = mkdtempSync(join(tmpdir(), 'artval-'));

/* ---------- Gate 1: syntax ---------- */
const JS_TYPES = /^(|text\/javascript|application\/javascript|module)$/i;
const blocks = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)]
  .map(m => ({ attrs: m[1], src: m[2], type: (m[1].match(/\btype\s*=\s*["']?([^"'\s>]+)/i) || [])[1] || '' }))
  .filter(b => b.src.trim() && JS_TYPES.test(b.type));
if (blocks.length === 0) note.push('no inline JavaScript <script> blocks found');

blocks.forEach((b, i) => {
  const p = join(tmp, `block${i}.${/^module$/i.test(b.type) ? 'mjs' : 'cjs'}`);
  writeFileSync(p, b.src);
  try {
    execFileSync(process.execPath, ['--check', p], { stdio: 'pipe' });
  } catch (e) {
    // node --check echoes the offending line; an embedded data blob can be 70KB on one
    // line, so clip each line or the report is unreadable.
    const clip = s => (s.length > 160 ? s.slice(0, 160) + ` …[${s.length} chars]` : s);
    const msg = (e.stderr?.toString() || e.message).split('\n').slice(0, 6).map(clip).join('\n    ');
    fail.push(`SYNTAX ERROR in <script> block ${i + 1}:\n    ${msg}`);
  }
});

/* ---------- Gate 2: it runs and renders ---------- */
// Find a playwright that both loads AND launches. An npx cache often holds several
// playwright versions, most pinned to a browser build that was never downloaded, so
// the first resolvable copy is frequently not a working one. Try them all.
async function launchBrowser() {
  const req = createRequire(import.meta.url);
  const expand = (dir, tail) => {
    try { return readdirSync(dir).map(e => `${dir}/${e}/${tail}`).filter(existsSync); } catch { return []; }
  };
  const HOME = homedir();
  const candidates = [...new Set([
    process.env.PLAYWRIGHT_PKG,
    'playwright',
    ...expand(`${HOME}/.npm/_npx`, 'node_modules/playwright'),
    ...expand(`${HOME}/.nvm/versions/node`, 'lib/node_modules/playwright'),
    '/usr/local/lib/node_modules/playwright',
    '/opt/homebrew/lib/node_modules/playwright',
    '/usr/lib/node_modules/playwright',
  ].filter(Boolean))];
  const tried = [];
  for (const c of candidates) {
    let pw;
    try { pw = req(c); } catch { tried.push(`${c}: not resolvable`); continue; }
    for (const opts of [{}, ...(process.env.CHROMIUM_PATH ? [{ executablePath: process.env.CHROMIUM_PATH }] : [])]) {
      try { return { browser: await pw.chromium.launch(opts), via: c + (opts.executablePath ? ' (CHROMIUM_PATH)' : '') }; }
      catch (e) { tried.push(`${c}${opts.executablePath ? ' (CHROMIUM_PATH)' : ''}: launch failed: ${e.message.split('\n')[0]}`); }
    }
  }
  return { browser: null, tried };
}

if (fail.length) {
  note.push('skipped browser gate: fix the syntax error first');
} else if (syntaxOnly) {
  note.push('SYNTAX ONLY: runtime gate skipped on request. A page can parse and still render nothing.');
} else {
  const { browser, via, tried } = await launchBrowser();
  if (!browser) {
    console.error('validate-artifact: could not start a browser. Tried:');
    for (const t of tried) console.error('  - ' + t);
    console.error('  Fix: `npx playwright install chromium`, or set PLAYWRIGHT_PKG / CHROMIUM_PATH.');
    console.error('  Refusing to report PASS on a syntax check alone (use --syntax-only to say so explicitly).');
    if (!keepTmp) rmSync(tmp, { recursive: true, force: true });
    process.exit(3);
  }
  note.push(`browser via ${via}`);
  // Artifact hosts often wrap a fragment in a document skeleton at publish time; do the
  // same here so the check sees what ships.
  const page_html = /<html[\s>]/i.test(html)
    ? html
    : `<!doctype html><html><head><meta charset="utf-8"></head><body>\n${html}\n</body></html>`;
  const pagePath = join(tmp, 'page.html');
  writeFileSync(pagePath, page_html);

  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push(`UNCAUGHT: ${e.message}`));
  page.on('console', m => { if (m.type() === 'error') errors.push(`CONSOLE: ${m.text()}`); });
  try {
    await page.goto('file://' + pagePath, { waitUntil: 'load', timeout: 20000 });
    await page.waitForTimeout(600); // let a deferred render finish
    const probe = await page.evaluate(sels => ({
      text: (document.body?.textContent || '').trim().length,
      missing: sels.filter(s => { try { return !document.querySelector(s); } catch { return true; } }),
    }), required);
    // Offline asset failures (web fonts, CDN, favicon) are network noise, not script
    // failures; a page renders fine without them. Only script errors gate the publish.
    const real = errors.filter(e => !/Failed to load resource|net::ERR_|fonts\.googleapis|favicon/i.test(e));
    if (real.length) fail.push(`PAGE ERRORS (${real.length}):\n    ` + real.slice(0, 8).join('\n    '));
    if (probe.text < minText) fail.push(`page rendered ${probe.text} chars of text (minimum ${minText}): its script likely never ran`);
    for (const s of probe.missing) fail.push(`required selector matched nothing: ${s}`);
    note.push(`rendered ${probe.text} chars of text; ${required.length - probe.missing.length}/${required.length} required selectors present`);
  } catch (e) {
    fail.push(`could not load the page in a browser: ${e.message}`);
  } finally {
    await browser.close();
  }
}

if (!keepTmp) rmSync(tmp, { recursive: true, force: true });

console.log(`validate-artifact: ${file}`);
console.log(`  script blocks checked: ${blocks.length}`);
for (const n of note) console.log(`  ${n}`);
if (fail.length) {
  console.error('\nFAIL: DO NOT PUBLISH');
  for (const f of fail) console.error('  • ' + f);
  process.exit(1);
}
console.log(syntaxOnly ? '\nPASS (syntax only).' : '\nPASS: page parses, runs clean, and rendered content.');
