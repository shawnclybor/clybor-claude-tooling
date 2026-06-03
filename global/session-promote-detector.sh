#!/usr/bin/env bash
# SessionStart hook (installed in ~/.claude/settings.json). Surfaces reusable tooling in the
# current project that is not promoted to — or has drifted from — clybor-claude-tooling.
# stdout is added to session context. Always exits 0 (never blocks a session).
CANON="${CLYBOR_TOOLING:-$HOME/gits/clybor-claude-tooling}"
[ -x "$CANON/scripts/check-promotion.sh" ] || exit 0
out="$(bash "$CANON/scripts/check-promotion.sh" --surface 2>&1)"
if [ -n "$out" ]; then
  echo "## Tooling promotion check (clybor-claude-tooling)"
  echo "$out"
  echo "_Promote with \`$CANON/scripts/promote.sh <path>\`._"
fi
exit 0
