#!/usr/bin/env bash
# guard-resolve.sh — FAIL-CLOSED launcher for security hooks.
#
# Most hooks resolve their script and, if it is missing, print a note and exit 0, which
# lets the tool call through. That is right for a reminder or a formatter and wrong for a
# guard: a security hook that silently stops running is worse than none, because nothing
# announces its absence.
#
# This launcher inverts that. Missing runtime or missing script => exit 2, which BLOCKS
# the tool call with a reason. You notice immediately.
#
# Usage (from a hook command in .claude/settings.json):
#   bash .claude/hooks/guard-resolve.sh <runtime> <path-relative-to-project-root> [args...]
#   e.g.  guard-resolve.sh python3 .claude/hooks/guards/protect-secrets.py
#
# WHAT THIS DOES NOT DO — read this before trusting it.
# It makes the LAUNCH fail closed. It does not make the guard itself fail closed: a guard
# that catches its own exceptions and then allows is still fail-open inside. Write guards
# that exit 2 on any internal error (see templates/guard-template.py). Nothing here covers
# the hook ENTRY being absent from settings.json, or bash itself failing to start. A hook
# is a backstop, never the only control.

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
