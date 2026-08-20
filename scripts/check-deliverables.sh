#!/usr/bin/env bash
# check-deliverables.sh — diff each active project's deliverables/ folder against
# the Deliverables section of its Notion project page.
#
# Contract (per docs/project-registry.md § Folder Convention):
#   {project}/deliverables/  ==  the Deliverables section on the Notion project page
#   One file on disk = one row in Notion. Anything not sent to the client does NOT
#   belong in deliverables/ (use drafts/ or working/).
#
# This script does NOT call Notion. The caller (weekly-project-integrity-review, or
# a human) fetches each active project page and dumps its body text to:
#     <pages-dir>/<slug>.txt
# The script then diffs disk against those dumps by exact filename.
#
# Usage:
#   scripts/check-deliverables.sh <pages-dir>
#
# Exit codes:
#   0 = every on-disk deliverable is logged in Notion
#   1 = drift found (unlogged files, or a project page dump is missing)
#
# Active-project map lives in scripts/deliverables-projects.tsv (slug<TAB>folder).
# Projects with no local folder (e.g. Business Development) are simply absent from
# that file — they are not flagged.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAP="$REPO/scripts/deliverables-projects.tsv"
PAGES_DIR="${1:-}"

if [[ -z "$PAGES_DIR" || ! -d "$PAGES_DIR" ]]; then
  echo "usage: scripts/check-deliverables.sh <pages-dir>" >&2
  echo "  <pages-dir> must contain <slug>.txt for each project in $MAP" >&2
  exit 2
fi

[[ -f "$MAP" ]] || { echo "missing map: $MAP" >&2; exit 2; }

drift=0
total_unlogged=0

while IFS=$'\t' read -r slug folder; do
  [[ -z "${slug:-}" || "$slug" == \#* ]] && continue

  dir="$REPO/$folder/deliverables"
  page="$PAGES_DIR/$slug.txt"

  if [[ ! -d "$dir" ]]; then
    echo "SKIP  $slug — no $folder/deliverables/ folder"
    continue
  fi
  if [[ ! -f "$page" ]]; then
    echo "ERROR $slug — no page dump at $page (fetch the Notion page first)"
    drift=1
    continue
  fi

  unlogged=()
  while IFS= read -r f; do
    base="$(basename "$f")"
    # exact-filename match only — never fuzzy/semantic (dedup by doc_key)
    if ! grep -Fq -- "$base" "$page"; then
      unlogged+=("${f#"$REPO/$folder/"}")
    fi
  # .okf.yaml sidecars are METADATA, not deliverables — they were never sent to a client and
  # can never be logged as a send, so counting them produced permanent unfixable drift
  # (18 of 27 items on one active project, 2026-08-05). They have their own gate: check-okf.sh.
  done < <(find "$dir" -type f ! -name '.DS_Store' ! -name '*.okf.yaml' | sort)

  if (( ${#unlogged[@]} == 0 )); then
    echo "OK    $slug — all deliverables logged"
  else
    echo "DRIFT $slug — ${#unlogged[@]} unlogged:"
    printf '        %s\n' "${unlogged[@]}"
    drift=1
    total_unlogged=$(( total_unlogged + ${#unlogged[@]} ))
  fi
done < "$MAP"

echo
if (( drift == 0 )); then
  echo "PASS — 0 unlogged deliverables across active projects."
else
  echo "FAIL — $total_unlogged unlogged deliverable(s). Log them on the Notion page, or move them out of deliverables/."
fi

# NOTE: the OKF frontmatter gate (scripts/check-okf.sh) deliberately does NOT
# run from here. This script requires a <pages-dir> of Notion page dumps and
# exits 2 without one — nesting OKF inside it would make an independent gate
# silently skip whenever that prep was missing. It runs as its own step in
# weekly-project-integrity-review instead.
exit $drift
