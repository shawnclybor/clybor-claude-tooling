#!/usr/bin/env python3
"""Catch prose that reads fluently and says nothing.

This is a DIFFERENT defect from the one `writing-quality` already hunts. That skill
targets AI-isms — stylistic tics ("delve", "it's not just X, it's Y", dash overuse).
This targets sentences that are grammatical, natural-sounding, and empty:

    "We check the spec against reality."

Nothing about that is an AI-ism. A person could have written it. It is still slop,
because a reader cannot say what would be different if it were true. (Measured
2026-09-02: one draft carried 13 of these; the phrase above was the worst.)

SCOPE, honestly stated. A phrase list catches YESTERDAY's offenders. Slop regenerates
— ban "leverage" and you get "harness". This script is the cheap repeat-offender
detector; the judgment detector is the ONE QUESTION in writing-quality's
"Empty prose" section, which catches novel emptiness a list never will. Neither
replaces the other. `test-empty-prose.sh` asserts this limit explicitly (case K1).

FALSE POSITIVES ARE THE FAILURE MODE. `check-plan-soundness.py` lost a check that
fired 32 times on a sound plan; a gate that cries wolf gets clicked through, and then
it is not a gate. Every pattern here is deliberately narrow. When in doubt it was left
out. Grow the lists from prose actually caught in review — never from words that
merely sound bad.

Usage:
  check-empty-prose.py <file> [<file>...]   exit 1 if any finding
  check-empty-prose.py --stdin              read prose on stdin
  check-empty-prose.py <file> --quiet       findings only, no summary

Exempt from scanning: regions between `<!-- empty-prose: off -->` and
`<!-- empty-prose: on -->` (so a rulebook can quote what it bans), fenced code
blocks, inline code spans, YAML frontmatter,
HTML tags/attributes, <style>/<script> bodies, and link URLs. Insider terms are
fine inside code; the defect is carrying them in reader-facing prose.
"""
import re
import sys

# ---------------------------------------------------------------------------
# Classes. Each maps to one of the six things a reader complained about:
# slogans, grandiosities, meaningless phrases, jargon, insider terms, flourishes.
# ---------------------------------------------------------------------------

SLOGAN = [
    r"against reality",
    r"claims about the world",
    r"one level down",
    r"at its core",
    r"at the end of the day",
    r"when you think about it",
    r"in a very real sense",
    r"on a fundamental level",
    r"the real question is",
    r"speaks to something",
    r"gets at something",
    r"it all comes down to",
    r"the beauty of it",
    r"that's the whole point",
    r"first principles",
]

GRANDIOSITY = [
    r"revolutioniz\w*",
    r"paradigm shift\w*",
    r"game[- ]chang\w+",
    r"supercharg\w+",
    r"world[- ]class",
    r"best[- ]in[- ]class",
    r"cutting[- ]edge",
    r"state of the art",
    r"unlock(?:s|ing)? the (?:power|potential)",
    r"harness(?:es|ing)? the (?:power|potential)",
    r"take (?:it|things|them) to the next level",
    r"empower(?:s|ing|ed)?\b",
    r"seamless(?:ly)?",
    r"unparalleled",
    r"transformative",
]

FILLER = [
    r"a number of",
    r"a range of",
    r"a variety of",
    r"several key",
    r"various different",
    r"countless",
    r"myriad",
    r"in order to be able to",
    r"it is important to note that",
    r"it is worth noting that",
    r"needless to say",
]

FLOURISH = [
    r"truly\b",
    r"profoundly\b",
    r"incredibly\b",
    r"immensely\b",
    r"tremendously\b",
    r"(?:very|quite|somewhat) unique",
    r"nothing short of",
    r"a testament to",
    r"lies at the heart of",
    r"more than just a",
]

# Insider terms are only a defect in READER-FACING prose. Code spans are stripped
# before scanning, so a filename inside backticks never reaches here.
INSIDER = [
    (r"\bmcp__[A-Za-z0-9_]+", "tool id"),
    (r"\b[a-z][a-z0-9_-]*\.(?:py|sh|json|jsonl|tsv|lock)\b", "script/data filename"),
    (r"\bSKILL\.md\b", "skill internals"),
    (r"\bfrontmatter\b", "skill internals"),
    (r"\b[a-z]+(?:-[a-z]+)*-governance\b", "governance skill name"),
    (r"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-", "raw UUID"),
    (r"\bPreToolUse|\bPostToolUse|\bStop hook\b", "harness internals"),
]

