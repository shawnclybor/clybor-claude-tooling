#!/usr/bin/env python3
"""Mechanically check a build plan for the defect classes that recur in this repo.

Honor-System Gates Fail — Codify as Scripts. build-plan requires DONE checks be
*binary*; it has no rule that they be *falsifiable*, and plan-template.md offers
"a string that grep finds" as a sanctioned form. Three validate rounds on
build-a-yellow-sheet each cleared ~30 findings and introduced 2-3 more, all from
six mechanical classes. This catches those six in seconds.

Usage:
  check-plan-soundness.py <plan.md> [--prd <prd.md>]   exit 1 if any check fails
  check-plan-soundness.py <plan.md> --quiet            errors only

Checks:
  1 self-satisfying DONE  — the DONE greps a literal its own task body wrote
  2 unauthored artifact   — a file in the acceptance test / checklist no task creates
  3 premature DONE        — a DONE depends on an artifact a later task authors
  4 criterion drift       — a criterion number missing from, or disagreeing across,
                            the PRD criteria table / PRD checklist / plan checklist
  5 dependency graph      — cycles, and edges naming tasks that do not exist
  6 duplicate task number
"""
import os
import re
import sys

TASK_RE = re.compile(
    r"^- \[[ x]\] \*\*(?P<num>(?:\d+[a-z]?|T[\w-]+))[.\s]\s*(?P<title>.*?)\*\*", re.M)
PCRIT_RE = re.compile(r"^- \[ \] (?P<id>P\d+)\s+(?P<text>.*)$", re.M)
CRIT_RE = re.compile(r"^- \[ \] (?P<num>\d+)\s+(?P<text>.*)$", re.M)
PRD_ROW_RE = re.compile(r"^\|\s*(?P<num>\d+)\s*\|(?P<rest>.*)\|\s*$", re.M)
PRD_CHECK_RE = re.compile(r"^- \[ \] (?P<num>\d+):\s*(?P<text>.*)$", re.M)
# a filename we care about: name.ext, optionally with directories
FILE_RE = re.compile(r"[\w./-]+\.(?:py|sh|json|md|docx|js|txt|xlsx)\b")
# strings a DONE greps for
GREP_RE = re.compile(r"""grep[^`\n]*?['"]([^'"]{4,})['"]""")
CONTAINS_RE = re.compile(r"""(?:contains|names|states|hits)\s+[`'"]([^`'"]{4,})[`'"]""")

STOP_FILES = {"plan.md", "prd.md", "validate.md", "evaluate.md", "index.md", "README.md"}


def parse_tasks(text):
    """Return [(num, title, body, done)] — body is everything before 'DONE:'."""
    out = []
    marks = [(m.start(), m.group("num"), m.group("title")) for m in TASK_RE.finditer(text)]
    for i, (start, num, title) in enumerate(marks):
        end = marks[i + 1][0] if i + 1 < len(marks) else len(text)
        chunk = text[start:end]
        # a task ends at the next markdown heading if one intervenes
        h = re.search(r"^#{2,4} ", chunk, re.M)
        if h:
            chunk = chunk[: h.start()]
        # The DONE clause is the LAST "DONE:" in the task — a task body may legitimately
        # mention the word (e.g. "Task 50's own DONE requires..."), and splitting on the first
        # occurrence swallows half the body into the DONE and mis-attributes its references.
        ms = list(re.finditer(r"\bDONE:", chunk)) or list(re.finditer(r"\bDONE\b", chunk))
        body, done = (chunk[: ms[-1].start()], chunk[ms[-1].start():]) if ms else (chunk, "")
        out.append((num, title.strip(), body, done))
    return out


def dep_edges(text):
    """Parse the explicit dependency line into (u, v) edges."""
    if "### Dependency order, explicitly" not in text:
        return [], False
    dep = text.split("### Dependency order, explicitly")[1].split("\n##")[0]
    edges = []
    for chain in re.findall(r"`([^`]+)`", dep):
        if "→" not in chain:
            continue
        parts = [p.strip() for p in chain.split("→")]

        def nodes(tok):
            tok = tok.strip().strip("{}")
            out = []
            for x in tok.split(","):
                x = x.strip()
                rng = re.search(r"(\d+)\s*-\s*(\d+)", x)
                if rng and "all of" in tok.lower():
                    out += [str(i) for i in range(int(rng.group(1)), int(rng.group(2)) + 1)]
                elif re.fullmatch(r"\d+[a-z]?", x):
                    out.append(x)
            return out

        for a, b in zip(parts, parts[1:]):
            for u in nodes(a):
                for v in nodes(b):
                    edges.append((u, v))
    return edges, True


def find_cycles(edges):
    g = {}
    for u, v in edges:
        g.setdefault(u, set()).add(v)
    colour, cycles = {}, []
    def walk(u, stack):
        colour[u] = 1
        stack.append(u)
        for v in g.get(u, ()):
            c = colour.get(v, 0)
            if c == 1:
                cycles.append(stack[stack.index(v):] + [v])
            elif c == 0:
                walk(v, stack)
        colour[u] = 2
        stack.pop()
    for u in list(g):
        if colour.get(u, 0) == 0:
            walk(u, [])
    return cycles


