#!/usr/bin/env python3
"""session_file_check.py — file-hygiene gate for the session-output skill.

Lints/validates every file a session created or edited, so a session report can
truthfully attest the touched files are clean. Stdlib only — no dependencies.

Usage:
    python3 session_file_check.py <file1> [file2 ...] [--git <repo_dir>] [--json]

    --git <repo_dir>   also print `git status --porcelain` for that repo
    --json             emit a machine-readable JSON summary instead of text

Exit code: 0 = every checked file clean; 1 = at least one issue (or missing file).

Run it WHERE THE FILES LIVE: for host files use Desktop Commander start_process on
the Mac; for sandbox outputs run in the container.
"""
import sys, os, json, subprocess


def check_py(p):
    try:
        compile(open(p, encoding="utf-8").read(), p, "exec")
        return True, "python: byte-compiles"
    except SyntaxError as e:
        return False, f"python: SyntaxError line {e.lineno}: {e.msg}"


def check_json(p):
    try:
        json.load(open(p, encoding="utf-8"))
        return True, "json: parses"
    except Exception as e:
        return False, f"json: {e}"


def check_sh(p):
    r = subprocess.run(["bash", "-n", p], capture_output=True, text=True)
    if r.returncode == 0:
        return True, "shell: syntax ok (bash -n)"
    return False, "shell: " + (r.stderr.strip().splitlines()[-1] if r.stderr.strip() else "syntax error")


def check_md(p):
    src = open(p, encoding="utf-8").read()
    if not src.startswith("---"):
        return True, "markdown: ok (no frontmatter)"
    end = src.find("\n---", 3)
    if end == -1:
        return False, "markdown: frontmatter opened but never closed"
    fm = src[3:end]
    # SKILL.md frontmatter description has a hard 1024-char cap (Anthropic install validation)
    in_desc, desc = False, []
    for line in fm.splitlines():
        if line.startswith("description:"):
            in_desc = True
            rest = line.split("description:", 1)[1].strip()
            desc.append(rest.lstrip("> ").strip()) if rest not in (">", "|", ">-", "|-") else None
        elif in_desc and (line.startswith("  ") or line.strip() == ""):
            desc.append(line.strip())
        elif in_desc:
            break
    dlen = len(" ".join(d for d in desc if d))
    if dlen > 1024:
        return False, f"markdown: frontmatter description {dlen} chars > 1024 cap"
    return True, "markdown: frontmatter closes; description ok"


def check_html(p):
    from html.parser import HTMLParser
    src = open(p, encoding="utf-8").read()
    try:
        HTMLParser().feed(src)
    except Exception as e:
        return False, f"html: parse error: {e}"
    low = src.lower()
    if "<html" in low and "</html>" in low:
        return True, "html: parses; <html>…</html> present"
    return False, "html: parses but missing <html>…</html> wrapper"


DISPATCH = {
    ".py": check_py, ".json": check_json, ".sh": check_sh, ".bash": check_sh,
    ".md": check_md, ".markdown": check_md, ".html": check_html, ".htm": check_html,
}
MARK = {"CLEAN": "✓", "ISSUE": "✗", "SKIP": "–", "MISSING": "✗"}


def main(argv):
    git_dir = None
    as_json = "--json" in argv
    if "--git" in argv:
        i = argv.index("--git")
        git_dir = argv[i + 1] if i + 1 < len(argv) else None
    skip = {"--json", "--git", git_dir}
    files = [a for a in argv if a not in skip and not a.startswith("--")]

    rows, bad, skipped = [], 0, 0
    for f in files:
        if not os.path.isfile(f):
            rows.append({"file": f, "status": "MISSING", "detail": "file not found"}); bad += 1; continue
        ext = os.path.splitext(f)[1].lower()
        fn = DISPATCH.get(ext)
        if not fn:
            rows.append({"file": f, "status": "SKIP", "detail": f"no checker for '{ext or 'no-ext'}'"}); skipped += 1; continue
        try:
            ok, msg = fn(f)
        except Exception as e:
            ok, msg = False, f"checker error: {e}"
        rows.append({"file": f, "status": "CLEAN" if ok else "ISSUE", "detail": msg})
        if not ok:
            bad += 1

    git_lines = []
    if git_dir and os.path.isdir(git_dir):
        r = subprocess.run(["git", "-C", git_dir, "status", "--porcelain"], capture_output=True, text=True)
        git_lines = [l for l in r.stdout.splitlines() if l.strip()]

    clean = len(files) - bad - skipped
    summary = {"total": len(files), "clean": clean, "issues": bad, "skipped": skipped,
               "all_clean": bad == 0, "rows": rows,
               "git_dir": git_dir, "git_uncommitted": git_lines}

    if as_json:
        print(json.dumps(summary, indent=2))
        return 1 if bad else 0

    print(f"FILE HYGIENE — {len(files)} file(s): {clean} clean, {bad} issue(s), {skipped} skipped")
    for r in rows:
        print(f"  {MARK[r['status']]} {r['status']:7} {os.path.basename(r['file'])} — {r['detail']}")
    if git_dir:
        print(f"git ({git_dir}): {len(git_lines)} uncommitted change(s)")
        for l in git_lines[:30]:
            print(f"    {l}")
    print("RESULT:", "ALL CLEAN" if bad == 0 else f"{bad} ISSUE(S) — fix or list as a loose thread")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
