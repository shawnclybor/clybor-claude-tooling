#!/usr/bin/env bash
# Negative control for review-drift.py.
#
# A drift detector that always says "drift" is as useless as one that never does. This seeds
# both directions: a healthy review history must come back clean, and each of the four drift
# mechanisms must be caught on its own, not just in aggregate.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
D="$HERE/review-drift.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
ok()   { echo "  ok   $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL $1"; fail=$((fail+1)); }

# fresh target per case so histories never bleed
new() { printf 'seed %s\n' "$1" > "$TMP/$1.md"; echo "$TMP/$1.md"; }
bump(){ echo "change $RANDOM" >> "$1"; }

green() { python3 "$D" check "$1" >/dev/null 2>&1 && ok "$2" || bad "$2 — expected clean, got drift"; }
red()   { python3 "$D" check "$1" 2>&1 | grep -q "$3" && ok "$2" || bad "$2 — expected $3, not detected"; }

echo "baseline"
t=$(new single); python3 "$D" record "$t" --must 3 --should 1 --note 1 >/dev/null
green "$t" "a single round cannot be assessed and does not cry drift"

t=$(new healthy)
python3 "$D" record "$t" --must 6 --should 4 --note 3 >/dev/null
bump "$t"; python3 "$D" record "$t" --must 2 --should 3 --note 5 >/dev/null
bump "$t"; python3 "$D" record "$t" --must 0 --should 2 --note 4 >/dev/null
green "$t" "healthy review (6->2->0, target changing) stays clean"

echo
echo "each mechanism, isolated"

t=$(new ratchet)
for n in 2 1 1; do bump "$t"; python3 "$D" record "$t" --must $n >/dev/null; done
red "$t" "ratchet: never comes back clean" "RATCHET"

t=$(new inflation)
python3 "$D" record "$t" --must 5 >/dev/null
python3 "$D" record "$t" --must 9 >/dev/null          # no bump: identical target
red "$t" "inflation: count rises on an unchanged target" "INFLATION"

t=$(new selfinflicted)
python3 "$D" record "$t" --must 4 >/dev/null
bump "$t"; python3 "$D" record "$t" --must 6 --self-inflicted 4 >/dev/null
red "$t" "self-inflicted: the loop generates its own findings" "SELF-INFLICTED"

t=$(new regrade)
python3 "$D" record "$t" --must 3 >/dev/null
python3 "$D" record "$t" --must 3 >/dev/null          # identical target, same count
red "$t" "re-grade: unchanged bytes, still must-fix" "RE-GRADE"

t=$(new cap)
for n in 1 1 1; do bump "$t"; python3 "$D" record "$t" --must $n >/dev/null; done
bump "$t"; python3 "$D" record "$t" --must 1 >/dev/null
red "$t" "cap: a 4th round with no written reason" "CAP"

t=$(new capexcused)
for n in 1 1 1; do bump "$t"; python3 "$D" record "$t" --must $n >/dev/null; done
bump "$t"; python3 "$D" record "$t" --must 1 --round-note "PRD rewritten; new target" >/dev/null
python3 "$D" check "$t" 2>&1 | grep -q "CAP" \
  && bad "cap with a written reason should not fire CAP" \
  || ok "cap: a written reason suppresses the CAP signal"

t=$(new rubricmoved); R="$TMP/rubric-copy.md"
printf 'must-fix: original bar\n' > "$R"
bump "$t"; python3 "$D" record "$t" --must 2 --rubric "$R" >/dev/null
printf 'must-fix: a STRICTER bar\n' > "$R"          # the standard changed silently
bump "$t"; python3 "$D" record "$t" --must 5 --rubric "$R" >/dev/null
red "$t" "rubric moved: the bar changed with no reason recorded" "RUBRIC MOVED"

t=$(new rubricexcused); R2="$TMP/rubric-copy2.md"
printf 'must-fix: original bar\n' > "$R2"
bump "$t"; python3 "$D" record "$t" --must 2 --rubric "$R2" >/dev/null
printf 'must-fix: a STRICTER bar\n' > "$R2"
bump "$t"; python3 "$D" record "$t" --must 5 --rubric "$R2" --round-note "bar tightened deliberately" >/dev/null
python3 "$D" check "$t" 2>&1 | grep -q "RUBRIC MOVED" \
  && bad "a recorded reason should suppress RUBRIC MOVED" \
  || ok "rubric moved: a written reason suppresses the signal"

echo
echo "=================================="
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ] || exit 1
