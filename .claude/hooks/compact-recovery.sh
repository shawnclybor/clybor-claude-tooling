#!/usr/bin/env bash
# Compact-recovery hook
#
# Triggered on Stop with the `compact` matcher. Re-injects ROADMAP.md (if present)
# and recent git history so the next thread has cross-compaction continuity.
#
# Generic: works for any project that follows the
# "ROADMAP.md at repo root" convention. If ROADMAP.md is missing, the hook degrades
# gracefully and prints only the git log.

set -uo pipefail

echo '---COMPACT RECOVERY---'

if [ -f ROADMAP.md ]; then
  echo '--- ROADMAP.md ---'
  cat ROADMAP.md
else
  echo '(no ROADMAP.md at repo root — skipping)'
fi

echo
echo '--- Recent commits ---'
git log --oneline -10 2>/dev/null || echo '(no git history yet)'
