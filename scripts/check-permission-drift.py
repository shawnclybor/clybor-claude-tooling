#!/usr/bin/env python3
"""Fail if any settings layer grants a tool with no specifier, and show what changed.

A bare tool name in permissions.allow ("Bash") matches EVERY use of that tool, so it
silently overrides every narrower rule beneath it. One "always allow" click writes one
permanently, with no record of when or why. This is the record.

Usage:
  check-permission-drift.py            # check, print a diff against the snapshot
  check-permission-drift.py --accept   # adopt current state as the new snapshot

Exit 0 clean, 1 on a bare grant or a missing snapshot, 2 on a malformed settings file.
"""
import json, os, sys, datetime

BARE_IS_WILDCARD = {"Bash", "Read", "Write", "Edit", "Agent", "Task", "Glob", "Grep",
                    "WebFetch", "WebSearch", "Skill", "NotebookEdit"}
SNAPSHOT = os.path.expanduser("~/.claude/permission-snapshot.json")

def layers():
    out = [("global", os.path.expanduser("~/.claude/settings.json"))]
    proj = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    out.append(("project", os.path.join(proj, ".claude", "settings.json")))
    out.append(("project-local", os.path.join(proj, ".claude", "settings.local.json")))
    return out

def read(path):
    if not os.path.exists(path):
        return None
    try:
        return json.load(open(path)).get("permissions", {}) or {}
    except (json.JSONDecodeError, OSError) as e:
        print(f"MALFORMED {path}: {e}", file=sys.stderr)
        sys.exit(2)

def is_bare(rule):
    if rule in BARE_IS_WILDCARD:
        return True
    # Tool(*) is equivalent to a bare tool name
    if rule.endswith("(*)") and rule[:-3] in BARE_IS_WILDCARD:
        return True
    return False

def current():
    state = {}
    for name, path in layers():
        p = read(path)
        if p is None:
            continue
        state[name] = {k: sorted(p.get(k, [])) for k in ("allow", "deny", "ask")}
    return state

def main():
    state = current()
    if "--accept" in sys.argv:
        json.dump({"taken": datetime.date.today().isoformat(), "state": state},
                  open(SNAPSHOT, "w"), indent=2)
        print(f"snapshot written: {SNAPSHOT}")
        return 0

    rc = 0
    # 1. the hard gate: no bare grants in allow, anywhere
    for layer, perms in state.items():
        bad = [r for r in perms.get("allow", []) if is_bare(r)]
        if bad:
            print(f"BARE GRANT in {layer} permissions.allow: {bad}")
            print(f"  A bare tool name matches every use of that tool and overrides every")
            print(f"  narrower rule below it. Remove it, or write a specifier: Bash(npm:*)")
            rc = 1

    # 2. the record: what moved since the snapshot
    if not os.path.exists(SNAPSHOT):
        print(f"NO SNAPSHOT at {SNAPSHOT} — run with --accept to start the record")
        return max(rc, 1)
    snap = json.load(open(SNAPSHOT))
    old = snap.get("state", {})
    moved = False
    for layer in sorted(set(old) | set(state)):
        for key in ("allow", "deny", "ask"):
            was = set(old.get(layer, {}).get(key, []))
            now = set(state.get(layer, {}).get(key, []))
            for r in sorted(now - was):
                print(f"ADDED   {layer}.{key}: {r}"); moved = True
            for r in sorted(was - now):
                print(f"REMOVED {layer}.{key}: {r}"); moved = True
    if not moved and rc == 0:
        print(f"clean — no bare grants, no drift since {snap.get('taken')}")
    elif moved:
        print(f"\ndrift since {snap.get('taken')}. If intended, re-run with --accept.")
    return rc

if __name__ == "__main__":
    sys.exit(main())
