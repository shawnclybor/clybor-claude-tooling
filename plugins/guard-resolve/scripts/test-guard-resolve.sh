#!/usr/bin/env bash
# test-guard-resolve.sh — negative control for guard-resolve.sh and the guard template.
#
#   bash scripts/test-guard-resolve.sh            run the cases against the real launcher
#   bash scripts/test-guard-resolve.sh --mutate   also break the launcher 4 ways; each
#                                                 break must make at least one case fail
#
# A launcher that only ever blocks is as useless as one that never does, so the cases
# cover both directions. Exit 0 = every case right (and, with --mutate, every break caught).
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
LAUNCHER="${LAUNCHER:-$HERE/scripts/guard-resolve.sh}"
TEMPLATE="$HERE/templates/guard-template.py"

run_cases() {
  local L="$1" fails=0 T; T="$(mktemp -d)"
  mkdir -p "$T/proj/.claude/hooks/guards" "$T/proj/sub/deeper" "$T/elsewhere"
  cp "$L" "$T/proj/.claude/hooks/guard-resolve.sh"
  cp "$TEMPLATE" "$T/proj/.claude/hooks/guards/protect.py"
  printf 'import sys; print("args:" + " ".join(sys.argv[1:]), file=sys.stderr); sys.exit(0)\n' \
    > "$T/proj/.claude/hooks/guards/echo-args.py"
  local G=.claude/hooks/guards/protect.py
  local BAD='{"tool_name":"Read","tool_input":{"file_path":".env"}}'
  local OK='{"tool_name":"Read","tool_input":{"file_path":"README.md"}}'

  case_() { # $1 label, $2 want exit, $3 want-in-stderr ("" = any), then: dir, stdin, command...
    local label="$1" want="$2" grepfor="$3" dir="$4" input="$5"; shift 5
    local got err
    err="$(cd "$dir" && printf '%s' "$input" | "$@" 2>&1 >/dev/null)"; got=$?
    if [ "$got" = "$want" ] && { [ -z "$grepfor" ] || printf '%s' "$err" | grep -q -- "$grepfor"; }; then
      [ -n "${QUIET:-}" ] || echo "ok   $label"
    else
      [ -n "${QUIET:-}" ] || echo "BAD  $label (want exit $want${grepfor:+ with \"$grepfor\"}, got $got: ${err:0:120})"
      fails=$((fails+1))
    fi
  }
  local R="bash .claude/hooks/guard-resolve.sh"
  case_ "allows a good call"                0 ""                    "$T/proj" "$OK"  $R python3 $G
  case_ "blocks a bad call, with reason"    2 "is protected"        "$T/proj" "$BAD" $R python3 $G
  case_ "blocks when the guard is missing"  2 "not found"           "$T/proj" "$OK"  $R python3 .claude/hooks/guards/missing.py
  case_ "blocks when the runtime is missing" 2 "runtime"            "$T/proj" "$OK"  $R no-such-runtime-xyz $G
  case_ "template blocks on unparseable input" 2 "could not check"  "$T/proj" "not json" $R python3 $G
  case_ "finds the guard from a subfolder"  2 "is protected"        "$T/proj/sub/deeper" "$BAD" bash "$T/proj/.claude/hooks/guard-resolve.sh" python3 $G
  case_ "finds it via CLAUDE_PROJECT_DIR"   2 "is protected"        "$T/elsewhere" "$BAD" env CLAUDE_PROJECT_DIR="$T/proj" bash "$T/proj/.claude/hooks/guard-resolve.sh" python3 $G
  case_ "passes extra arguments through"    0 "args:--strict x"     "$T/proj" "$OK"  $R python3 .claude/hooks/guards/echo-args.py --strict x

  # The settings.json wiring from the skill: if the launcher itself is missing, block.
  local WIRE='g=.claude/hooks/guard-resolve.sh; t=.claude/hooks/guards/protect.py; [ -n "$CLAUDE_PROJECT_DIR" ] && [ -f "$CLAUDE_PROJECT_DIR/$g" ] && exec bash "$CLAUDE_PROJECT_DIR/$g" python3 "$t"; p="$PWD"; while [ "$p" != "/" ]; do [ -f "$p/$g" ] && exec bash "$p/$g" python3 "$t"; p=$(dirname "$p"); done; echo "GUARD BLOCKED: guard-resolve.sh not found from $PWD" >&2; exit 2'
  case_ "wiring blocks a bad call"          2 "is protected"        "$T/proj" "$BAD" env -u CLAUDE_PROJECT_DIR bash -c "$WIRE"
  case_ "wiring blocks if the launcher is gone" 2 "guard-resolve.sh not found" "$T/elsewhere" "$OK" env -u CLAUDE_PROJECT_DIR bash -c "$WIRE"

  rm -rf "$T"
  return "$fails"
}

run_cases "$LAUNCHER"; fails=$?
echo
if [ "$fails" != 0 ]; then echo "FAIL: $fails case(s) wrong"; exit 1; fi
echo "PASS: all cases right"
[ "${1:-}" = "--mutate" ] || exit 0

echo
survived=0
mutant() { # $1 label, $2 python replace(old, new) on the launcher
  local M; M="$(mktemp)"
  python3 -c "import sys; s=open('$LAUNCHER').read(); old,new=$2; assert s.count(old)==1, 'mutant did not apply: '+old; open('$M','w').write(s.replace(old,new))" || exit 2
  if QUIET=1 run_cases "$M"; then echo "SURVIVED — $1"; survived=$((survived+1)); else echo "caught   — $1"; fi
  rm -f "$M"
}
mutant "a missing guard is allowed"         "('  exit 2\n}', '  exit 0\n}')"
mutant "the runtime check is skipped"       "('command -v \"\$RUNTIME\" >/dev/null 2>&1 || die', 'true || die')"
mutant "no search up from subfolders"       "('    p=\$(dirname \"\$p\")\n', '    break\n')"
mutant "CLAUDE_PROJECT_DIR is ignored"      "('if [ -n \"\${CLAUDE_PROJECT_DIR:-}\" ] && [ -f', 'if false && [ -f')"
echo
[ "$survived" = 0 ] && { echo "PASS: all 4 launcher breaks caught"; exit 0; }
echo "FAIL: $survived break(s) survived"; exit 1
