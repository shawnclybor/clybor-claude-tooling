#!/usr/bin/env bash
# session-context.sh — SessionStart hook. Auto-loads project rule + recent knowledge log
# into context so referencing them is not honor-system. stdout is added to session context.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" 2>/dev/null || exit 0

emitted=0
for r in .claude/rules/*-project.md; do
  [ -f "$r" ] || continue
  [ "$emitted" -eq 0 ] && echo "## Project context (auto-loaded by SessionStart hook)"
  emitted=1
  echo "- Load \`$r\` for engagement/domain specifics before project work."
done

if [ -f knowledge/log.md ]; then
  [ "$emitted" -eq 0 ] && echo "## Project context (auto-loaded by SessionStart hook)"
  emitted=1
  echo ""
  echo "### Recent knowledge/log.md"
  grep -E '^- ' knowledge/log.md | head -n 6
fi
exit 0
