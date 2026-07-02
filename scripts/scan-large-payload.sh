#!/usr/bin/env bash
# scan-large-payload.sh — cheap-tier trigger scan for oversized payloads (e.g. a 394KB
# Gmail body) that would blow a subagent's context if read inline, or that land in
# plugin-temp where subagents / the Read tool can't reach them.
#
# Pattern (detect -> land -> grep): when a fetched payload exceeds ~40KB, write it to a
# tool-readable path on the session mount via Desktop Commander (NOT plugin-temp), then run
# this script to answer the binary trigger question deterministically — zero LLM/context cost.
# Escalate to a chunked map-reduce subagent ONLY if a HIT needs semantic summarisation.
#
# Usage: bash scripts/scan-large-payload.sh <file> <keyword> [keyword ...]
#   <file>     absolute path to the saved payload (plain text)
#   <keyword>  one or more case-insensitive terms (quote multi-word phrases)
#
# Output: per-keyword HIT [n line(s)] with bounded context, or MISS, then a SUMMARY line.
# Exit:   0 = scan ran; 1 = usage error or file missing.

set -u
CTX=1            # context lines shown around each match
MAX_LINES=12     # cap reported lines per keyword (prevents context re-bloat)
SNIPPET=240      # max chars per reported line

if [ "$#" -lt 2 ]; then
  echo "usage: scan-large-payload.sh <file> <keyword> [keyword ...]" >&2
  exit 1
fi

FILE="$1"; shift
if [ ! -f "$FILE" ]; then
  echo "MISSING: $FILE — land the payload on a tool-readable path (session mount) via DC first." >&2
  exit 1
fi

bytes=$(wc -c < "$FILE" | tr -d ' ')
lines=$(wc -l < "$FILE" | tr -d ' ')
kw_count="$#"
echo "FILE: $FILE  (${bytes} bytes, ${lines} lines)"
echo "KEYWORDS: $*"
echo "===="

hits=0
for kw in "$@"; do
  n=$(grep -icF -- "$kw" "$FILE" 2>/dev/null || true); n=${n:-0}
  if [ "$n" -gt 0 ]; then
    hits=$((hits + 1))
    echo "HIT  [${n} line(s)]  \"$kw\""
    grep -inF -C"$CTX" -- "$kw" "$FILE" 2>/dev/null | head -n "$MAX_LINES" | cut -c1-"$SNIPPET"
  else
    echo "MISS  \"$kw\""
  fi
  echo "----"
done
echo "SUMMARY: ${hits}/${kw_count} keyword(s) hit."
