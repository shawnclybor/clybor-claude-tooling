#!/usr/bin/env python3
"""Validate PRP artifact naming + OKF frontmatter.

Two modes:
  PreToolUse hook  — reads the Write payload on stdin; exit 2 blocks the write.
  --audit <dir>    — checks every .md already on disk; exit 1 if any fail.

Convention: .claude/prp-naming.md
"""
import json, os, re, sys

KIND_TYPES = {
    "prd": {"note"}, "plan": {"note"}, "validate": {"note"}, "evaluate": {"note"},
    "adversarial": {"note"}, "findings": {"note"}, "review": {"note"},
    "handoff": {"note"}, "prompt": {"note"}, "brief": {"note", "deliverable"},
    "card": {"note"}, "transcript": {"source", "note"},
    "session-summary": {"note"}, "notes": {"note"},
}
EXEMPT = {"prd.md", "plan.md", "validate.md", "evaluate.md", "index.md", "log.md",
          "NAMING.md", "README.md"}
# Scope: the artifact level only — the immediate children of .claude/PRPs/<slug>/.
# Subdirectories are deliberately OUT of scope. They hold pulled client sources
# (jk-source/), test fixtures (client-fixtures/, render-gate-probe/), earlier research,
# and the shipped case-folder/_template/ product files, which carry their own contract.
# Renaming any of those would corrupt provenance or break the product.
# The build-* pipeline owns its own frontmatter contract on these artifacts
# (slug / target_type / profile / status / plan_ref). They are NOT OKF files;
# forcing OKF on them would fight the skills that write and read them.
# Only the pipeline's OWN artifacts, identified by exact name: plan.md / validate.md /
# evaluate.md are already in EXEMPT, so prd-<slug>.md is the one that reaches here.
# A dated file merely STARTING with a pipeline kind (validate-evidence-delta-…) is an
# ordinary OKF artifact, not a pipeline one.
PIPELINE_REQUIRED = ("slug", "status")
PROVENANCE = ("project", "resource", "source", "sources", "related")
TIMESTAMP = ("updated", "created", "timestamp")
NAME_RE = re.compile(r"^(?P<kind>[a-z]+(?:-[a-z]+)?)-(?P<rest>[a-z0-9-]+)\.md$")
DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}")
BAD_DATE_RE = re.compile(r"\b(\d{1,2}[-_]\d{1,2}[-_]\d{2,4}|\d{8})\b")


def parse_front(text):
    if not text.startswith("---"):
        return None
    end = text.find("\n---", 3)
    if end == -1:
        return None
    fm = {}
    for line in text[3:end].splitlines():
        m = re.match(r"^([A-Za-z_]+):\s*(.*)$", line)
        if m:
            fm[m.group(1)] = m.group(2).strip()
    return fm


def check(path, content):
    """Return a list of problem strings. Empty list = pass."""
    base = os.path.basename(path)
    probs = []
    if base in EXEMPT:
        return probs
    if base.startswith("prd-"):
        kind = "prd"
    else:
        m = NAME_RE.match(base)
        if not m:
            return [f"filename does not match <kind>-<subject>[-YYYY-MM-DD].md "
                    f"(lowercase, hyphens only): {base}"]
        # longest-matching kind wins, so 'session-summary' beats 'session'
        kind = next((k for k in sorted(KIND_TYPES, key=len, reverse=True)
                     if base.startswith(k + "-")), None)
        if kind is None:
            return [f"unknown kind '{m.group('kind')}' in {base}. "
                    f"Known: {', '.join(sorted(KIND_TYPES))}"]
    if BAD_DATE_RE.search(base) and not DATE_RE.search(base):
        probs.append(f"non-ISO date in {base} — use YYYY-MM-DD as the last segment")

    fm = parse_front(content)
    if fm is None:
        probs.append("missing okf-adapted-v0.1 frontmatter block")
        return probs
    if base.startswith("prd-"):
        for req in PIPELINE_REQUIRED:
            if req not in fm:
                probs.append(f"pipeline artifact missing required '{req}:' "
                             f"(build-* contract, not OKF)")
        return probs
    for req in ("type", "title"):
        if req not in fm:
            probs.append(f"frontmatter missing required '{req}:'")
    if not any(k in fm for k in PROVENANCE):
        probs.append(f"frontmatter needs >=1 provenance field ({'/'.join(PROVENANCE)})")
    if not any(k in fm for k in TIMESTAMP):
        probs.append(f"frontmatter needs >=1 timestamp ({'/'.join(TIMESTAMP)})")
    t = fm.get("type")
    if t and kind in KIND_TYPES and t not in KIND_TYPES[kind]:
        probs.append(f"type: '{t}' disagrees with kind '{kind}' — expected "
                     f"{' or '.join(sorted(KIND_TYPES[kind]))}. One of the two is lying.")
    if "project" in fm and not re.fullmatch(
            r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", fm["project"]):
        probs.append(f"project: must be a bare 36-char Notion UUID, got '{fm['project']}'")
    return probs


def audit(root):
    failed = 0
    for f in sorted(os.listdir(root)):            # top level only, by design
        if True:
            if not f.endswith(".md"):
                continue
            p = os.path.join(root, f)
            try:
                probs = check(p, open(p, encoding="utf-8").read())
            except Exception as e:                      # unreadable => report, don't crash
                probs = [f"unreadable: {e}"]
            if probs:
                failed += 1
                print(f"FAIL {p}")
                for x in probs:
                    print(f"     - {x}")
    print(f"\n{'FAIL' if failed else 'PASS'}: {failed} file(s) with problems")
    return 1 if failed else 0


def main():
    if "--audit" in sys.argv:
        sys.exit(audit(sys.argv[sys.argv.index("--audit") + 1]))
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)                                     # not our business
    if payload.get("tool_name") != "Write":
        sys.exit(0)
    ti = payload.get("tool_input", {}) or {}
    path = ti.get("file_path", "")
    if "/.claude/PRPs/" not in path or not path.endswith(".md"):
        sys.exit(0)
    # artifact level only: <...>/.claude/PRPs/<slug>/<file>.md — nothing deeper
    tail = path.split("/.claude/PRPs/", 1)[1].split("/")
    if len(tail) != 2:
        sys.exit(0)
    probs = check(path, ti.get("content", "") or "")
    if probs:
        print("BLOCKED (PRP naming convention — .claude/prp-naming.md)\n"
              + "\n".join(f"  - {p}" for p in probs)
              + "\nFix the filename or the frontmatter and retry.", file=sys.stderr)
        sys.exit(2)
    sys.exit(0)


if __name__ == "__main__":
    main()
