#!/usr/bin/env python3
"""owed.py — what the user owes next on one Notion project, from Notion itself, not from memory.

  python3 scripts/owed.py <project-id> [--days 2] [--before YYYY-MM-DD] [--from-file saved.txt]

Why (2026-11-05): a session logged two items the user owed in Notion and never told them, and left a task
with no due date, which drops out of every "due soon" view. A report built from memory of the session
misses what the session never looked at. This prints the list the report must paste.

Runs life-crm's notion-active.py (env NOTION_ACTIVE overrides its path) and sorts the open tasks into:
  OVERDUE      due before today
  DUE SOON     due within --days (default 2), or on/before --before (e.g. the next client meeting)
  NO DATE      undated: invisible to every due-date view; give it a check-back date
Exit 0 = listed (an empty list is printed as such). 1 = Notion could not be read: never report "nothing
owed" from a failed read. 2 = bad input. --from-file parses saved notion-active output (tests, offline).
"""
import argparse
import datetime
import os
import subprocess
import sys

DEFAULT = os.path.expanduser("~/gits/life-crm/scripts/notion-active.py")


def parse(text):
    """notion-active lines: Priority | Status | Due | Title | page id."""
    rows = []
    for line in text.splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = [p.strip() for p in line.split(" | ")]
        if len(parts) < 5:
            continue
        pri, status, due, page = parts[0], parts[1], parts[2], parts[-1]
        title = " | ".join(parts[3:-1])
        try:
            d = datetime.date.fromisoformat(due[:10])
        except ValueError:
            d = None
        rows.append({"priority": pri, "status": status, "due": d, "title": title, "page": page})
    return rows


def main(argv):
    ap = argparse.ArgumentParser(description="What the user owes next on one Notion project.")
    ap.add_argument("project")
    ap.add_argument("--days", type=int, default=2)
    ap.add_argument("--before")
    ap.add_argument("--from-file")
    ap.add_argument("--today")  # tests only
    try:
        a = ap.parse_args(argv)
        today = datetime.date.fromisoformat(a.today) if a.today else datetime.date.today()
        before = datetime.date.fromisoformat(a.before) if a.before else None
    except (SystemExit, ValueError):
        return 2
    if a.from_file:
        if not os.path.isfile(a.from_file):
            print(f"owed: no such file {a.from_file}")
            return 2
        text = open(a.from_file, encoding="utf-8").read()
    else:
        script = os.environ.get("NOTION_ACTIVE", DEFAULT)
        try:
            r = subprocess.run([sys.executable, script, a.project], capture_output=True, text=True, timeout=120)
        except (OSError, subprocess.TimeoutExpired) as e:
            print(f"owed: could not run {script}: {e}. Notion NOT read — do not report 'nothing owed'.")
            return 1
        if r.returncode != 0 or not r.stdout.startswith("#"):
            print(f"owed: notion-active failed (exit {r.returncode}): {(r.stderr or r.stdout).strip()[:300]}")
            print("Notion NOT read — do not report 'nothing owed'.")
            return 1
        text = r.stdout
    rows = parse(text)
    content = [l for l in text.splitlines() if l.strip() and not l.startswith("#")]
    if content and not rows:  # output we could not parse is not "nothing owed" (chaos review 2026-11-05)
        print(f"owed: could not parse any of {len(content)} task line(s). Notion NOT read — do not report 'nothing owed'.")
        return 1
    horizon = max(today + datetime.timedelta(days=a.days), before or today)
    groups = {"OVERDUE": [], "DUE SOON": [], "NO DATE": []}
    for t in rows:
        if t["due"] is None:
            groups["NO DATE"].append(t)
        elif t["due"] < today:
            groups["OVERDUE"].append(t)
        elif t["due"] <= horizon:
            groups["DUE SOON"].append(t)
    print(f"owed: {len(rows)} open task(s); due-soon window to {horizon.isoformat()}")
    for name, ts in groups.items():
        print(f"{name}: {len(ts)}")
        for t in ts:
            due = t["due"].isoformat() if t["due"] else "no date"
            print(f"  - {due} | {t['status']} | {t['title'][:150]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
