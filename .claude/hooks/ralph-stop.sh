#!/usr/bin/env bash
# ralph-stop.sh
#
# Stop hook implementing the Ralph Loop pattern.
# Reads .ralph-loop/state.json. If an active loop exists, decides whether to:
#   - Allow exit (completion-promise emitted, or max-iterations hit)
#   - Block exit and re-feed the prompt (continue the loop)
#
# Trigger: configured in settings.json under "hooks.Stop"
# Stdin:   JSON from Claude Code containing session_id, transcript_path, etc.
# Stdout:  JSON {"decision": "block", "reason": "..."} to block exit
#          Empty / exit 0 to allow exit
#
# Inspired by Anthropic's official ralph-loop plugin.

set -uo pipefail

STATE_FILE=".ralph-loop/state.json"

# No active loop → allow exit
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# Read stdin (Claude Code passes a JSON event)
STDIN_JSON="$(cat 2>/dev/null || echo '{}')"

# Pull fields out of state
PROMPT=$(jq -r '.prompt // ""' "$STATE_FILE" 2>/dev/null)
COMPLETION_PROMISE=$(jq -r '.completion_promise // "DONE"' "$STATE_FILE" 2>/dev/null)
MAX_ITER=$(jq -r '.max_iterations // 50' "$STATE_FILE" 2>/dev/null)
CURRENT_ITER=$(jq -r '.current_iteration // 0' "$STATE_FILE" 2>/dev/null)

# Pull transcript path from the stdin event so we can look for the completion-promise
TRANSCRIPT_PATH=$(echo "$STDIN_JSON" | jq -r '.transcript_path // ""' 2>/dev/null)

# Check if the completion-promise appears in the recent transcript
PROMISE_FOUND=0
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  # Look at the last 200 lines of the transcript for the exact promise string
  if tail -200 "$TRANSCRIPT_PATH" 2>/dev/null | grep -q -F "$COMPLETION_PROMISE"; then
    PROMISE_FOUND=1
  fi
fi

# Decision: completion-promise emitted → allow exit, clear state
if [ "$PROMISE_FOUND" = "1" ]; then
  rm -f "$STATE_FILE"
  echo "Ralph loop complete — completion-promise '$COMPLETION_PROMISE' detected after $CURRENT_ITER iterations." >&2
  exit 0
fi

# Decision: max iterations hit → allow exit, clear state
if [ "$CURRENT_ITER" -ge "$MAX_ITER" ]; then
  rm -f "$STATE_FILE"
  echo "Ralph loop halted — max-iterations ($MAX_ITER) reached without completion-promise. State cleared." >&2
  exit 0
fi

# Decision: continue the loop. Increment iteration count, re-feed the prompt.
NEXT_ITER=$((CURRENT_ITER + 1))
TMP_FILE="${STATE_FILE}.tmp"
jq --argjson n "$NEXT_ITER" '.current_iteration = $n | .last_continued_at = (now | todate)' \
  "$STATE_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$STATE_FILE"

# Block exit with a JSON decision. The "reason" field is what gets fed back to Claude.
REASON="Ralph iteration $NEXT_ITER of $MAX_ITER. Continue working on the task. When complete, emit the exact string: $COMPLETION_PROMISE

Original task:
$PROMPT"

# Use jq to safely build the JSON payload
jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
exit 0
