#!/usr/bin/env python3
"""<guard-name> — PreToolUse guard. Blocks <what>, because <why>.

Contract (Claude Code command hooks):
  stdin:  the hook's JSON payload ({"tool_name": ..., "tool_input": {...}, ...})
  exit 0: allow the call
  exit 2: block the call; stderr is the reason Claude reads

Fails CLOSED: any error inside the guard, including a payload it cannot parse, blocks.
guard-resolve.sh makes the launch fail closed; this structure makes the guard itself fail
closed. Keep both.
"""
import json
import re
import sys

# What this guard protects. Keep the list explicit: a guard nobody can read is a guard
# nobody can trust.
PROTECTED = [
    re.compile(r"(^|/)\.env(\.|$)"),
]


def decide(payload):
    """Return a reason string to block, or None to allow."""
    tool = payload["tool_name"]
    args = payload.get("tool_input") or {}
    path = args.get("file_path") or args.get("path") or ""
    if tool in ("Read", "Edit", "Write", "MultiEdit") and any(rx.search(path) for rx in PROTECTED):
        return f"{path} is protected by <guard-name>."
    return None


def main():
    try:
        reason = decide(json.load(sys.stdin))
    except Exception as err:  # fail closed: a guard that cannot decide blocks
        print(f"GUARD BLOCKED: <guard-name> could not check this call ({err!r}).", file=sys.stderr)
        return 2
    if reason:
        print(f"GUARD BLOCKED: {reason}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