def reachable_before(edges, target):
    """Tasks that must precede `target` per the declared edges."""
    rev = {}
    for u, v in edges:
        rev.setdefault(v, set()).add(u)
    seen, stack = set(), [target]
    while stack:
        cur = stack.pop()
        for p in rev.get(cur, ()):
            if p not in seen:
                seen.add(p)
                stack.append(p)
    return seen


AUTHOR_VERB = (r"(?:author|write|writes|create|creates|add|adds|new|produce|produces|"
               r"emit|emits|ship|ships|rename|renames|extract|extracts|build|builds|"
               r"implement|implements|copy|copies|vendor|vendors|capture|captures|"
               r"save|saves|seed|seeds|place|places|generate|generates|commit|commits|run)")
# this plan's idiom is "**N. Title** — `path/file.ext`, what it does": the file in
# subject position, with no verb. Treat the head of the body as authorship.
SUBJECT_WINDOW = 200


def author_map(tasks):
    """filename -> the task that actually AUTHORS it.

    Mentioning a file is not authoring it: Task 1 names validate-skill.py, Task 8
    runs run-tests.sh. Require either the filename in the task title, or an
    authoring verb within ~90 chars before it in the body. Files nobody claims are
    treated as pre-existing and never produce a premature-DONE.
    """
    authors = {}
    for num, title, body, _done in tasks:
        titled = {os.path.basename(f) for f in FILE_RE.findall(title)}
        claimed = set(titled)
        claimed |= {os.path.basename(f) for f in FILE_RE.findall(body[:SUBJECT_WINDOW])}
        for m in re.finditer(AUTHOR_VERB + r"[^.\n]{0,90}?(" + FILE_RE.pattern + ")",
                             body, re.I):
            claimed.add(os.path.basename(m.group(1)))
        for base in claimed:
            if base in STOP_FILES:
                continue
            authors.setdefault(base, num)
    return authors


