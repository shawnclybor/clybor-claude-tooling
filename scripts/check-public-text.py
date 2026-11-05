#!/usr/bin/env python3
"""check-public-text.py — PreToolUse hook (Bash): block client names in PR, issue, release and comment text
bound for a PUBLIC GitHub repo.

Why (2026-11-05): a PR description on the public tooling repo named a client engagement. The commit gate
(verify-clean.py --staged) scans staged files only; text passed to gh never touches git, and GitHub keeps
every revision of it even after an edit.

Fires only where `gh` starts a command (line start, or after ; & | ( or an env/cd prefix) and the command is
`gh [global flags] pr|issue|release create|edit|comment`, or `gh api` with a body field. Scans only what is
published: --title/--body/--notes values (also the --x=value form), --body-file/--notes-file/--input files
(~ and $VARS expanded), files named in "$(cat FILE)", and gh api -f/-F/--field/--raw-field values.
Text it cannot read (stdin "-", an unknown substitution) is denied: say where the text is, or pass a file.
The target repo is -R/--repo, else the origin of the directory the command cd's into, else the hook's cwd.
A fork whose parent is public counts as public (gh pr create targets the parent by default).
Unknown visibility on a matching command is denied (fail closed). A crash blocks only matching commands.
Test hooks: PUBLIC_TEXT_VISIBILITY=PUBLIC|PRIVATE skips GitHub; PUBLIC_TEXT_DENYLIST=<file>.
"""
import importlib.util
import json
import os
import re
import shlex
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
START = r"(?:^|[;&|(]|&&|\|\|)\s*(?:cd\s+\S+\s*&&\s*)?(?:\w+=\S+\s+)*"
TRIGGER = re.compile(START + r"gh(?:\s+-{1,2}[\w-]+(?:[ =](?!pr\b|issue\b|release\b|api\b)\S+)?)*\s+"
                     r"(?:(?:pr|issue|release)\s+(?:create|edit|comment)\b|api\b)", re.M)
TEXT_FLAGS = {"--title", "-t", "--body", "-b", "--notes", "-n"}
FILE_FLAGS = {"--body-file", "-F", "--notes-file", "--input"}
API_FIELDS = {"-f", "--raw-field", "--field"}
ZERO_WIDTH = re.compile("[​-‍⁠﻿]")


def deny(reason):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny",
                                             "permissionDecisionReason": reason}}))
    return 0


def run(args, timeout=20):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ""


def target_repo(cmd, cwd):
    m = re.search(r"\bgh\s+api\s+(?:-\S+\s+)*/?repos/([\w.-]+/[\w.-]+)", cmd)
    if m:
        return m.group(1)
    m = re.search(r"(?:-R|--repo)[ =](\S+)", cmd)
    if m:
        segs = m.group(1).strip("'\"").rstrip("/").split("/")
        return "/".join(segs[-2:]) if len(segs) >= 2 else None
    m = re.search(r"\bcd\s+(\S+)\s*&&[^\n]*\bgh\b", cmd)
    d = os.path.expanduser(os.path.expandvars(m.group(1).strip("'\""))) if m else cwd
    d = d if os.path.isabs(d) else os.path.join(cwd, d)
    url = run(["git", "-C", d, "remote", "get-url", "origin"])
    m = re.search(r"github\.com[:/]([\w.-]+/[\w.-]+?)(?:\.git)?$", url)
    return m.group(1) if m else None


def visibility(repo):
    if os.environ.get("PUBLIC_TEXT_VISIBILITY"):
        return os.environ["PUBLIC_TEXT_VISIBILITY"]
    info = run(["gh", "repo", "view", repo, "--json", "visibility,parent"])
    try:
        j = json.loads(info)
    except ValueError:
        return None
    if j.get("visibility", "").upper() == "PUBLIC":
        return "PUBLIC"
    parent = j.get("parent") or {}
    if parent.get("name"):
        pv = run(["gh", "repo", "view", f"{parent['owner']['login']}/{parent['name']}", "--json", "visibility",
                  "-q", ".visibility"])
        if pv.upper() == "PUBLIC":
            return "PUBLIC"
    return j.get("visibility") or None


