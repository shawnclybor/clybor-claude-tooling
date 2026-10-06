#!/usr/bin/env python3
"""Fail when a Claude plugin directory contains another plugin's manifest.

claude.ai's marketplace sync rejects a plugin whose tree holds a second
.claude-plugin/plugin.json (error marketplace_sync_multiple_manifests), and
`claude plugin validate` does not catch it. A test fixture that is itself a
small plugin is the usual cause.

Reads the git index, so it checks exactly what is being committed.
Sibling plugins in a marketplace repo (plugins/a, plugins/b) are fine.

Usage: check-plugin-manifests.py [repo-dir]
Exit 0 = clean, not a git repo, or no plugins. Exit 1 = nested manifest found.
"""
import subprocess
import sys
from pathlib import PurePosixPath

MANIFEST = ".claude-plugin/plugin.json"


def plugin_roots(repo):
    r = subprocess.run(["git", "-C", repo, "ls-files", "-z"], capture_output=True)
    if r.returncode != 0:
        return None
    roots = []
    for f in r.stdout.decode("utf-8", "replace").split("\0"):
        if f == MANIFEST or f.endswith("/" + MANIFEST):
            roots.append(str(PurePosixPath(f).parent.parent))  # "." for the repo root
    return roots


def main(repo="."):
    roots = plugin_roots(repo)
    if not roots:
        return 0
    bad = [(o, i) for o in roots for i in roots
           if i != o and (o == "." or i.startswith(o + "/"))]
    for outer, inner in bad:
        name = "the repo root" if outer == "." else f"'{outer}'"
        print(f"nested plugin manifest: {inner}/{MANIFEST} sits inside the plugin at {name}.\n"
              f"  claude.ai's marketplace sync rejects that plugin (marketplace_sync_multiple_manifests).\n"
              f"  Fix: store the inner manifest under another name (e.g. plugin.fixture.json)\n"
              f"  and rebuild it in a temp dir when the test runs.", file=sys.stderr)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:2]))
