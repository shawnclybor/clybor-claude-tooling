#!/usr/bin/env bash
# check-root-strays.sh — the repo root has an owner.
#
# WHY THIS EXISTS AND WHY IT IS NOT A WRITE HOOK: loose files accumulate at a repo
# root one at a time, and each one is individually too small to argue with. The
# audit that produced this script found ten of them spanning four months in one repo.
# Not one would have been caught by a PreToolUse veto on Write: half were not
# markdown, and the rest had been silenced in .gitignore at the moment they
# appeared rather than filed. Ignoring a file hides it from git; a frontmatter or
# convention gate that walks `for d in */` cannot see a root file at all. Two blind
# spots stack, and a silenced root file becomes invisible to every gate a repo has.
#
# So the missing check is a periodic census of the root, not an intercept. One
# stray every couple of weeks does not earn a veto, and a veto that can wrongly
# block a write is expensive in an agent session where overriding it is awkward.
#
# THIS SCRIPT DELIBERATELY IGNORES .gitignore. Consulting git status would rebuild
# the exact blind spot it exists to close: a stray is a stray whether or not
# someone silenced it. It walks the filesystem.
#
# ALLOWLIST, NOT PATTERN-MATCH. A root file earns its place by being named. Coverage
# fails SAFE — a new root file is a stray by default. Universal entries are built in
# below; per-repo additions go in a `.root-allow` file at the repo root, one name per
# line, `#` for comments. That keeps this script identical across repos.
#
# BASH 3.2 COMPATIBLE. macOS ships 3.2; no mapfile, no associative arrays.
#
# Usage:  bash scripts/check-root-strays.sh           # report strays
#         bash scripts/check-root-strays.sh --quiet   # counts only
#
# Exit codes: 0 = root is clean; 1 = strays found; 2 = gate inspected nothing.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

# Files that belong at ANY repo root.
ALLOWED="CLAUDE.md README.md LICENSE LICENSE.md CONTRIBUTING.md Makefile
         .gitignore .gitattributes .editorconfig .DS_Store .root-allow"

# Per-repo additions. Keeping these out of the script is what makes it promotable.
ALLOW_FILE=".root-allow"
if [ -f "$ALLOW_FILE" ]; then
  while IFS= read -r line; do
    line="${line%%#*}"                       # strip comments
    line="$(printf '%s' "$line" | tr -d '[:space:]')"
    [ -n "$line" ] && ALLOWED="$ALLOWED $line"
  done < "$ALLOW_FILE"
fi

is_allowed() {
  case " $ALLOWED " in
    *" $1 "*) return 0 ;;
  esac
  return 1
}

# Where a stray most likely belongs. Advisory only — this script never moves
# anything. Filing is a human decision because a filename can carry provenance a
# mechanical move would destroy.
suggest() {
  case "$1" in
    *HANDOFF*|*handoff*)
      echo "a handoffs/ folder, named <subject>-YYYY-MM-DD.md" ;;
    PROMPT-*|prompt-*|*-prompt.md)
      echo "a working/ or scratch folder — prompts are session artifacts" ;;
    *.bak-*|*.bak|*~)
      echo "delete — git history is the backup for a tracked file" ;;
    *.log)
      echo "review — a root log is either a live instrument (add it to .root-allow) or debris" ;;
    *.xlsx|*.docx|*.pptx|*.pdf|*.csv|*.png|*.jpg)
      echo "the owning project's working/ or downloads/ folder" ;;
    *.ts|*.js|*.py|*.sh|*.osts)
      echo "a scripts/ or tools/ folder, or the owning project" ;;
    *)
      echo "unclear — decide deliberately, do not guess" ;;
  esac
}

strays=0
inspected=0

echo "=== repo root census ==="

for f in * .[!.]*; do
  [ -e "$f" ] || continue          # glob matched nothing
  [ -f "$f" ] || continue          # directories are out of scope
  inspected=$((inspected + 1))
  is_allowed "$f" && continue
  strays=$((strays + 1))
  if [ $QUIET -eq 0 ]; then
    echo "STRAY $f"
    echo "      -> $(suggest "$f")"
  fi
done

echo
echo "Root files inspected: $inspected   Strays: $strays"

# Vacuous-pass guard: a gate that inspects nothing must not report success.
# Every repo root holds at least one file.
if [ $inspected -eq 0 ]; then
  echo "FAIL — gate inspected nothing. Wrong cwd or a shell incompatibility."
  echo "       Treat as a failure, never as a pass."
  exit 2
fi

if [ $strays -eq 0 ]; then
  echo "OK    root is clean."
  exit 0
fi

echo
echo "A file at the root has no owner and no gate: convention gates walk directories,"
echo "and .gitignore hides rather than files. Move each stray to the folder that owns"
echo "it, or add it to $ALLOW_FILE with a comment saying why."
exit 1
