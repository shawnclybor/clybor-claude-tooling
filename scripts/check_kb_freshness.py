#!/usr/bin/env python3
"""
check_kb_freshness.py — tells a session, at start, how old its knowledge base is.

WHY THIS EXISTS: on 2026-09-25 a cloud session loaded a CLAUDE.md seven weeks stale.
`main` had stopped at 2026-08-07 while ~95 commits sat on unmerged branches, so the
session was told the GTM set was "closed at seven" and the tracker was v11 — both
superseded on the branches. Nothing said so. The content was fine; the session was
simply standing on the wrong commit, and a stale file reads exactly like a current one.

WHAT IT REPORTS (report-only, never blocks):
  1. Branch drift — remote branches carrying commits this checkout lacks, whose tip is
     newer than this checkout's tip OR was active in the last DRIFT_WINDOW_DAYS. The first
     is "you are on the wrong commit"; the second is unmerged work that will go stale.
     Older abandoned branches stay quiet.
  2. ROADMAP age — days since ROADMAP.md `updated:`. It is the compact-recovery
     re-inject target, so a stale one re-teaches every fresh context.
  3. Stale wiki — knowledge/wiki articles marked `status: current` whose `updated:` is
     older than WIKI_MAX_DAYS. "Current" on a dated snapshot is the claim that misleads.

Fix path for every finding: the `kb-refresh` skill.

WHERE IT RUNS: SessionStart, via .claude/hooks/session-context.sh (--audit).

USAGE
    python3 scripts/check_kb_freshness.py --audit            # print findings only
    python3 scripts/check_kb_freshness.py --audit --no-fetch # skip `git fetch`
"""

import argparse
import datetime as dt
import glob
import os
import re
import subprocess
import sys

ROADMAP_MAX_DAYS = 7
WIKI_MAX_DAYS = 30
DRIFT_WINDOW_DAYS = 30
FETCH_TIMEOUT_S = 10
MAX_BRANCHES_SHOWN = 5

DATE_RE = re.compile(r"(\d{4}-\d{2}-\d{2})")


def git(*args, timeout=None):
    r = subprocess.run(["git", *args], capture_output=True, text=True, timeout=timeout)
    return r.stdout.strip() if r.returncode == 0 else ""


def frontmatter_field(text, field):
    """First `field: value` in the leading --- block, else the first `field:` line anywhere
    in the first 15 lines (ROADMAP.md carries a bare `updated:` line under its heading)."""
    lines = text.splitlines()
    head = lines[:15]
    if head and head[0].strip() == "---":
        for ln in head[1:]:
            if ln.strip() == "---":
                break
            if ln.startswith(f"{field}:"):
                return ln.split(":", 1)[1].strip().strip('"\'')
    for ln in head:
        if ln.startswith(f"{field}:"):
            return ln.split(":", 1)[1].strip().strip('"\'')
    return None


def age_days(value, today):
    if not value:
        return None
    m = DATE_RE.search(value)
    if not m:
        return None
    try:
        return (today - dt.date.fromisoformat(m.group(1))).days
    except ValueError:
        return None


def stale_wiki(root, today, max_days=WIKI_MAX_DAYS):
    out = []
    for path in sorted(glob.glob(os.path.join(root, "knowledge", "wiki", "*.md"))):
        text = open(path, encoding="utf-8").read()
        if (frontmatter_field(text, "status") or "") != "current":
            continue
        days = age_days(frontmatter_field(text, "updated"), today)
        if days is not None and days > max_days:
            out.append((os.path.basename(path), days))
    return out


def roadmap_age(root, today):
    path = os.path.join(root, "ROADMAP.md")
    if not os.path.exists(path):
        return None
    return age_days(frontmatter_field(open(path, encoding="utf-8").read(), "updated"), today)


def branch_drift(today, fetch=True, window_days=DRIFT_WINDOW_DAYS):
    """Remote branches with commits HEAD lacks, whose tip is newer than HEAD's tip or
    falls inside the recent window."""
    if fetch:
        try:
            git("fetch", "--quiet", "origin", timeout=FETCH_TIMEOUT_S)
        except subprocess.TimeoutExpired:
            pass  # offline or slow: fall back to the refs already present
    head_ts = git("log", "-1", "--format=%ct")
    if not head_ts:
        return []
    head_ts = int(head_ts)
    cutoff = today - dt.timedelta(days=window_days)
    refs = git("for-each-ref", "--format=%(refname:short) %(committerdate:unix)",
               "refs/remotes/origin/").splitlines()
    out = []
    for line in refs:
        name, _, ts = line.rpartition(" ")
        if not name or name.endswith("/HEAD") or not ts.isdigit():
            continue
        tip_day = dt.datetime.fromtimestamp(int(ts), dt.timezone.utc).date()
        if int(ts) <= head_ts and tip_day < cutoff:
            continue
        ahead = git("rev-list", "--count", f"HEAD..{name}")
        if ahead.isdigit() and int(ahead) > 0:
            out.append((name, int(ahead), int(ts)))
    return sorted(out, key=lambda b: -b[2])


def report(root, today, fetch=True):
    lines = []
    drift = branch_drift(today, fetch)
    if drift:
        head = git("rev-parse", "--abbrev-ref", "HEAD") or "HEAD"
        lines.append(f"⚠ Recent work on other branches is NOT in this checkout ({head}) — "
                     "CLAUDE.md, ROADMAP and wiki here may be stale or incomplete:")
        for name, ahead, ts in drift[:MAX_BRANCHES_SHOWN]:
            when = dt.datetime.fromtimestamp(ts, dt.timezone.utc).date().isoformat()
            lines.append(f"    - {name}: {ahead} commits not here, tip {when}")
        if len(drift) > MAX_BRANCHES_SHOWN:
            lines.append(f"    - …and {len(drift) - MAX_BRANCHES_SHOWN} more")
    days = roadmap_age(root, today)
    if days is not None and days > ROADMAP_MAX_DAYS:
        lines.append(f"⚠ ROADMAP.md `updated:` is {days} days old (limit {ROADMAP_MAX_DAYS}).")
    wiki = stale_wiki(root, today)
    if wiki:
        lines.append(f"⚠ {len(wiki)} wiki article(s) say `status: current` but are older than "
                     f"{WIKI_MAX_DAYS} days:")
        lines += [f"    - {name} ({d} days)" for name, d in wiki]
    if lines:
        lines.insert(0, "### Knowledge-base freshness")
        lines.append("  Fix: run the `kb-refresh` skill before relying on these facts.")
    return lines


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--audit", action="store_true", help="print findings only (default)")
    ap.add_argument("--no-fetch", action="store_true", help="skip git fetch")
    a = ap.parse_args()
    root = git("rev-parse", "--show-toplevel") or os.getcwd()
    out = report(root, dt.date.today(), fetch=not a.no_fetch)
    if out:
        print("\n".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
