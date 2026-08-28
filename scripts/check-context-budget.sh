#!/usr/bin/env bash
# check-context-budget.sh — size gate for always-on context.
# Enforces CLAUDE.md Hard Rule 7 (Governance Placement) via Hard Rule 12 (scripts as gates).
# Budgets: CLAUDE.md <= 2200 words; each .claude/rules/*.md <= 250 lines;
#          docs/project-registry.md longest line <= 3000 chars (Status-field refatten guard;
#          recalibrated 1400 -> 3000 on 2026-08-14 — see the comment above the check_maxline call).
# Exit 0 = within budget. Exit 2 = over budget — trim narrative to KB pointers
# or move domain-specific content into a plugin skill.

set -u
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0

check_words() { # $1=path $2=budget
  local w
  w=$(wc -w < "$1" | tr -d ' ')
  if [ "$w" -gt "$2" ]; then
    echo "[OVER] $1 — ${w} words (budget $2). Trim narrative to KB pointers or move content to a plugin skill."
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
    echo "[OVER] $1 — ${l} lines (budget $2). Move detail into the relevant plugin skill."
    FAIL=1
  elif [ "$l" -gt $(( $2 * 90 / 100 )) ]; then
    echo "[WARN] $1 — ${l} lines (budget $2, >=90%)."
  else
    echo "[OK]   $1 — ${l} lines (budget $2)."
  fi
}

check_maxline() { # $1=path $2=budget(chars) — catches a single Status cell regrowing into a journal
  local maxlen
  maxlen=$(awk '{ if (length > m) m=length } END { print m+0 }' "$1")
  if [ "$maxlen" -gt "$2" ]; then
    echo "[OVER] $1 — longest line ${maxlen} chars (budget $2). A Status field is regrowing into a journal — move the detail to the project's memory file and keep the registry Status to one line."
    FAIL=1
  elif [ "$maxlen" -gt $(( $2 * 90 / 100 )) ]; then
    echo "[WARN] $1 — longest line ${maxlen} chars (budget $2, >=90%)."
  else
    echo "[OK]   $1 — longest line ${maxlen} chars (budget $2)."
  fi
}

check_words "$REPO_ROOT/CLAUDE.md" 2200
for f in "$REPO_ROOT/.claude/rules/"*.md; do
  [ -f "$f" ] && check_lines "$f" 250
done
for f in "$REPO_ROOT/memory/context/"*.md; do
  [ -f "$f" ] && check_words "$f" 500
done
# Recalibrated 1400 -> 3000 on 2026-08-14. The old limit was failed simultaneously by
# the three heaviest active engagements (2842, 2662 and 2018 chars) — i.e. by all of
# them at once. A limit that only ever fires on the busiest projects is measuring
# engagement size, not journal-creep, and a gate that is permanently red teaches you to
# ignore red gates. 3000 still catches a Status cell genuinely running away.
check_maxline "$REPO_ROOT/docs/project-registry.md" 3000

if [ "$FAIL" -eq 1 ]; then
  exit 2
fi
exit 0
