#!/usr/bin/env bash
# promote.sh — copy a reusable artifact from the current project into clybor-claude-tooling
# at the same relative path, so it becomes canonical. Then commit it here.
#   usage: scripts/promote.sh [--scrub] <relative-path> [<relative-path> ...]
#
# Before anything is copied, the project copy is scanned for private details (the same
# scan verify-clean.py runs at commit time: denylist terms, IDs, emails, home paths).
#   - clean            -> copied as-is
#   - private, default -> REFUSED. Keep it local (list it in .claude/promotion-ignore with
#                         the reason), or rerun with --scrub
#   - private, --scrub -> copied, then scrub.py replaces the private details in the
#                         CANONICAL copy with tokens; the project keeps its own version.
#                         Review the diff, and add the project path to promotion-ignore,
#                         since the two copies now differ on purpose.
# Promotion is a judgment call as well as a copy: run the promote-to-tooling skill's
# universality test first. This script only enforces the part a script can.
set -euo pipefail
CANON="${CLYBOR_TOOLING:-$HOME/gits/clybor-claude-tooling}"
REPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SCRUB=0
[ "${1:-}" = "--scrub" ] && { SCRUB=1; shift; }
[ -d "$CANON" ] || { echo "clybor-tooling not found at $CANON" >&2; exit 2; }
[ "$#" -ge 1 ] || { echo "usage: promote.sh [--scrub] <relative-path> ..." >&2; exit 2; }

private_findings() { # $1 = file or dir; prints findings, returns 1 when private
  local tmp; tmp="$(mktemp -d)"
  cp -R "$1" "$tmp/"
  local out rc=0
  out="$(python3 "$CANON/scripts/verify-clean.py" --target "$tmp" 2>&1)" || rc=$?
  rm -rf "$tmp"
  [ "$rc" = 1 ] && { printf '%s\n' "$out" | grep -E '^FAIL' | sed "s#$tmp/##"; return 1; }
  return 0
}

refused=0
for rel in "$@"; do
  src="$REPO/$rel"
  [ -e "$src" ] || { echo "skip (missing): $rel" >&2; continue; }
  dst="$CANON/$rel"

  if ! findings="$(private_findings "$src")"; then
    if [ "$SCRUB" = 0 ]; then
      echo "REFUSED: $rel contains private details:" >&2
      printf '%s\n' "$findings" | sed 's/^/  /' >&2
      echo "  Keep it local (add it to .claude/promotion-ignore with the reason)," >&2
      echo "  or promote a scrubbed copy: promote.sh --scrub $rel" >&2
      refused=$((refused+1)); continue
    fi
  fi

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

  if [ "$SCRUB" = 1 ]; then
    if [ -d "$dst" ]; then find "$dst" -type f -print0 | xargs -0 python3 "$CANON/scripts/scrub.py"
    else python3 "$CANON/scripts/scrub.py" "$dst"; fi
    if ! left="$(private_findings "$dst")"; then
      echo "WARNING: $rel still has private details after scrubbing; edit $dst by hand:" >&2
      printf '%s\n' "$left" | sed 's/^/  /' >&2
      refused=$((refused+1))
    fi
    echo "promoted (scrubbed): $rel  →  $CANON/$rel   — review: git -C $CANON diff -- $rel"
    echo "  then add '$rel' to $REPO/.claude/promotion-ignore (the copies now differ on purpose)"
  else
    echo "promoted: $rel  →  $CANON/$rel"
  fi
done

echo
echo "Next: cd $CANON && git add -A && git commit  (review the diff first)."
[ "$refused" = 0 ]
