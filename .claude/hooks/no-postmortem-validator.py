#!/usr/bin/env python3
"""
HOOK: no-postmortem-validator.py
TRIGGER: PreToolUse on Edit|Write|MultiEdit
PURPOSE: BLOCK post-mortem / tombstone prose from landing in operational
         artifacts (skills, plans, specs, runbooks, manifests). Replaces the
         advisory no-postmortem-reminder.py — this one DENIES the write via JSON
         permissionDecision, so it cannot be walked past. Honor-system gates fail;
         this is the codified gate.

SCOPE: Every markdown file in the repo — CLAUDE.md, ROADMAP.md, docs/,
       workstreams/, knowledge/wiki/, .claude/. Code files are out of scope
       (validate-code-write.py); running logs, raw captures and audit docs are
       exempt (EXEMPT_PATHS + PROVENANCE_HINTS).

OVERRIDE (conscious, never silent):
  - the file name signals provenance (audit/postmortem/changelog/history/...), OR
  - the content carries the literal marker:  <!-- postmortem-ok -->

TIERS:
  - BLOCK (deny): unambiguous tombstones + manifest-cell removal-rationale essays.
  - WARN  (stderr, non-blocking): softer diff-against-the-past phrasing.

Rule of thumb: state things as they ARE, not as a diff against what they were.
Rationale for cuts belongs in the COMMIT MESSAGE, not the artifact.

EXIT CODES:
  0 — always (block is signalled via JSON deny, not exit code)
"""
import json
import re
import sys

# Scope is EVERY markdown file in the repo. Prose lands in docs/, workstreams/,
# ROADMAP.md and CLAUDE.md far more often than in .claude/ — an allowlist there
# left the loudest surfaces ungated. Exemptions below, plus the name-based
# PROVENANCE_HINTS and the inline override marker.
EXEMPT_PATHS = (
    "/knowledge/log.md",    # append-only running log — diff-against-past is its job
    "/knowledge/raw/",      # unedited captures
    "/docs/reference/",     # client source converted verbatim — not our prose to police
    "/node_modules/", "/.git/", "/_archived/",
)
PROVENANCE_HINTS = (
    "postmortem", "post-mortem", "post_mortem", "audit", "changelog",
    "change-log", "session-log", "session_log", "history", "decision-log",
    "provenance",
)
OVERRIDE_MARKER = "<!-- postmortem-ok -->"

# --- BLOCK tier: unambiguous tombstones (case-insensitive) ---
BLOCK_PATTERNS = [
    (r"\bformerly\b", "tombstone: 'formerly'"),
    (r"\bwas previously known as\b", "tombstone: 'was previously known as'"),
    (r"\bused to (be|have|read|live|do)\b", "tombstone: 'used to ...'"),
    (r"\bcut[-\s]20\d\d[-\s]\d\d", "tombstone: 'Cut-YYYY-MM-DD'"),
    (r"~~[^~\n]+~~", "strikethrough (~~...~~)"),
    (r"\bresolved on:?\s*20?\d\d", "post-mortem: 'RESOLVED on <date>'"),
    (r"three reviewers? converged", "review-narration: 'three reviewers converged'"),
    (r"\bpost-(adversarial-review|kiss-review|kiss|chaos-review|review)\b",
     "review-narration: 'post-<review>'"),
    (r"\bai cosplay\b", "meta-narration: 'AI cosplay'"),
    (r"(?m)^#{1,6}\s.*\b(what changed|changes made|what(?:'s| was| we) (?:cut|fixed|removed|added)"
     r"|before\s*(?:/|and|→|vs\.?)\s*after|summary of changes)\b",
     "change-narration heading"),
    (r"\bupdated to reflect\b", "change-narration: 'updated to reflect'"),
    (r"\breplaces the (previous|old|former|prior)\b", "tombstone: 'replaces the previous ...'"),
    (r"\bthis (?:doc|file|section) (?:now|previously)\b", "self-narration: 'this doc now/previously ...'"),
]

# Case-SENSITIVE gravestone heading, e.g. '## Spec Xy — REMOVED'
REMOVED_HEADING = re.compile(r"(?m)^#{1,6}\s.*\bREMOVED\b")

