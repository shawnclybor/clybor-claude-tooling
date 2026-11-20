#!/usr/bin/env python3
"""check-unlinked-deliverables.py: flag project drafts/deliverables that the project's own
cold-start entry points never name.

Why: a deliverable named only in a task tracker or a chat is invisible to the next session,
and the registry/memory/folder checks in check-backlinks.sh never look inside drafts/ or
deliverables/, so they report "All checks passed" while it sits there. A cold session reads the
project's registry block, its memory file and <project>/index.md first, so every recent
top-level entry in <project>/drafts/ or <project>/deliverables/ must be named in one of those.
Only the project's OWN entry points count: a mention in another project's notes does not.

Which folders: every folder a registry "Local folder" row names (docs/registry/*.md when the
registry is split, else docs/project-registry.md). Repos that also keep a ```layout block in
.claude/rules/filing.md and scripts/check-layout.py add its projects: and areas: folders.
A folder's entry points are the registry blocks naming it plus the memory files those blocks
name; a folder no block names falls back to memory/projects/<folder>.md (counted in the summary).

Matching (Unicode NFC, case-insensitive, on name boundaries so "a.docx" is not met by "Banana.docx"):
  - a folder by its name;
  - a file by its name, by its stem in another format ("x.md" covers "x.pdf"), or by a folder of
    the same stem ("kit-v1/" covers "kit-v1.zip");
  - the shorthand "name.{md,docx,pdf}" counts for each format listed.

Recency: a file's own mtime; a folder's NEWEST content file (sidecars and dotfiles ignored),
or its own mtime when empty. Accepted risk: a sync tool that rewrites mtimes makes old entries
look recent and they get flagged. That is noise, never a false pass.

Usage:  python3 scripts/check-unlinked-deliverables.py [--root PATH] [--days N]   (--days 0 = no window)
Exit:   0 clean · 1 unlinked entries · 2 could not check (no folders found, unreadable layout, or any crash)
"""
import argparse, glob, importlib.util, os, re, sys, time, unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))


def _crash(t, e, tb):
    sys.__excepthook__(t, e, tb); sys.exit(2)  # a crash is "could not check", never "unlinked"
sys.excepthook = _crash

ap = argparse.ArgumentParser()
ap.add_argument("--root", default=os.path.dirname(HERE))
ap.add_argument("--days", type=int, default=14)
a = ap.parse_args()
root = os.path.abspath(a.root)

# Optional layout block: only where the repo has both check-layout.py and filing.md.
layout_folders = []
_rules = os.path.join(root, ".claude", "rules", "filing.md")
_cl = os.path.join(HERE, "check-layout.py")
if os.path.exists(_cl) and os.path.exists(_rules):
    spec = importlib.util.spec_from_file_location("check_layout", _cl)
    cl = importlib.util.module_from_spec(spec); spec.loader.exec_module(cl)
    cl.RULES = _rules
    lay = cl.load_layout()  # exits 2 itself if the layout block is unreadable
    layout_folders = [f for f in lay["projects"] + lay["areas"] if "*" not in f]


def norm(s):
    return unicodedata.normalize("NFC", s).casefold()


def read(path):
    try:
        return open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return ""


def first_tick(block, label):
    m = re.search(r"\|\s*\*\*" + label + r"\*\*\s*\|[^`\n]*`([^`]+)`", block)
    return m.group(1).strip() if m else None


# folder -> registry blocks and memory files that belong to it
reg_files = sorted(glob.glob(os.path.join(root, "docs", "registry", "*.md")))
if not reg_files:
    reg_files = [os.path.join(root, "docs", "project-registry.md")]
owned = {}
for rf in reg_files:
    for block in re.split(r"\n(?=### )", read(rf)):
        folder = first_tick(block, "Local folder")
        if not folder:
            continue
        key = folder.strip("/").split("/")[0]
        texts = owned.setdefault(key, [])
        texts.append(block)
        mem = first_tick(block, "Memory file")
        if mem:
            texts.append(read(os.path.join(root, mem)))


def expand_braces(text):
    extra = [f"{m.group(1)}.{ext}" for m in re.finditer(r"([\w.\-]+)\.\{([\w,]+)\}", text)
             for ext in m.group(2).split(",")]
    return text + "\n" + "\n".join(extra)


def newest_mtime(p):
    t = os.lstat(p).st_mtime  # lstat: a broken symlink must not crash the gate
    if os.path.isdir(p) and not os.path.islink(p):
        own, t = t, 0  # a folder's own mtime moves on any rename; date it by its content files only
        for dp, dns, fns in os.walk(p):
            dns[:] = [d for d in dns if not d.startswith(".")]
            for f in fns:
                if f.startswith(".") or f.endswith((".okf", ".okf.yaml")):
                    continue  # sidecars are rewritten by the OKF fixer; they are not content
                try:
                    t = max(t, os.lstat(os.path.join(dp, f)).st_mtime)
                except OSError:
                    pass
        if t == 0:
            t = own  # no content files: fall back to the folder's own date
    return t


B = r"(?<![\w.-])"
cutoff = time.time() - a.days * 86400 if a.days > 0 else None
folders = evaluated = skipped_old = unmapped = 0
unmapped_names = []  # a bare count is unactionable: name them (granola-processing 2026-11-19)
unlinked = []
for proj in list(dict.fromkeys(list(owned) + layout_folders)):
    if not os.path.isdir(os.path.join(root, proj)):
        continue
    folders += 1
    texts = owned.get(proj)
    if texts is None:
        unmapped += 1
        unmapped_names.append(proj)
        texts = [read(os.path.join(root, "memory", "projects", proj + ".md"))]
    hay = norm(expand_braces("\n".join(texts + [read(os.path.join(root, proj, "index.md"))])))
    for sub in ("drafts", "deliverables"):
        d = os.path.join(root, proj, sub)
        if not os.path.isdir(d):
            continue
        for name in sorted(os.listdir(d)):
            if name.startswith((".", "_")) or name.endswith((".okf", ".okf.yaml")):  # "_" = archive dirs
                continue
            p = os.path.join(d, name)
            if cutoff and newest_mtime(p) < cutoff:
                skipped_old += 1
                continue
            evaluated += 1
            n = norm(name)
            ok = re.search(B + re.escape(n) + r"(?![\w-])", hay) is not None
            if not ok and os.path.isfile(p) and "." in n:
                ok = re.search(B + re.escape(n.rsplit(".", 1)[0]) + r"(\.\w|/)", hay) is not None
            if not ok:
                unlinked.append(f"{proj}/{sub}/{name}")

for u in unlinked:
    print(f"UNLINKED {u}")
window = f"{a.days}d" if cutoff else "none"
print(f"folders={folders} evaluated={evaluated} unlinked={len(unlinked)} skipped_older={skipped_old} "
      f"unmapped_folders={unmapped} window={window}")
if unmapped_names:
    print("UNMAPPED_FOLDERS " + " ".join(sorted(unmapped_names)) +
          "  (no registry folder row; Check 7 fell back to memory/projects/<name>.md only)")
if folders == 0:
    print("FAIL: found no project folders (registry Local folder rows or layout). Wrong --root?"); sys.exit(2)
sys.exit(1 if unlinked else 0)
