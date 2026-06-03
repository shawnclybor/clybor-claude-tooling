#!/usr/bin/env bash
# check-promotion.sh — detect reusable tooling in the current repo that is NOT promoted
# to clybor-claude-tooling, or that has DRIFTED from the canonical copy.
#
# Modes:
#   --surface  list candidates + drift, always exit 0   (SessionStart / global pre-commit nudge)
#   --gate     block (exit 1) on ANY drift of shared tooling (full tree), warn on candidates
#              (per-project .githooks/pre-commit — managed projects must never drift)
#
# Canonical repo: $CLYBOR_TOOLING or ~/gits/clybor-claude-tooling.
# Reusable categories (relative to repo root): .claude/skills .claude/hooks .claude/commands
#   .claude/agents .githooks scripts/*.sh — EXCLUDING per-project files (see SKIP).
set -uo pipefail
MODE="${1:---surface}"
CANON="${CLYBOR_TOOLING:-$HOME/gits/clybor-claude-tooling}"
REPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO" || exit 0

# Don't analyze the canonical repo against itself.
[ "$(cd "$CANON" 2>/dev/null && pwd)" = "$REPO" ] && exit 0
# Don't scan the home dir — global ~/.claude/skills are not project tooling.
[ "$REPO" = "$HOME" ] && exit 0
[ -d "$CANON" ] || { [ "$MODE" = "--gate" ] && exit 0; echo "(clybor-tooling not found at $CANON; set CLYBOR_TOOLING)"; exit 0; }

# Per-project files that legitimately differ and must NOT be promotion-checked.
SKIP_RE='(\.claude/rules/.*-project\.md|\.claude/settings\.json|CLAUDE\.md|knowledge/)'

candidates=(); drift=()
scan() { # $1 = relative path of a candidate file
  local rel="$1"
  printf '%s\n' "$rel" | grep -qE "$SKIP_RE" && return
  local canon="$CANON/$rel"
  if [ ! -e "$canon" ]; then candidates+=("$rel");
  elif ! diff -q "$rel" "$canon" >/dev/null 2>&1; then drift+=("$rel"); fi
}

list_files() {
  { ls .githooks/* 2>/dev/null
    ls scripts/*.sh 2>/dev/null
    find .claude/skills .claude/hooks .claude/commands .claude/agents -type f 2>/dev/null
  } | sort -u
}

# Full-tree scan for both modes: drift in any shared tooling file is caught regardless of
# what is staged. This is what makes --gate non-honor-system.
while IFS= read -r f; do [ -n "$f" ] && scan "$f"; done < <(list_files)

if [ "${#drift[@]}" -gt 0 ]; then
  echo "⚠ tooling DRIFT vs clybor-claude-tooling (promote or sync):" >&2
  for d in "${drift[@]}"; do echo "  ~ $d" >&2; done
fi
if [ "${#candidates[@]}" -gt 0 ]; then
  echo "↑ promotable tooling not in clybor-claude-tooling:"
  for c in "${candidates[@]}"; do echo "  + $c   →  scripts/promote.sh $c"; done
fi

if [ "$MODE" = "--gate" ] && [ "${#drift[@]}" -gt 0 ]; then
  echo "Promoted tooling has drifted. Run: $CANON/scripts/promote.sh <file>  (or 'git commit --no-verify')." >&2
  exit 1
fi
exit 0
