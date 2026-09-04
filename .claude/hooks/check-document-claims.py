#!/usr/bin/env python3
"""
HOOK: check-document-claims.py
TRIGGER: PreToolUse on Write|Edit (JSON on stdin) -- and `--files <md>...` for the pre-commit backstop
PURPOSE: An ABSOLUTE claim about what a document prints must cite a line. "The bill contains no
         zero token anywhere", "the credit columns are blank", "every printed total is zero" --
         each is a statement about the PAPER, and each is blocked unless the sentence carries a
         citation of the shape a refusal already carries: `bill-frye.txt:115`, `line 115`,
         `lines 57-59`. The citation comes from `case-folder/investigate.py`; that is the
         "required" half of the tool.

SCOPE: Markdown whose path names the Yellow Sheet build -- `yellow_sheet` (memories) or
       `yellow-sheet` (every PRP slug and the corpus skill). Nothing else. Code is out of scope.

WHAT IS NOT A CLAIM (measured over the build's memories before wiring, see test):
  - a QUOTED sentence -- "..." / '...' / *...* -- repeating a claim is not making one
  - fenced code, inline code spans, YAML frontmatter
  - a sentence with no absolute in it. "The bill prints a total" is a description; "the bill
    prints NO total ANYWHERE" is the class that did the damage. The judgment half stays with the
    reader and is recorded as this gate's known miss.

OVERRIDE (conscious, never silent): the literal marker  <!-- claims-ok -->  in the content, or
CLAIMS_OK=1 on the pre-commit path.

EXIT: hook mode always 0 (block travels as a JSON deny). --files mode: 1 on any finding, else 0.
"""
import json
import re
import sys
from pathlib import Path

SCOPE_HINTS = ("yellow_sheet", "yellow-sheet")
OVERRIDE_MARKER = "<!-- claims-ok -->"

# A claim has FOUR parts, and the fourth is what separates it from a rule. Measured before this was
# added: 95 hits over the build's memories, 498 over its PRP prose, and nearly every one was a
# definition -- "a refused document writes no figure", "every printed total zero" (a limb's name).
# The four wrong claims of 2026-09-03 all named a SPECIFIC document: a provider's bill, a matter, a
# file. A sentence about "a bill" is a rule; a sentence about "Frye's bill" is a claim.
DOC = re.compile(
    r"\b(bills?|liens?|documents?|pages?|statements?|summar(?:y|ies)|forms?|packets?|scans?|pdfs?|"
    r"sheets?|trackers?|itemizations?|totals?\s+rows?|headers?|columns?|rows?|box(?:es)?\s*\d*|"
    r"invoices?|eobs?|text\s+layer|super\s?bills?|files?)\b", re.I)
VERB = re.compile(
    r"\b(prints?|printed|states?|stated|contains?|contained|carr(?:y|ies|ied)|shows?|showed|"
    r"lists?|listed|records?|recorded|reads?|holds?|has|have|had|is|are|was|were)\b", re.I)
ABSOLUTE = re.compile(
    r"\bnowhere\b|\bno\s+(?:\w+\s+){0,3}?(?:anywhere|at\s+all)\b|"
    r"\b(?:contains?|states?|prints?|has|have|carr(?:y|ies)|shows?|lists?|holds?)\s+no\b|"
    r"\bnone\s+of\b|\bstructurally\s+blank\b|\b(?:is|are|were|was)\s+(?:entirely\s+|all\s+)?blank\b|"
    r"\bevery\s+(?:\w+\s+){0,3}?(?:is\s+|reads\s+)?zero\b|"
    r"\bexactly\s+(?:one|\d+)\s+(?:money\s+)?(?:token|figure|amount|zero)s?\b|"
    r"\bzero\s+(?:money\s+)?tokens?\b|\b(?:only|single)\s+(?:money\s+)?(?:token|figure|amount)\b", re.I)
# The specific referent: a file, a matter letter, or a proper name that is not a sentence-starter.
FILE_REF = re.compile(r"\bmatter-[a-z]\b|\b[\w-]+\.(?:txt|pdf|docx?|json|xlsx)\b|\bbill-[\w-]+", re.I)
CAP_STOP = {"the", "a", "an", "it", "its", "this", "that", "these", "those", "every", "each", "no",
            "none", "nothing", "all", "any", "some", "one", "two", "three", "both", "measured", "note",
            "see", "if", "when", "where", "while", "so", "but", "and", "or", "our", "their", "we",
            "they", "there", "here", "what", "which", "who", "why", "how", "read", "run", "do", "not",
            "in", "on", "at", "for", "from", "with", "without", "before", "after", "then", "now",
            "structural", "unread", "refusal", "recovery", "stage", "limb", "criterion", "task",
            "provider", "records", "needed", "case", "info", "dos", "breakdown", "summary", "totals",
            "findings", "contact", "log", "on", "lien", "yes", "monday", "tuesday", "wednesday",
            "thursday", "friday", "saturday", "sunday", "shawn", "prolaw", "medi-cal", "dhcs",
            "cms-1500", "eob", "eobs", "excel", "word", "python", "bash", "json", "ocr", "pua"}
CAP = re.compile(r"(?<![.`\"'*_(\[|/#-])\b([A-Z][\w'&.-]{1,})\b")


def specific(sentence):
    if FILE_REF.search(sentence):
        return True
    caps = [m.group(1) for m in CAP.finditer(sentence)]
    return any(c.lower().rstrip("'s") not in CAP_STOP and c.lower() not in CAP_STOP
               and not c.isupper() for c in caps)


