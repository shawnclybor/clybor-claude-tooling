#!/usr/bin/env python3
"""mutate.py — prove think-first's tests can fail.

A test suite that has only ever passed is indistinguishable from one that cannot fail.
This copies the plugin to a temp dir once per mutant, breaks one behaviour on purpose,
runs `claude plugin test`, and requires the suite to go RED. The unmutated copy must
go GREEN first, or nothing below means anything.

Exit 0 = the clean copy passes AND every mutant is caught.
Exit 1 = a mutant survived (a test is missing or toothless), or the clean copy failed.
Exit 2 = a mutation did not apply (the source moved; update the mutant, don't skip it).

Usage: python3 plugins/think-first/scripts/mutate.py
"""
import os
import shutil
import subprocess
import sys
import tempfile

PLUGIN = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
THINK = "hooks/think.ts"
REGISTER = "hooks/register.ts"

# (id, what it breaks, file, exact text to find, replacement)
MUTANTS = [
    ("T1", "writes are never blocked", THINK,
     "const writing = !s.thought && matches(writes, tool)", "const writing = false"),
    ("T2", "retries are never blocked", THINK,
     "const retrying = s.failed.has(tool) && matches(retries, tool)", "const retrying = false"),
    ("T3", "a new user message does not reset", REGISTER,
     "    s.thought = false\n", ""),
    ("T4", "a failed call is not recorded", REGISTER,
     "if (r.isError) s.failed.add(e.tool)", "if (false) s.failed.add(e.tool)"),
    ("T5", "a thinking step does not clear failures", REGISTER,
     "        s.failed.clear()\n", ""),
    ("T6", "one thinking-tool error already counts as unavailable", REGISTER,
     "s.thinkErrors >= 2", "s.thinkErrors >= 1"),
    ("T7", "a malformed thinking call counts as unavailable", REGISTER,
     "} else if (r.isError && !isMalformed(r.text ?? '')) {", "} else if (r.isError) {"),
    ("T8", "a crash lets the call through", REGISTER,
     "if (!isThinkTool(e.tool) && (e.tool.startsWith('mcp__') || matches(writes, e.tool))) {", "if (false) {"),
    ("T9", "warn mode blocks like enforce", REGISTER,
     "options.mode === 'warn' ? 'warn' : 'enforce'", "'enforce'"),
    ("T10", "broken settings are silently ignored", THINK,
     "if (errors.length > 0 && tool.startsWith('mcp__')) {", "if (false) {"),
    ("T11", "any failure blocks every tool", THINK,
     "const retrying = s.failed.has(tool) && matches(retries, tool)", "const retrying = s.failed.size > 0 && matches(retries, tool)"),
    ("T12", "notes to Claude are dropped", REGISTER,
     "if (note && r.deny === undefined)", "if (false)"),
    ("T14", "nothing counts as continuing work; every prompt resets", REGISTER,
     "    if (CONTINUES.has(e.origin.kind)) return next(e)\n", ""),
    ("T15", "no prompt resets except the person typing", REGISTER,
     "if (CONTINUES.has(e.origin.kind)) return next(e)", "if (e.origin.kind !== 'composer') return next(e)"),
    ("T13", "a successful thinking step is not recorded", REGISTER,
     "        s.thought = true\n", ""),
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
            dst = os.path.join(tmp, "think-first")
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
