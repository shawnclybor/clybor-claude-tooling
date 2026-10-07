#!/usr/bin/env bash
# test-clarity-stop-hook.sh — live battery for global/clarity-stop-hook.json, a prompt-type
# Stop hook (installed through the clarity-check plugin) in which a model judges whether
# Claude's final reply is clear before the user sees it.
#
# The judge is a model, so verdicts vary run to run: each case runs REPS times and must be
# right every time. A control run with no hook proves the battery can fail: the unclear
# reply must come back unrevised when nothing is judging it.
#
# Each run is a headless `claude -p` told to reply with a fixture verbatim, loading ONLY this
# hook (--setting-sources project in an empty temp dir). A block shows as a second turn.
# Costs a few cents per run.
#
# Usage: bash global/test-clarity-stop-hook.sh [hook.json]   REPS=3 by default
#        exit 0 = every case right on every run, 1 = any miss

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="${1:-$HERE/clarity-stop-hook.json}"
REPS="${REPS:-3}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
echo '{}' > "$TMP/none.json"
PASS=0; FAIL=0

UNCLEAR='Done. Summary of what shipped: bumped acme-core to v2.4.1 via scripts/release.sh, PROMOTE-OK from validate-release.py, edited SKILL.md frontmatter for billing-guide, page 3a025bc3-529a-813b updated via mcp__notion__update-page, and the PreToolUse hook passed. Everything is landed and in place. All set.'
DENSE='Fixed. sync-gate.py now reads last_message first and falls back to log_path; added a SYNC_GATE_LOG env override; tests/test-sync-gate.sh is 4/4 on the fix and 3/4 on HEAD. Hook config in settings.json unchanged, ARMED still False.'
CLEAR='The duplicate-task bug in meeting logging is fixed and installed.

1. Meeting logging. Claude now creates one task per action item instead of two, which was the problem you hit on Monday. I confirmed it by logging a test meeting. Recommendation: no action needed.
2. Test note. The test left a note in your notes list titled "TEST - delete me". It is harmless but clutters the list. Recommendation: delete it when convenient.
3. Older duplicates. Tasks duplicated before today are still there, 14 of them across three projects. Removing them by hand would take a while. Recommendation: reply "clean them up" and I will merge them.'
QUESTION='Which calendar should the planning call go on: the work one or the personal one?'

# turns <settings.json> <text> -> number of turns the run took (2 = the hook blocked once)
turns() {
  (cd "$TMP" && timeout 300 claude -p "Reply with exactly the following text, verbatim, and nothing else. Do not use any tools. Text: $2" \
    --model haiku --setting-sources project --settings "$1" --output-format json 2>/dev/null) | jq -r '.num_turns // "error"'
}

# check <name> <want-turns> <settings.json> <text> <reps>
check() {
  local i got
  for i in $(seq 1 "$5"); do
    got=$(turns "$3" "$4")
    if [ "$got" = "$2" ]; then PASS=$((PASS+1)); echo "PASS  $1 #$i"
    else FAIL=$((FAIL+1)); echo "FAIL  $1 #$i (turns $got, want $2)"; fi
  done
}

check "control: unclear reply, no hook -> not revised" 1 "$TMP/none.json" "$UNCLEAR" 1
check "unclear wrap-up -> blocked"                     2 "$HOOK" "$UNCLEAR"  "$REPS"
check "short but dense reply -> blocked"               2 "$HOOK" "$DENSE"    "$REPS"
check "clear numbered wrap-up -> passes"               1 "$HOOK" "$CLEAR"    "$REPS"
check "plain question -> passes"                       1 "$HOOK" "$QUESTION" "$REPS"

# This file is canonical. The installed copy ships in the clarity-check plugin (uploaded to
# the account, so it runs in cloud Cowork and syncs to Claude Code). Exactly one installed
# copy is right: Claude Code does not merge identical prompt hooks, so a second copy in
# ~/.claude/settings.json judges every reply twice. Report missing, drifted and doubled copies.
same() { jq -e --slurpfile c "$HOOK" '[.hooks.Stop[]?.hooks[]? | select(.type=="prompt")] | any(. == $c[0].hooks.Stop[0].hooks[0])' "$1" >/dev/null 2>&1; }
COPIES=0
for f in ~/.claude/plugins/synced/*/clarity-check/hooks/hooks.json; do
  [ -f "$f" ] || continue
  if same "$f"; then COPIES=$((COPIES+1)); echo "OK    synced plugin copy matches canonical"
  else echo "WARN  synced plugin copy differs from canonical: $f (rebuild and re-upload clarity-check)"; fi
done
if same ~/.claude/settings.json; then COPIES=$((COPIES+1)); echo "INFO  ~/.claude/settings.json also has a copy"; fi
case "$COPIES" in
  0) echo "WARN  no installed copy matches canonical (upload the clarity-check plugin)" ;;
  1) ;;
  *) echo "WARN  $COPIES installed copies: every reply is judged $COPIES times; remove the settings.json copy" ;;
esac

echo "---"; echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