CLASSES = [
    ("slogan",      SLOGAN,      "reads well, states nothing a reader could check"),
    ("grandiosity", GRANDIOSITY, "marketing register; claims importance instead of showing it"),
    ("filler",      FILLER,      "words that survive deletion with no loss of meaning"),
    ("flourish",    FLOURISH,    "ornament standing in for a specific claim"),
]


# ---------------------------------------------------------------------------
# Prose extraction — everything below is about NOT scanning what isn't prose.
# ---------------------------------------------------------------------------

def extract_prose(text):
    """Blank out non-prose regions, preserving line numbers so findings can cite them."""

    def blank(m):
        # keep newlines so line numbers stay true
        return re.sub(r"[^\n]", " ", m.group(0))

    # explicit suppression: a rulebook must be able to quote what it bans.
    #   <!-- empty-prose: off -->  ...examples...  <!-- empty-prose: on -->
    text = re.sub(r"<!--\s*empty-prose:\s*off\s*-->.*?<!--\s*empty-prose:\s*on\s*-->",
                  blank, text, flags=re.S | re.I)
    # YAML frontmatter
    text = re.sub(r"\A---\n.*?\n---\n", blank, text, flags=re.S)
    # <style> / <script> bodies
    text = re.sub(r"<(style|script)\b.*?</\1>", blank, text, flags=re.S | re.I)
    # fenced code blocks
    text = re.sub(r"```.*?```", blank, text, flags=re.S)
    text = re.sub(r"~~~.*?~~~", blank, text, flags=re.S)
    # indented code blocks (4+ spaces at line start, after a blank line)
    text = re.sub(r"(?m)^(?: {4}|\t)\S[^\n]*$", blank, text)
    # inline code spans
    text = re.sub(r"`[^`\n]+`", blank, text)
    # HTML tags and their attributes
    text = re.sub(r"<[^>\n]+>", blank, text)
    # markdown link/image targets — keep the visible text, drop the URL
    text = re.sub(r"\]\([^)\n]*\)", blank, text)
    # bare URLs
    text = re.sub(r"https?://\S+", blank, text)
    return text


def scan(text):
    """Return [(line_no, class_name, matched_text, why)]."""
    prose = extract_prose(text)
    findings = []

    for name, patterns, why in CLASSES:
        for pat in patterns:
            for m in re.finditer(pat, prose, re.I):
                line = prose.count("\n", 0, m.start()) + 1
                findings.append((line, name, m.group(0).strip(), why))

    for pat, label in INSIDER:
        for m in re.finditer(pat, prose):
            line = prose.count("\n", 0, m.start()) + 1
            findings.append((line, "insider-term", m.group(0).strip(),
                             f"{label} left undefined in reader-facing prose"))

    findings.sort(key=lambda f: (f[0], f[1]))
    return findings


def main(argv):
    quiet = "--quiet" in argv
    args = [a for a in argv if not a.startswith("--")]

    if "--stdin" in argv:
        sources = [("<stdin>", sys.stdin.read())]
    elif args:
        sources = []
        for path in args:
            try:
                sources.append((path, open(path, encoding="utf-8").read()))
            except OSError as e:
                print(f"cannot read {path}: {e}", file=sys.stderr)
                return 2
    else:
        print(__doc__.strip().split("Usage:")[1].strip(), file=sys.stderr)
        return 2

    total = 0
    for path, text in sources:
        findings = scan(text)
        total += len(findings)
        for line, cls, hit, why in findings:
            print(f"{path}:{line}: [{cls}] {hit!r} — {why}")

    if not quiet:
        if total:
            print(f"\n{total} finding(s). Each is a place to name the specific thing "
                  f"instead of gesturing at it.", file=sys.stderr)
        else:
            print("no empty-prose findings", file=sys.stderr)

    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
