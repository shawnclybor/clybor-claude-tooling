#!/usr/bin/env python3
"""check-send-text.py — PreToolUse hook: block Gmail and Notion writes that claim something was settled
(agreed, confirmed, approved, decided, ...) without citing the evidence on the same line.

Why (2026-11-05): a proposal was recorded as "agreed" in a Notion task title and a working doc. The
draft checker (check-draft.py) only sees files, and emails and Notion pages are written straight into a
tool call, so this runs the same settled-word check on the tool call itself.

Wire it on PreToolUse with a matcher for the write tools, for example:
  mcp__claude_ai_Gmail__(create_draft|update_draft|send_message|reply|forward)|mcp__notion__notion-(create-pages|update-page)
Collects every string in tool_input and checks it line by line. A line passes when the word is negated
("not yet confirmed") or the line cites a message ID (16 hex), a file path, a link or a § reference.
Notion and other internal writes are denied until cited. Gmail writes are never denied for this: the user
is asked to confirm, so no IDs or markers end up in client email. A crash allows the call with a stderr warning: this is
a backstop, and the draft-check router row still applies.
"""
import importlib.util
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


ZERO_WIDTH = re.compile("[​-‍⁠﻿]")


def strings(obj, key=""):
    """Every string that will be written. Skips the text being replaced (old_str) and one-word field
    values such as a Status of "Decided" (chaos review 2026-11-05)."""
    if isinstance(obj, str):
        if key != "old_str" and len(obj.split()) > 1:
            yield obj
    elif isinstance(obj, dict):
        for k, v in obj.items():
            yield from strings(v, k)
    elif isinstance(obj, list):
        for v in obj:
            yield from strings(v, key)


def main():
    data = json.load(sys.stdin)
    spec = importlib.util.spec_from_file_location("cd", os.path.join(HERE, "check-draft.py"))
    cd = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cd)
    bad = []
    for s in strings(data.get("tool_input") or {}):
        for line in ZERO_WIDTH.sub("", s).split("\n"):
            if line.lstrip().startswith(">"):  # quoted history in a reply or forward
                continue
            for m in cd.SETTLED.finditer(line):
                if cd.NEGATED.search(line[:m.start()]) or cd.CITED.search(line):
                    continue
                bad.append(f'"{m.group(0)}" in: {line.strip()[:120]}')
                break
    if bad:
        # Email goes to the client: never force IDs or markers into it. Ask the user instead (side-agent
        # review 2026-11-05). Internal records (Notion) are blocked until the line cites its evidence.
        email = "gmail" in (data.get("tool_name") or "").lower()
        decision = "ask" if email else "deny"
        fix = ("Confirm each claim is settled in a message you can point to, or reword it (proposed, pending)."
               if email else
               "Cite the message ID, file or link on that line, or reword it (proposed, pending, not yet confirmed).")
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse", "permissionDecision": decision,
            "permissionDecisionReason": f"check-send-text: settled-sounding claim with no evidence. {fix} "
            + " | ".join(bad[:5])}}))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(f"check-send-text: internal error, call allowed: {e}", file=sys.stderr)
        sys.exit(0)
