#!/usr/bin/env bash
# Negative control for check-plan-soundness.py.
#
# A verifier that never fails is not a verifier. This seeds one defect per check
# class into a copy of a known-good plan and requires the checker to go red on
# each, then requires it to go green on the unmodified copy.
#
# Usage: test-plan-soundness.sh [plan.md] [prd.md]
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/check-plan-soundness.py"
PLAN="${1:-$HERE/../PRPs/build-a-yellow-sheet/plan.md}"
PRD="${2:-$HERE/../PRPs/build-a-yellow-sheet/prd-yellow-sheet.md}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
run() { python3 "$CHECK" "$1" --prd "$PRD" >/dev/null 2>&1; echo $?; }

green() {  # $1 label, $2 file — expect exit 0
  if [ "$(run "$2")" = "0" ]; then echo "  ok   $1"; pass=$((pass+1))
  else echo "  FAIL $1 — expected PASS, got FAIL"; fail=$((fail+1)); fi
}
red() {    # $1 label, $2 file — expect non-zero
  if [ "$(run "$2")" != "0" ]; then echo "  ok   $1"; pass=$((pass+1))
  else echo "  FAIL $1 — checker stayed green on a seeded defect"; fail=$((fail+1)); fi
}

echo "baseline"
cp "$PLAN" "$TMP/clean.md"
green "unmodified plan passes" "$TMP/clean.md"

echo
echo "seeded defects — each must turn the checker red"

# 1 self-satisfying DONE: grep for a phrase the task body itself writes
python3 - "$TMP/clean.md" "$TMP/d1.md" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
import re
_m = re.search(r"^- \[[ x]\] \*\*6\. Money parsing module\*\*", s, re.M)
assert _m, "seed needle for Task 6 no longer matches the live plan -- the selftest cannot seed this defect"
s = s.replace(_m.group(0),
  "- [ ] **99. Bogus task** — this body contains the phrase quantum-marmalade-token. DONE: `grep -q \"quantum-marmalade-token\" out.md` hits.\n" + _m.group(0), 1)
open(sys.argv[2], "w", encoding="utf-8").write(s)
PY
red "self-satisfying DONE" "$TMP/d1.md"

# 2 unauthored artifact referenced by the acceptance test
python3 - "$TMP/clean.md" "$TMP/d2.md" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
s = s.replace("## Acceptance test", "## Acceptance test\n\nAlso runs `tests/nobody-authors-this.sh`.\n", 1)
open(sys.argv[2], "w", encoding="utf-8").write(s)
PY
red "unauthored artifact" "$TMP/d2.md"

# 3 dependency cycle
python3 - "$TMP/clean.md" "$TMP/d3.md" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
s = s.replace("### Dependency order, explicitly",
              "### Dependency order, explicitly\n\n`7 → 8` · `8 → 7`\n", 1)
open(sys.argv[2], "w", encoding="utf-8").write(s)
PY
red "dependency cycle" "$TMP/d3.md"

# 4 dependency edge naming a task that does not exist
python3 - "$TMP/clean.md" "$TMP/d4.md" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
s = s.replace("### Dependency order, explicitly",
              "### Dependency order, explicitly\n\n`7 → 998`\n", 1)
open(sys.argv[2], "w", encoding="utf-8").write(s)
PY
red "undefined task in dependency order" "$TMP/d4.md"

# 5 duplicate task number
python3 - "$TMP/clean.md" "$TMP/d5.md" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
import re
_m = re.search(r"^- \[[ x]\] \*\*6\. Money parsing module\*\*", s, re.M)
assert _m, "seed needle for Task 6 no longer matches the live plan -- the selftest cannot seed this defect"
s = s.replace(_m.group(0),
  "- [ ] **7. Duplicate of seven** — filler. DONE: nothing.\n" + _m.group(0), 1)
open(sys.argv[2], "w", encoding="utf-8").write(s)
PY
red "duplicate task number" "$TMP/d5.md"

