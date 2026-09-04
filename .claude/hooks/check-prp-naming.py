#!/usr/bin/env python3
"""Validate PRP artifact naming + OKF frontmatter.

Three modes:
  PreToolUse hook  — reads the Write payload on stdin; exit 2 blocks the write.
  --audit <dir>    — checks every .md on disk + index staleness; exit 1 if any fail.
  --index <dir>    — regenerate index.md from the artifacts' own frontmatter.
  --index-all      — regenerate every slug under .claude/PRPs/. Wired at SessionStart:
                     a sweep, not an intercept, so it cannot be bypassed by Bash writes.

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
EXEMPT = {"prd.md", "premises.md", "probe.md", "plan.md", "validate.md", "evaluate.md",
          "index.md", "log.md", "NAMING.md", "README.md"}
# premises.md and probe.md joined the root set 2026-09-02 with the pipeline re-cut:
# prd -> probe -> validate -> plan. build-probe writes probe.md (and the probes/ dir,
# which is a subdirectory and therefore already out of scope); build-validate writes
# premises.md. Both are pipeline artifacts with the same frontmatter contract as the
# other four, so they belong here and not behind a <kind>-<subject> rename.
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


# A slug under PRPs is a BUILD, and a build starts with a PRD. Without this, any
# artifact kind can conjure a slug just by naming one, which turns the tree into a
# filing cabinet for whatever had nowhere else to go. A `_`-prefixed directory is the
# escape hatch for something that is deliberately not a build.
SLUG_SEED = {"prd.md", "index.md", "log.md", "NAMING.md", "README.md"}


def slug_has_prd(slug_dir):
    try:
        return any(f == "prd.md" or f.startswith("prd-")
                   for f in os.listdir(slug_dir) if f.endswith(".md"))
    except OSError:
        return False


def slug_problem(slug_dir, base):
    """None when the write is allowed to land in this slug."""
    slug = os.path.basename(os.path.normpath(slug_dir))
    if slug.startswith("_") or base in SLUG_SEED or base.startswith("prd-"):
        return None
    if slug_has_prd(slug_dir):
        return None
    return (f"'{slug}/' holds no PRD, so it is not a build. A slug under .claude/PRPs/ "
            f"earns its place with a PRD — write that first (build-prd), or put this in "
            f"a '_'-prefixed directory if it is deliberately not a build.")


def placement_problem(path):
    """Where a file sits is as much the convention as what it is called. The pipeline
    fixed names belong at the slug root because build-* reads them there; every other
    artifact belongs in <slug>/<kind>/."""
    base = os.path.basename(path)
    parent = os.path.basename(os.path.dirname(path))
    if base in EXEMPT or base.startswith("prd-"):
        return None
    kind = kind_of(base)
    if kind in (None, "pipeline", "meta"):
        return None                                     # the naming check owns this case
    if parent == kind:
        return None
    if parent in KIND_TYPES:
        return f"filed under '{parent}/' but the kind is '{kind}' — move to '{kind}/{base}'"
    return (f"artifact at the slug root — move to '{kind}/{base}'. Only prd / probe / "
            f"premises / validate / plan / evaluate live at the root (build-* contract).")


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
    pp = placement_problem(path)
    if pp:
        probs.append(pp)

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



# ---------------------------------------------------------------- index mode
# Naming told you what a file IS. It never told you the folder what it HOLDS,
# so every artifact landed correctly named and completely unlinked. index.md was
# reserved in EXEMPT from the start and never written. This generates it from the
# frontmatter the files already carry — no hand-maintenance, so it cannot rot by
# neglect, only by staleness, which audit() now reports.
PIPELINE_NAMES = {"prd.md", "plan.md", "validate.md", "evaluate.md"}
META_NAMES = {"log.md", "README.md", "NAMING.md"}
INDEX_NAME = "index.md"
GEN_MARK = "<!-- GENERATED by check-prp-naming.py --index. Do not hand-edit. -->"


def kind_of(base):
    """The kind prefix for grouping, or None. Longest match wins."""
    if base.startswith("prd-") or base in PIPELINE_NAMES:
        return "pipeline"
    if base in META_NAMES:
        return "meta"
    return next((k for k in sorted(KIND_TYPES, key=len, reverse=True)
                 if base.startswith(k + "-")), None)


def kind_dirs(root):
    """Subdirectories NAMED AFTER A KIND hold artifacts of that kind and are walked.
    Any other subdirectory is opaque — jk-source/ (client provenance), case-folder/
    (shipped product), client-fixtures/ and render-gate-probe/ (fixtures). The rule is
    the directory's own name, so there is no allowlist to keep in step."""
    return [d for d in sorted(os.listdir(root))
            if d in KIND_TYPES and os.path.isdir(os.path.join(root, d))]


