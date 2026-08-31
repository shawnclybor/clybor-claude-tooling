#!/usr/bin/env bash
# check-new-names.sh — Rule 9 gate for the project registry (and optionally memory files).
#
# Detects PERSON-NAME strings that are NEW versus the last snapshot, so a session
# must verify each new name against a real source (Contact DB, verbatim transcript)
# before it hardens into a cross-session entry point. Born from a 2026-07-02
# incident: an unsourced person name with no basis in any transcript or note sat in
# docs/project-registry.md under one project's section. The registry is gitignored, so git history
# cannot catch this — this script keeps its own snapshot instead.
#
# Usage:  bash scripts/check-new-names.sh            # check registry vs snapshot
#         bash scripts/check-new-names.sh --accept   # accept current state as baseline
#
# Exit codes: 0 = no new names (or accepted); 1 = new names found (gate FAILS —
# verify each name per Hard Rule 9, then re-run with --accept).

set -euo pipefail
cd "$(dirname "$0")/.."

REGISTRY="docs/project-registry.md"
CACHE_DIR=".cache"
SNAPSHOT="$CACHE_DIR/registry-names.txt"
KNOWN="$CACHE_DIR/known-names.txt"   # optional manually-curated allowlist, one name per line

mkdir -p "$CACHE_DIR"

# Weekday and month tokens. A candidate containing ANY of these in ANY position is a
# date fragment, not a name — "Tue Sep" (from "call MOVED → Tue Sep 1"), "Dana Sep",
# "Alex Mon Aug". Added 2026-08-31 after the weekly sweep: the shape `[A-Z][a-z]{2,}`
# matches every abbreviated weekday and month, so any Status line carrying a date bred a
# false positive, and a gate that cries wolf weekly is a gate you learn to --accept blind.
# Measured on the live registry: 125 candidates → 109, all 16 dropped were date fragments,
# no real name lost (the people behind "Dana Sep" etc. survive as proper First+Last
# pairs elsewhere, or only ever appear as a single token this regex never matched).
# NOTE (public copy): the example names above are ANONYMIZED. The life-crm original
# cites real client-side people and is blocked here by the denylist gate — do not
# "resync" this comment from life-crm verbatim, it will re-leak. Logic is identical.
# KNOWN TRADE-OFF: a person actually named June, May, or August is now skipped. If that
# ever happens, narrow this list — do NOT reach for .cache/known-names.txt, which only
# suppresses names you have already seen and cannot surface one this filter ate.
DATEWORDS='Mon|Tue|Tues|Wed|Weds|Thu|Thur|Thurs|Fri|Sat|Sun|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec|January|February|March|April|June|July|August|September|October|November|December'

# Extract candidate person names: Capitalized First Last pairs, minus obvious non-names.
extract_names() {
  grep -oE '\b[A-Z][a-z]{2,}( [A-Z][a-z]{2,}){1,2}\b' "$REGISTRY" \
    | grep -vE '^(The|New|Full|Open|Active|Local|Notion|Google|Drive|Client|Project|Status|Memory|Head|Series|Best|Inc|Law|Firm|Group|Task|Note|Day|Window|Phase|Invoice|Harvest|Slack|Gmail|Docker|Semantic|Layer|Quarterly|Boot|Camp|Champion|Builder|Track|Service|Agreement|Federal|Governance|Discovery|Business|Development|Knowledge|Base|Contact|Database|Registry|Automotive|Insurance|Education|Consulting|Solutions|Strategies|Leadership|Impact|Elevate|Innovating|Curriculum|Chatbot|Mentor|Dashboard|Eval|Framework|Custom|Build|Absence|Management|Automation|Clinical|Trial|Platform|Advertising|Medical|Research|Studies|Miami|Boston|Atlanta|Pittsburgh|Jacksonville|Delray|Beach|Syracuse|Amsterdam|Urbandale)' \
    | grep -vE "(^|[[:space:]])($DATEWORDS)([[:space:]]|\$)" \
    | sort -u
}

if [[ "${1:-}" == "--accept" ]]; then
  extract_names > "$SNAPSHOT"
  echo "[OK] Baseline accepted: $(wc -l < "$SNAPSHOT" | tr -d ' ') names snapshotted to $SNAPSHOT"
  exit 0
fi

if [[ ! -f "$SNAPSHOT" ]]; then
  echo "[WARN] No snapshot yet — creating baseline from current registry (first run)."
  extract_names > "$SNAPSHOT"
  echo "[OK] Baseline created ($(wc -l < "$SNAPSHOT" | tr -d ' ') names). Future runs will diff against it."
  exit 0
fi

CURRENT="$(mktemp)"
extract_names > "$CURRENT"

NEW_NAMES="$(comm -13 "$SNAPSHOT" "$CURRENT" || true)"
if [[ -f "$KNOWN" && -n "$NEW_NAMES" ]]; then
  NEW_NAMES="$(echo "$NEW_NAMES" | grep -vxFf "$KNOWN" || true)"
fi
rm -f "$CURRENT"

if [[ -z "$NEW_NAMES" ]]; then
  echo "[OK] No new person-name strings in $REGISTRY since last accepted baseline."
  exit 0
fi

echo "[GATE FAIL] New person-name strings entered $REGISTRY since the last baseline:"
echo "$NEW_NAMES" | sed 's/^/  - /'
echo ""
echo "Per Hard Rule 9: verify EACH name against the Contact DB, a verbatim transcript,"
echo "or the cited Notion source note. Fix any mis-transcription, then re-run:"
echo "  bash scripts/check-new-names.sh --accept"
exit 1
