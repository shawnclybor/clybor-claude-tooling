#!/usr/bin/env bash
# test-classify-drift.sh — negative control for classify-drift.py.
#
# Builds a throwaway canonical repo and project repo holding one file per case, and
# requires each to get its label: BEHIND, AHEAD, BOTH, PRIVATE. Then breaks the
# classifier three ways (--mutate) and requires every break to be caught.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CLASSIFIER="$HERE/classify-drift.py"
T="$(mktemp -d)"; C="$T/canon"; P="$T/project"
mkdir -p "$C/scripts" "$P/scripts"
cp "$HERE/verify-clean.py" "$C/scripts/"   # PRIVATE uses the same scan as the commit gate
g() { git -C "$1" "${@:2}" >/dev/null 2>&1; }
for r in "$C" "$P"; do g "$r" init -q; g "$r" config user.email t@t; g "$r" config user.name t; done
w() { printf '%s\n' "$2" > "$1"; }

# behind: both had v1; canon moved to v2
w "$C/scripts/behind.sh" "echo v1"; w "$P/scripts/behind.sh" "echo v1"
# ahead: both had v1; the project moved to v2
w "$C/scripts/ahead.sh" "echo v1"; w "$P/scripts/ahead.sh" "echo v1"
# both: both had v1; each moved differently
w "$C/scripts/both.sh" "echo v1"; w "$P/scripts/both.sh" "echo v1"
# private: the project copy carries an email address
w "$C/scripts/private.sh" "echo v1"; w "$P/scripts/private.sh" "echo v1"
g "$C" add -A; g "$C" commit -qm v1; g "$P" add -A; g "$P" commit -qm v1
w "$C/scripts/behind.sh" "echo v2"
w "$P/scripts/ahead.sh"  "echo v2"
w "$C/scripts/both.sh"   "echo canon-v2"; w "$P/scripts/both.sh" "echo project-v2"
w "$P/scripts/private.sh" "echo v2 # ask $(printf '%s@%s' someone client-domain.org)"  # built at run time: the file itself must pass the public-repo scan
g "$C" add -A; g "$C" commit -qm v2; g "$P" add -A; g "$P" commit -qm v2

run() { # $1 = classifier -> prints failures, returns count
  local fails=0 got want rel
  while IFS=$'\t' read -r got rel _; do
    want="$(basename "$rel" .sh | tr a-z A-Z)"
    if [ "$got" = "$want" ]; then [ -n "${QUIET:-}" ] || echo "ok   $rel -> $got"
    else [ -n "${QUIET:-}" ] || echo "BAD  $rel -> $got (want $want)"; fails=$((fails+1)); fi
  done < <(python3 "$1" "$P" "$C" scripts/behind.sh scripts/ahead.sh scripts/both.sh scripts/private.sh)
  return "$fails"
}

run "$CLASSIFIER"; fails=$?
echo
[ "$fails" = 0 ] || { echo "FAIL: $fails case(s) wrong"; rm -rf "$T"; exit 1; }
echo "PASS: all four cases labelled right"

if [ "${1:-}" = "--mutate" ]; then
  echo
  survived=0
  mutant() { # $1 label, $2 python (old, new)
    local M="$C/scripts/classify-drift.py"
    python3 -c "s=open('$CLASSIFIER').read(); old,new=$2; assert s.count(old)==1, old; open('$M','w').write(s.replace(old,new))" || exit 2
    if QUIET=1 run "$M"; then echo "SURVIVED — $1"; survived=$((survived+1)); else echo "caught   — $1"; fi
  }
  mutant "private copies are not detected"   "('    if is_private(proj_file):', '    if False:')"
  mutant "behind and ahead are swapped"      "('        return \"BEHIND\"\n    if was_committed(project', '        return \"AHEAD\"\n    if was_committed(project')"
  mutant "history is ignored (all BOTH)"     "('            return True\n    return False', '            return False\n    return False')"
  echo
  [ "$survived" = 0 ] && echo "PASS: all 3 classifier breaks caught" || { echo "FAIL: $survived break(s) survived"; rm -rf "$T"; exit 1; }
fi
rm -rf "$T"
