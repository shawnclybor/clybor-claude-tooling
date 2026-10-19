#!/usr/bin/env bash
# test-check-context-budget.sh — fixture tests for check-context-budget.sh.
# Each case builds a throwaway repo, runs the script inside it, and checks the exit code
# (0 within budget, 2 over) plus the line it prints. The exit code is the contract callers
# read, so every case asserts it.
#   bash scripts/test-check-context-budget.sh [path/to/check-context-budget.sh]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="${1:-$HERE/check-context-budget.sh}"
[ -f "$SCRIPT" ] || { echo "no script at $SCRIPT"; exit 2; }
PASS=0; FAILN=0

line_of() { python3 -c "print('x' * $1)"; }

run_case() { # $1=label $2=want_exit $3=want_regex ; fixture already built in $T
  local out rc
  out=$(bash "$T/scripts/check-context-budget.sh" 2>&1); rc=$?
  if [ "$rc" = "$2" ] && echo "$out" | grep -qE "$3"; then
    PASS=$((PASS+1)); echo "PASS  $1"
  else
    FAILN=$((FAILN+1)); echo "FAIL  $1 (exit $rc, want $2; want /$3/)"; echo "$out" | sed 's/^/      /'
  fi
}

fixture() { # fresh repo with the script under test and a small CLAUDE.md
  T=$(mktemp -d); mkdir -p "$T/scripts" "$T/docs" "$T/.claude/rules"
  cp "$SCRIPT" "$T/scripts/check-context-budget.sh"
  echo "short router" > "$T/CLAUDE.md"
}

fixture; run_case "all within budget" 0 '\[OK\]'; rm -rf "$T"

fixture; { echo short; line_of 3200; } > "$T/docs/project-registry.md"
run_case "registry line over budget exits 2 and names the line" 2 '\[OVER\].*3200 chars at line 2'; rm -rf "$T"

fixture; { echo short; echo short; line_of 2800; } > "$T/docs/project-registry.md"
run_case "registry line at >=90% warns, exits 0, names the line" 0 '\[WARN\].*2800 chars at line 3'; rm -rf "$T"

fixture; python3 -c "print(' '.join(['w']*2300))" > "$T/CLAUDE.md"
run_case "CLAUDE.md over word budget exits 2" 2 '\[OVER\].*CLAUDE\.md'; rm -rf "$T"

fixture; for i in $(seq 1 260); do echo "l$i"; done > "$T/.claude/rules/big.md"
run_case "rules file over line budget exits 2" 2 '\[OVER\].*big\.md'; rm -rf "$T"

fixture; rm "$T/CLAUDE.md"
run_case "missing file is SKIP, never silently OK" 0 '\[SKIP\].*CLAUDE\.md'; rm -rf "$T"

echo "$PASS passed, $FAILN failed"
[ "$FAILN" -eq 0 ]
