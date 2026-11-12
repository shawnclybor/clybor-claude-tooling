#!/usr/bin/env python3
"""check-plugin-sync.py - are a project's Cowork plugins in step: source, bundle, installs?

  python3 check-plugin-sync.py <project-root>

check-promotion.sh compares a project's tooling against this master. A plugin source folder
(cowork/<plugin>/) syncs along a different path that never touches the master:

  source folder -> cowork/<plugin>.plugin bundle (version bump) -> installed copies

A plugin that carries private details (a meeting room, a client name) belongs in its own
project and never in a public master, so this path is the only place its drift can show.
Labels printed:

  UNBUMPED        source differs from the bundle, both carry the same version. Installs can
                  never pick the change up. Bump the version and rebuild.
  UNBUILT         source version is newer than the bundle. Rebuild.
  SOURCE-BEHIND   the bundle is newer than its source folder. Bring the source up first.
  INSTALLED-LAGS  the newest installed copy at a location is older than the project's.
  UNMERGED        a local branch has commits under cowork/ (last 30 days) that the default
                  branch lacks, so new worktrees start without them.

Install locations: CLYBOR_PLUGIN_INSTALL_GLOBS (os.pathsep-separated globs, each matching
plugin root folders); defaults below. Output: one tab-separated "LABEL<TAB>subject<TAB>advice"
line per finding, nothing when all is in step. Always exits 0: information, not a gate.
"""
import glob
import json
import os
import subprocess
import sys
import zipfile

DEFAULT_GLOBS = [
    "~/.claude/plugins/synced/*/*",
    "~/Library/Application Support/Claude/local-agent-mode-sessions/*/*/rpm/plugin_*",
]
JUNK_PARTS = {".DS_Store", "Thumbs.db", "__pycache__", "node_modules", ".git"}
MANIFEST = ".claude-plugin/plugin.json"


def junk(rel):
    return (any(p in JUNK_PARTS for p in rel.split("/"))
            or rel.endswith((".pyc", "~")) or ".bak-" in rel)


def vkey(v):
    out = []
    for part in str(v).split("."):
        digits = ""
        for c in part:
            if not c.isdigit():
                break
            digits += c
        out.append(int(digits) if digits else 0)
    return tuple(out)


def name_version(raw):
    try:
        d = json.loads(raw)
        return d.get("name"), str(d.get("version", "0"))
    except (ValueError, AttributeError):
        return None, None


def source_files(src):
    files = {}
    for root, dirs, names in os.walk(src):
        dirs[:] = [d for d in dirs if d not in JUNK_PARTS]
        for n in names:
            p = os.path.join(root, n)
            rel = os.path.relpath(p, src).replace(os.sep, "/")
            if not junk(rel):
                with open(p, "rb") as f:
                    files[rel] = f.read()
    return files


def bundle_files(path):
    with zipfile.ZipFile(path) as z:
        return {i.filename: z.read(i) for i in z.infolist()
                if not i.is_dir() and not junk(i.filename)}


def newest_installs(globs, name):
    """Per location glob, the newest installed copy of plugin `name` as (glob, version)."""
    found = []
    for g in globs:
        best = None
        for d in glob.glob(os.path.expanduser(g)):
            mf = os.path.join(d, MANIFEST)
            if not os.path.isfile(mf):
                continue
            try:
                with open(mf, encoding="utf-8") as f:
                    n, v = name_version(f.read())
            except OSError:
                continue
            if n == name and (best is None or vkey(v) > vkey(best)):
                best = v
        if best is not None:
            found.append((g, best))
    return found


def git(repo, *args):
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None


def unmerged_branches(repo):
    base = next((b for b in ("main", "master")
                 if git(repo, "rev-parse", "--verify", "-q", "refs/heads/" + b)), None)
    if not base:
        return []
    out = []
    refs = git(repo, "for-each-ref", "--format=%(refname:short)", "refs/heads") or ""
    for br in refs.splitlines():
        if br == base:
            continue
        n = git(repo, "rev-list", "--count", "--since=30.days", f"{base}..{br}", "--", "cowork/")
        if n and n != "0":
            out.append((br, base, n))
    return out


def check_plugin(cw, name, globs):
    src = os.path.join(cw, name)
    with open(os.path.join(src, MANIFEST), encoding="utf-8") as f:
        pname, sver = name_version(f.read())
    pname = pname or name
    subj = f"cowork/{name}/"
    found, target = [], sver
    bpath = os.path.join(cw, name + ".plugin")
    if os.path.isfile(bpath):
        try:
            bf = bundle_files(bpath)
        except (zipfile.BadZipFile, OSError) as e:
            return [("UNREADABLE", f"cowork/{name}.plugin", f"cannot open the bundle: {e}")]
        _, bver = name_version(bf.get(MANIFEST, b"").decode("utf-8", "replace"))
        sf = source_files(src)
        changed = sorted(k for k in set(sf) | set(bf) if sf.get(k) != bf.get(k))
        shown = ", ".join(changed[:4]) + (f" (+{len(changed) - 4} more)" if len(changed) > 4 else "")
        if bver is None:
            pass
        elif vkey(sver) == vkey(bver) and changed:
            found.append(("UNBUMPED", subj, f"source differs from {name}.plugin but both say {sver} "
                          f"({shown}); installs cannot pick this up. Bump the version and rebuild"))
        elif vkey(sver) > vkey(bver):
            found.append(("UNBUILT", subj, f"source is {sver}, {name}.plugin is {bver}; rebuild the bundle"))
        elif vkey(sver) < vkey(bver):
            found.append(("SOURCE-BEHIND", subj, f"{name}.plugin is {bver}, source folder is {sver}; "
                          "bring the source up before the next edit"))
        if bver is not None and vkey(bver) > vkey(target):
            target = bver
    for g, iv in newest_installs(globs, pname):
        if vkey(iv) < vkey(target):
            where = g.replace(os.path.expanduser("~"), "~", 1)
            found.append(("INSTALLED-LAGS", f"{pname} @ {where}", f"newest installed copy is {iv}, "
                          f"project has {target}; reinstall the current .plugin there"))
    return found


def main():
    repo = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else ".")
    cw = os.path.join(repo, "cowork")
    if not os.path.isdir(cw):
        return
    env = os.environ.get("CLYBOR_PLUGIN_INSTALL_GLOBS")
    globs = [g for g in env.split(os.pathsep) if g] if env else DEFAULT_GLOBS
    findings = []
    for name in sorted(os.listdir(cw)):
        if name.startswith(("_", ".")) or not os.path.isfile(os.path.join(cw, name, MANIFEST)):
            continue
        try:
            findings += check_plugin(cw, name, globs)
        except OSError as e:
            findings.append(("UNREADABLE", f"cowork/{name}/", str(e)))
    branches = unmerged_branches(repo)
    for br, base, n in branches[:5]:
        findings.append(("UNMERGED", br, f"{n} recent commit(s) under cowork/ not on {base}; "
                         f"worktrees made from {base} start without them. Merge, or rebase the worktree"))
    if len(branches) > 5:
        findings.append(("UNMERGED", f"+{len(branches) - 5} more branches", "git branch --no-merged"))
    for f in findings:
        print("\t".join(f))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # information, never a crash that hides the rest of the report
        print(f"UNREADABLE\tcheck-plugin-sync.py\t{type(e).__name__}: {e}")
