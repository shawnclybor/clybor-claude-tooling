#!/usr/bin/env bash
# test-check-plugin-sync.sh - the promotion check must see a plugin's own sync path.
#
# Fixture = the 2026-11-11 miss: a hooks plugin's source edited, version left alone, bundle
# not rebuilt, installs a version behind, fix sitting on an unmerged branch.
#   in step                            -> no plugin finding
#   source edited, version unchanged   -> UNBUMPED
#   bumped + rebuilt, install still old -> INSTALLED-LAGS (and no UNBUMPED)
#   install updated                    -> quiet again
#   fix committed on a side branch     -> UNMERGED
#   plugin listed in promotion-ignore  -> no plugin finding (a retired plugin kept as history)
#   --gate with all of the above       -> still exit 0 (information, not a block)
#
#   bash scripts/test-check-plugin-sync.sh            # this checkout
#   CHECK=/path/old-check-promotion.sh bash ...       # another version (must go red if pre-fix)
#   bash scripts/test-check-plugin-sync.sh --mutate   # break the checker; each break must be caught
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="${CHECK:-$HERE/check-promotion.sh}"
SYNC="${SYNC:-$HERE/check-plugin-sync.py}"

run() { # $1 = check-promotion.sh, $2 = check-plugin-sync.py; returns failure count
  local fails=0 T C P S I out rc
  T="$(mktemp -d)"; C="$T/canon"; P="$T/project"; S="$P/cowork/demo-gate"; I="$T/installs"
  mkdir -p "$C/scripts" "$S/.claude-plugin" "$S/hooks" "$I/plugin_a/.claude-plugin"
  cp "$1" "$C/scripts/check-promotion.sh"
  [ -f "$2" ] && cp "$2" "$C/scripts/check-plugin-sync.py"
  ok()  { [ -n "${QUIET:-}" ] || echo "ok   $1"; }
  bad() { [ -n "${QUIET:-}" ] || echo "BAD  $1"; fails=$((fails+1)); }
  mf()  { printf '{"name":"demo-gate","version":"%s"}\n' "$1"; }
  pack() { python3 - "$S" "$P/cowork/demo-gate.plugin" <<'PY'
import os, sys, zipfile
src, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out, "w") as z:
    for root, _, names in os.walk(src):
        for n in names:
            p = os.path.join(root, n); z.write(p, os.path.relpath(p, src))
PY
  }
  probe() { (cd "$P" && CLYBOR_TOOLING="$C" CLYBOR_PLUGIN_INSTALL_GLOBS="$I/*" \
             bash "$C/scripts/check-promotion.sh" "${1:---surface}" 2>&1); }
  local em; em="$(printf '%s@%s' t example.invalid)"   # built at run time: this file must pass the public-repo scan
  g() { git -C "$P" -c user.name=t -c user.email="$em" "$@" >/dev/null 2>&1; }

  mf 1.0.0 > "$S/.claude-plugin/plugin.json"
  printf "export const ROOM = 'old-room'\n" > "$S/hooks/meeting.ts"
  pack
  mf 1.0.0 > "$I/plugin_a/.claude-plugin/plugin.json"
  g init -q -b main && g add -A && g commit -q -m base

  out="$(probe)"
  case "$out" in *demo-gate*) bad "in step: no plugin finding";; *) ok "in step: no plugin finding";; esac

  printf "export const ROOM = 'new-room'\n" > "$S/hooks/meeting.ts"   # the Nov 11 edit, no bump
  out="$(probe)"
  grep -q '\[UNBUMPED\] cowork/demo-gate/' <<<"$out" && ok "edited source, same version -> UNBUMPED" \
    || bad "edited source, same version -> UNBUMPED"

  mf 1.0.1 > "$S/.claude-plugin/plugin.json"; pack
  out="$(probe)"
  if ! grep -q UNBUMPED <<<"$out" && grep -q '\[INSTALLED-LAGS\] demo-gate' <<<"$out"; then
    ok "bumped + rebuilt, install on 1.0.0 -> INSTALLED-LAGS only"
  else bad "bumped + rebuilt, install on 1.0.0 -> INSTALLED-LAGS only"; fi

  mf 1.0.1 > "$I/plugin_a/.claude-plugin/plugin.json"
  out="$(probe)"
  case "$out" in *demo-gate*) bad "install updated: quiet";; *) ok "install updated: quiet";; esac

  g checkout -q -b records-fix && g add -A && g commit -q -m fix
  out="$(probe)"
  grep -q '\[UNMERGED\] records-fix' <<<"$out" && ok "fix only on a side branch -> UNMERGED" \
    || bad "fix only on a side branch -> UNMERGED"

  printf "export const ROOM = 'retired'\n" > "$S/hooks/meeting.ts"   # unbumped again...
  mkdir -p "$P/.claude"; printf 'cowork/demo-gate/   # retired, kept as history\n' > "$P/.claude/promotion-ignore"
  out="$(probe)"                                                     # ...but opted out
  ! grep -q 'cowork/demo-gate/' <<<"$out" && ok "promotion-ignore silences a retired plugin" \
    || bad "promotion-ignore silences a retired plugin"

  probe --gate >/dev/null; rc=$?
  [ "$rc" = 0 ] && ok "--gate stays exit 0 on plugin findings" || bad "--gate stays exit 0 (rc=$rc)"

  rm -rf "$T"; return "$fails"
}

run "$CHECK" "$SYNC"; fails=$?
echo
[ "$fails" = 0 ] || { echo "FAIL: $fails case(s) wrong"; exit 1; }
echo "PASS: all cases right"
[ "${1:-}" = "--mutate" ] || exit 0

echo; survived=0
mutant() {
  local M; M="$(mktemp)"
  python3 -c "s=open('$SYNC').read(); old,new=$2; assert s.count(old)==1, old; open('$M','w').write(s.replace(old,new))" || exit 2
  if QUIET=1 run "$CHECK" "$M"; then echo "SURVIVED - $1"; survived=$((survived+1)); else echo "caught   - $1"; fi
  rm -f "$M"
}
mutant "same-version source change ignored" "('elif vkey(sver) == vkey(bver) and changed:', 'elif False:')"
mutant "installed copies never compared"    "('        if vkey(iv) < vkey(target):', '        if False:')"
mutant "unmerged branches never checked"     "('        if n and n != \"0\":', '        if False:')"
mutant "promotion-ignore not honoured"       "('        if any(fnmatch.fnmatchcase(f\"cowork/{name}/\", g) for g in ignore):', '        if False:')"
echo
[ "$survived" = 0 ] && echo "PASS: every break caught" || { echo "FAIL: $survived break(s) survived"; exit 1; }