def published_text(cmd, cwd):
    """(text, unreadable-reason or None)."""
    toks = shlex.split(cmd)
    parts = []

    def read(path):
        p = os.path.expanduser(os.path.expandvars(path))
        p = p if os.path.isabs(p) else os.path.join(cwd, p)
        if path == "-" or "$" in p or not os.path.isfile(p):
            raise FileNotFoundError(path)
        return open(p, encoding="utf-8", errors="replace").read()

    def value(v):
        for sub in re.findall(r"\$\(\s*cat\s+([^)\s]+)\s*\)", v):
            parts.append(read(sub.strip("'\"")))
        if re.search(r"\$\((?!\s*cat\s)|`", v):
            raise FileNotFoundError("a command substitution in the text")
        parts.append(v)

    i = 0
    while i < len(toks):
        t = toks[i]
        key, eq, val = t.partition("=")
        nxt = toks[i + 1] if i + 1 < len(toks) else None
        if key in TEXT_FLAGS | FILE_FLAGS | API_FIELDS and (eq or nxt is not None):
            v = val if eq else nxt
            if key in FILE_FLAGS:
                parts.append(read(v))
            elif key in API_FIELDS:
                value(v.split("=", 1)[1] if "=" in v else v)
            else:
                value(v)
            i += 1 if eq else 2
            continue
        i += 1
    return "\n".join(parts)


def main(raw):
    data = json.loads(raw)
    cmd = (data.get("tool_input") or {}).get("command", "")
    if not TRIGGER.search(cmd):
        return 0
    cwd = data.get("cwd") or os.getcwd()
    repo = target_repo(cmd, cwd)
    vis = visibility(repo) if repo else None
    if vis is None:
        return deny(f"check-public-text: could not tell whether {repo or 'the target repo'} is public, so the "
                    "published text was not scanned. Retry, or name the repo with -R owner/repo.")
    if vis.upper() != "PUBLIC":
        return 0
    try:
        text = published_text(cmd, cwd)
    except (FileNotFoundError, ValueError) as e:
        return deny(f"check-public-text: {repo} is PUBLIC and the text could not be read for scanning ({e}). "
                    "Pass it with --body or --body-file <real file>.")
    text = ZERO_WIDTH.sub("", text)
    # Long single lines make the PII regexes slow: scan in 2,000-character chunks (chaos review 2026-11-05).
    chunks = "\n".join(line[i:i + 2000] for line in text.split("\n") for i in range(0, max(len(line), 1), 2000))
    spec = importlib.util.spec_from_file_location("vc", os.path.join(HERE, "verify-clean.py"))
    vc = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(vc)
    if os.environ.get("PUBLIC_TEXT_DENYLIST"):
        vc.DENYLIST = os.environ["PUBLIC_TEXT_DENYLIST"]
    tmp = os.path.join(os.environ.get("TMPDIR", "/tmp"), f"public-text-{os.getpid()}.txt")
    with open(tmp, "w") as f:
        f.write(chunks)
    try:
        hits = vc.scan_file(tmp, vc.load_denylist(), None, os.path.dirname(tmp))
    finally:
        os.remove(tmp)
    if hits:
        found = "; ".join(sorted({m for _, _, m in hits}))[:400]
        return deny(f"check-public-text: {repo} is PUBLIC and this text names something on the blocklist "
                    f"({found}). GitHub keeps every revision, so scrub it before it goes up.")
    return 0


if __name__ == "__main__":
    raw = sys.stdin.read()
    try:
        sys.exit(main(raw))
    except Exception as e:
        # Fail closed only for matching gh commands; any other Bash call must never be blocked by this hook.
        print(f"check-public-text: internal error {e}", file=sys.stderr)
        sys.exit(2 if TRIGGER.search(raw) else 0)
