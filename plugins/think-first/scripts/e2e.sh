#!/usr/bin/env bash
# e2e.sh — think-first in real `claude -p` sessions. Costs four short model runs.
# WebFetch stands in for a write, so nothing outside this machine is changed.
#
#   S  empty Claude config          -> the plugin's own sequential-thinking server connects
#                                      (no model call; proves the plugin installs its server)
#   A  no thinking step             -> WebFetch blocked as a write
#   B  thinking step first          -> a sequentialthinking tool runs, then WebFetch runs
#   C  fetch fails, retried at once -> the retry is blocked (writes off, retries=WebFetch)
#   D  gate OFF, same as A          -> WebFetch runs (proves A's block came from think-first)
#
# If you already run a sequential-thinking server yourself, Claude Code uses yours and skips
# the plugin's duplicate; that is why S uses an empty config.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
OUT="$(mktemp -d)"
COMMON=(--permission-mode bypassPermissions --max-turns 8 --output-format stream-json --verbose)
ON=(--plugin-dir . --settings tests/fixtures/e2e-settings.json)

A="Use WebFetch to fetch https://example.com and tell me its title. Do not call any thinking tool first. If a call is blocked, quote the block message exactly and stop."
B="First call the sequentialthinking tool once with thoughtNumber 1, totalThoughts 1, nextThoughtNeeded false, thought 'plan the fetch'. Then use WebFetch to fetch https://example.com and tell me its title. Quote any block message exactly."
C="Use WebFetch to fetch https://nonexistent.invalid/page. If it fails, immediately make the exact same WebFetch call again, with no other tool call in between. Quote any block message exactly, then stop."

CD="$(mktemp -d)"
CLAUDE_CONFIG_DIR="$CD" claude -p "ok" --plugin-dir . --max-turns 1 --output-format stream-json --verbose < /dev/null > "$OUT/S.jsonl" 2>&1
rm -rf "$CD"
claude -p "$A" "${ON[@]}" "${COMMON[@]}" < /dev/null > "$OUT/A.jsonl" 2>&1
claude -p "$B" "${ON[@]}" "${COMMON[@]}" < /dev/null > "$OUT/B.jsonl" 2>&1
claude -p "$C" --plugin-dir . --settings tests/fixtures/e2e-retry-settings.json "${COMMON[@]}" < /dev/null > "$OUT/C.jsonl" 2>&1
claude -p "$A" "${COMMON[@]}" < /dev/null > "$OUT/D.jsonl" 2>&1

python3 - "$OUT" <<'PY'
import json, os, sys
out = sys.argv[1]
def calls(leg):
    uses, results, servers = [], [], []
    for ln in open(os.path.join(out, leg + ".jsonl")):
        try: o = json.loads(ln)
        except ValueError: continue
        if o.get("type") == "system" and o.get("subtype") == "init":
            servers = [s.get("name") + ":" + s.get("status", "?") for s in o.get("mcp_servers", [])]
        for b in (o.get("message") or {}).get("content") or []:
            if not isinstance(b, dict): continue
            if b.get("type") == "tool_use": uses.append(b["name"])
            if b.get("type") == "tool_result": results.append(str(b.get("content")))
    return uses, results, servers
ok = True
def check(leg, cond, what):
    global ok
    print(f"{leg}: {'PASS' if cond else 'FAIL'} — {what}"); ok &= cond
u, r, s = calls("S")
check("S", "plugin:think-first:sequential-thinking:connected" in s, f"plugin installed and connected its own server ({s})")
u, r, s = calls("A")
check("A", "WebFetch" in u and any("think-first: blocked WebFetch because it is a write" in x for x in r),
      "write blocked before any thinking step")
u, r, s = calls("B")
st = [x for x in u if x.endswith("__sequentialthinking")]
check("B", bool(st) and "WebFetch" in u and not any("think-first: blocked" in x for x in r),
      f"thinking tool ran ({st[:1]}), then the write ran")
u, r, s = calls("C")
check("C", u.count("WebFetch") >= 2 and any("last call failed" in x for x in r), "immediate retry after a failure blocked")
u, r, s = calls("D")
check("D", "WebFetch" in u and not any("think-first: blocked" in x for x in r), "without think-first the write is not blocked")
print("transcripts:", out); sys.exit(0 if ok else 1)
PY
