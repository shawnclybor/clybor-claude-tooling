#!/usr/bin/env bash
# guard-resolve.sh — FAIL-CLOSED launcher for security hooks.
#
# The other hooks in this directory resolve their script and, if it is missing,
# print a note and exit 0 ("fails open by design"). That is right for a style
# reminder and wrong for a guard: a security hook that silently stops running
# is worse than no security hook, because the absence is not self-announcing.
#
# This launcher inverts that. Missing runtime or missing script => exit 2,
# which BLOCKS the tool call. You will notice immediately.
#
# Usage (from settings.json):
#   bash .claude/hooks/guard-resolve.sh <runtime> <path-relative-to-repo-root> [args...]
#   e.g.  guard-resolve.sh node .claude/hooks/vendor/guard-pack/guard-pack.js
#
# WHAT THIS DOES NOT DO — read this before trusting it.
# It makes the LAUNCH fail closed. It does not make the guards themselves fail
# closed: vendor/guard-pack/guard-pack.js catches a throwing guard, logs it and
# skips to the next one, and its top-level catch emits '{}' (= allow). That is
# upstream's deliberate design and the file is byte-pinned against upstream
# tests, so it is not ours to change. The settings.json entries do cover this
# script going missing — they exit 2 themselves if they cannot find it — but
# nothing covers the hook ENTRY being absent from settings.json, or bash
# failing to start. See CLAUDE.md Hard Rule 18: a crashed hook silently
# allows. A hook is a backstop, never the sole gate.

set -uo pipefail

RUNTIME="${1:?guard-resolve: no runtime given}"
REL="${2:?guard-resolve: no script path given}"
shift 2

die() {
  echo "GUARD BLOCKED: $1" >&2
  echo "  Tool call denied because the guard could not run. Fix the guard, or" >&2
  echo "  remove its entry from .claude/settings.json if you meant to disable it." >&2
  exit 2
}

command -v "$RUNTIME" >/dev/null 2>&1 || die "runtime '$RUNTIME' not found on PATH"

SCRIPT=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -f "$CLAUDE_PROJECT_DIR/$REL" ]; then
  SCRIPT="$CLAUDE_PROJECT_DIR/$REL"
else
  p="$PWD"
  while [ "$p" != "/" ]; do
    if [ -f "$p/$REL" ]; then SCRIPT="$p/$REL"; break; fi
    p=$(dirname "$p")
  done
fi

[ -n "$SCRIPT" ] || die "script '$REL' not found (CLAUDE_PROJECT_DIR=${CLAUDE_PROJECT_DIR:-unset}, PWD=$PWD)"

exec "$RUNTIME" "$SCRIPT" "$@"
