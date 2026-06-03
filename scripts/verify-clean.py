#!/usr/bin/env python3
"""verify-clean.py — PII + undeclared-token gate for the tooling catalog.

Scans assets/ (default) or --target <dir> for:
  1. Denylist terms (scripts/denylist.local.json — gitignored, never ships)
  2. Regex PII classes: UUID/32-hex identifiers, IPv4, email, /Users/<name> paths
  3. Token mode: any {{TOKEN}} not declared in that asset's catalog.json
     adaptation_points. Enforced only when catalog.json exists; absent
     (Stage B) -> WARN + exit 0 for tokens, PII still enforced.

Exit 0 = clean. Exit 1 = findings (printed file:line). Used as pre-commit hook.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DENYLIST = os.path.join(ROOT, "scripts", "denylist.local.json")
CATALOG = os.path.join(ROOT, "catalog.json")

REGEX_CLASSES = {
    "uuid/hex-id": re.compile(r"\b[0-9a-f]{8}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{12}\b", re.I),
    "ipv4": re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b"),
    "email": re.compile(r"\b[\w.+-]+@[\w-]+\.[\w.]+\b"),
    "user-path": re.compile(r"/Users/[a-z][a-z0-9_-]*", re.I),
}
TOKEN_RE = re.compile(r"\{\{([A-Z0-9_]+)\}\}")
SKIP_IPV4 = {"0.0.0.0", "127.0.0.1", "1.0.0", "0.1.0"}  # version-string lookalikes


def load_denylist():
    if not os.path.exists(DENYLIST):
        print(f"WARN: denylist not found at {DENYLIST} — denylist pass skipped")
        return {}
    raw = json.load(open(DENYLIST))
    # keep only list-valued classes; "_comment" and other metadata keys are not term lists
    return {k: v for k, v in raw.items() if isinstance(v, list) and not k.startswith("_")}


def load_declared_tokens():
    """asset-id -> set of declared tokens; None if catalog absent."""
    if not os.path.exists(CATALOG):
        return None
    cat = json.load(open(CATALOG))
    return {a["id"]: {t.strip("{}") for t in a.get("adaptation_points", [])} for a in cat.get("assets", [])}


def asset_id_for(path, target):
    rel = os.path.relpath(path, target)
    parts = rel.split(os.sep)
    if len(parts) >= 2 and parts[0] == "skills":
        return parts[1]
    return None


def scan_file(path, denylist, declared, target):
    findings = []
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except (OSError, UnicodeError) as e:
        return [(path, 0, f"unreadable: {e}")]
    aid = asset_id_for(path, target)
    for n, line in enumerate(text.split("\n"), 1):
        for cls, terms in denylist.items():
            for term in terms:
                if term.lower() in line.lower():
                    findings.append((path, n, f"denylist[{cls}]: {term}"))
        for cls, rx in REGEX_CLASSES.items():
            for m in rx.finditer(line):
                if cls == "ipv4" and m.group(0) in SKIP_IPV4:
                    continue
                findings.append((path, n, f"regex[{cls}]: {m.group(0)}"))
        if declared is not None and aid is not None:
            for m in TOKEN_RE.finditer(line):
                if m.group(1) not in declared.get(aid, set()):
                    findings.append((path, n, f"undeclared-token: {{{{{m.group(1)}}}}} not in {aid} adaptation_points"))
    return findings


def main():
    target = os.path.join(ROOT, "assets")
    args = sys.argv[1:]
    if "--target" in args:
        target = os.path.abspath(args[args.index("--target") + 1])
    if not os.path.isdir(target):
        print(f"clean: target {target} does not exist or is empty")
        return 0
    denylist = load_denylist()
    declared = load_declared_tokens()
    token_note = ""
    if declared is None:
        token_note = "WARN: catalog.json absent — token declarations not enforced this run"
    findings = []
    for dirpath, _dirnames, filenames in os.walk(target):
        for fn in filenames:
            if fn == ".DS_Store" or fn.endswith((".zip", ".plugin", ".png", ".jpg")):
                continue
            findings.extend(scan_file(os.path.join(dirpath, fn), denylist, declared, target))
    if token_note:
        print(token_note)
    if findings:
        for path, n, msg in findings:
            print(f"FAIL {os.path.relpath(path, ROOT)}:{n}  {msg}")
        print(f"\n{len(findings)} finding(s). Tree is NOT clean.")
        return 1
    print(f"clean: {target} (denylist {'on' if denylist else 'OFF'}, tokens {'on' if declared is not None else 'warn-only'})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
