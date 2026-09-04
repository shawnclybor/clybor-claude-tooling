#!/usr/bin/env bash
# test-document-claims.sh -- negative control for check-document-claims.py.
#
#   M1-M4  the four wrong claims made on this build on 2026-09-03, uncited -- must be BLOCKED.
#   C1-C7  clean controls -- must NOT fire. The same claims cited; a description with no
#          absolute; a quoted claim; a fenced block; an out-of-scope path; the override marker;
#          a NOT-IN-TEXT statement (the honest form the tool prints).
#   K1     known miss -- "the firm's zeros are transcribed, not defaulted" carries no absolute.
#          The gate is EXPECTED to let it through; the judgment half is the reader's. If K1
#          starts being caught, someone widened ABSOLUTE -- check C1-C7 before celebrating.
#
# Usage: bash .claude/hooks/test-document-claims.sh
set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 1
GATE="${GATE:-.claude/hooks/check-document-claims.py}"
pass=0; fail=0
ok()  { printf '  ok   %-3s %s\n' "$1" "$2"; pass=$((pass+1)); }
bad() { printf '  FAIL %-3s %s\n' "$1" "$2"; fail=$((fail+1)); }

# hook <path> <content>  -> prints "deny" or "allow"
hook() {
  python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":sys.argv[2]}}))' "$1" "$2" \
    | python3 "$GATE" | grep -q '"deny"' && echo deny || echo allow
}
P=".serena/memories/yellow_sheet/probe.md"
assert_deny()  { [[ "$(hook "$P" "$2")" == deny ]]  && ok "$1" "blocked: ${2:0:60}" || bad "$1" "NOT blocked: ${2:0:60}"; }
assert_allow() { [[ "$(hook "${3:-$P}" "$2")" == allow ]] && ok "$1" "allowed: ${2:0:60}" || bad "$1" "WRONGLY blocked: ${2:0:60}"; }

echo "mutants -- must be blocked"
assert_deny M1 "Advanced Imaging - Lancaster contains no zero token anywhere in the document."
assert_deny M2 "Frye's credit columns are blank on the bill; only the charges are printed."
assert_deny M3 "The 360 Wellness bill is structurally blank and states nothing about money."
assert_deny M4 "Every printed total on the Joint Chiropractic bill is zero, so the document states no charge at all."

echo "controls -- must be allowed"
assert_allow C1 "Advanced Imaging states one zero, in box 29 AMOUNT PAID (bill-advanced-imaging.txt:41), and nowhere else."
assert_allow C2 "The bill prints a columnar totals row with six figures under five headers (lines 63 and 115)."
assert_allow C3 "The lien governs over the bill, and the bill prints its own total row."
assert_allow C4 "session-c3 wrote that \"the zeros are transcribed and the bill contains no other figure anywhere\", which did not survive."
assert_allow C5 $'Measured:\n```\nthe bill contains no zero token anywhere\n```\nSee the run.'
assert_allow C6 "The bill contains no zero token anywhere in the document." "docs/some-other-project/notes.md"
assert_allow C7 $'<!-- claims-ok -->\nThe bill contains no zero token anywhere in the document.'
assert_allow C9 "A bill whose text holds no money token at all is refused at limb 2; every printed total zero is limb 1a."
assert_allow C8 "4010.00 is NOT IN TEXT for bill-360-wellness.txt; that is a fact about our extraction, not the page."

echo "known miss -- expected to pass through"
if [[ "$(hook "$P" "The firm's zeros are transcribed, not defaulted.")" == allow ]]; then
  ok K1 "not caught (expected -- no absolute; the reader's half)"
else
  bad K1 "K1 is now caught: ABSOLUTE was widened; re-check C1-C8"
fi

echo "files mode -- exit code carries the verdict"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/yellow_sheet"
printf 'The Acme bill contains no zero token anywhere.\n' > "$T/yellow_sheet/a.md"
printf 'The bill prints a total (bill.txt:12).\n' > "$T/yellow_sheet/b.md"
python3 "$GATE" --files "$T/yellow_sheet/a.md" --quiet >/dev/null 2>&1; [[ $? -eq 1 ]] && ok F1 "--files exits 1 on a finding" || bad F1 "--files did not exit 1"
python3 "$GATE" --files "$T/yellow_sheet/b.md" --quiet >/dev/null 2>&1; [[ $? -eq 0 ]] && ok F2 "--files exits 0 when clean" || bad F2 "--files did not exit 0"

echo; echo "passed $pass, failed $fail"
[[ $fail -eq 0 ]]
