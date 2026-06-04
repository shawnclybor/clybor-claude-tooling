#!/usr/bin/env python3
"""
HOOK: no-postmortem-precommit.py
ROLE: Commit-boundary backstop for no-postmortem-validator.py. Scans STAGED .md
      files in the operational dirs for the SAME block patterns (imported from the
      validator — single source of truth) and FAILS the commit if any are found.
      Catches prose that never went through the PreToolUse gate (manual edits,
      non-Claude tools, the validator being bypassed).

WIRED: via a local .git/hooks/pre-commit shim, which the global pre-commit execs.
OVERRIDE (per file): provenance file name, or an inline <!-- postmortem-ok --> marker.

EXIT CODES:
  0 — clean (or nothing in scope)
  1 — blocked: staged operational doc carries tombstone/post-mortem prose
"""
import importlib.util
import os
import subprocess
import sys

sys.dont_write_bytecode = True  # don't litter consumer repos with __pycache__/*.pyc

HERE = os.path.dirname(os.path.abspath(__file__))
VALIDATOR = os.path.join(HERE, "no-postmortem-validator.py")


def load_validator():
    spec = importlib.util.spec_from_file_location("npm_validator", VALIDATOR)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def git(*args):
    return subprocess.run(
        ["git", *args], capture_output=True, text=True
    )


def main():
    if not os.path.exists(VALIDATOR):
        sys.exit(0)
    v = load_validator()

    res = git("diff", "--cached", "--name-only", "--diff-filter=ACM")
    if res.returncode != 0:
        sys.exit(0)
    staged = [p for p in res.stdout.splitlines() if p.strip()]

    blocked = []
    for rel in staged:
        # validator.in_scope expects a path containing /.claude/...; rel is repo-relative.
        if not v.in_scope("/" + rel):
            continue
        if any(h in rel.lower() for h in v.PROVENANCE_HINTS):
            continue
        show = git("show", f":{rel}")
        if show.returncode != 0:
            continue
        content = show.stdout
        if v.OVERRIDE_MARKER in content:
            continue
        hits = v.find_hits(content)
        if hits:
            blocked.append((rel, hits))

    if blocked:
        print(
            "BLOCKED by the no-postmortem gate — staged operational docs carry "
            "tombstone / post-mortem prose:",
            file=sys.stderr,
        )
        for rel, hits in blocked:
            print(f"  {rel}", file=sys.stderr)
            for h in hits:
                print(f"     - {h}", file=sys.stderr)
        print(
            "\nState things as they ARE; put rationale for cuts in the commit "
            "message. Per file, override with a *-audit.md name or an inline "
            "<!-- postmortem-ok --> marker.",
            file=sys.stderr,
        )
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
