#!/usr/bin/env bash
# test-promote.sh — negative control for promote.sh's private-details check.
#
#   clean file             -> promoted as-is
#   private file           -> refused, nothing copied, non-zero exit
#   private file, --scrub  -> promoted with the private details replaced by tokens
# --mutate breaks promote.sh two ways; each break must be caught.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PROMOTE="${PROMOTE:-$HERE/promote.sh}"

run() { # $1 = promote.sh to test; returns failure count
  local fails=0 T C P rc
  T="$(mktemp -d)"; C="$T/canon"; P="$T/project"
  mkdir -p "$C/scripts" "$P/tools"
  cp "$HERE/verify-clean.py" "$HERE/scrub.py" "$C/scripts/"
  [ -f "$HERE/denylist.local.json" ] && cp "$HERE/denylist.local.json" "$C/scripts/"
  git -C "$P" init -q
  printf 'echo generic\n' > "$P/tools/clean.sh"
  printf 'echo ask %s@%s\n' someone client-domain.org > "$P/tools/private.sh"  # built at run time: this file must pass the public-repo scan
  ok() { [ -n "${QUIET:-}" ] || echo "ok   $1"; }
  bad() { [ -n "${QUIET:-}" ] || echo "BAD  $1"; fails=$((fails+1)); }

  (cd "$P" && CLYBOR_TOOLING="$C" bash "$1" tools/clean.sh >/dev/null 2>&1); rc=$?
  [ "$rc" = 0 ] && cmp -s "$P/tools/clean.sh" "$C/tools/clean.sh" && ok "clean file promoted as-is" || bad "clean file promoted as-is (rc=$rc)"

  (cd "$P" && CLYBOR_TOOLING="$C" bash "$1" tools/private.sh >/dev/null 2>&1); rc=$?
  [ "$rc" != 0 ] && [ ! -e "$C/tools/private.sh" ] && ok "private file refused, nothing copied" || bad "private file refused (rc=$rc)"

  (cd "$P" && CLYBOR_TOOLING="$C" bash "$1" --scrub tools/private.sh >/dev/null 2>&1); rc=$?
  if [ "$rc" = 0 ] && [ -f "$C/tools/private.sh" ] && ! grep -q "client-domain" "$C/tools/private.sh" \
     && grep -q "client-domain" "$P/tools/private.sh"; then ok "--scrub promotes a cleaned copy, project keeps its own"
  else bad "--scrub promotes a cleaned copy (rc=$rc)"; fi

  rm -rf "$T"; return "$fails"
}

run "$PROMOTE"; fails=$?
echo
[ "$fails" = 0 ] || { echo "FAIL: $fails case(s) wrong"; exit 1; }
echo "PASS: all cases right"
[ "${1:-}" = "--mutate" ] || exit 0

echo; survived=0
mutant() {
  local M; M="$(mktemp)"
  python3 -c "s=open('$PROMOTE').read(); old,new=$2; assert s.count(old)==1, old; open('$M','w').write(s.replace(old,new))" || exit 2
  if QUIET=1 run "$M"; then echo "SURVIVED — $1"; survived=$((survived+1)); else echo "caught   — $1"; fi
  rm -f "$M"
}
mutant "private details are never checked"  "('  if ! findings=\"\$(private_findings \"\$src\")\"; then', '  if false; then')"
mutant "--scrub copies without scrubbing"   "('    else python3 \"\$CANON/scripts/scrub.py\" \"\$dst\"; fi', '    else true; fi')"
echo
[ "$survived" = 0 ] && echo "PASS: both breaks caught" || { echo "FAIL: $survived break(s) survived"; exit 1; }
