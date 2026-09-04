#!/usr/bin/env bash
# test-kiss-yagni.sh — negative control for kiss-yagni-reminder.py.
#
# This hook is an ADVISORY, and the whole point is that it stays one. Three
# properties are load-bearing, and every case below asserts all three:
#
#   never blocks   — nothing on stdout. A PreToolUse hook signals a block with a
#                    JSON permissionDecision; an advisory that ever emitted one
#                    would veto writes silently, which is the worst failure here.
#   never fails    — exit 0, always. A non-zero exit surfaces as a tool error.
#   never crashes  — no traceback. Shipped with a real crash on {"file_path": null},
#                    because .get(key, "") returns None for a key that is PRESENT
#                    and null; the default only covers a MISSING key. The traceback
#                    read as a genuine failure and the checkpoint never printed.
#
#   R1-R8   reminder fires — code files across languages.
#   S1-S6   silent — prose, data, no extension, and the wrong tool. A reminder that
#           fires on everything is one the reader learns to skip, which is
#           indistinguishable from having no reminder.
#   M1-M10  malformed payloads. M1 is the shipped crash; the rest are its neighbours.
#   K1      known limit — the hook says nothing about HOW verbose the code is, and
#           does not look at .md at all. It is a nudge, not a prose gate. If K1
#           starts failing, someone grew this past its job.
#
# Usage: bash .claude/hooks/test-kiss-yagni.sh

set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 1

HOOK="${HOOK:-.claude/hooks/kiss-yagni-reminder.py}"
[ -f "$HOOK" ] || { echo "no such hook: $HOOK" >&2; exit 2; }

pass=0
fail=0
ok()  { printf '  ok   %-4s %s\n' "$1" "$2"; pass=$((pass+1)); }
bad() { printf '  FAIL %-4s %s\n' "$1" "$2"; fail=$((fail+1)); }

OUT=""; ERR=""; RC=0
# stdout and stderr kept apart: the reminder goes to stderr, a block would go to stdout.
run() { # run <payload-json>
  local eo; eo="$(mktemp)"
  OUT="$(printf '%s' "$1" | python3 "$HOOK" 2>"$eo")"; RC=$?
  ERR="$(cat "$eo")"; rm -f "$eo"
}

# The three invariants, asserted on every single case.
invariants() { # invariants <id>  -> echoes a reason, or nothing
  [ "$RC" -ne 0 ]                          && { echo "exit $RC (must be 0)"; return; }
  [ -n "$OUT" ]                            && { echo "wrote to stdout: ${OUT:0:60}"; return; }
  printf '%s' "$ERR" | grep -qi traceback  && { echo "traceback: $(printf '%s' "$ERR" | tail -1)"; return; }
  echo ""
}

payload() { printf '{"tool_name":"%s","tool_input":{"file_path":"%s"}}' "$1" "$2"; }

assert_reminds() { # <id> <path>
  run "$(payload Write "$2")"
  local why; why="$(invariants)"
  if [ -n "$why" ]; then bad "$1" "$2 — $why"
  elif ! printf '%s' "$ERR" | grep -q "KISS/YAGNI checkpoint"; then
    bad "$1" "$2 — code file, but no checkpoint printed"
  else ok "$1" "$2 — checkpoint"
  fi
}

assert_silent() { # <id> <label> <payload>
  run "$3"
  local why; why="$(invariants)"
  if [ -n "$why" ]; then bad "$1" "$2 — $why"
  elif [ -n "$ERR" ]; then bad "$1" "$2 — false positive: $(printf '%s' "$ERR" | head -1)"
  else ok "$1" "$2 — silent"
  fi
}

assert_survives() { # <id> <label> <payload>
  run "$3"
  local why; why="$(invariants)"
  if [ -n "$why" ]; then bad "$1" "$2 — $why"; else ok "$1" "$2 — survived"; fi
}

echo "REMINDER FIRES — code files"
assert_reminds R1 /r/lib/parse.py
assert_reminds R2 /r/scripts/deploy.sh
assert_reminds R3 /r/src/app.ts
assert_reminds R4 /r/src/App.tsx
assert_reminds R5 /r/cmd/main.go
assert_reminds R6 /r/src/lib.rs
assert_reminds R7 /r/Widget.java
assert_reminds R8 /r/a/b/c/deeply/nested/thing.cpp
run "$(payload Edit /r/lib/parse.py)"
[ -z "$(invariants)" ] && printf '%s' "$ERR" | grep -q KISS \
  && ok R9 "Edit fires too, not just Write" || bad R9 "Edit did not fire"

echo
echo "SILENT — not code, or not a write"
assert_silent S1 "prose .md"        "$(payload Write /r/docs/notes.md)"
assert_silent S2 "data .json"       "$(payload Write /r/pkg/tsconfig.json)"
assert_silent S3 "plain .txt"       "$(payload Write /r/a/notes.txt)"
assert_silent S4 "no extension"     "$(payload Write /r/Makefile)"
assert_silent S5 "Read a code file" "$(payload Read /r/lib/parse.py)"
assert_silent S6 "Bash tool"        '{"tool_name":"Bash","tool_input":{"command":"ls"}}'

echo
echo "MALFORMED — must survive, never block, never crash"
assert_survives M1  "file_path is null (the shipped crash)" '{"tool_name":"Write","tool_input":{"file_path":null}}'
assert_survives M2  "tool_input is null"                    '{"tool_name":"Write","tool_input":null}'
assert_survives M3  "tool_input is a list"                  '{"tool_name":"Write","tool_input":[1,2]}'
assert_survives M4  "file_path is an int"                   '{"tool_name":"Write","tool_input":{"file_path":42}}'
assert_survives M5  "payload is a list"                     '[1,2,3]'
assert_survives M6  "payload is a bare string"              '"hello"'
assert_survives M7  "empty object"                          '{}'
assert_survives M8  "tool_input missing"                    '{"tool_name":"Write"}'
assert_survives M9  "not json at all"                       'garbage'
assert_survives M10 "empty stdin"                           ''

echo
echo "KNOWN LIMIT — the hook is expected NOT to do this"
run "$(payload Write /r/docs/verbose-notes.md)"
if [ -z "$ERR" ]; then
  ok K1 "says nothing about prose or comment bloat — it is a nudge, not a gate"
else
  bad K1 "fired on .md — someone grew this past its job; re-check S1-S6"
fi

echo
echo "-----------------------------------------"
printf 'passed %d, failed %d\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
