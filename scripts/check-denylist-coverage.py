#!/usr/bin/env python3
"""check-denylist-coverage.py — fail when a client in the life-crm registry is missing from the blocklist.

  python3 scripts/check-denylist-coverage.py [--registry DIR] [--denylist FILE]

Why (2026-11-05): a client repo name reached this public repo because the blocklist only held longer
phrases ("Acme Analytics"), not the bare name ("Acme"). The clean gate (verify-clean.py) is only as good as its list.
This checks the list itself: every client named in a registry heading ("### Client (Person) -- Project",
"### A / B -- Project") must appear in the blocklist's client or person terms.

Defaults: ~/gits/life-crm/docs/registry and scripts/denylist.local.json. Headings that are not clients
(internal workstreams) are skipped via the INTERNAL set below.
Exit 0 = covered. 1 = names missing (printed). 2 = a file is missing.
"""
import argparse
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
INTERNAL = {"2025 dutch tax filing", "business development", "clybor consulting", "workspace tools & assets"}


def names(heading):
    h = re.sub(r"^#+\s*", "", heading).split(" -- ")[0]
    found = []
    for part in h.split(" / "):
        person = re.search(r"\(([^)]+)\)", part)
        base = re.sub(r"\([^)]*\)", "", part).strip()
        if base and base.lower() not in INTERNAL:
            found.append(base)
        if person and base.lower() not in INTERNAL:
            found += [p.split(",")[0].strip() for p in person.group(1).split("/") if p.strip()]
    return [n for n in found if n.lower() not in INTERNAL]


def main(argv):
    ap = argparse.ArgumentParser(description="Every registry client must be on the blocklist.")
    ap.add_argument("--registry", default=os.path.expanduser("~/gits/life-crm/docs/registry"))
    ap.add_argument("--denylist", default=os.path.join(HERE, "denylist.local.json"))
    a = ap.parse_args(argv)
    if not os.path.isdir(a.registry) or not os.path.isfile(a.denylist):
        print(f"check-denylist-coverage: missing {a.registry if not os.path.isdir(a.registry) else a.denylist}")
        return 2
    d = json.load(open(a.denylist))
    terms = [t for k in ("client", "person") for t in d.get(k, []) if t.strip()]

    def caught(name):
        # The scanner's own rule (verify-clean.py NAME_CLASSES): a term matches on word boundaries. Covered
        # means the scanner would flag the bare name, not that the name sits inside some longer term
        # (chaos review 2026-11-05: "Acme" passed against "Acme Corp Holdings").
        low = name.lower()
        for t in terms:
            lead = r"\b" if t[:1].isalnum() else ""
            trail = r"\b" if t[-1:].isalnum() else ""
            if re.search(lead + re.escape(t.lower()) + trail, low):
                return True
        return False

    missing = []
    for f in sorted(glob.glob(os.path.join(a.registry, "*.md"))):
        heads = [l for l in open(f, encoding="utf-8") if re.match(r"#{2,3} ", l)]  # every client heading
        for n in (x for h in heads for x in names(h)):
            if not caught(n):
                missing.append((os.path.basename(f), n))
    for f, n in missing:
        print(f"MISSING {n!r}  (from {f})")
    print(f"check-denylist-coverage: {len(missing)} registry name(s) missing from the blocklist")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
