#!/usr/bin/env bash
# test-check-draft.sh — fixture tests for check-draft.py (2026-11-05: quote drift, "agreed" with no source,
# counts carried forward instead of recomputed). Synthetic fixtures only.
# Exit 0 = all pass, 1 = a case diverged.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
CD="$HERE/check-draft.py"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
expect() { # name expected-exit draft-text [extra args...]
  local name=$1 want=$2 text=$3; shift 3
  printf '%s\n' "$text" > "$T/d.md"
  out=$(python3 "$CD" "$T/d.md" "$@" 2>&1); got=$?
  if [ "$got" = "$want" ]; then echo "ok   $name"; else echo "FAIL $name: exit $got, expected $want"; echo "$out" | sed 's/^/     /'; fail=1; fi
}

cat > "$T/src.txt" <<'EOF'
Ship small reports that are reviewed in the weekly planning meeting (or monthly -- does it matter?)
June 30 was chosen as the latest date for the first hiring plan, rather than a hard cutoff.
EOF
cat > "$T/counts.json" <<'EOF'
{"punch_list": {"rows": 45, "rows_with_id": 43, "distinct_ids": 41}, "backlog": {"items": 99, "open": 49}, "missing_open": ["11"]}
EOF
S=(--sources "$T/src.txt")
C=(--counts "$T/counts.json")

# Quotes
expect "exact quote passes" 0 'Alex: "June 30 was chosen as the latest date" for the plan.' "${S[@]}"
expect "curly quotes, case and spacing differences pass" 0 'It says “ship small reports   that are Reviewed in the weekly planning meeting”.' "${S[@]}"
expect "strengthened quote fails" 1 'It "defines the planning loop as reports reviewed weekly" in planning.' "${S[@]}"
expect "quote split by an ellipsis checks each piece" 0 '"June 30 was chosen as the latest date ... rather than a hard cutoff"' "${S[@]}"
expect "one bad piece of an ellipsis quote fails" 1 '"June 30 was chosen as the latest date ... a hard and binding cutoff for everyone"' "${S[@]}"
printf 'No true work\xef\xac\x82ow exists yet.\n' > "$T/lig.txt"
expect "PDF ligatures (fl) match plain text" 0 'Notes: "No true workflow exists yet".' --sources "$T/lig.txt"
expect "short quotes (under 4 words) are skipped" 0 'They called it "a filter, really".' "${S[@]}"
expect "a quote wrapped across two lines is checked whole" 0 $'Alex wrote "June 30 was chosen as the latest\ndate for the first hiring plan" and "ship small reports that are reviewed".' "${S[@]}"
expect "a wrapped quote that drifts still fails" 1 $'Alex wrote "June 30 was picked as the latest\ndate for the first hiring plan".' "${S[@]}"
expect "quotes are not checked without --sources" 0 'It "defines the planning loop as reports reviewed weekly" in planning.'

# Settled words
expect "'agreed' with no source fails" 1 'Who writes it (agreed Nov 5): Sam.'
expect "'confirmed' with a message ID passes" 0 'Alex confirmed the baseline (0123456789abcdef).'
expect "'approved' with a file path passes" 0 'Approved tools are listed in docs/working/brief.md.'
expect "'decided' with a link passes" 0 'The client decided the date ([email](https://example.com/x)).'
expect "negated ('not yet confirmed') passes" 0 'Owner: Sam (proposed, not yet confirmed with them).'
expect "a negated word does not excuse a later bare one" 1 'Not yet confirmed by the client, but agreed by Sam.'
expect "marker with a reason passes" 0 'One KPI set agreed by the boards <!-- settled-ok: a target -->'
expect "explicit marker passes" 0 'The four agreed principles <!-- settled-ok -->'
expect "settled words inside a code block are ignored" 0 $'```text\nagreed\n```'
expect "settled words in frontmatter are ignored" 0 $'---\nstatus: approved\n---\nBody text.'

# Counts
expect "counts from the file pass" 0 'The punch list has 45 rows: 43 with an ID, 41 distinct. 49 of 99 are open; 11 are missing.' "${C[@]}"
expect "a count not in the file fails" 1 'The punch list has 42 rows.' "${C[@]}"
expect "dates, years, IDs, versions, labels and list markers are ignored" 0 $'1. On 2026-11-05 (Nov 5, 2026) at 15:00, Phase 1 of WS1 covers _001, FY2028, v1.2, D4, deadbeef and $1,000.' "${C[@]}"
expect "--allow admits a number" 0 'Thirty to forty minutes: 30 minutes.' "${C[@]}" --allow 30
expect "percentages are counts too" 1 'Coverage is 70% of items.' "${C[@]}"
expect "counts are not checked without --counts" 0 'The punch list has 42 rows.'
printf '{"goal_1_actions": 9}' > "$T/more.json"
expect "two counts files are both used" 0 'Goal 1 lists 9 actions across 99 items.' --counts "$T/counts.json" "$T/more.json"

