#!/usr/bin/env bash
# promote.sh — copy a reusable artifact from the current project into clybor-claude-tooling
# at the same relative path, so it becomes canonical. Then commit it here.
#   usage: scripts/promote.sh <relative-path> [<relative-path> ...]
set -euo pipefail
CANON="${CLYBOR_TOOLING:-$HOME/gits/clybor-claude-tooling}"
REPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
[ -d "$CANON" ] || { echo "clybor-tooling not found at $CANON" >&2; exit 2; }
[ "$#" -ge 1 ] || { echo "usage: promote.sh <relative-path> ..." >&2; exit 2; }

for rel in "$@"; do
  src="$REPO/$rel"
  [ -e "$src" ] || { echo "skip (missing): $rel" >&2; continue; }
  dst="$CANON/$rel"
  mkdir -p "$(dirname "$dst")"
  if [ -d "$src" ]; then
    # Copy the directory's CONTENTS. `cp -R dir existing_dir` nests a second copy inside the
    # first on every re-promote, so the top-level files never update and the drift gate keeps
    # firing on a copy that looks promoted.
    mkdir -p "$dst"
    cp -R "$src"/. "$dst"/
    find "$dst" -name __pycache__ -type d -prune -exec rm -rf {} + 2>/dev/null
  else
    cp "$src" "$dst"
    [ -x "$src" ] && chmod +x "$dst"
  fi
  echo "promoted: $rel  →  $CANON/$rel"
done

echo
echo "Next: cd $CANON && git add -A && git commit  (review the diff first)."
