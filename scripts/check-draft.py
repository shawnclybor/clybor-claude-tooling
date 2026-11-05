#!/usr/bin/env python3
"""check-draft.py — fail a draft whose quotes, settled claims or counts are not backed by a source.

  python3 scripts/check-draft.py DRAFT [--sources TXT ...] [--counts COUNTS.json ...] [--allow 7,12]

Why (2026-11-05): in one session, paraphrase drifted stronger than the source ("proposed" became
"agreed", "lists as a task" became "defines"), and counts were carried forward from old notes instead of
recomputed. Reminders to "verify" did not stop it. This does: every check fails the run.

  1. Quotes    (needs --sources) Every "quoted phrase" of 4+ words must appear word for word in a source
               text. Comparison ignores case, spacing, curly vs straight quotes and markdown emphasis; a
               quote with "..." or "…" is checked piece by piece.
  2. Settled   (always) Words that claim something is settled (agreed, confirmed, approved, decided,
               signed off) fail unless negated ("not yet confirmed") or the same line cites its evidence: a message ID (16 hex),
               a file path, a link or a §-reference. Mark a deliberate line with  <!-- settled-ok -->  (a reason may follow: <!-- settled-ok: why -->).
  3. Counts    (needs --counts) Every number left after removing dates, years, times, money, IDs and
               versions (digits attached to letters, _ . - or /), numbered labels ("Phase 1", "WS1") and
               list markers must be a value in COUNTS.json (any nesting) or in --allow.

Source texts come from read-source.py (OUTDIR/<stem>.txt) or any plain-text extraction.
Exit 0 = clean. 1 = findings (printed file:line). 2 = bad input.
"""
import argparse
import json
import re
import sys
import unicodedata

SETTLED = re.compile(r"\b(agreed|confirmed|approved|decided|signed[- ]off)\b", re.I)
NEGATED = re.compile(r"\b(?:not|never|pending|un|yet to be|to be)\s+(?:yet\s+)?$|\bun$", re.I)
CITED = re.compile(r"\b[0-9a-f]{16}\b|[\w.-]+/[\w./-]+\.\w+|\]\(|https?://|§|<!-- settled-ok")
LABEL = (r"phase|goal|step|page|slide|section|activity|option|round|session|meeting|"
         r"milestone|tier|week|wave|sprint|part|level|chapter|appendix|"
         r"task order|order|exhibit|ws|d|q|p|v")


def norm(s):
    s = unicodedata.normalize("NFKC", s)  # PDF ligatures: "ﬂ" -> "fl" (2026-11-05 real-run false alarm)
    s = s.replace("’", "'").replace("‘", "'").replace("“", '"').replace("”", '"')
    s = re.sub(r"[*_`]", "", s)
    return re.sub(r"\s+", " ", s).strip().lower()


def quotes(line):
    line = re.sub(r"(?<=\d)\"", " ", line)  # inch marks (12") are not quotes
    for m in re.finditer(r'"([^"\n]{3,})"|“([^”\n]{3,})”', line):
        yield m.group(1) or m.group(2)


def numbers_left(line):
    s = re.sub(r"`[^`]*`|https?://\S+|<!--.*?-->", " ", line)
    s = re.sub(r"\b\d{4}-\d{2}-\d{2}\b|\b\d{1,2}:\d{2}\b|[$€£]\s?[\d,.]+[kKmM]?\b", " ", s)
    s = re.sub(r"\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?\s+\d{1,2}\b", " ", s, flags=re.I)
    s = re.sub(rf"\b(?:{LABEL})\s*#?\d+\b", " ", s, flags=re.I)
    s = re.sub(r"\b(?:19|20)\d{2}\b", " ", s)
    s = re.sub(r"^\s*(?:[-*]\s+)?\d+[.)]\s", " ", s)
    # IDs and versions (_001, D4, v1.2, FY2028, deadbeef, 1a2b3c4d-5e6f) are digits touching letters, _ . - or /.
    # Decimals, fractions and "99-row" are still counts (chaos review 2026-11-05).
    return [n.replace(",", "") for n in re.findall(r"(?<![\w.\-/])\d[\d,]*(?:\.\d+)?%?(?![\w]|\.\d)", s)]


def count_values(obj, acc):
    if isinstance(obj, dict):
        for v in obj.values():
            count_values(v, acc)
    elif isinstance(obj, list):
        for v in obj:
            count_values(v, acc)
    elif isinstance(obj, bool):
        pass
    elif isinstance(obj, (int, float)):
        acc.add(str(int(obj)) if float(obj).is_integer() else str(obj))
    elif isinstance(obj, str) and re.fullmatch(r"\d+(?:\.\d+)?%?", obj.strip()):
        acc.add(obj.strip())
    return acc


def main(argv):
    ap = argparse.ArgumentParser(description="Fail a draft whose quotes, settled claims or counts are unbacked.")
    ap.add_argument("draft")
    ap.add_argument("--sources", nargs="*", default=[])
    ap.add_argument("--counts", nargs="*")
    ap.add_argument("--allow", default="")
    try:
        a = ap.parse_args(argv)
        lines = open(a.draft, encoding="utf-8").read().split("\n")
        corpus = norm(" ".join(open(p, encoding="utf-8", errors="replace").read() for p in a.sources))
        counts = None
        for cf in a.counts or []:
            counts = count_values(json.load(open(cf)), counts or set())
    except SystemExit:
        return 2
    except (OSError, ValueError) as e:
        print(f"check-draft: {e}")
        return 2
    allow = {x.strip() for x in a.allow.split(",") if x.strip()}
    findings = []
    in_front = lines[:1] == ["---"]
    in_code = False
    body = []  # (line number, text) outside frontmatter and code blocks
    for n, line in enumerate(lines, 1):
        if in_front:
            in_front = not (n > 1 and line.strip() == "---")
            continue
        if line.strip().startswith("```"):
            in_code = not in_code
            continue
        if not in_code:
            body.append((n, line))
    # Quotes are matched per paragraph: wrapped markdown splits a quote across lines (2026-11-05 false alarm).
    if a.sources:
        para, start = [], None
        for n, line in body + [(None, "")]:
            if line.strip():
                para.append(line)
                start = start or n
                continue
            text = re.sub(r"(?<=\d)\"", " ", " ".join(para))
            if text.count('"') % 2 or text.count("\u201c") != text.count("\u201d"):
                findings.append((start, "unbalanced quotation marks in this paragraph: check the quotes by hand"))
            for q in quotes(" ".join(para)):
                for piece in re.split(r"\.\.\.|…", q):
                    p = norm(piece).strip(" .,;:")
                    if len(p.split()) >= 4 and p not in corpus:
                        findings.append((start, f'quote not found in sources: "{piece.strip()[:80]}"'))
            para, start = [], None
    for n, line in body:
        for m in SETTLED.finditer(line):
            if NEGATED.search(line[:m.start()]) or CITED.search(line):
                continue
            findings.append((n, f'"{m.group(0)}" with no cited message, file or link on the line'))
            break
        if counts is not None:
            for num in numbers_left(line):
                if not ({num, num.rstrip("%")} & (counts | allow)):
                    findings.append((n, f"number {num} is not in {', '.join(a.counts)}"))
    for n, msg in findings:
        print(f"FAIL {a.draft}:{n}  {msg}")
    checks = ["settled words"] + (["quotes"] if a.sources else []) + (["counts"] if counts is not None else [])
    print(f"check-draft: {len(findings)} finding(s) ({', '.join(checks)} checked)")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
