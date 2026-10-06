#!/usr/bin/env bash
# test-check-plugin-manifests.sh — check-plugin-manifests.py passes clean layouts and fails nested ones.
set -uo pipefail
CHECK="$(cd "$(dirname "$0")" && pwd)/check-plugin-manifests.py"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fails=0

case_() { # $1 = name, $2 = expected exit, rest = manifest dirs to create and stage
  local name="$1" want="$2"; shift 2
  local d="$T/$name"; mkdir -p "$d"; git -C "$d" init -q
  for p in "$@"; do mkdir -p "$d/$p/.claude-plugin"; echo '{}' > "$d/$p/.claude-plugin/plugin.json"; done
  git -C "$d" add -A
  python3 "$CHECK" "$d" 2>/dev/null; local got=$?
  if [ "$got" = "$want" ]; then echo "PASS: $name"; else echo "FAIL: $name (exit $got, want $want)"; fails=$((fails+1)); fi
}

case_ single-plugin            0 .
case_ root-plus-test-fixture   1 . tests/fixtures/fixture-guides
case_ marketplace-siblings     0 plugins/a plugins/b
case_ marketplace-nested       1 plugins/a plugins/a/tests/fx
case_ no-plugins               0
# a file that is only on disk (not staged) is not what gets committed, so it must not count
case_ unstaged-nested-ignored  0 .
mkdir -p "$T/unstaged-nested-ignored/tests/fx/.claude-plugin"
echo '{}' > "$T/unstaged-nested-ignored/tests/fx/.claude-plugin/plugin.json"
python3 "$CHECK" "$T/unstaged-nested-ignored" 2>/dev/null \
  && echo "PASS: unstaged file not counted" || { echo "FAIL: unstaged file counted"; fails=$((fails+1)); }
# outside a git repo: no-op
mkdir -p "$T/not-a-repo" && python3 "$CHECK" "$T/not-a-repo" 2>/dev/null \
  && echo "PASS: not-a-repo" || { echo "FAIL: not-a-repo"; fails=$((fails+1)); }

[ "$fails" = 0 ] && echo "ALL PASS" || { echo "$fails FAILED"; exit 1; }