def artifacts(root):
    """Artifact-level .md: the slug root plus its kind subdirectories, index.md
    excluded. Paths are slug-relative, e.g. 'transcript/transcript-…-attributed.md'."""
    out = [f for f in sorted(os.listdir(root))
           if f.endswith(".md") and f != INDEX_NAME
           and os.path.isfile(os.path.join(root, f))]
    for d in kind_dirs(root):
        out += [os.path.join(d, f)
                for f in sorted(os.listdir(os.path.join(root, d)))
                if f.endswith(".md") and os.path.isfile(os.path.join(root, d, f))]
    return out


def read_meta(root, base):
    path = os.path.join(root, base)
    try:
        fm = parse_front(open(path, encoding="utf-8").read()) or {}
    except Exception:
        fm = {}
    def g(key, default="—"):
        v = (fm.get(key) or "").strip().strip('"').strip("'")
        return v if v else default
    return {"file": base, "kind": kind_of(os.path.basename(base)) or "unfiled",
            "title": g("title"), "type": g("type"), "status": g("status"),
            "project": g("project", ""),
            "updated": g("updated") or g("created") or g("timestamp")}


def build_index(root):
    import datetime
    slug = os.path.basename(os.path.normpath(root))
    rows = [read_meta(root, f) for f in artifacts(root)]
    groups = {}
    for r in rows:
        groups.setdefault(r["kind"], []).append(r)
    # pipeline first, meta last, kinds alphabetical between
    order = ([k for k in ["pipeline"] if k in groups]
             + sorted(k for k in groups if k not in ("pipeline", "meta"))
             + [k for k in ["meta"] if k in groups])

    # provenance is inherited from the artifacts, never hardcoded — this script is
    # canonical tooling and must carry no single project's identifiers.
    seen = [r["project"] for r in rows if r["project"]]
    proj = max(set(seen), key=seen.count) if seen else None

    out = (["---", "type: note", f'title: "Index — {slug}"']
           + ([f"project: {proj}"] if proj else [])
           + [f"updated: {datetime.date.today().isoformat()}",
           "status: current", "schema: okf-adapted-v0.1",
           "tags: [prp, index, generated]", "---", "",
           f"# Index — {slug}", "", GEN_MARK, "",
           f"{len(rows)} artifact(s) at the artifact level — the slug root and its kind "
           "folders. Opaque subdirectories are listed by name only "
           "(see `.claude/prp-naming.md`).", ""])
    for k in order:
        g = groups[k]
        out += [f"## {k} ({len(g)})", "",
                "| file | title | status | updated |", "|---|---|---|---|"]
        for r in sorted(g, key=lambda r: r["file"]):
            out.append(f"| `{r['file']}` | {r['title']} | {r['status']} | {r['updated']} |")
        out.append("")
    subs = sorted(d for d in os.listdir(root)
                  if os.path.isdir(os.path.join(root, d)) and d not in kind_dirs(root))
    if subs:
        out += ["## subdirectories (not indexed)", ""]
        out += [f"- `{d}/`" for d in subs] + [""]
    return "\n".join(out)


def write_index(root, quiet=False):
    path = os.path.join(root, INDEX_NAME)
    content = build_index(root)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)
    if not quiet:
        print(f"wrote {path} ({len(artifacts(root))} artifact(s), {len(content)} bytes)")
    return 0


