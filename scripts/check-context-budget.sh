#!/usr/bin/env bash
# check-context-budget.sh — size gate for always-on context.
# Always-on files are paid for in context on every request; this enforces the
# "keep rules tight" rule mechanically (honor-system gates fail — codify as scripts).
# Budgets: CLAUDE.md <= 2200 words; each .claude/rules/*.md <= 250 lines.
# Safe in repos without these files (skips absent checks).
# Exit 0 = within budget. Exit 2 = over budget — trim narrative or move content
# into a skill / lazy-loaded rule file.

set -u
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
FAIL=0

check_words() { # $1=path $2=budget
  local w
  w=$(wc -w < "$1" | tr -d ' ')
  if [ "$w" -gt "$2" ]; then
    echo "[OVER] $1 — ${w} words (budget $2). Trim narrative or move content to a skill."
    FAIL=1
  elif [ "$w" -gt $(( $2 * 90 / 100 )) ]; then
    echo "[WARN] $1 — ${w} words (budget $2, >=90% — trim before adding more)."
  else
    echo "[OK]   $1 — ${w} words (budget $2)."
  fi
}

check_lines() { # $1=path $2=budget
  local l
  l=$(wc -l < "$1" | tr -d ' ')
  if [ "$l" -gt "$2" ]; then
    echo "[OVER] $1 — ${l} lines (budget $2). Move detail into a skill."
    FAIL=1
  elif [ "$l" -gt $(( $2 * 90 / 100 )) ]; then
    echo "[WARN] $1 — ${l} lines (budget $2, >=90%)."
  else
    echo "[OK]   $1 — ${l} lines (budget $2)."
  fi
}

[ -f "$ROOT/CLAUDE.md" ] && check_words "$ROOT/CLAUDE.md" 2200
for f in "$ROOT/.claude/rules/"*.md; do
  [ -f "$f" ] && check_lines "$f" 250
done

[ "$FAIL" -eq 1 ] && exit 2
exit 0