# Removal-rationale essay fragments that read as post-mortem ANYWHERE they appear.
BLOCK_FRAGMENTS_ANYWHERE = [
    r"r[io]de in via",
    r"scrubbed post-?checkout",
    r"near-useless",
    r"nothing invokes it",
    r"what was cut",
    r"\btombstone\b",
]
# Fragments that are fine in prose but signal an essay when stuffed into a
# markdown TABLE cell (manifests/spec tables must stay terse).
BLOCK_FRAGMENTS_TABLE = [
    "redundant with",
    "unrunnable without",
    "orphan (",
    "authoring-scope",
    "not the operational run path",
]

# --- WARN tier: softer signals (non-blocking) ---
WARN_PATTERNS = [
    (r"\bno longer\b", "'no longer ...'"),
    (r"\bpreviously\b", "'previously'"),
    (r"\bsuperseded\b", "'superseded'"),
    (r"\bdeprecated\b", "'deprecated'"),
    (r"\(retired\b", "'(retired ...)'"),
    (r"\bgoing forward\b", "ceremonial: 'going forward'"),
    (r"\bas of (today|this writing)\b", "ceremonial: 'as of today'"),
]


def extract_content(tool_name, tool_input):
    if tool_name == "Write":
        return tool_input.get("content", "") or ""
    if tool_name == "Edit":
        return tool_input.get("new_string", "") or ""
    if tool_name == "MultiEdit":
        return "\n".join(
            (e.get("new_string", "") or "") for e in tool_input.get("edits", [])
        )
    return ""


def in_scope(file_path):
    p = file_path.replace("\\", "/").lower()
    return p.endswith(".md") and not any(d in p for d in EXEMPT_PATHS)


def find_hits(content):
    hits = []
    for pat, label in BLOCK_PATTERNS:
        m = re.search(pat, content, re.IGNORECASE)
        if m:
            hits.append(f"{label} → \"{m.group(0)[:60].strip()}\"")

    mh = REMOVED_HEADING.search(content)
    if mh:
        hits.append(f"gravestone heading → \"{mh.group(0)[:60].strip()}\"")

    for frag in BLOCK_FRAGMENTS_ANYWHERE:
        m = re.search(frag, content, re.IGNORECASE)
        if m:
            hits.append(f"removal-rationale prose → \"{m.group(0)[:60].strip()}\"")

    for line in content.splitlines():
        if line.lstrip().startswith("|"):
            low = line.lower()
            for frag in BLOCK_FRAGMENTS_TABLE:
                if frag in low:
                    hits.append(f"manifest-cell rationale essay → \"{frag}\"")
    # dedupe, preserve order
    return list(dict.fromkeys(hits))


def main():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    tool_name = data.get("tool_name", "")
    if tool_name not in ("Edit", "Write", "MultiEdit"):
        sys.exit(0)

    tool_input = data.get("tool_input", {})
    file_path = tool_input.get("file_path", "")
    if not in_scope(file_path):
        sys.exit(0)
    if any(h in file_path.lower() for h in PROVENANCE_HINTS):
        sys.exit(0)

    content = extract_content(tool_name, tool_input)
    if not content or OVERRIDE_MARKER in content:
        sys.exit(0)

    hits = find_hits(content)
    if hits:
        reason = (
            "BLOCKED — post-mortem / tombstone prose in an operational artifact:\n  - "
            + "\n  - ".join(hits)
            + "\n\nState things as they ARE, not as a diff against what they were. "
            "Rationale for cuts goes in the COMMIT MESSAGE, not the doc.\n"
            "Genuine audit/provenance doc? Name it *-audit.md / *-postmortem.md, "
            "or add the line  <!-- postmortem-ok -->  to consciously override."
        )
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }
        }))
        sys.exit(0)

    warns = []
    for pat, label in WARN_PATTERNS:
        m = re.search(pat, content, re.IGNORECASE)
        if m:
            warns.append(f"{label} → \"{m.group(0)[:40].strip()}\"")
    if warns:
        print(
            "[no-postmortem] soft signals (not blocked — check for tombstone framing):\n  - "
            + "\n  - ".join(warns),
            file=sys.stderr,
        )
    sys.exit(0)


if __name__ == "__main__":
    main()
