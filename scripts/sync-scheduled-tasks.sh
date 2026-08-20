#!/usr/bin/env bash
# sync-scheduled-tasks.sh — one-way mirror: Claude Desktop's task store -> the repo.
#
# DIRECTION IS FIXED AND ONE-WAY.
#   SOURCE OF TRUTH : ~/Documents/Claude/Scheduled   (Claude Desktop writes here)
#   MIRROR          : ~/gits/life-crm/scheduled      (git copy, for version control)
# Never copy repo -> Documents. That would overwrite live task definitions with
# stale ones. There is no flag to reverse this script.
#
# History: until 2026-08-14 the app's store was a SYMLINK into the repo. That put
# a Claude-Desktop-protected location inside life-crm, and Claude Desktop silently
# refused to mount the repo for ~5 days (56 dropped mounts). The symlink guard
# below exists so that regression is caught loudly instead of silently.

set -euo pipefail

SRC="$HOME/Documents/Claude/Scheduled"
DST="$HOME/gits/life-crm/scheduled"
MIN_TASKS=20   # tripwire: a near-empty source means something is wrong, not that you deleted 40 tasks

fail() { echo "sync-scheduled-tasks: $*" >&2; exit 1; }

[ -e "$SRC" ] || fail "source missing: $SRC"
[ -L "$SRC" ] && fail "REGRESSION: $SRC is a symlink again. This is what broke repo mounting on 2026-08-14. Replace it with a real directory before syncing."
[ -d "$SRC" ] || fail "source is not a directory: $SRC"
[ -d "$DST" ] || fail "mirror missing: $DST"

count=$(find "$SRC" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
[ "$count" -ge "$MIN_TASKS" ] || fail "only $count task folders in source (expected >= $MIN_TASKS). Refusing to mirror — this looks like data loss, not a cleanup."

# --delete makes this a true mirror: tasks removed in the app are removed from git.
rsync -a --delete --exclude '.DS_Store' "$SRC/" "$DST/"

cd "$HOME/gits/life-crm"
if [ -z "$(git status --porcelain scheduled)" ]; then
  echo "sync-scheduled-tasks: no changes ($count tasks)"
  exit 0
fi

echo "sync-scheduled-tasks: changes detected —"
git status --short scheduled
git add -A scheduled
git commit -q -m "scheduled: sync task prompts from Claude Desktop ($count tasks)"
echo "sync-scheduled-tasks: committed $(git rev-parse --short HEAD)"
