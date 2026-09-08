#!/usr/bin/env python3
"""
HOOK: no-postmortem-precommit.py
ROLE: Commit-boundary backstop for no-postmortem-validator.py, on both of its
      surfaces, with the patterns imported from the validator — single source of
      truth. FAILS the commit on a hit. Catches prose that never went through the
      PreToolUse gate (manual edits, non-Claude tools, a peer session, the
      validator being bypassed).

      STAGED .md   — the whole file is prose, so the whole file is scanned.
      STAGED code  — ADDED LINES ONLY, and of those only the comments and
                     docstrings. A commit is answerable for the prose it adds;
                     the rest of the file is the sweep's business, not this
                     gate's, and scanning it would make every commit a flag day.

WIRED: via a local .git/hooks/pre-commit shim, which the global pre-commit execs.
OVERRIDE (per file): provenance file name, or the token postmortem-ok stated
      OUTSIDE backticks — a doc that merely quotes the token is showing it, not
      claiming it.

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
        # scope_of expects a path containing /.claude/...; rel is repo-relative.
        mode = v.scope_of("/" + rel)
        if not mode:
            continue
        if any(h in rel.lower() for h in v.PROVENANCE_HINTS):
            continue
        show = git("show", f":{rel}")
        if show.returncode != 0:
            continue
        content = show.stdout

        if mode == "md":
            prose = v.prose_of(content, "md")
        else:
            diff = git("diff", "--cached", "-U0", "--", rel)
            if diff.returncode != 0:
                continue
            added = "\n".join(
                ln[1:] for ln in diff.stdout.splitlines()
                if ln.startswith("+") and not ln.startswith("+++")
            )
            ext = os.path.splitext(rel)[1].lower()
            prose = v.prose_of(added, "code", ext, fallback=False)
        if not prose.strip() or v.OVERRIDE_MARKER in prose:
            continue

        hits = v.find_hits(prose, mode)
        if hits:
            blocked.append((rel, hits))

    if blocked:
        print(
            "BLOCKED by the no-postmortem gate — staged files carry "
            "tombstone / change-narration prose:",
            file=sys.stderr,
        )
        for rel, hits in blocked:
            print(f"  {rel}", file=sys.stderr)
            for h in hits:
                print(f"     - {h}", file=sys.stderr)
        print(
            "\nState things as they ARE; put the reason for a change in the commit "
            "message. Per file, override with a provenance name (*-audit.md) or "
            "the token  postmortem-ok  in the file.",
            file=sys.stderr,
        )
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