def index_problems(root):
    """Staleness of index.md vs the artifacts. Empty list = current."""
    path = os.path.join(root, INDEX_NAME)
    files = artifacts(root)
    if not files:
        return []
    if not os.path.exists(path):
        return [f"{INDEX_NAME} missing — run: "
                f"python3 .claude/hooks/check-prp-naming.py --index {root}"]
    try:
        text = open(path, encoding="utf-8").read()
    except Exception as e:
        return [f"{INDEX_NAME} unreadable: {e}"]
    probs = [f"{INDEX_NAME} does not list '{f}'" for f in files if f not in text]
    # Staleness is a CONTENT question, not a timestamp one. An mtime comparison answers
    # "was the index written last?", which diverges from "is the index wrong?" on every
    # write that does not change what the index renders — ticking a checkbox, or a bare
    # touch. That fired on a clean slug reporting "0 file(s) with problems", which trains
    # people to regenerate reflexively and stop reading the output. Rebuilding in memory
    # and diffing catches the case the mtime check existed for (frontmatter title/status
    # changed while the filename stayed put) with no false positives.
    try:
        if build_index(root).strip() != text.strip():
            probs.append(f"{INDEX_NAME} content is stale — run: "
                         f"python3 .claude/hooks/check-prp-naming.py --index {root}")
    except Exception as e:                              # never fail the audit on the check itself
        probs.append(f"{INDEX_NAME} could not be rebuilt for comparison: {e}")
    return probs


def audit(root):
    failed = 0
    for f in artifacts(root):
        p = os.path.join(root, f)
        try:
            probs = check(p, open(p, encoding="utf-8").read())
        except Exception as e:                          # unreadable => report, don't crash
            probs = [f"unreadable: {e}"]
        if probs:
            failed += 1
            print(f"FAIL {p}")
            for x in probs:
                print(f"     - {x}")
    sprob = slug_problem(root, "")
    if sprob:
        print(f"FAIL {root}\n     - {sprob}")
    iprobs = index_problems(root)
    for x in iprobs:
        print(f"FAIL {os.path.join(root, INDEX_NAME)}\n     - {x}")
    total = failed + len(iprobs) + (1 if sprob else 0)
    print(f"\n{'FAIL' if total else 'PASS'}: {failed} file(s) with problems, "
          f"{len(iprobs)} index problem(s)")
    return 1 if total else 0


def file_strays(root):
    """Move slug-root artifacts into their kind folder. The veto catches a Write; a file
    created by Bash (cat > …) or pulled by rclone arrives here instead."""
    moved = []
    for f in sorted(os.listdir(root)):
        src = os.path.join(root, f)
        if not f.endswith(".md") or not os.path.isfile(src):
            continue
        if f == INDEX_NAME or f in EXEMPT or f.startswith("prd-"):
            continue
        k = kind_of(f)
        if k in (None, "pipeline", "meta"):
            continue                                    # unknown kind: report, never guess
        dst = os.path.join(root, k, f)
        if os.path.exists(dst):
            continue                                    # collision: leave it for a human
        os.makedirs(os.path.join(root, k), exist_ok=True)
        os.rename(src, dst)
        moved.append(f"{f} -> {k}/")
    return moved


def index_all(prps="/.claude/PRPs"):
    """Regenerate every slug index. Sweep at a session boundary — unlike the Write
    hook, this sees files however they arrived (Bash, rclone, a concurrent session)."""
    root = os.path.join(os.getcwd(), ".claude", "PRPs")
    if not os.path.isdir(root):
        return 0                                        # not this repo; stay quiet
    n = 0
    for slug in sorted(os.listdir(root)):
        d = os.path.join(root, slug)
        if slug.startswith("_") or not os.path.isdir(d):
            continue                                    # _templates/_profiles hold no artifacts
        try:
            strays = file_strays(d)
            for m in strays:
                print(f"filed {slug}/{m}")
            if artifacts(d):
                write_index(d, quiet=True)
                n += 1
        except Exception as e:                          # never break session start
            print(f"skipped {slug}: {e}")
    if n:
        print(f"PRP index refreshed ({n} slug(s))")
    return 0


def main():
    if "--index-all" in sys.argv:
        sys.exit(index_all())
    if "--index" in sys.argv:
        sys.exit(write_index(sys.argv[sys.argv.index("--index") + 1]))
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
    if not (len(tail) == 2 or (len(tail) == 3 and tail[1] in KIND_TYPES)):
        sys.exit(0)                                     # deeper => opaque subdirectory
    slug_dir = path.rsplit("/.claude/PRPs/", 1)[0] + "/.claude/PRPs/" + tail[0]
    probs = check(path, ti.get("content", "") or "")
    sp = slug_problem(slug_dir, os.path.basename(path))
    if sp:
        probs.insert(0, sp)
    if probs:
        print("BLOCKED (PRP naming convention — .claude/prp-naming.md)\n"
              + "\n".join(f"  - {p}" for p in probs)
              + "\nFix the filename or the frontmatter and retry.", file=sys.stderr)
        sys.exit(2)
    sys.exit(0)


if __name__ == "__main__":
    main()