# Chaos review 2026-11-05 repros
expect "an inch mark does not hide a bad quote" 1 'The 12" ruler. He said "the plan is final and done" today.' "${S[@]}"
expect "an unbalanced quote mark fails" 1 'He said "the plan is final and done today.' "${S[@]}"
expect "decimals are counts" 1 'Score 99.5 overall.' "${C[@]}"
expect "fractions are counts" 1 'That is 98/100 done.' "${C[@]}"
expect "hyphenated counts are counts" 1 'A 98-row sheet.' "${C[@]}"
expect "'row N' is a count, not a label" 1 'See row 98.' "${C[@]}"
expect "a percentage matches its count" 0 'Coverage: 49% of items.' "${C[@]}"

# Tagged counts: a number tied to the count it claims to be (2026-11-05: "7" passed by coincidence)
expect "a correctly tagged count passes" 0 'Open items: 49 <!-- count: backlog.open -->.' "${C[@]}"
expect "a wrongly tagged count fails even if the number exists elsewhere" 1 'Open items: 45 <!-- count: backlog.open -->.' "${C[@]}"
expect "a tag pointing nowhere fails" 1 'Open items: 49 <!-- count: backlog.nope -->.' "${C[@]}"
expect "--strict fails an untagged number" 1 'Open items: 49.' "${C[@]}" --strict
expect "--strict passes when every number is tagged" 0 'Open 49 <!-- count: backlog.open --> of 99 <!-- count: backlog.items -->.' "${C[@]}" --strict

expect "day-before-month dates are ignored" 0 'Deck dated 29 Mar 2026.' "${C[@]}" --strict
expect "plural labels and ranges are ignored" 0 'Phases 2–4 need sponsorship; see Sections 3-5.' "${C[@]}" --strict

# Rule review 2026-11-05: a clean run must not be vacuous
expect "--strict fails a draft with quotes but no --sources" 1 'He said "the plan is final and done" today.' --strict
expect "--strict fails a draft with numbers but no --counts" 1 'There are 49 open items.' --strict
expect "a settled claim without quote marks is still checked" 1 'Sam confirmed the scope last week.'
out=$(printf 'Open 49.\n' > "$T/d.md"; python3 "$CD" "$T/d.md" "${C[@]}" --allow 360 2>&1)
grep -q "checked 0 quote(s), 1 number(s)" <<<"$out" && grep -q "waved through by hand: --allow 360" <<<"$out" && echo "ok   output says what was checked and what was waved through" || { echo "FAIL checked/waived summary"; echo "$out"; fail=1; }

expect "'finalized' with no source fails" 1 'The scope is finalized.'
expect "'aligned on' with no source fails" 1 'We aligned on the March statement.'

# Bad input
python3 "$CD" "$T/nope.md" >/dev/null 2>&1; [ $? = 2 ] && echo "ok   missing draft is bad input" || { echo "FAIL missing draft"; fail=1; }
printf 'x\n' > "$T/d.md"; printf '{bad' > "$T/bad.json"
python3 "$CD" "$T/d.md" --counts "$T/bad.json" >/dev/null 2>&1; [ $? = 2 ] && echo "ok   bad counts file is bad input" || { echo "FAIL bad counts json"; fail=1; }

# Originals only under --strict (2026-11-05)
{ echo "[read-source] original: /x/downloads/sow.pdf"; cat "$T/src.txt"; } > "$T/stamped.txt"
expect "--strict fails a source that is not a read-source extract (our own notes)" 1 'Alex: "June 30 was chosen as the latest date" for the plan.' "${S[@]}" --strict
expect "--strict passes a stamped read-source extract" 0 'Alex: "June 30 was chosen as the latest date" for the plan.' --sources "$T/stamped.txt" --strict
expect "--strict fails if any one source is unstamped" 1 'Alex: "June 30 was chosen as the latest date" for the plan.' --sources "$T/stamped.txt" "$T/src.txt" --strict
expect "without --strict an unstamped source still works" 0 'Alex: "June 30 was chosen as the latest date" for the plan.' "${S[@]}"
printf 'Alex: "June 30 was chosen as the latest date" for the plan.\n' > "$T/od.md"
python3 "$CD" "$T/od.md" --sources "$T/stamped.txt" --strict | grep -q "originals read: /x/downloads/sow.pdf" && echo "ok   the output lists the originals read" || { echo "FAIL originals not listed"; fail=1; }
printf '\xef\xbb\xbf' > "$T/bom.txt"; cat "$T/stamped.txt" >> "$T/bom.txt"
expect "--strict passes a stamped extract that starts with a byte-order mark" 0 'Alex: "June 30 was chosen as the latest date" for the plan.' --sources "$T/bom.txt" --strict
{ cat "$T/stamped.txt"; echo "[read-source] original: /x/downloads/memo.docx"; echo more; } > "$T/two.txt"
python3 "$CD" "$T/od.md" --sources "$T/two.txt" --strict | grep -q "sow.pdf; /x/downloads/memo.docx" && echo "ok   every stamp in a joined file is listed" || { echo "FAIL joined stamps not listed"; fail=1; }
python3 "$CD" "$T/od.md" --sources "$T/src.txt" | grep -q "not read-source extracts" && echo "ok   without --strict an unstamped source is noted" || { echo "FAIL no note without --strict"; fail=1; }
[ $fail -eq 0 ] && echo "test-check-draft: all passed" || echo "test-check-draft: FAILURES"
exit $fail