# 6 task with no DONE check at all
python3 - "$TMP/clean.md" "$TMP/d6.md" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
import re
_m = re.search(r"^- \[[ x]\] \*\*6\. Money parsing module\*\*", s, re.M)
assert _m, "seed needle for Task 6 no longer matches the live plan -- the selftest cannot seed this defect"
s = s.replace(_m.group(0),
  "- [ ] **97. No gate here** — this task states an intention and never says how it is checked.\n" + _m.group(0), 1)
open(sys.argv[2], "w", encoding="utf-8").write(s)
PY
red "task with no DONE check" "$TMP/d6.md"

# 7 T-prefixed task ids must produce dependency edges too. TASK_RE accepts `T3a`
# and `TR7-1`; if the edge parser does not, a T-id plan yields ZERO edges and the
# cycle / undefined-task / premature-DONE checks silently pass on anything.
python3 - "$TMP/clean.md" "$TMP/d7.md" <<'PY2'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
s = s.replace("### Dependency order, explicitly",
              "### Dependency order, explicitly\n\n`T9z → T8y` · `T8y → T9z`\n", 1)
s = s.replace("## Test authorship map",
  "- [ ] **T8y Filler eight** — filler. DONE: exits 0.\n"
  "- [ ] **T9z Filler nine** — filler. DONE: exits 0.\n\n## Test authorship map", 1)
open(sys.argv[2], "w", encoding="utf-8").write(s)
PY2
red "dependency cycle among T-prefixed task ids" "$TMP/d7.md"

# 8 a T-prefixed edge naming a task that does not exist must still be caught
python3 - "$TMP/clean.md" "$TMP/d8.md" <<'PY2'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
s = s.replace("### Dependency order, explicitly",
              "### Dependency order, explicitly\n\n`T8y → T404-nope`\n", 1)
s = s.replace("## Test authorship map",
  "- [ ] **T8y Filler eight** — filler. DONE: exits 0.\n\n## Test authorship map", 1)
open(sys.argv[2], "w", encoding="utf-8").write(s)
PY2
red "undefined T-prefixed task in dependency order" "$TMP/d8.md"

# 9 citing another slug's task bodies by NUMBER, with no sources.lock, is unpinned.
#   Added 2026-09-01: a plan folded task bodies from a sibling slug while a concurrent
#   session cut that slug 14 tasks -> 10. Six of seven citations changed meaning silently.
python3 - "$TMP/clean.md" "$TMP/d9.md" <<'PY2'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
s = s.replace("## Mandatory reading",
  "## Mandatory reading\n\n| `.claude/PRPs/other-slug/plan.md` | Tasks 1-11 | bodies cited, not copied |\n", 1)
open(sys.argv[2], "w", encoding="utf-8").write(s)
PY2
red "unpinned citation of a sibling slug's tasks" "$TMP/d9.md"

# 9b the same citation WITH a sources.lock reference must pass — the pin is the fix,
#    so the check must be satisfiable, not merely loud.
python3 - "$TMP/d9.md" "$TMP/d9b.md" <<'PY2'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
s = s.replace("## Mandatory reading",
  "Citations pinned in `probes/sources.lock`.\n\n## Mandatory reading", 1)
open(sys.argv[2], "w", encoding="utf-8").write(s)
PY2
green "pinned citation passes" "$TMP/d9b.md"

# 10 a DONE depending on "the runner" with no filename defeats the premature-DONE check
python3 - "$TMP/clean.md" "$TMP/d10.md" <<'PY2'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
s = s.replace("## Test authorship map",
  "- [ ] **T9z Filler nine** — filler. DONE: the runner reports it by name and exits 0.\n\n## Test authorship map", 1)
open(sys.argv[2], "w", encoding="utf-8").write(s)
PY2
red "DONE names an artifact only in prose" "$TMP/d10.md"

echo
echo "=================================="
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ] || exit 1
