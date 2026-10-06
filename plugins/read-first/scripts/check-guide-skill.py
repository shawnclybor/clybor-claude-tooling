#!/usr/bin/env python3
"""check-guide-skill.py — does a guide skill follow the standard?

A guide skill is one part rules and one part operating manual. read-first only checks that
a guide was loaded; this checks that what was loaded has both parts, in order.

Required:
  - frontmatter with `name` and `description` (description 1-1024 characters,
    and no ": " in it, which breaks the YAML header)
  - `## Rules` with at least one list item under it
  - `## Operating manual`, after `## Rules`
  - `### Known issues` inside the operating manual, with a `| Date |` table
  - every Known issues row dated YYYY-MM-DD, or the "None confirmed yet" placeholder

Usage: python3 check-guide-skill.py <SKILL.md> [<SKILL.md> ...]
Exit 0 = every file passes. Exit 1 = at least one fails (reasons printed). Exit 2 = usage.
"""
import json
import re
import sys

DATE_ROW = re.compile(r"^\|\s*(\d{4}-\d{2}-\d{2}|None confirmed yet)\s*\|")


def frontmatter(text):
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---", 4)
    if end < 0:
        return None
    head = text[4:end]
    try:  # parse the header the way Claude Code does, when PyYAML is installed
        import yaml
        data = yaml.safe_load(head)
        if isinstance(data, dict):
            return {k: ("" if v is None else str(v)) for k, v in data.items()}, text[end + 4:], True
    except ImportError:
        pass
    except Exception as err:
        return {"_yaml_error": str(err).splitlines()[0]}, text[end + 4:], True
    fields = {}
    for line in head.splitlines():
        m = re.match(r"^([A-Za-z_-]+):\s?(.*)$", line)
        if m:
            fields[m.group(1)] = unquote(m.group(2).strip())
    return fields, text[end + 4:], False


def unquote(v):
    """A quoted YAML scalar's value, without PyYAML: count characters, not escapes."""
    if len(v) >= 2 and v[0] == v[-1] == '"':
        try:
            return json.loads(v)
        except ValueError:
            return v[1:-1]
    if len(v) >= 2 and v[0] == v[-1] == "'":
        return v[1:-1].replace("''", "'")
    return v


def sections(body, level):
    """[(title, text)] for each heading of exactly `level` hashes."""
    marks = [(m.start(), m.group(1).strip()) for m in re.finditer(rf"^{'#' * level} (?!#)(.+)$", body, re.M)]
    out = []
    for i, (pos, title) in enumerate(marks):
        stop = marks[i + 1][0] if i + 1 < len(marks) else len(body)
        out.append((title, body[pos:stop]))
    return out


def check(path):
    problems = []
    text = open(path, encoding="utf-8").read()
    fm = frontmatter(text)
    if fm is None:
        return ["no frontmatter (the file must open with --- and close it with ---)"]
    fields, body, parsed = fm
    if "_yaml_error" in fields:
        return [f"frontmatter is not valid YAML ({fields['_yaml_error']})"]
    for key in ("name", "description"):
        if not fields.get(key):
            problems.append(f"frontmatter has no {key}")
    desc = fields.get("description", "")
    if len(desc) > 1024:
        problems.append(f"description is {len(desc)} characters; the limit is 1024")
    raw = re.search(r"^description:\s?(.*)$", text[4:text.find("\n---", 4)], re.M)
    raw = raw.group(1).strip() if raw else ""
    if not parsed and ": " in raw and raw[:1] not in "\"'":
        problems.append('description contains ": ", which breaks the YAML header')

    h2 = sections(body, 2)
    titles = [t.lower() for t, _ in h2]
    if "rules" not in titles:
        problems.append("no `## Rules` section")
    if "operating manual" not in titles:
        problems.append("no `## Operating manual` section")
    if "rules" in titles and "operating manual" in titles and titles.index("rules") > titles.index("operating manual"):
        problems.append("`## Rules` must come before `## Operating manual`")

    for title, text_ in h2:
        if title.lower() == "rules" and not re.search(r"^\s*(?:[-*]|\d+\.)\s+\S", text_, re.M):
            problems.append("`## Rules` has no list items")
        if title.lower() == "operating manual":
            known = [t for t in sections(text_, 3) if t[0].lower() == "known issues"]
            if not known:
                problems.append("`## Operating manual` has no `### Known issues`")
                continue
            rows = [ln for ln in known[0][1].splitlines() if ln.startswith("|")]
            if not rows or not re.match(r"^\|\s*Date\s*\|", rows[0]):
                problems.append("`### Known issues` has no `| Date |` table")
                continue
            for ln in rows[2:]:
                if not DATE_ROW.match(ln):
                    problems.append(f"Known issues row is not dated YYYY-MM-DD: {ln.strip()[:60]}")
    return problems


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    failed = 0
    for path in argv[1:]:
        problems = check(path)
        if problems:
            failed += 1
            print(f"FAIL {path}")
            for p in problems:
                print(f"  - {p}")
        else:
            print(f"PASS {path}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
