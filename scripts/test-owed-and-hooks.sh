#!/usr/bin/env bash
# test-owed-and-hooks.sh — fixture tests for owed.py, check-denylist-coverage.py, check-public-text.py and
# check-send-text.py (2026-11-05). Synthetic data only; no network (visibility is injected).
# Exit 0 = all pass, 1 = a case diverged.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
ok() { echo "ok   $1"; }
no() { echo "FAIL $1"; fail=1; }

# --- owed.py ---------------------------------------------------------------------------------------------
cat > "$T/active.txt" <<'EOF'
# 4 active tasks · project x · Priority | Status | Due | Title | page id
High | Not started | 2026-11-04 | Late thing | aaa
High | Not started | 2026-11-06 | Soon thing | bbb
Medium | On Hold | — | Undated thing | ccc
Low | Not started | 2026-12-01 | Far thing | ddd
EOF
o=$(python3 -I "$HERE/owed.py" x --from-file "$T/active.txt" --today 2026-11-05 2>&1); rc=$?
[ $rc = 0 ] && grep -q "OVERDUE: 1" <<<"$o" && grep -q "DUE SOON: 1" <<<"$o" && grep -q "NO DATE: 1" <<<"$o" && ! grep -q "Far thing" <<<"$o" \
  && ok "owed: overdue, due soon and undated sorted; far tasks left out" || { no "owed grouping"; echo "$o"; }
o=$(python3 -I "$HERE/owed.py" x --from-file "$T/active.txt" --today 2026-11-05 --before 2026-12-01 2>&1)
grep -q "DUE SOON: 2" <<<"$o" && ok "owed: --before widens the window to the next meeting" || no "owed --before"
printf 'P2|Open|2026-11-06|x|y\nError: something broke\n' > "$T/junk.txt"
python3 -I "$HERE/owed.py" x --from-file "$T/junk.txt" >/dev/null 2>&1; [ $? = 1 ] && ok "owed: unparseable output is a failure, never 'nothing owed'" || no "owed junk"
python3 -I "$HERE/owed.py" x --from-file "$T/nope.txt" >/dev/null 2>&1; [ $? = 2 ] && ok "owed: a missing file is bad input" || no "owed missing file"
o=$(NOTION_ACTIVE=/nonexistent/notion-active.py python3 -I "$HERE/owed.py" x 2>&1); rc=$?
[ $rc = 1 ] && grep -q "do not report 'nothing owed'" <<<"$o" && ok "owed: a failed Notion read exits 1, never 'nothing owed'" || no "owed failed read"

# --- check-denylist-coverage.py ------------------------------------------------------------------------
mkdir -p "$T/reg"
printf '### Acme Widgets (Jane Roe) -- Pilot\n' > "$T/reg/acme.md"
printf '### Business Development (BD)\n' > "$T/reg/bd.md"
printf '{"client": ["Acme Widgets"], "person": ["Jane Roe"]}' > "$T/dl-ok.json"
printf '{"client": ["Acme Widgets"], "person": []}' > "$T/dl-gap.json"
python3 -I "$HERE/check-denylist-coverage.py" --registry "$T/reg" --denylist "$T/dl-ok.json" >/dev/null && ok "coverage: all names on the list passes (internal headings skipped)" || no "coverage ok case"
o=$(python3 -I "$HERE/check-denylist-coverage.py" --registry "$T/reg" --denylist "$T/dl-gap.json" 2>&1); rc=$?
[ $rc = 1 ] && grep -q "MISSING 'Jane Roe'" <<<"$o" && ok "coverage: a missing contact fails" || no "coverage gap case"
mkdir -p "$T/reg2"
printf '### Acme -- Pilot\n' > "$T/reg2/a.md"
printf '### Beta Labs -- One\nnotes\n### Gamma Corp -- Two\n' > "$T/reg2/b.md"
printf '{"client": ["Acme Corp Holdings", "Beta Labs"], "person": ["a"]}' > "$T/dl2.json"
o=$(python3 -I "$HERE/check-denylist-coverage.py" --registry "$T/reg2" --denylist "$T/dl2.json" 2>&1)
grep -q "MISSING 'Acme'" <<<"$o" && ok "coverage: a name only inside a longer term is not covered" || no "coverage substring"
grep -q "MISSING 'Gamma Corp'" <<<"$o" && ok "coverage: a second client heading in a file is checked" || no "coverage second heading"

