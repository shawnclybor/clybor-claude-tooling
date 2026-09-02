#!/usr/bin/env bash
# test-empty-prose.sh — negative control for check-empty-prose.py.
#
# Both directions, per the house rule that a detector nobody has tried to fool is
# just an opinion with a script around it:
#
#   M1-M5  mutants — must be caught, and caught ON THE CLASS THE ROW NAMES.
#          Asserting "something was flagged" would pass even if every mutant
#          tripped the same pattern; the class assertion is what makes it a test.
#   C1-C5  clean controls — must NOT fire at all. These are the ones that matter.
#          check-plan-soundness.py lost a check that fired 32 times on a sound
#          plan; false positives are how a gate stops being a gate.
#   K1     known limit — a fluent, empty sentence that is on NO list. The script
#          is EXPECTED to miss it. That miss is why writing-quality's ONE QUESTION
#          exists. If K1 ever starts failing, someone widened a pattern; check
#          that C1-C5 still pass before celebrating.
#
# Usage: bash .claude/hooks/test-empty-prose.sh

set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 1

GATE="${GATE:-.claude/hooks/check-empty-prose.py}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0

ok()   { printf '  ok   %-4s %s\n' "$1" "$2"; pass=$((pass+1)); }
bad()  { printf '  FAIL %-4s %s\n' "$1" "$2"; fail=$((fail+1)); }

# assert_catches <id> <class> <prose...>
assert_catches() {
  local id="$1" cls="$2" file="$TMP/$1.md"
  shift 2
  printf '%s\n' "$*" > "$file"
  local out rc
  out="$(python3 "$GATE" "$file" --quiet 2>&1)"; rc=$?
  if [[ $rc -ne 1 ]]; then
    bad "$id" "expected a finding, got exit $rc"
  elif ! printf '%s' "$out" | grep -q "\[$cls\]"; then
    bad "$id" "caught, but not on [$cls] — got: $(printf '%s' "$out" | head -1)"
  else
    ok "$id" "[$cls] caught"
  fi
}

# assert_clean <id> <label> ; body on stdin
assert_clean() {
  local id="$1" label="$2" file="$TMP/$1.md"
  cat > "$file"
  local out rc
  out="$(python3 "$GATE" "$file" --quiet 2>&1)"; rc=$?
  if [[ $rc -eq 0 ]]; then
    ok "$id" "$label"
  else
    bad "$id" "$label — false positive: $(printf '%s' "$out" | head -2 | tr '\n' ' ')"
  fi
}

echo "MUTANTS — each must be caught on its own class"

assert_catches M1 slogan \
  "We check the spec against reality before planning, which keeps the work honest."

assert_catches M2 grandiosity \
  "This seamless, best-in-class workflow will revolutionize how engineering teams ship software."

assert_catches M3 filler \
  "There are a number of reasons for this, and it is worth noting that several key factors apply here."

assert_catches M4 insider-term \
  "Run check-plan-soundness.py before the review round, then read SKILL.md for the rest of the contract."

assert_catches M5 flourish \
  "The outcome was truly remarkable, and stands as a testament to what the group achieved together."

echo
echo "CLEAN CONTROLS — must not fire"

assert_clean C1 "plain technical prose on the same subject" <<'EOF'
The script opens the file, counts the rows, and prints the number.
Compare that number to the one written in the spec. If they differ, the
spec was written before somebody edited the file, and the plan built on
it is wrong. This takes about four seconds to find out.
EOF

assert_clean C2 "filenames inside code spans are exempt" <<'EOF'
Run `check-plan-soundness.py` before the review, and read the notes in
`SKILL.md` if the output is unclear. Neither of those is prose — they are
names of things you type, so they belong in code formatting.
EOF

assert_clean C3 "fenced code blocks are exempt" <<'EOF'
Call the search tool rather than the built-in one:

```
mcp__brave-search__brave_web_search(query="...", count=10)
```

The governance rule exists because the built-in tool bypasses the local layer.
EOF

assert_clean C4 "frontmatter and HTML attributes are exempt" <<'EOF'
---
name: some-skill
description: a number of things, truly world-class
---

<div class="wrap" data-note="seamless best-in-class">
The page shows the count next to the figure it came from.
</div>
EOF

assert_clean C5 "the rewritten blog copy — dogfood" <<'EOF'
A spec is full of statements of fact. The test suite has 683 checks. The
bills folder has 41 files. Every bill names a provider. All true when
someone typed them. Some are false a week later, because a file moved, a
document got edited, or somebody else changed a script. Nothing in the
document knows it has gone stale. It reads exactly the same either way.
EOF

assert_clean C6 "explicit suppression region for a rulebook's own examples" <<'EOF'
Do not write like this. The banned phrases are listed below as examples.

<!-- empty-prose: off -->
- "at its core"
- "seamless, best-in-class, revolutionize"
- "truly a testament to"
<!-- empty-prose: on -->

Anything outside that region is still scanned normally.
EOF

echo
echo "KNOWN LIMIT — the script is expected to miss this"

K1="$TMP/K1.md"
cat > "$K1" <<'EOF'
We align the implementation with the underlying intent of the system, so
that each component reflects the shape of the problem it was built to solve.
EOF
if python3 "$GATE" "$K1" --quiet >/dev/null 2>&1; then
  ok   K1 "missed, as documented — novel emptiness needs the ONE QUESTION, not a list"
else
  bad  K1 "unexpectedly caught — a pattern was widened; re-verify C1-C5 before keeping it"
fi

echo
echo "-----------------------------------------"
printf 'passed %d, failed %d\n' "$pass" "$fail"
[[ $fail -eq 0 ]] || exit 1
