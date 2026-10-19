#!/usr/bin/env bash
# sync-down.sh — copy canonical tooling down into a project, but only files that are BEHIND.
#
# After a change lands here, every project still carrying the old copy shows drift, and projects
# whose pre-commit runs `check-promotion.sh --gate` refuse commits until they catch up. This copies
# exactly the files classify-drift.py labels BEHIND: the project's bytes were once committed to the
# canonical file, so overwriting them cannot lose a local edit. AHEAD, BOTH and PRIVATE files are
# listed and left alone; .claude/promotion-ignore is honoured because check-promotion.sh applies it.
#
#   scripts/sync-down.sh <project-root>            # dry run: say what would be copied
#   scripts/sync-down.sh <project-root> --apply    # copy, then re-run the drift check
#
# Copies into the working tree only; review and commit in the project as usual.
set -uo pipefail
CANON="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="${1:?usage: sync-down.sh <project-root> [--apply]}"
APPLY="${2:-}"
cd "$PROJECT" || exit 2

report="$(CLYBOR_TOOLING="$CANON" bash "$CANON/scripts/check-promotion.sh" --surface 2>&1 >/dev/null)"
behind=(); others=()
while IFS= read -r line; do
  case "$line" in
    "  ~ [BEHIND] "*) rel="${line#  ~ \[BEHIND\] }"; behind+=("${rel%% — *}") ;;
    "  ~ ["*) others+=("${line#  ~ }") ;;
  esac
done <<< "$report"

for o in ${others+"${others[@]}"}; do echo "leave  $o"; done
if [ "${#behind[@]}" -eq 0 ]; then echo "nothing BEHIND in $PROJECT"; exit 0; fi
for rel in "${behind[@]}"; do
  if [ "$APPLY" = "--apply" ]; then
    cp "$CANON/$rel" "$PROJECT/$rel" && echo "synced $rel"
  else
    echo "would sync $rel"
  fi
done
if [ "$APPLY" = "--apply" ]; then
  echo "${#behind[@]} file(s) synced. Remaining drift:"
  CLYBOR_TOOLING="$CANON" bash "$CANON/scripts/check-promotion.sh" --surface 2>&1 >/dev/null | grep '~' || echo "  none"
else
  echo "${#behind[@]} file(s) BEHIND. Re-run with --apply to copy them."
fi
