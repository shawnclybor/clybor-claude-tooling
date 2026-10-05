#!/usr/bin/env bash
# verify-plugin-shipped.sh <plugin> <skill> <needle>
#
# Answers ONE question the other plugin scripts cannot: after a promote, is the
# edit actually on disk where the running session reads it?
#
# WHY THIS EXISTS. plugin-governance's content check says "invoke the edited skill
# and look for your edit." That check cannot distinguish two states that produce
# an IDENTICAL symptom at the Skill-tool surface:
#
#   (a) bundle fresh, reader stale  -> the ship WORKED; Cowork is serving a copy it
#                                      read into memory at session start. Restart.
#   (b) bundle stale                -> the ship genuinely FAILED. Diagnose/re-promote.
#
# Read literally, the prose gate points at (b) in both cases. Acting on that in
# state (a) means re-promoting a successful ship -- and because Rule 2 makes version
# bumps monotonic, that churn is permanent. Confirmed 2026-09-25 on
# life-crm-meta 2.8.2: all three on-disk copies carried the edit, including the
# exact base dir the Skill invocation printed, and the invocation still returned
# pre-edit text.
#
# The other validators all inspect the CANDIDATE before it ships
# (validate-plugin.py, validate-plugin-promotion.py, check-skill-descriptions.py).
# None of them look at deployed state. That is the gap this fills.
#
# Exit 0  = every on-disk copy carries the needle -> state (a). RESTART, do not re-promote.
# Exit 1  = at least one copy is missing it       -> state (b). Real failure.
# Exit 2  = usage error, or nothing found to check.

set -uo pipefail

if [ $# -ne 3 ]; then
  cat >&2 <<USAGE
usage: bash scripts/verify-plugin-shipped.sh <plugin> <skill> <needle>

  <plugin>  bundle basename, e.g. life-crm-meta
  <skill>   skill directory name, e.g. insight-crystallizer
  <needle>  a distinctive literal string from your edit (grep -F). Searched across the
            WHOLE skill folder (SKILL.md + references/ + scripts/), not SKILL.md only.

example:
  bash scripts/verify-plugin-shipped.sh life-crm-meta insight-crystallizer \\
    'does not exist on the KB database'
USAGE
  exit 2
fi

PLUGIN="$1"; SKILL="$2"; NEEDLE="$3"
REPO="${REPO:-$(cd "$(dirname "$0")/.." && pwd)}"   # the repo this script lives in
BUNDLE="$REPO/cowork/$PLUGIN.plugin"
REL="skills/$SKILL/SKILL.md"   # used only to LOCATE deployed copies of the skill
SKDIR="skills/$SKILL"          # searched in full for the needle
# Why the whole folder: until 2026-09-30 only SKILL.md was searched, so an edit to a
# references/ shelf file (notion-governance v1.28.6) reported STALE on all three copies
# while every copy carried it -- a false state (b) that invites a needless re-promote.

fail=0
checked=0

ver_of() { # <plugin.json path>
  python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1]))["version"])
except Exception: print("?")' "$1" 2>/dev/null || echo "?"
}

echo "== verify-plugin-shipped: $PLUGIN / $SKILL =="
echo "   needle: $NEEDLE"
echo

# --- 1. the promoted bundle -------------------------------------------------
if [ ! -f "$BUNDLE" ]; then
  echo "   BUNDLE   MISSING      $BUNDLE" >&2
  echo >&2
  echo "BLOCKED: no bundle at that path. Wrong plugin name, or never promoted." >&2
  exit 2
fi
bver=$(unzip -p "$BUNDLE" .claude-plugin/plugin.json 2>/dev/null \
       | python3 -c 'import json,sys
try: print(json.load(sys.stdin)["version"])
except Exception: print("?")')
# NOT `grep -q`: under pipefail, -q exits on the first match, unzip dies of SIGPIPE (141)
# and the pipeline reads as "no match" -- a false STALE. Let grep drain the stream.
if unzip -p "$BUNDLE" "$SKDIR/*" 2>/dev/null | grep -F -- "$NEEDLE" >/dev/null; then
  echo "   BUNDLE   OK    v$bver  $BUNDLE"
else
  echo "   BUNDLE   STALE v$bver  $BUNDLE"
  fail=1
fi
checked=$((checked+1))

# --- 2. deployed copies -----------------------------------------------------
# rpm      = per-session plugin dir the rebuild script syncs
# hostloop = extract the Skill tool actually names as its base directory.
#            The hash segments vary per session, so glob rather than hardcode.
shopt -s nullglob
declare -a DEPLOYED=()
for f in \
  "$HOME/Library/Application Support/Claude/local-agent-mode-sessions"/*/*/rpm/plugin_*/"$REL" \
  /var/folders/*/*/T/claude-hostloop-plugins/*/plugin_*/"$REL"
do
  DEPLOYED+=("$f")
done
shopt -u nullglob

if [ ${#DEPLOYED[@]} -eq 0 ]; then
  echo
  echo "   (no deployed copies of $SKILL found)"
  echo
  echo "INCONCLUSIVE: the bundle was checked but no installed copy was located." >&2
  echo "  Either the plugin is not installed, or this host lays sessions out differently." >&2
  echo "  Do NOT read this as a failed ship -- it is an absence of evidence." >&2
  exit 2
fi

for f in "${DEPLOYED[@]}"; do
  d="${f%/$REL}"
  label="rpm"; case "$d" in *claude-hostloop-plugins*) label="hostloop";; esac
  dver=$(ver_of "$d/.claude-plugin/plugin.json")
  if grep -rqF -- "$NEEDLE" "$d/$SKDIR" 2>/dev/null; then
    printf "   %-8s OK    v%-7s %s\n" "$label" "$dver" "$d"
  else
    printf "   %-8s STALE v%-7s %s\n" "$label" "$dver" "$d"
    fail=1
  fi
  checked=$((checked+1))
done

# --- verdict ----------------------------------------------------------------
echo
if [ $fail -eq 0 ]; then
  cat <<VERDICT
SHIPPED: all $checked on-disk copies carry the edit.

  If invoking the skill still returns the OLD text, that is state (a) -- the
  ship worked and Cowork is serving a copy it read into memory at session start.

  ACTION: fully quit and reopen Cowork, then re-invoke to confirm.
  DO NOT re-promote. The edit is already on disk; another bump churns the
  version permanently (Rule 2 is monotonic) and fixes nothing.
VERDICT
  exit 0
fi

cat >&2 <<VERDICT
BLOCKED: at least one on-disk copy is missing the edit -- state (b), a real failure.

  A STALE BUNDLE means the promote did not include your edit. Likely causes:
  edits applied outside the staged dir, or a wrong-source-tree rebuild
  (plugin-governance, Source-of-Truth Model).

  A STALE DEPLOYED copy with a fresh bundle means the install did not propagate.
  Reinstall from the Cowork Plugins menu, then re-run this script.

  Either way the fix is upstream of a restart -- so unlike exit 0, restarting
  here will NOT help.
VERDICT
exit 1