def check(plan_path, prd_path=None, quiet=False):
    text = open(plan_path, encoding="utf-8").read()
    tasks = parse_tasks(text)
    problems = []
    if not tasks:
        print("PARSE ERROR: no tasks matched. Expected checklist lines shaped\n"
              "  - [ ] **12. Title** — body. DONE: check.\n"
              "  - [ ] **T3a Title** — body. DONE: check.\n"
              "Refusing to report — with no tasks parsed every artifact would look unauthored.")
        return 2

    def bad(kind, msg):
        problems.append((kind, msg))

    # ---- 6 duplicate task numbers -------------------------------------------
    seen = {}
    for num, title, _b, _d in tasks:
        if num in seen:
            bad("dup-task", "task %s defined twice (%r / %r)" % (num, seen[num], title))
        seen[num] = title

    # ---- 1 self-satisfying DONE ---------------------------------------------
    for num, _title, body, done in tasks:
        if not done.strip():
            bad("no-done", "task %s has no DONE check" % num)
            continue
        body_l = body.lower()
        targets = set(GREP_RE.findall(done)) | set(CONTAINS_RE.findall(done))
        for t in targets:
            t_clean = t.strip()
            # a grep for a filename or a shell flag is fine; prose is not
            if FILE_RE.fullmatch(t_clean) or t_clean.startswith("-"):
                continue
            if len(t_clean.split()) < 2 and "-" not in t_clean and "_" not in t_clean:
                continue
            if t_clean.lower() in body_l:
                bad("self-satisfying",
                    "task %s DONE greps %r, which its own body already writes" % (num, t_clean))

    # ---- 5 dependency graph --------------------------------------------------
    edges, have_dep = dep_edges(text)
    defined = {t[0] for t in tasks}
    if have_dep:
        for u, v in edges:
            for x in (u, v):
                if x not in defined:
                    bad("undefined-task", "dependency edge names task %s, which does not exist" % x)
        for cyc in find_cycles(edges):
            bad("cycle", "dependency cycle: " + " -> ".join(cyc))
    else:
        bad("no-dep-order", "plan has no '### Dependency order, explicitly' section")

    # ---- 3 premature DONE ----------------------------------------------------
    # A plan may declare tasks that land in ONE commit; ordering among them is moot.
    # Syntax anywhere in the plan:  <!-- soundness: same-commit 24,47,55 -->
    same = set()
    for m in re.finditer(r"<!--\s*soundness:\s*same-commit\s+([\d,\sab]+)-->", text):
        grp = {x.strip() for x in m.group(1).split(",") if x.strip()}
        same |= {(a, b) for a in grp for b in grp if a != b}

    authors = author_map(tasks)
    shared = {}                      # file -> every task an explicit map lists as an owner
    # An explicit authorship map is authoritative over the heuristic. This is the
    # phi-guard remedy the five-whys identified and build-plan never adopted.
    for m in re.finditer(r"^\|([^|]*`[^|]*)\|\s*([^|]+?)\s*\|\s*$", text, re.M):
        cell, owner = m.group(1), m.group(2).strip().strip("*").strip()
        if not re.match(r"^(?:\d+[a-z]?|T[\w-]+)", owner):
            continue
        owners = [o.strip().strip("*") for o in owner.split("/")]
        owners = [o.split()[0] for o in owners if o.split()]
        for f in re.findall(r"`([^`]+)`", cell):      # a cell may list several files
            authors[os.path.basename(f)] = owners[0]
            shared.setdefault(os.path.basename(f), set()).update(owners)
    for infra in ("phi-scan.py", "validate-skill.py", "check-tracker.py",
                  "run_all_gates.sh", "build_yellow_sheet.js"):
        authors.pop(infra, None) if infra in ("phi-scan.py",) else None
    done_nums = {m.group("num") for m in re.finditer(r"^- \[x\] \*\*(?P<num>\d+[a-z]?)\.", text, re.M)}
    for num, _title, _body, done in tasks:
        if num in done_nums:
            continue                      # already executed; ordering is moot
        preds = reachable_before(edges, num) if have_dep else set()
        for f in set(FILE_RE.findall(done)):
            base = os.path.basename(f)
            owner = authors.get(base)
            if owner is None or owner == num:
                continue
            if num in shared.get(base, ()):      # co-owner per the authorship map
                continue
            if owner not in preds and (owner, num) not in same:
                bad("premature-done",
                    "task %s DONE uses %s, authored by task %s, with no declared %s -> %s edge"
                    % (num, base, owner, owner, num))

    # ---- 2 unauthored artifact ----------------------------------------------
    checklist = "\n".join(m.group(0) for m in PCRIT_RE.finditer(text))
    checklist += "\n" + "\n".join(m.group(0) for m in CRIT_RE.finditer(text))
    accept = ""
    if "## Acceptance test" in text:
        accept = text.split("## Acceptance test")[1].split("\n## ")[0]
    reported = set()
    for f in sorted({os.path.basename(x) for x in FILE_RE.findall(checklist + accept)}):
        base = f
        if base in STOP_FILES or base in authors or base in reported:
            continue
        reported.add(base)
        # pre-existing hub/infra files are not authored by this plan
        if base in ("run_all_gates.sh", "validate-skill.py", "check-tracker.py", "phi-scan.py",
                    "vendor-untrusted-block.py", "phi-scan.py", "SkillsHub.xlsx"):
            continue
        bad("unauthored", "%s is used by the acceptance test / checklist but no task authors it" % base)

    # ---- 4 criterion drift ---------------------------------------------------
    if prd_path and os.path.exists(prd_path):
        prd = open(prd_path, encoding="utf-8").read()
        table = {}
        if "### Success criteria" in prd:
            seg = prd.split("### Success criteria")[1].split("\n#### ")[0]
            for m in PRD_ROW_RE.finditer(seg):
                table[m.group("num")] = m.group("rest")
        prd_check = {m.group("num"): m.group("text") for m in PRD_CHECK_RE.finditer(prd)}
        plan_check = {m.group("num"): m.group("text") for m in CRIT_RE.finditer(text)}
        for num in sorted(table, key=int):
            if num not in prd_check:
                bad("criterion-drift", "PRD criterion %s has no PRD acceptance-checklist line" % num)
            if num not in plan_check:
                bad("criterion-drift", "PRD criterion %s has no plan acceptance-checklist line" % num)
            # cheap disagreement signal: a distinctive token in one and absent from both others
            for tok in ("no new reds", "refuse-to-render"):
                in_t = tok in table.get(num, "").lower()
                in_p = tok in prd_check.get(num, "").lower()
                in_l = tok in plan_check.get(num, "").lower()
                if in_t != in_p or in_t != in_l:
                    if in_t or in_p or in_l:
                        bad("criterion-drift",
                            "criterion %s: %r appears in %s but not the others"
                            % (num, tok,
                               ", ".join(n for n, f in
                                         (("PRD table", in_t), ("PRD checklist", in_p), ("plan checklist", in_l))
                                         if f)))

    # ---- report --------------------------------------------------------------
    by_kind = {}
    for kind, msg in problems:
        by_kind.setdefault(kind, []).append(msg)
    for kind in sorted(by_kind):
        print("%s (%d)" % (kind.upper(), len(by_kind[kind])))
        for msg in by_kind[kind]:
            print("  - " + msg)
        print()
    print("%d task(s) parsed, %d dependency edge(s)" % (len(tasks), len(edges)))
    if problems:
        print("FAIL: %d problem(s)" % len(problems))
        return 1
    print("PASS: plan is mechanically sound")
    return 0


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        print(__doc__)
        return 2
    prd = None
    if "--prd" in sys.argv:
        i = sys.argv.index("--prd")
        if i + 1 < len(sys.argv):
            prd = sys.argv[i + 1]
            args = [a for a in args if a != prd]
    if prd is None:
        guess = os.path.join(os.path.dirname(args[0]), "prd.md")
        cand = [f for f in os.listdir(os.path.dirname(args[0]) or ".") if f.startswith("prd")]
        prd = guess if os.path.exists(guess) else (
            os.path.join(os.path.dirname(args[0]), cand[0]) if cand else None)
    return check(args[0], prd, "--quiet" in sys.argv)


if __name__ == "__main__":
    sys.exit(main())