# --- check-public-text.py --------------------------------------------------------------------------------
printf '{"client": ["Acme Widgets"], "person": []}' > "$T/dl.json"
pt() { printf '%s' "$1" | PUBLIC_TEXT_VISIBILITY="$2" PUBLIC_TEXT_DENYLIST="$T/dl.json" python3 -I "$HERE/check-public-text.py"; }
j() { python3 -c 'import json,sys; print(json.dumps({"tool_input": {"command": sys.argv[1]}, "cwd": sys.argv[2]}))' "$1" "$T"; }
o=$(pt "$(j 'gh pr create -R me/tools --title x --body "Synced for the Acme Widgets repo"')" PUBLIC)
grep -q '"deny"' <<<"$o" && ok "public text: a client name in a PR body on a PUBLIC repo is denied" || no "public deny"
o=$(pt "$(j 'gh pr create -R me/tools --title x --body "Synced for a client repo"')" PUBLIC)
[ -z "$o" ] && ok "public text: clean PR text passes" || no "public clean"
o=$(pt "$(j 'gh pr create -R me/tools --title x --body "Synced for the Acme Widgets repo"')" PRIVATE)
[ -z "$o" ] && ok "public text: private repos are not scanned" || no "public private"
printf '{"client": ["Acme Widgets"], "person": [], "path": ["ownername"]}' > "$T/dl.json"
o=$(pt "$(j 'gh pr create -R ownername/tools --title x --body "Synced for a client repo"')" PUBLIC)
[ -z "$o" ] && ok "public text: a blocklisted owner in -R owner/repo is not flagged (only published text is scanned)" || no "public owner false positive"
o=$(pt "$(j 'python3 edit.py --text "gh pr create --body Acme Widgets"')" PUBLIC)
[ -z "$o" ] && ok "public text: a command that only mentions gh pr create is not treated as one" || no "public mention false positive"
o=$(pt "$(j 'cd /tmp && GH_X=1 gh pr create -R x/y --title "Acme Widgets"')" PUBLIC)
grep -q '"deny"' <<<"$o" && ok "public text: gh after cd && and an env prefix is still caught" || no "public prefix"
# Chaos review 2026-11-05: ways the text used to slip past the scan
printf 'Notes for Acme Widgets\n' > "$T/cat.md"
for c in 'gh api repos/o/r/issues/1/comments -f body="Acme Widgets update"' \
         'gh pr create -R o/r --title x --body "$(cat cat.md)"' \
         'gh pr create -R o/r --title x --body-file=cat.md' \
         'gh -R o/r pr create --title "Acme Widgets"' \
         'gh issue comment 4 -R o/r --body "Acme Widgets"'; do
  o=$(pt "$(j "$c")" PUBLIC); grep -q '"deny"' <<<"$o" && ok "public text: caught: ${c:0:46}" || no "public bypass: $c"
done
printf 'harmless\n' > "$T/-"  # a file literally named "-" must not be mistaken for the stdin body
o=$(pt "$(j 'gh pr create -R o/r --title x --body-file -')" PUBLIC)
grep -q 'could not be read' <<<"$o" && ok "public text: unreadable text (stdin) is denied, not waved through" || no "public stdin"
o=$(pt "$(j 'gh api repos/o/r/branches')" PUBLIC)
[ -z "$o" ] && ok "public text: a gh api read with no body passes" || no "public api read"
printf 'Notes for Acme Widgets\n' > "$T/body.md"
o=$(pt "$(j 'gh pr edit 3 -R me/tools --body-file body.md')" PUBLIC)
grep -q '"deny"' <<<"$o" && ok "public text: --body-file contents are scanned" || no "public body-file"
o=$(pt "$(j 'git status')" PUBLIC)
[ -z "$o" ] && ok "public text: unrelated commands pass untouched" || no "public unrelated"

printf 'not json' | python3 -I "$HERE/check-public-text.py" >/dev/null 2>&1; [ $? = 0 ] && ok "public text: a crash on a non-gh call never blocks it" || no "public crash non-gh"
printf 'not json; gh pr create --body x' | python3 -I "$HERE/check-public-text.py" >/dev/null 2>&1; [ $? = 2 ] && ok "public text: a crash on a gh text call blocks it" || no "public crash gh"

# --- check-send-text.py ----------------------------------------------------------------------------------
st() { python3 -c 'import json,sys; print(json.dumps({"tool_name": sys.argv[1], "tool_input": {"content": sys.argv[2]}}))' "$1" "$2" | python3 -I "$HERE/check-send-text.py"; }
o=$(st mcp__notion__notion-update-page 'Owner: Sam (agreed Nov 5).')
grep -q '"deny"' <<<"$o" && ok "send: an uncited 'agreed' in a Notion write is denied" || no "send notion deny"
o=$(st mcp__notion__notion-update-page 'Alex confirmed the baseline (0123456789abcdef).')
[ -z "$o" ] && ok "send: a cited claim passes" || no "send cited"
o=$(st mcp__notion__notion-update-page 'Proposed, not yet confirmed with Sam.')
[ -z "$o" ] && ok "send: a negated claim passes" || no "send negated"
o=$(st mcp__claude_ai_Gmail__create_draft 'Thanks, Alex confirmed the baseline.')
grep -q '"ask"' <<<"$o" && ! grep -q '"deny"' <<<"$o" && ok "send: an email is never blocked, the user is asked" || no "send gmail ask"
sj() { python3 -c 'import json,sys; print(json.dumps({"tool_name": sys.argv[1], "tool_input": json.loads(sys.argv[2])}))' "$1" "$2" | python3 -I "$HERE/check-send-text.py"; }
o=$(sj mcp__notion__notion-update-page '{"content_updates": [{"old_str": "Vendor agreed to the price", "new_str": "Vendor proposed the price"}]}')
[ -z "$o" ] && ok "send: the text being replaced (old_str) is not checked" || no "send old_str"
o=$(sj mcp__notion__notion-update-page '{"properties": {"Status": "Decided"}}')
[ -z "$o" ] && ok "send: a one-word field value (Status: Decided) is not checked" || no "send status"
o=$(st mcp__claude_ai_Gmail__reply $'Thanks, see below.\n> We confirmed the scope last week.')
[ -z "$o" ] && ok "send: quoted history in a reply is not checked" || no "send quoted"
o=$(st mcp__notion__notion-update-page $'Owner: Sam (agr​eed Nov 5).')
grep -q '"deny"' <<<"$o" && ok "send: a zero-width character does not hide 'agreed'" || no "send zero-width"
o=$(printf 'not json' | python3 -I "$HERE/check-send-text.py" 2>/dev/null); rc=$?
[ $rc = 0 ] && [ -z "$o" ] && ok "send: a crash allows the call (backstop, not a wall)" || no "send crash"

[ $fail -eq 0 ] && echo "test-owed-and-hooks: all passed" || echo "test-owed-and-hooks: FAILURES"
exit $fail
