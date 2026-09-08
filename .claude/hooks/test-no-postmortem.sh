#!/usr/bin/env bash
# Negative control for no-postmortem-validator.py. Both directions: prose that
# MUST be denied, and prose that MUST pass. A gate that only ever says no is
# indistinguishable from a broken gate.
HOOK="$(cd "$(dirname "$0")" && pwd)/no-postmortem-validator.py"
pass=0; fail=0

run() {  # run <file_path> <content>
  python3 - "$1" "$2" <<'PY' | python3 "$HOOK"
import json, sys
print(json.dumps({"tool_name": "Write",
                  "tool_input": {"file_path": sys.argv[1], "content": sys.argv[2]}}))
PY
}

deny() {  # deny <label> <file_path> <content>
  if run "$2" "$3" | grep -q '"deny"'; then
    pass=$((pass+1)); printf '  ok   DENY  %s\n' "$1"
  else
    fail=$((fail+1)); printf '  FAIL want deny  %s\n' "$1"
  fi
}

allow() {  # allow <label> <file_path> <content>
  if run "$2" "$3" | grep -q '"deny"'; then
    fail=$((fail+1)); printf '  FAIL want allow %s\n' "$1"
  else
    pass=$((pass+1)); printf '  ok   ALLOW %s\n' "$1"
  fi
}

echo "== code comments that MUST be denied =="
deny "absence announcement"   /r/a.py  '# ⚠ NO `Acct #(s)` COLUMN. Alysia asked for it off this tab (criterion 4).
X = 1'
deny "used to hold"           /r/a.sh  '# Checking the column that used to hold one proves nothing.
echo hi'
deny "no longer"              /r/a.py  '# the guard is no longer needed here
X = 1'
deny "we removed"             /r/a.py  '# we removed the roll-up from this tab
X = 1'
deny "the old behaviour"      /r/a.py  '# the old behaviour returned None on a blank cell
X = 1'
deny "formerly in docstring"  /r/a.py  'def f():
    """formerly the bill reader."""
    return 1'
deny "multiline docstring"    /r/a.py  '"""
Reader.

We renamed the header key here.
"""
X = 1'
deny "trailing comment"       /r/a.py  'X = 1  # previously held the account number'
deny "change-narration head"  /r/a.py  '# What changed
# - one thing
X = 1'
deny "js // comment"          /r/a.js  '// this used to be a Map, keyed by provider
const x = 1;'

echo "== markdown still denied (no regression) =="
deny "md formerly"            /r/a.md  'The reader, formerly the parser, does X.'
deny "md strikethrough"       /r/a.md  'A ~~dropped~~ column.'

echo "== code that MUST pass =="
allow "tombstone in a LITERAL" /r/a.py 'MSG = "this column was formerly the Acct #"
X = 1'
allow "refusal text literal"   /r/a.py 'def why():
    return "we removed nothing; the bill is unread"'
allow "purpose clause"         /r/a.py '# the regex used to match the header row
X = 1'
allow "no longer THAN"         /r/a.py '# keep the label no longer than 40 chars
X = 1'
allow "lowercase absence"      /r/a.py "# an empty cell is dropped; there is no such column here
X = 1"
allow "real Acct comment"      /r/a.py "# Only an ACCOUNT reaches the sheet's Acct # column.
X = 1"
allow "override token"         /r/a.py '# we removed the column  postmortem-ok
X = 1'
allow "provenance filename"    /r/a-audit.py '# we removed the column
X = 1'
allow "out of scope ext"       /r/a.txt '# we removed the column'
allow "plain code, no prose"   /r/a.py 'def f(a, b):
    return a + b'

echo "== quotation is a reference, not an instance =="
deny "bare tombstone in md"    /r/a.md  'The reader was formerly the parser.'
allow "md quotes the token"    /r/a.md  'The gate blocks `formerly` and `used to be` in prose.'
allow "md fenced example"      /r/a.md  'Blocked shapes:

```
# we removed the column
```
'
allow "real md marker"         /r/a.md  '<!-- postmortem-ok -->
The reader was formerly the parser.'
deny  "quoted marker is NOT a claim" /r/a.md 'Override with the token `postmortem-ok`.
The reader was formerly the parser.'
allow "code quotes the token"  /r/a.py  '# a comment carrying `used to be` names the banned shape
X = 1'
deny  "code quoted marker"     /r/a.py  '# override with `postmortem-ok`; we removed the column
X = 1'

echo
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
