#!/usr/bin/env python3
"""
HOOK: no-postmortem-validator.py
TRIGGER: PreToolUse on Edit|Write|MultiEdit
PURPOSE: BLOCK post-mortem / tombstone prose from landing in operational
         artifacts (skills, plans, specs, runbooks, manifests). Replaces the
         advisory no-postmortem-reminder.py — this one DENIES the write via JSON
         permissionDecision, so it cannot be walked past. Honor-system gates fail;
         this is the codified gate.

SCOPE: Two surfaces.
       MD   — every markdown file in the repo: CLAUDE.md, ROADMAP.md, docs/,
              workstreams/, knowledge/wiki/, .claude/. The whole file is prose.
       CODE — the COMMENTS and DOCSTRINGS of every file in CODE_EXTS. A string
              literal is data the program carries, not prose about the program,
              so literals are never scanned; a refusal message quoting the word
              "formerly" is a value, and passes.
       Running logs, raw captures and audit docs are exempt (EXEMPT_PATHS +
       PROVENANCE_HINTS).

OVERRIDE (conscious, never silent):
  - the file name signals provenance (audit/postmortem/changelog/history/...), OR
  - the content carries the literal token:  postmortem-ok
    (as `<!-- postmortem-ok -->` in markdown, or bare in a code comment)

TIERS:
  - BLOCK (deny): unambiguous tombstones + manifest-cell removal-rationale essays.
  - WARN  (stderr, non-blocking): softer diff-against-the-past phrasing.

Rule of thumb: state things as they ARE, not as a diff against what they were.
A comment says what the code DOES; the reason for a change belongs in the
COMMIT MESSAGE, not in the file the change touched.

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
    # A build_state memory is a DATED LOG, not a spec. It records what was measured WHEN,
    # including the entries a later one supersedes and the reasoning behind a cut — which is
    # the value of a memory and the opposite of what forward-only prose asks for. Same warrant
    # as knowledge/log.md above. Other memories stay in scope; they ARE specs.
    "/.serena/memories/yellow_sheet/build_state.md",
    "/knowledge/raw/",      # unedited captures
    "/docs/reference/",     # client source converted verbatim — not our prose to police
    "/node_modules/", "/.git/", "/_archived/",
)
PROVENANCE_HINTS = (
    "postmortem", "post-mortem", "post_mortem", "audit", "changelog",
    "change-log", "session-log", "session_log", "history", "decision-log",
    "provenance",
)
# The bare token, so ONE marker serves both surfaces: `<!-- postmortem-ok -->`
# in markdown contains it, and a code comment can carry it without HTML.
OVERRIDE_MARKER = "postmortem-ok"

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
    (r"\bno longer\b(?!\s+than)", "'no longer ...'"),
    (r"\bpreviously\b", "'previously'"),
    (r"\bsuperseded\b", "'superseded'"),
    (r"\bdeprecated\b", "'deprecated'"),
    (r"\(retired\b", "'(retired ...)'"),
    (r"\bgoing forward\b", "ceremonial: 'going forward'"),
    (r"\bas of (today|this writing)\b", "ceremonial: 'as of today'"),
]


# --- CODE surface -----------------------------------------------------------
CODE_EXTS = (
    ".py", ".pyi", ".sh", ".bash", ".zsh", ".js", ".mjs", ".cjs", ".jsx",
    ".ts", ".tsx", ".rb", ".go", ".rs", ".java", ".kt", ".swift", ".scala",
    ".c", ".h", ".cc", ".cpp", ".hpp", ".cs", ".php", ".pl", ".lua", ".r",
    ".sql", ".yml", ".yaml", ".toml", ".ini", ".cfg", ".tf",
)
COMMENT_LEADERS = ("#", "//")
SQL_LIKE = (".sql", ".lua")

# Tombstones as they appear in CODE comments. Each carries its own flags, because
# an absence-announcement is only a tombstone when it SHOUTS -- lowercase "no such
# column" is ordinary prose about the present.
CODE_BLOCK_PATTERNS = [
    # "no longer than 40 chars" is a bound, not a tombstone.
    (r"\bno longer\b(?!\s+than)", "tombstone: 'no longer ...'", re.I),
    (r"\b(?:was|were|had)\s+previously\b"
     r"|\bpreviously\s+(?:was|were|had|held|read|lived|carried|printed|returned|named|called)\b",
     "tombstone: 'previously ...'", re.I),
    # The past-habitual senses only. "the regex used to match the header" is a
    # PURPOSE clause about code that exists, and stays legal.
    (r"\bused to\s+(?:be|hold|carry|sit|say|print|return|mean|name|contain"
     r"|occupy|point|go|come|live|read|exist|have)\b",
     "tombstone: 'used to ...'", re.I),
    (r"\bthe (?:old|previous|former|prior)\s+"
     r"(?:behaviou?r|version|code|implementation|rule|column|name|field|shape"
     r"|form|path|check|gate|header|key)\b",
     "tombstone: 'the <old> <thing>'", re.I),
    (r"\bwe (?:dropped|removed|deleted|cut|renamed|moved|replaced)\b",
     "change-narration: 'we <verb>ed ...'", re.I),
    (r"\basked (?:for |to have )?(?:it|them|this|that|[^.\n]{1,40}?)\s+off\b",
     "decision-narration: 'asked for it off ...'", re.I),
    # An announced ABSENCE is a diff against a state where the thing was present.
    (r"(?m)^\W*NO\s+[`'\"]?[\w #()&/.-]{2,40}[`'\"]?\s+"
     r"(?:COLUMN|FIELD|TAB|KEY|ROW|CELL|SECTION|SHEET|FLAG|ARG)\b",
     "absence-announcement: 'NO <thing> COLUMN'", 0),
    # The markdown heading form with its '#' already stripped as a comment leader.
    (r"(?m)^\W*(?:what changed|changes made"
     r"|what(?:'s| was| we) (?:cut|fixed|removed|added)"
     r"|before\s*(?:/|and|→|vs\.?)\s*after|summary of changes)\b",
     "change-narration heading", re.I),
]

# A fragment carrying none of this is prose, not code -- which is how an Edit
# landing INSIDE a docstring is still read as prose despite showing no delimiter.
CODE_SHAPE = re.compile(
    r"(?m)^\s*(?:def|class|import|from|return|if|for|while|with|try|except"
    r"|elif|else|fi|done|esac|function)\b"
    r"|[=;{}]|\(\)|\)\s*:\s*$|^\s*[\w.]+\(",
)
TRIPLE = re.compile(r'"""|\'\'\'')