CITATION = re.compile(
    r"\S+\.(?:txt|pdf|docx?|json|xlsx|csv|md|py)(?::|#L?)\d+|\blines?\s+\d+|\bL\d+\b|\bln\s*\d+", re.I)

QUOTED = re.compile(r"\"[^\"\n]{3,}\"|“[^”\n]{3,}”|'[^'\n]{8,}'|\*[^*\n]{3,}\*|_[^_\n]{3,}_")
FENCE = re.compile(r"```.*?```", re.S)
SPAN = re.compile(r"`[^`\n]*`")
FRONTMATTER = re.compile(r"\A---\n.*?\n---\n", re.S)
SPLIT = re.compile(r"(?<=[.!?])\s+(?=[A-Z⚠⛔✅])|\n")


def strip_exempt(text):
    text = FRONTMATTER.sub("", text)
    text = FENCE.sub("", text)
    text = SPAN.sub("`x`", text)
    return QUOTED.sub('"q"', text)


def is_claim(sentence):
    return bool(DOC.search(sentence) and VERB.search(sentence) and ABSOLUTE.search(sentence)
                and specific(sentence) and not CITATION.search(sentence))


def findings(text):
    """-> [(line_no, sentence)] uncited absolute document claims, on the ORIGINAL line numbers."""
    out = []
    clean = strip_exempt(text)
    # Line numbers: work per original line so a finding points somewhere real.
    for ln, line in enumerate(clean.split("\n"), 1):
        if not line.strip() or line.lstrip().startswith(("|--", "|:-")):
            continue
        for s in SPLIT.split(line):
            s = s.strip(" |-*>#")
            if len(s) > 20 and is_claim(s):
                out.append((ln, s))
    return out


def in_scope(path):
    p = path.replace("\\", "/").lower()
    return p.endswith(".md") and any(h in p for h in SCOPE_HINTS)


def content_of(tool_name, tool_input):
    if tool_name == "Write":
        return tool_input.get("content") or ""
    if tool_name == "Edit":
        return tool_input.get("new_string") or ""
    if tool_name == "MultiEdit":
        return "\n".join(e.get("new_string") or "" for e in tool_input.get("edits") or [])
    return ""


def hook_mode():
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)
    tool_name = data.get("tool_name", "")
    tool_input = data.get("tool_input", {}) or {}
    path = tool_input.get("file_path", "") or ""
    if tool_name not in ("Write", "Edit", "MultiEdit") or not in_scope(path):
        sys.exit(0)
    content = content_of(tool_name, tool_input)
    if not content or OVERRIDE_MARKER in content:
        sys.exit(0)
    hits = findings(content)
    if hits:
        shown = "\n  - ".join(f'"{s[:110]}"' for _ln, s in hits[:6])
        reason = (
            "BLOCKED -- an absolute claim about a document with no line cited:\n  - " + shown +
            "\n\nA statement about the PAPER needs the line it rests on, the way a refusal names its "
            "limb. Run  python3 case-folder/investigate.py <source.txt|case-dir> <claim>  and cite "
            "what it prints (file:line). If it says NOT IN TEXT, say that -- it is a fact about our "
            "extraction, not about the page.\nQuoting someone else's claim? Wrap it in quotes. "
            "Conscious override: add the line  <!-- claims-ok -->"
        )
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                                 "permissionDecision": "deny",
                                                 "permissionDecisionReason": reason}}))
    sys.exit(0)


def files_mode(paths, quiet):
    rc = 0
    for p in paths:
        try:
            text = Path(p).read_text(errors="replace")
        except OSError:
            continue
        if not in_scope(p) or OVERRIDE_MARKER in text:
            continue
        for ln, s in findings(text):
            rc = 1
            print(f'{p}:{ln} [document-claim] "{s[:120]}"')
    if rc and not quiet:
        print("document-claim gate: cite the line (investigate.py), quote it, or CLAIMS_OK=1", file=sys.stderr)
    return rc


def staged_mode(quiet):
    """Only the ADDED lines of staged in-scope .md -- existing debt blocks nothing until it is rewritten.

    Measured before this mode existed: 8 legacy hits across the build's memories, 3 of them in the
    memory that RECORDS the four wrong claims. A whole-file scan would have blocked the next commit
    of that file for quoting the thing it exists to warn about. New claims must cite; old prose is
    the reader's problem, not the committer's.
    """
    import subprocess
    try:
        names = subprocess.run(["git", "diff", "--cached", "--name-only", "--diff-filter=ACM", "-z"],
                               capture_output=True, text=True, check=True).stdout.split("\0")
    except (subprocess.CalledProcessError, OSError):
        return 0
    rc = 0
    for name in (n for n in names if n and in_scope(n)):
        diff = subprocess.run(["git", "diff", "--cached", "-U0", "--", name],
                              capture_output=True, text=True).stdout
        if OVERRIDE_MARKER in diff:
            continue
        added = "\n".join(l[1:] for l in diff.split("\n") if l.startswith("+") and not l.startswith("+++"))
        for _ln, s in findings(added):
            rc = 1
            print(f'{name} [document-claim] "{s[:120]}"')
    if rc and not quiet:
        print("document-claim gate: cite the line (investigate.py), quote it, or CLAIMS_OK=1", file=sys.stderr)
    return rc


if __name__ == "__main__":
    args = sys.argv[1:]
    if args and args[0] == "--staged":
        sys.exit(staged_mode("--quiet" in args))
    if args and args[0] == "--files":
        quiet = "--quiet" in args
        sys.exit(files_mode([a for a in args[1:] if a != "--quiet"], quiet))
    hook_mode()
