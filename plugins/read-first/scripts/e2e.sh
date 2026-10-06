#!/usr/bin/env bash
# e2e.sh — read-first in three real `claude -p` sessions. Costs three short model runs.
#
#   A  gate on,  guide NOT loaded  -> WebFetch must be blocked with read-first's message
#   B  gate on,  guide loaded      -> WebFetch must run
#   C  gate OFF, guide NOT loaded  -> WebFetch must run (proves A's block came from read-first)
#
# The rule under test is "WebFetch => fixture-guide", set through tests/fixtures/e2e-settings.json.
# Exit 0 = all three legs behaved; 1 = a leg did not. The model is in the loop, so a rare
# failure can be the model ignoring the prompt: read the printed transcript before concluding.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
OUT="$(mktemp -d)"
FIX=tests/fixtures/fixture-guides
ASK_A="Use the WebFetch tool to fetch https://example.com and tell me the page title. Do not load any skill first. If the tool call is blocked, quote the block message exactly and stop."
ASK_B="First load the fixture-guide skill with the Skill tool. Then use WebFetch to fetch https://example.com and tell me the page title. If any call is blocked, quote the block message exactly."

run() { # $1 = leg, rest = extra flags, prompt last
  local leg="$1"; shift
  claude -p "${@: -1}" "${@:1:$#-1}" --plugin-dir "$FIX" --allowedTools "WebFetch Skill" \
    --max-turns 6 --output-format stream-json --verbose < /dev/null > "$OUT/$leg.jsonl" 2>&1
}

run A --plugin-dir . --settings tests/fixtures/e2e-settings.json "$ASK_A"
run B --plugin-dir . --settings tests/fixtures/e2e-settings.json "$ASK_B"
run C "$ASK_A"

python3 - "$OUT" <<'EOF'
import json, sys, os
out = sys.argv[1]
BLOCK = "read-first: blocked WebFetch until the fixture-guide"

def calls(leg):
    uses, results = [], []
    for ln in open(os.path.join(out, leg + ".jsonl")):
        try: o = json.loads(ln)
        except ValueError: continue
        for b in (o.get("message") or {}).get("content") or []:
            if not isinstance(b, dict): continue
            if b.get("type") == "tool_use": uses.append(b["name"])
            if b.get("type") == "tool_result": results.append(str(b.get("content")))
    return uses, results

ok = True
def check(leg, cond, what):
    global ok
    print(f"{leg}: {'PASS' if cond else 'FAIL'} — {what}")
    ok &= cond

u, r = calls("A")
check("A", "WebFetch" in u and any(BLOCK in x for x in r), "WebFetch attempted and blocked by read-first")
u, r = calls("B")
check("B", "Skill" in u and "WebFetch" in u and not any("read-first: blocked" in x for x in r),
      "guide loaded, then WebFetch ran unblocked")
u, r = calls("C")
check("C", "WebFetch" in u and not any("read-first: blocked" in x for x in r),
      "without read-first the same request is not blocked")
print(f"transcripts: {out}")
sys.exit(0 if ok else 1)
EOF
