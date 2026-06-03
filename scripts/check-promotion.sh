#!/usr/bin/env bash
# check-promotion.sh — detect reusable tooling in the current repo that is NOT promoted
# to clybor-claude-tooling, or that has DRIFTED from the canonical copy.
#
# Modes:
#   --surface  list candidates + drift, always exit 0   (for SessionStart hook)
#   --gate     block (exit 1) on DRIFT of staged files; warn on new candidates (for pre-commit)
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

if [ "$MODE" = "--gate" ]; then
  # only staged files (bash 3.2 portable — no mapfile)
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    printf '%s\n' "$f" | grep -qE '^(\.githooks/|scripts/.*\.sh$|\.claude/(skills|hooks|commands|agents)/)' || continue
    [ -f "$f" ] && scan "$f"
  done < <(git diff --cached --name-only 2>/dev/null)
else
  while IFS= read -r f; do [ -n "$f" ] && scan "$f"; done < <(list_files)
fi

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
