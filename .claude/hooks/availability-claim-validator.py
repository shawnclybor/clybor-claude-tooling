#!/usr/bin/env python3
"""
HOOK: availability-claim-validator.py
TRIGGER: PreToolUse on Write|Edit (+ Notion create/update, see settings wiring)
PURPOSE: An unavailability claim is a FINDING and needs the probe that produced
         it. This gate fires when text asserts something is blocked, unreachable,
         missing, or owed by someone else WITHOUT probe evidence nearby.

WHY IT EXISTS: the same failure recurred four times in one week on a single
engagement, always the same shape — an availability assumption that was never
probed, surviving because it kept being copied forward:
  1. a document recorded "unavailable", unread for two weeks, opened first try
  2. a library marked "unreachable by any connector" — never probed, then copied
     into three downstream documents
  3. that same library, parked two months as inaccessible, opened first try in a browser
  4. a dependency logged as owed by another person, findable on the first search
Two of the four were caught only because a human challenged the premise. None
were caught by review: a confident unavailability claim reads exactly like a
finding, and reviewers check prose, not whether a probe ran.

MODE: report-only until backtested. See REPORT_ONLY below.
OVERRIDE (conscious, never silent):
  - the literal marker  <!-- probe-ok: reason -->
  - writing NOT PROBED next to the claim (that IS the compliant form)

EXIT CODES:
  0 — always (decisions are signalled via JSON / stderr, not exit codes)
"""
import json
import re
import sys

# Report-only until the backtest says the false-positive rate is acceptable.
# Flip to False to let the PreToolUse tier warn loudly / precommit block.
REPORT_ONLY = True

EXEMPT_PATHS = (
    "/docs/reference/",     # vendored third-party source — not our prose to police
    "/node_modules/", "/.git/", "/_archived/",
)
OVERRIDE_RE = re.compile(r"<!--\s*probe-ok:", re.I)

# --- Claim patterns: assertion-shaped unavailability ---------------------------
CLAIM_PATTERNS = [
    (r"\bunreachable\b",                     "unreachable"),
    (r"\binaccessible\b",                    "inaccessible"),
    (r"\bnot reachable\b",                   "not reachable"),
    (r"\bcann?o?'?t be reached\b",           "cannot be reached"),
    (r"\b(cannot|can't|can not) access\b",   "cannot access"),
    (r"\bno access to\b",                    "no access to"),
    (r"\bdoes\s?n[o']?t exist\b",            "does not exist"),
    (r"\bno longer exists\b",                "no longer exists"),
    (r"\b(is|are|remains?) unavailable\b",   "is unavailable"),
    (r"\b(is|are|remains?) not available\b", "is not available"),
    (r"\bblocked on\b",                      "blocked on"),
    (r"\bgated on\b",                        "gated on"),
    (r"\bowed by\b",                         "owed by"),
    (r"\bwaiting on\b",                      "waiting on"),
    (r"\bawaiting\b",                        "awaiting"),
    (r"\bnot found\b",                       "not found"),
]

# --- Probe markers: evidence the claim was actually tested ---------------------
PROBE_PATTERNS = [
    r"NOT PROBED",
    # tool names — the strongest signal that a probe ran
    r"\bsharepoint_(search|folder_search)\b", r"\bread_resource\b",
    r"\boutlook_(email|calendar)_search\b", r"\bchat_message_search\b",
    r"\bnotion-(fetch|search|query-data-sources)\b",
    # a project's own gate scripts: check_gate, check-knowledge, verify_schema, ...
    r"\b(verify|check)[-_]\w+\b", r"\bgit (log|ls-files|check-ignore)\b",
    r"\bgrep\b",
    # explicit probe language
    r"\bprobed?\b", r"\bsearched\b", r"\bqueried\b", r"\bre-?read\b",
    r"\bspot-?check", r"\bverified\b", r"\bconfirmed by\b", r"\benumerated\b",
    r"\breturned (no|zero|nothing|empty|\d)", r"\bfirst-party\b",
    # real tool results
    r"\bHTTP \d{3}\b", r"\b(403|404|406)\b", r"\bFORBIDDEN\b", r"\bAccessDenied\b",
    r"\btwo strikes\b",
    # a date stamp adjacent to the claim implies a dated observation
    r"\b20\d\d-\d\d-\d\d\b",
]
CLAIM_RE = [(re.compile(p, re.I), label) for p, label in CLAIM_PATTERNS]
PROBE_RE = [re.compile(p, re.I) for p in PROBE_PATTERNS]


def _strip_code_fences(text):
    """Blank out fenced code blocks so tool output / prompts don't trip the gate."""
    out, fenced = [], False
    for line in text.split("\n"):
        if line.lstrip().startswith("```"):
            fenced = not fenced
            out.append("")
            continue
        out.append("" if fenced else line)
    return out


def _skip_line(line):
    """Quoted speech and blockquotes are someone else's claim, not ours."""
    s = line.strip()
    if s.startswith(">"):
        return True
    if s.startswith("|") and s.count("|") >= 2 and "--" in s:
        return True  # table separator row
    return False


def scan_text(text, path="", window=3):
    """Return [(lineno, label, line)] for unavailability claims lacking probe evidence."""
    if any(seg in path.replace("\\", "/") for seg in EXEMPT_PATHS):
        return []
    if OVERRIDE_RE.search(text or ""):
        return []

    lines = _strip_code_fences(text or "")
    findings = []
    for i, line in enumerate(lines):
        if _skip_line(line):
            continue
        for rx, label in CLAIM_RE:
            m = rx.search(line)
            if not m:
                continue
            # Quoted claim on this line → attributed to a source, not asserted by us.
            span = line[max(0, m.start() - 1): m.end() + 1]
            if '"' in span or "“" in line[:m.start()]:
                continue
            lo, hi = max(0, i - window), min(len(lines), i + window + 1)
            ctx = "\n".join(lines[lo:hi])
            if any(p.search(ctx) for p in PROBE_RE):
                continue
            findings.append((i + 1, label, line.strip()[:150]))
            break
    return findings


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)
    ti = payload.get("tool_input", {}) or {}
    path = ti.get("file_path") or ti.get("notebook_path") or ""
    text = ti.get("new_string") or ti.get("content") or ""
    if not text:
        sys.exit(0)

    findings = scan_text(text, path)
    if not findings:
        sys.exit(0)

    lines = "\n".join(f"  L{n}: [{label}] {snippet}" for n, label, snippet in findings)
    msg = (
        "AVAILABILITY GATE — unavailability claim without a probe:\n"
        f"{lines}\n"
        "An unavailability claim is a FINDING. Run the probe, then record the tool, "
        "filter and date beside it. Cannot probe → write 'NOT PROBED' and name what "
        "would settle it. Inherited claim + access has changed → re-probe.\n"
        "Override: <!-- probe-ok: reason -->"
    )
    if REPORT_ONLY:
        print(f"[report-only] {msg}", file=sys.stderr)
    else:
        print(msg, file=sys.stderr)
    sys.exit(0)


if __name__ == "__main__":
    main()
