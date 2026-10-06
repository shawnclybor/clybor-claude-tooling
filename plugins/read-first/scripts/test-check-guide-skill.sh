#!/usr/bin/env bash
# Negative control for check-guide-skill.py: the good fixture and the template's own
# shape must PASS, and each seeded defect must FAIL. A checker that only ever says
# PASS is indistinguishable from a broken one.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
CHK="python3 scripts/check-guide-skill.py"
GOOD=tests/guide-fixtures/good.md
T="$(mktemp -d)"; fails=0

expect() { # $1 = want (0|1), $2 = label, $3 = file
  $CHK "$3" > "$T/out" 2>&1; got=$?
  if [ "$got" = "$1" ]; then echo "ok   $2"; else echo "BAD  $2 (want exit $1, got $got)"; cat "$T/out"; fails=$((fails+1)); fi
}
mutant() { # $1 = label, $2 = python expression over s
  python3 -c "import sys; s=open('$GOOD').read(); s=$2; open('$T/m.md','w').write(s)"
  expect 1 "$1" "$T/m.md"
}

expect 0 "good fixture passes" "$GOOD"
mutant "no Rules section"            "s.replace('## Rules\n','## Policies\n')"
mutant "no Operating manual"         "s.replace('## Operating manual\n','## Notes\n')"
mutant "manual before rules"         "s.split('## Rules')[0]+'## Operating manual'+s.split('## Operating manual')[1]+'\n## Rules'+s.split('## Rules')[1].split('## Operating manual')[0]"
mutant "Rules with no list items"    "s.replace('- Subscribing anyone to alerts.\n','').replace('- Sharing a person\'s home location in a forecast request.\n','').replace('1. Is the unit stated in the request?\n','')"
mutant "no Known issues"             "s.replace('### Known issues','### Issues')"
mutant "undated known issue"         "s.replace('| 2026-10-05 |','| last week |')"
mutant "colon-space in description"  "s.replace('Worst trap is','Worst trap:')"
mutant "no frontmatter"              "s.split('---\n',2)[2]"
# Escapes in a quoted description are not characters: 1010 real characters, 1515 raw.
python3 - "$GOOD" "$T" <<'PY'
import re, sys
good, out = sys.argv[1], sys.argv[2]
s = open(good).read()
quoted = '"' + 'x\\"' * 505 + '"'          # YAML text: x\" repeated -> value x" (2 chars each)
plain = '"' + 'x' * 1030 + '"'
open(out + '/q.md', 'w').write(re.sub(r'^description: .*$', lambda m: 'description: ' + quoted, s, count=1, flags=re.M))
open(out + '/l.md', 'w').write(re.sub(r'^description: .*$', lambda m: 'description: ' + plain, s, count=1, flags=re.M))
PY
expect 0 "quoted description with escapes is measured unescaped" "$T/q.md"
expect 1 "a description over 1024 characters fails" "$T/l.md"
echo
[ "$fails" = 0 ] && echo "PASS: checker passes the good guides and fails all 9 defects" || echo "FAIL: $fails case(s) wrong"
exit $([ "$fails" = 0 ] && echo 0 || echo 1)
