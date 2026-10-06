#!/usr/bin/env python3
"""mutate.py — prove read-first's tests can fail.

A test suite that has only ever passed is indistinguishable from one that cannot fail.
This copies the plugin to a temp dir once per mutant, breaks one behaviour on purpose,
runs `claude plugin test`, and requires the suite to go RED. The unmutated copy must
go GREEN first, or nothing below means anything.

Exit 0 = the clean copy passes AND every mutant is caught.
Exit 1 = a mutant survived (a test is missing or toothless), or the clean copy failed.
Exit 2 = a mutation did not apply (the source moved; update the mutant, don't skip it).

Usage: python3 plugins/read-first/scripts/mutate.py
"""
import os
import shutil
import subprocess
import sys
import tempfile

PLUGIN = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RULES = "hooks/rules.ts"
REGISTER = "hooks/register.ts"

# (id, what it breaks, file, exact text to find, replacement)
MUTANTS = [
    ("M1", "gate always allows", RULES,
     "  const verdict = (reason: string): Decision =>",
     "  return { kind: 'allow' }\n  const verdict = (reason: string): Decision =>"),
    ("M2", "loaded guides are never recorded", REGISTER,
     "    loaded.add(bare(e.skill))\n", ""),
    ("M3", "plugin prefix is not stripped", RULES,
     "skill.slice(skill.lastIndexOf(':') + 1).trim()", "skill.trim()"),
    ("M4", "a crash lets the call through", REGISTER,
     "    if (isGuarded(e.tool, rules)) {", "    if (false && isGuarded(e.tool, rules)) {"),
    ("M5", "warn mode blocks like enforce", REGISTER,
     "options.mode === 'warn' ? 'warn' : 'enforce'", "'enforce'"),
    ("M6", "strict mode is ignored", REGISTER,
     "const strict = options.strict === true", "const strict = false"),
    ("M7", "names every needed guide, not just the missing ones", RULES,
     "const missing = needed.filter(g => !loaded.has(g))",
     "const missing = needed.every(g => loaded.has(g)) ? [] : needed"),
    ("M8", "an unreadable rule is silently dropped", RULES,
     "  if (r.errors.length > 0 && isGuarded(tool, r)) {", "  if (false) {"),
    ("M9", "the block message drops the write-guide-skill pointer", RULES,
     "then retry this same call. ${fix}`", "then retry this same call.`"),
    ("M11", "/regex/ rules are read as globs", RULES,
     "pattern.length > 2 && pattern.startsWith('/') && pattern.endsWith('/')", "false"),
    ("M12", "match=first is ignored", RULES,
     "const chosen = match === 'first' ? hits.slice(0, 1) : hits", "const chosen = hits"),
    ("M13", "match=first takes the last rule instead", RULES,
     "hits.slice(0, 1)", "hits.slice(-1)"),
    ("M10", "every MCP tool is blocked, mapped or not", RULES,
     "    return { kind: 'allow' }\n  }\n\n  const missing",
     "    return verdict('blocked')\n  }\n\n  const missing"),
]


def run_tests(path):
    p = subprocess.run(["claude", "plugin", "test", path], capture_output=True, text=True)
    out = p.stdout + p.stderr
    fails = [ln.strip() for ln in out.splitlines() if ln.strip().startswith("(fail)")]
    return p.returncode, out, fails


def main():
    rc, out, fails = run_tests(PLUGIN)
    if rc != 0 or fails or " pass" not in out:
        print("CLEAN COPY FAILED — fix the plugin before reading any mutant result.\n" + out)
        return 1
    print("clean copy: GREEN")

    survived = 0
    for mid, what, rel, find, repl in MUTANTS:
        with tempfile.TemporaryDirectory() as tmp:
            dst = os.path.join(tmp, "read-first")
            shutil.copytree(PLUGIN, dst, ignore=shutil.ignore_patterns(".claude-plugin/types"))
            f = os.path.join(dst, rel)
            src = open(f, encoding="utf-8").read()
            if src.count(find) != 1:
                print(f"{mid} DID NOT APPLY ({src.count(find)} matches) — {what}")
                return 2
            open(f, "w", encoding="utf-8").write(src.replace(find, repl))
            rc, out, fails = run_tests(dst)
            if rc != 0 and fails:
                print(f"{mid} caught   — {what}  ({len(fails)} test(s) went red)")
            else:
                survived += 1
                print(f"{mid} SURVIVED — {what}  (rc={rc}; no test failed)")
    print()
    if survived:
        print(f"FAIL: {survived} of {len(MUTANTS)} mutants survived")
        return 1
    print(f"PASS: all {len(MUTANTS)} mutants caught")
    return 0


if __name__ == "__main__":
    sys.exit(main())
