#!/usr/bin/env python3
"""scrub.py — deterministic PII scrubber for harvested assets.

Usage: python3 scripts/scrub.py <file> [<file> ...]

Replaces, in place:
  - denylist terms (scripts/denylist.local.json) with the class's {{TOKEN}}
    or neutral text, per the "replace" field
  - regex classes: UUIDs/32-hex -> {{RECORD_ID}}, IPv4 -> {{SERVER_IP}},
    email -> {{CONTACT_EMAIL}}, /Users/<name> -> {{HOME}}

Idempotent: replacement tokens contain no scannable PII, so a second run
is a no-op. Run verify-clean.py afterward — scrub catches the known list;
verify is the gate.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DENYLIST = os.path.join(ROOT, "scripts", "denylist.local.json")

REGEX_REPLACEMENTS = [
    (re.compile(r"\b[0-9a-f]{8}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{12}\b", re.I), "{{RECORD_ID}}"),
    (re.compile(r"\b(?:(?:\d{1,3}\.){3}\d{1,3})\b(?<!0\.0\.0\.0)(?<!127\.0\.0\.1)"), "{{SERVER_IP}}"),
    (re.compile(r"\b[\w.+-]+@[\w-]+\.[\w.]+\b"), "{{CONTACT_EMAIL}}"),
    (re.compile(r"/Users/[a-z][a-z0-9_-]*", re.I), "{{HOME}}"),
]


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    deny = json.load(open(DENYLIST)) if os.path.exists(DENYLIST) else {}
    rc = 0
    for path in sys.argv[1:]:
        text = orig = open(path, encoding="utf-8").read()
        for cls, terms in deny.items():
            token = cls.upper().replace("-", "_")
            for term in sorted(terms, key=len, reverse=True):
                text = re.sub(re.escape(term), "{{%s}}" % token, text, flags=re.I)
        for rx, repl in REGEX_REPLACEMENTS:
            text = rx.sub(repl, text)
        if text != orig:
            open(path, "w", encoding="utf-8").write(text)
            print(f"scrubbed: {path}")
        else:
            print(f"no-op:    {path}")
    return rc


if __name__ == "__main__":
    sys.exit(main())
