#!/usr/bin/env python3
"""
check_grep_blindspots.py — the probe-visibility gate.

RULE: before an empty search is recorded as absence, the probe must be able to SEE
the thing it claims is missing.

WHY: `grep` in this environment is shimmed to `ugrep --ignore-files`, so a recursive
grep SILENTLY SKIPS every gitignored file and exits 1 as though the corpus were clean.
Proven 2026-08-17: `grep -ril manheim .` returned nothing over a directory whose CSV
provably contained "Manheim"; deleting the local .gitignore made the match reappear.
Three of five eval subagents reported "no matches across all 16 files" — each honestly
reporting a probe that had been narrowed under them.

THE ERROR CLASS THIS CATCHES: a false-zero probe recorded as a finding. This is the
availability gate (CLAUDE.md rule 3) failing WHILE BEING FOLLOWED CORRECTLY — the agent
ran a search, got zero, and wrote it up. check_dependency_probes.py forces a probe to be
declared; this one checks the declared probe could actually reach the target.

In this repo the blind zone is `knowledge/raw/` — the append-only estate inventories,
which is precisely the corpus an "is X in the estate?" probe needs to read.

⚠️ WHY THIS GATE IS DECLARATIVE, NOT EMPIRICAL. The first version planted a canary in an
ignored directory and ran `grep` via subprocess to measure the blindness. It reported
ALL CLEAR — because the shim is a shell function injected into Claude Code's own Bash
tool, and `subprocess.run(["grep"])` invokes the real binary, bypassing it. `zsh -i -c`
does not load it either (verified 2026-08-17). No child process can reproduce the
hazard, so a gate that tries to measure it hands out false all-clears — strictly worse
than no gate. Detection is therefore: shim present (CLAUDE_CODE_EXECPATH is set) AND
gitignored content files exist ⇒ those paths are unreachable by recursive grep.

MODES
  --audit    summary for SessionStart. Always exits 0.
  --paths P… report whether the given paths fall inside the blind zone. Exits 1 if any do.
  (default)  full report. Exits 1 if any blind zone holds content.
"""
import argparse
import os
import subprocess
import sys


def repo_root():
    try:
        return subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return os.getcwd()


# Derived junk is noise, not a hidden finding. Filtered at the source: a `scripts/`
# directory holding only `scripts/__pycache__/*.pyc` was reported BLIND because the
# ignored-file prefix matched. Caught in test 2026-08-17.
SKIP = ("__pycache__", ".serena/", ".DS_Store", ".pyc")


def ignored_files(root):
    """Content files present on disk that git is ignoring — the blind zone."""
    r = subprocess.run(
        ["git", "ls-files", "--others", "--ignored", "--exclude-standard"],
        cwd=root, capture_output=True, text=True,
    )
    out = []
    for line in r.stdout.splitlines():
        if any(s in line for s in SKIP):
            continue
        p = os.path.join(root, line)
        # Only a non-empty regular file can hide a finding.
        if os.path.isfile(p) and os.path.getsize(p) > 0:
            out.append(line)
    return out


def blind_zones(files):
    """Group ignored content files by directory."""
    zones = {}
    for f in files:
        zones.setdefault(os.path.dirname(f) or ".", []).append(f)
    return zones


def shim_active():
    """True when grep is the Claude Code ugrep shim (--ignore-files), which is what
    makes gitignored paths unreachable. See the module docstring for why this is an
    env check and not a measurement."""
    return bool(os.environ.get("CLAUDE_CODE_EXECPATH"))


def is_ignored(root, relpath, ignored=None):
    """True if git ignores `relpath` — i.e. recursive grep cannot reach it.

    ⚠️ A directory needs its CONTENTS tested, not itself. `knowledge/raw/*` ignores the
    files inside `knowledge/raw` but not the directory entry, so `check-ignore` on the
    bare directory returns 'not ignored' for the single most important blind zone in
    this repo. Caught in test 2026-08-17."""
    rel = relpath.rstrip("/")
    if os.path.isdir(os.path.join(root, rel)):
        if ignored is None:
            ignored = ignored_files(root)
        prefix = rel + "/"
        return any(f.startswith(prefix) for f in ignored)
    r = subprocess.run(
        ["git", "check-ignore", "-q", rel],
        cwd=root, capture_output=True, text=True,
    )
    return r.returncode == 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--audit", action="store_true")
    ap.add_argument("--paths", nargs="*", default=None)
    a = ap.parse_args()

    root = repo_root()
    zones = blind_zones(ignored_files(root))

    if a.paths is not None:
        bad = 0
        ign = ignored_files(root)
        for p in a.paths:
            if is_ignored(root, p, ign):
                print(f"BLIND {p} — gitignored; recursive grep cannot reach it")
                bad += 1
            else:
                print(f"OK    {p} — reachable by recursive grep")
        return 1 if bad else 0

    if not shim_active():
        if not a.audit:
            print("grep shim not detected (CLAUDE_CODE_EXECPATH unset) — "
                  "recursive grep is the real binary and sees ignored files.")
        return 0

    if not zones:
        if not a.audit:
            print("No gitignored content files present. No blind zone.")
        return 0

    n = sum(len(v) for v in zones.values())

    if a.audit:
        print("## Probe visibility (grep blind zone)")
        print(f"⚠️  Recursive grep CANNOT see {n} gitignored file(s) in "
              f"{len(zones)} path(s): {', '.join(sorted(zones))}")
        print("   A recursive-grep zero over these is NOT evidence of absence. "
              "Name the directory, use an explicit glob, or parse in Python.")
        return 0

    print(f"Repo: {root}")
    print(f"Blind zone: {n} file(s) across {len(zones)} path(s)\n")
    for z in sorted(zones):
        print(f"  {z}/  ({len(zones[z])} file(s))")
        for f in sorted(zones[z])[:6]:
            print(f"      {os.path.basename(f)}")
    print()
    print("The grep shim (ugrep --ignore-files) is active, so `grep -r … .` from the")
    print("repo root SKIPS every path above and exits 1 as though it were clean.")
    print()
    print("Any 'not found' claim whose probe was a recursive grep from the root is")
    print("UNMEASURED over these paths. Re-probe by naming the directory as the search")
    print("root, using an explicit glob, or parsing in Python.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
