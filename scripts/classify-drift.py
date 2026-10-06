#!/usr/bin/env python3
"""classify-drift.py — say WHICH WAY a drifted tooling file differs, and whether it is private.

check-promotion.sh finds files whose project copy differs from the canonical copy here.
A difference alone doesn't say what to do. This script names the case:

  PRIVATE  the project copy contains private details (denylist terms, IDs, emails, home
           paths — the same scan verify-clean.py runs). Keep it local and list it in
           .claude/promotion-ignore with the reason, or strip the details with scrub.py
           before promoting. Checked first: it decides whether promoting is safe at all.
  BEHIND   the project copy is an older version of the canonical file. Canon moved on;
           sync down (copy canon -> project).
  AHEAD    the canonical file is an older version of the project copy. The project
           improved it; promote up, after the promote-to-tooling skill's universality test.
  BOTH     neither copy appears in the other's history: both changed. Merge by hand.

"Older version" is decided from git history: a copy is BEHIND if its exact bytes were
once committed to the canonical file, AHEAD if the canonical bytes were once committed
in the project. Uncommitted edits are invisible to history, which can only make a file
look like BOTH — never a wrong BEHIND or AHEAD.

Usage: classify-drift.py <project_root> <canon_root> <relative-path> [...]
Prints one line per path: "<CLASS>\t<path>\t<what to do>". Exit 0 always (a reporter,
not a gate); exit 2 on usage errors.
"""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))

ADVICE = {
    "PRIVATE": "contains private details; keep it local (add to .claude/promotion-ignore with the reason) or scrub before promoting",
    "BEHIND": "canon changed since this copy; sync down from clybor-claude-tooling",
    "AHEAD": "this project improved it; promote up after the universality test (promote-to-tooling skill)",
    "BOTH": "both copies changed; merge by hand",
}


def git(repo, *args):
    p = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True)
    return p.stdout.strip() if p.returncode == 0 else ""


def blob(path):
    p = subprocess.run(["git", "hash-object", path], capture_output=True, text=True)
    return p.stdout.strip()


def was_committed(repo, rel, sha):
    """Did these exact bytes ever exist at `rel` in `repo`'s history?"""
    if not sha or not git(repo, "rev-parse", "--git-dir"):
        return False
    for commit in git(repo, "log", "--format=%H", "--all", "--", rel).splitlines():
        if git(repo, "rev-parse", f"{commit}:{rel}") == sha:
            return True
    return False


def is_private(path):
    scanner = os.path.join(HERE, "verify-clean.py")
    if not os.path.exists(scanner):
        return False
    with tempfile.TemporaryDirectory() as tmp:
        dst = os.path.join(tmp, os.path.basename(path))
        with open(path, "rb") as src, open(dst, "wb") as out:
            out.write(src.read())
        p = subprocess.run([sys.executable, scanner, "--target", tmp], capture_output=True, text=True)
        return p.returncode == 1


def classify(project, canon, rel):
    proj_file, canon_file = os.path.join(project, rel), os.path.join(canon, rel)
    if is_private(proj_file):
        return "PRIVATE"
    if was_committed(canon, rel, blob(proj_file)):
        return "BEHIND"
    if was_committed(project, rel, blob(canon_file)):
        return "AHEAD"
    return "BOTH"


def main(argv):
    if len(argv) < 4:
        print(__doc__, file=sys.stderr)
        return 2
    project, canon, rels = argv[1], argv[2], argv[3:]
    for rel in rels:
        c = classify(project, canon, rel)
        print(f"{c}\t{rel}\t{ADVICE[c]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
