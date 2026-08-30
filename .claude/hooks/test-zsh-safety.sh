#!/usr/bin/env bash
# Negative control for check-zsh-safety.py.
#
# A gate that blocks everything is as useless as one that blocks nothing, so this seeds both
# directions. And every case is asserted TWICE: once against the hook's verdict, once against what
# zsh ACTUALLY does with the same string. A blocked shape must really misbehave in zsh; an allowed
# shape must really run clean. That binds the rule to measured behaviour instead of to the author's
# belief about zsh -- the rule cannot quietly drift into superstition.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
H="$HERE/check-zsh-safety.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
printf 'needleval\n' > "$TMP/real.md"

pass=0; fail=0
ok()  { echo "  ok   $1"; pass=$((pass+1)); }
bad() { echo "  FAIL $1"; fail=$((fail+1)); }

# blocks <label> <command>            -- hook must exit 2
blocks() { python3 "$H" --check "$2" >/dev/null 2>&1; [ $? -eq 2 ] && ok "blocks: $1" || bad "blocks: $1 -- hook allowed it"; }
# allows <label> <command>            -- hook must exit 0
allows() { python3 "$H" --check "$2" >/dev/null 2>&1; [ $? -eq 0 ] && ok "allows: $1" || bad "allows: $1 -- hook blocked it: $(python3 "$H" --check "$2" 2>&1 | sed -n 2p)"; }
# zsh_breaks <label> <command> <needle-that-must-be-ABSENT-from-output>
zsh_breaks() { local out; out="$(cd "$TMP" && zsh -c "$2" 2>&1)"; grep -qF -- "$3" <<<"$out" && bad "zsh breaks: $1 -- it did NOT break (saw '$3')" || ok "zsh breaks: $1"; }
# zsh_clean <label> <command> <needle-that-must-be-PRESENT>
zsh_clean() { local out; out="$(cd "$TMP" && zsh -c "$2" 2>&1)"; grep -qF -- "$3" <<<"$out" && ok "zsh clean: $1" || bad "zsh clean: $1 -- expected '$3', got: $out"; }
# names <label> <command> <needle> -- the message must name the offending word, not just complain
names() { python3 "$H" --check "$2" 2>&1 | grep -qF -- "$3" && ok "names: $1" || bad "names: $1 -- message never mentions $3"; }

echo "EQUALS expansion -- must block, and must really break"
blocks     "bare === separator"  'echo start; echo ===; echo after'
zsh_breaks "bare === separator"  'echo start; echo ===; echo after' 'after'
blocks     "=== mid-command"     'echo a === b'
zsh_breaks "=== mid-command"     'echo a === b; echo reached' 'reached'
blocks     "single-bracket =="   '[ x == x ] && echo yes'
zsh_breaks "single-bracket =="   '[ x == x ] && echo yes' 'yes'
blocks     "=ls silent swap"     'echo =ls'
zsh_breaks "=ls silent swap"     'echo =ls' '=ls'
blocks     "-- ==== separator"   'echo -- ===='

echo
echo "NOMATCH on tool-destined globs -- must block, and must really break"
blocks     "grep --include glob" 'grep -rn x --include=*.md .'
# The two NOMATCH halves are asserted SEPARATELY because they are different dangers. grep never runs
# (its match is absent) -- but unlike EQUALS, the script keeps going and the exit code stays 0, so the
# call reports success while carrying a hole. Asserting only truncation here would be asserting the
# wrong failure, and would go green against a shell that had stopped early for some other reason.
zsh_breaks "grep --include glob never runs"    'grep -rn needleval --include=*.md . ; echo reached' 'needleval'
zsh_clean  "grep --include glob stays rc 0"    'grep -rn needleval --include=*.md . ; echo reached' 'reached'
zsh_clean  "...while the quoted twin DOES run" "grep -rn needleval --include='*.md' . ; echo reached" 'needleval'
blocks     "find -name glob"     'find . -maxdepth 1 -name *.nomatchxyz'
zsh_breaks "find -name glob"     'find . -maxdepth 1 -name *.nomatchxyz' './real.md'
blocks     "rsync --exclude"     'rsync -a --exclude=*.pyc src/ dst/'

echo
echo "quoted, escaped, bracketed, commented -- must ALLOW, and must really run"
allows    "quoted separator"   'echo "==="'
zsh_clean "quoted separator"   'echo "==="; echo after' 'after'
allows    "dash separator"     'echo ---'
allows    "double-bracket =="  '[[ x == x ]] && echo yes'
zsh_clean "double-bracket =="  '[[ x == x ]] && echo yes' 'yes'
allows    "assignment"         'FOO=bar; echo $FOO'
zsh_clean "assignment"         'FOO=bar; echo $FOO' 'bar'
allows    "option with value"  'git diff --stat=200'
allows    "quoted include"     "grep -rn x --include='*.md' ."
zsh_clean "quoted include"     "grep -rln real --include='*.md' . ; echo reached" 'reached'
allows    "quoted find -name"  'find . -maxdepth 1 -name "*.md"'
zsh_clean "quoted find -name"  'find . -maxdepth 1 -name "*.md"' './real.md'
allows    "single-quoted =="   "awk '\$1 == \"x\" { print }' /dev/null"
allows    "python -c =="       'python3 -c "print(1 == 1)"'
zsh_clean "python -c =="       'python3 -c "print(1 == 1)"' 'True'
allows    "escaped ==="        'echo \==='
zsh_clean "escaped ==="        'echo \===' '==='
allows    "=== in a comment"   'echo one # === two'
zsh_clean "=== in a comment"   'echo one # === two' 'one'
allows    "herestring"         'cat <<< "==="'
zsh_clean "herestring"         'cat <<< "==="' '==='

hd="$(printf 'cat <<%sEOF%s\n=== inside a heredoc ===\nEOF\necho after\n' "'" "'")"
allows    "heredoc body"       "$hd"
zsh_clean "heredoc body"       "$hd" 'after'

echo
echo "stated non-coverage -- these are NOT flagged, on purpose"
allows "bare shell glob (documented as out of scope)" 'ls *.md'

echo
echo "message quality"
names "offending word appears" 'echo a === b' '==='
names "fix is concrete"        'grep -rn x --include=*.md .' "--include='*.md'"

echo
echo "hook plumbing"
printf '{"tool_name":"Bash","tool_input":{"command":"echo ==="}}' | python3 "$H" >/dev/null 2>&1
[ $? -eq 2 ] && ok "PreToolUse JSON blocks" || bad "PreToolUse JSON blocks"
printf '{"tool_name":"Write","tool_input":{"file_path":"x","content":"echo ==="}}' | python3 "$H" >/dev/null 2>&1
[ $? -eq 0 ] && ok "non-Bash tool ignored" || bad "non-Bash tool ignored"
printf 'not json at all' | python3 "$H" >/dev/null 2>&1
[ $? -eq 0 ] && ok "fail-open on garbage input" || bad "fail-open on garbage input"
printf '{"tool_name":"Bash","tool_input":{}}' | python3 "$H" >/dev/null 2>&1
[ $? -eq 0 ] && ok "fail-open on missing command" || bad "fail-open on missing command"

echo
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ] || exit 1
MIN_ASSERTIONS=45
if [ "$pass" -lt "$MIN_ASSERTIONS" ]; then
  printf 'FAIL: %d assertions ran, floor is %d -- cases went missing.\n' "$pass" "$MIN_ASSERTIONS"
  exit 1
fi
