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

# Availability gate — standing audit, NOT an entry gate. Commit hooks catch a claim
# the moment it is written and never ask again; every failure this gate exists for
# was a claim that SAT (Seismic ~2 months, Dep 13 six days). This re-asks each session.
if [ -f scripts/check_dependency_probes.py ]; then
  out="$(python3 scripts/check_dependency_probes.py --audit 2>/dev/null)"
  if [ -n "$out" ]; then
    [ "$emitted" -eq 0 ] && echo "## Project context (auto-loaded by SessionStart hook)"
    emitted=1
    echo ""
    echo "### Open dependencies"
    echo "$out"
  fi
fi

# Probe-visibility gate — names the paths where a recursive-grep zero means nothing.
# check_dependency_probes forces a probe to be DECLARED; this one says whether the
# probe could have reached its target. Both are needed: on 2026-08-17 three of five
# eval subagents recorded a false negative from a grep that had been silently narrowed.
if [ -f scripts/check_grep_blindspots.py ]; then
  out="$(python3 scripts/check_grep_blindspots.py --audit 2>/dev/null)"
  if [ -n "$out" ]; then
    [ "$emitted" -eq 0 ] && echo "## Project context (auto-loaded by SessionStart hook)"
    emitted=1
    echo ""
    echo "$out"
  fi
fi
exit 0
