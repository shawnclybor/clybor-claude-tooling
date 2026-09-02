#!/usr/bin/env bash
# probes/lock.sh — add or refresh entries in sources.lock WITHOUT dropping existing ones.
#
#   bash lock.sh <path> [<path> ...]
#
# Why this exists: the obvious way to build the lock is `: > sources.lock` in a loop, and that
# silently destroys pins someone else added. Measured 2026-09-02 — a concurrent session had pinned
# three cited sibling plans by sha256; a probe repoint truncated the file and took those pins with
# it. Nothing detected it, because a lock with fewer entries still verifies clean.
#
# A path already present is REFRESHED only if its hash still matches. If it has changed, this
# refuses and says so: re-pinning a moved source is a decision, never a side effect of adding one.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK="$HERE/sources.lock"
touch "$LOCK"
added=0; kept=0; refused=0

for p in "$@"; do
  [ -f "$p" ] || { echo "  SKIP    $p (not a file)"; continue; }
  sha="$(shasum -a 256 "$p" | cut -d' ' -f1)"
  size="$(wc -c <"$p" | tr -d ' ')"
  old="$(grep -F "$(printf '%s\t' "$p")" "$LOCK" 2>/dev/null | head -1 || true)"
  if [ -n "$old" ]; then
    old_sha="$(printf '%s' "$old" | cut -f2)"
    if [ "$old_sha" = "$sha" ]; then kept=$((kept+1)); echo "  ok      $p (already pinned, unchanged)"
    else
      refused=$((refused+1))
      echo "  REFUSED $p — pinned as $old_sha, now $sha."
      echo "          The source moved. Re-pin deliberately (edit sources.lock) after deciding the change is intended."
    fi
    continue
  fi
  printf '%s\t%s\t%s\n' "$p" "$sha" "$size" >> "$LOCK"
  added=$((added+1)); echo "  pinned  $p"
done

printf '\n%s added / %s already pinned / %s refused — %s total entries\n' \
  "$added" "$kept" "$refused" "$(grep -c . "$LOCK" || echo 0)"
[ "$refused" -eq 0 ]