def comment_text(line, leaders):
    """The comment on `line`, or ''. Quote-aware: a leader inside a string
    literal is part of a value, and a value is not prose about the program."""
    quote, i, n = None, 0, len(line)
    while i < n:
        ch = line[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
            continue
        if ch in "\"'":
            quote = ch
            i += 1
            continue
        for lead in leaders:
            if line.startswith(lead, i):
                return line[i + len(lead):]
        i += 1
    return ""


def code_prose(content, ext="", fallback=True):
    """Every comment and docstring in `content`, joined. Nothing else.

    `fallback` reads a delimiter-less fragment as prose (an Edit landing inside a
    docstring). A diff hunk sets it False: added lines carrying only string data
    have no delimiters either, and they are values rather than prose."""
    leaders = COMMENT_LEADERS + (("--",) if ext in SQL_LIKE else ())
    out, in_doc = [], False
    for line in content.splitlines():
        marks = TRIPLE.findall(line)
        if in_doc:
            out.append(TRIPLE.split(line)[0] if marks else line)
            if len(marks) % 2:
                in_doc = False
            continue
        if marks:
            parts = TRIPLE.split(line)
            out.extend(parts[1:])
            if len(marks) % 2:
                in_doc = True
            continue
        c = comment_text(line, leaders)
        if c:
            out.append(c)
    if fallback and not out and not CODE_SHAPE.search(content):
        return content          # an edit landing inside a docstring
    return "\n".join(out)


# Quoted text is a REFERENCE to a token, never an instance of it -- the same
# warrant that keeps a string literal out of scope in code. A rulebook has to be
# able to print the words it bans, and a doc that merely SHOWS the override token
# has not claimed it. Backticks are the mark of quotation on both surfaces.
FENCED = re.compile(r"(?ms)^\s*```.*?^\s*```\s*$")
INLINE_CODE = re.compile(r"`{1,3}[^`\n]*`{1,3}")


def strip_quoted(text):
    return INLINE_CODE.sub(" ", FENCED.sub(" ", text))


def prose_of(content, mode, ext="", fallback=True):
    """The prose in `content` for its surface, with quotation removed."""
    p = content if mode == "md" else code_prose(content, ext, fallback)
    return strip_quoted(p)


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


def scope_of(file_path):
    """'md', 'code', or None."""
    p = file_path.replace("\\", "/").lower()
    if any(d in p for d in EXEMPT_PATHS):
        return None
    if p.endswith(".md"):
        return "md"
    if p.endswith(CODE_EXTS):
        return "code"
    return None


def find_hits(content, mode="md"):
    hits = []
    if mode == "code":
        for pat, label, flags in CODE_BLOCK_PATTERNS:
            m = re.search(pat, content, flags)
            if m:
                hits.append(f"{label} → \"{m.group(0)[:60].strip()}\"")
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
    mode = scope_of(file_path)
    if not mode:
        sys.exit(0)
    if any(h in file_path.lower() for h in PROVENANCE_HINTS):
        sys.exit(0)

    content = extract_content(tool_name, tool_input)
    if not content:
        sys.exit(0)

    lp = file_path.lower()
    ext = lp[lp.rfind("."):] if "." in lp else ""
    prose = prose_of(content, mode, ext)
    if not prose.strip() or OVERRIDE_MARKER in prose:
        sys.exit(0)

    hits = find_hits(prose, mode)
    if hits:
        where = ("a CODE COMMENT" if mode == "code"
                 else "an operational artifact")
        cure = ("A comment says what the code DOES, not what it stopped doing. "
                "The reason for a change goes in the COMMIT MESSAGE.\n"
                "Genuinely a provenance note? add the token  postmortem-ok  "
                "to it to consciously override."
                if mode == "code" else
                "State things as they ARE, not as a diff against what they were. "
                "Rationale for cuts goes in the COMMIT MESSAGE, not the doc.\n"
                "Genuine audit/provenance doc? Name it *-audit.md / *-postmortem.md, "
                "or add the line  <!-- postmortem-ok -->  to consciously override.")
        reason = (
            f"BLOCKED — post-mortem / change-narration prose in {where}:\n  - "
            + "\n  - ".join(hits)
            + "\n\n" + cure
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
        m = re.search(pat, prose, re.IGNORECASE)
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
