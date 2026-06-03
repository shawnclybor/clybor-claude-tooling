#!/usr/bin/env bash
# log-correction.sh — edit-source gate (pairs with the writing-quality skill).
# When the user corrects a draft, log the correction pattern. A repeat means the
# fix belongs in the SOURCE (voice guide, template, skill rules), not the draft.
#
# Usage: log-correction.sh "<pattern-slug>" "<project>"
#   pattern-slug: kebab-case label, e.g. "formal-closing-line", "passive-voice-opener".
#                 Reuse existing slugs from the log so repeats actually match.
# Exit 0 = first occurrence logged. Exit 2 = REPEAT — propose source-level fix.

set -u
if [ "$#" -lt 2 ]; then
  echo "usage: $0 \"<pattern-slug>\" \"<project>\""
  exit 1
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LOG="$ROOT/.claude/draft-corrections.log"
mkdir -p "$(dirname "$LOG")"
touch "$LOG"

PATTERN="$1"
PROJECT="$2"

PRIOR=$(grep -c "|${PATTERN}|" "$LOG" 2>/dev/null || true)
echo "$(date +%F)|${PATTERN}|${PROJECT}" >> "$LOG"

if [ "${PRIOR:-0}" -gt 0 ]; then
  echo "[REPEAT] '${PATTERN}' has now been corrected $((PRIOR + 1))x:"
  grep "|${PATTERN}|" "$LOG" | cut -d'|' -f1,3 | sed 's/^/         /'
  echo "Propose the source-level fix — voice guide, template, or writing-quality rules —"
  echo "not another draft fix."
  exit 2
fi

echo "[LOGGED] ${PATTERN} (${PROJECT}) — first occurrence."
exit 0
