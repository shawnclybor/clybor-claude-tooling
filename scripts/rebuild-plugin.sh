#!/usr/bin/env bash
# rebuild-plugin.sh — enforcing gate for Cowork plugin rebuilds (plugin-governance, Hard Rule 12)
#
# Usage:
#   bash scripts/rebuild-plugin.sh <plugin-name> --stage [--reason <slug>]
#   bash scripts/rebuild-plugin.sh <plugin-name> --promote --bump patch|minor|major \
#        [--reason <slug>] [--allow-desc-change] \
#        [--allow-shrink=<skill>:<reason>] [--allow-remove=<skill>:<reason>]
#
# --allow-shrink / --allow-remove pass straight through to validate-plugin-promotion.py
# (repeatable). Removal additionally requires --bump major, per Iron Rule 2.
#
# --stage:   pending-edits check -> dated backup -> fresh extract from LIVE .plugin
#            into cowork/_stage-<reason>/ -> prints stage path. Edits are YOUR job.
# --promote: version bump from LIVE (never from stage) -> plugin.json description
#            guard -> zip -> validate-plugin.py -> validate-plugin-promotion.py ->
#            promote -> rpm live-copy sync -> stage cleanup (trap-enforced) ->
#            check-backlinks.sh.
#
# Exit non-zero on any violated gate. The skill (plugin-governance) is the pointer;
# this script is the gate.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
COWORK="$ROOT/cowork"
RPM_GLOB="$HOME/Library/Application Support/Claude/local-agent-mode-sessions/*/*/rpm"

PLUGIN="${1:-}"; shift || true
MODE="" ; BUMP="" ; REASON="rebuild" ; ALLOW_DESC=0 ; OVERRIDES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --stage) MODE=stage ;;
    --promote) MODE=promote ;;
    --bump) BUMP="${2:-}"; shift ;;
    --reason) REASON="${2:-}"; shift ;;
    --allow-desc-change) ALLOW_DESC=1 ;;
    --allow-shrink=*|--allow-remove=*) OVERRIDES+=("$1") ;;
    *) echo "FATAL: unknown arg $1"; exit 2 ;;
  esac
  shift
done

[ -n "$PLUGIN" ] && [ -n "$MODE" ] || { echo "Usage: rebuild-plugin.sh <plugin> --stage|--promote [--bump LEVEL] [--reason SLUG]"; exit 2; }

# ---- Source-of-truth model per plugin (plugin-governance § Source-of-Truth Model) ----
# The plugin->model map is DATA, not logic: it names project- and client-specific
# bundles, so it lives in a sidecar TSV rather than hardcoded here. That keeps this
# script client-agnostic (promotable to clybor-claude-tooling) and lets a new plugin
# be classified by editing one data line instead of patching a case statement.
#
# Format: "<plugin-name><TAB|space><persistent|ephemeral>", one per line; '#' comments
# and blank lines ignored. Override the path with PLUGIN_MODEL_MAP for testing.
#
# UNLISTED => ephemeral, and it WARNS. History: life-crm-enforcement was absent from
# the old case statement on 2026-08-10, so it fell through to the silent ephemeral
# catch-all while plugin-governance's Source-of-Truth table listed it as persistent.
# A --stage would have extracted LIVE over the source folder and --promote would have
# shipped that, silently discarding edits held only in cowork/life-crm-enforcement/ —
# the 2026-05-12 wrong-source-tree failure class. Silence was the bug; hence the warn.
MODEL_MAP="${PLUGIN_MODEL_MAP:-$ROOT/scripts/plugin-source-model.tsv}"

model_for() {
  local want="$1" name model
  if [ -f "$MODEL_MAP" ]; then
    while read -r name model _; do
      case "$name" in ''|\#*) continue ;; esac
      if [ "$name" = "$want" ]; then
        case "$model" in
          persistent|ephemeral) echo "$model"; return 0 ;;
          *) echo "FATAL: $MODEL_MAP: bad model '$model' for '$name' (want persistent|ephemeral)" >&2; exit 2 ;;
        esac
      fi
    done < "$MODEL_MAP"
  else
    # FATAL, not a warn. Guessing "ephemeral" with no map is the DESTRUCTIVE guess:
    # --stage would extract LIVE over a persistent source folder and --promote would
    # ship it, discarding edits held only in cowork/<plugin>/. Refuse instead.
    echo "FATAL: plugin source-model map not found at $MODEL_MAP." >&2
    echo "       Cannot determine whether '$want' is persistent or ephemeral, and guessing" >&2
    echo "       ephemeral risks overwriting a persistent source folder. Create the map" >&2
    echo "       (see scripts/plugin-source-model.tsv) or set PLUGIN_MODEL_MAP." >&2
    exit 2
  fi
  echo "WARN: '$want' is not listed in $MODEL_MAP — defaulting to ephemeral. If its source of truth is a persistent cowork/$want/ folder, add it to the map BEFORE staging, or --stage will overwrite that folder from LIVE." >&2
  echo ephemeral
}
MODEL=$(model_for "$PLUGIN")
LIVE="$COWORK/$PLUGIN.plugin"
STAGE="$COWORK/_stage-$REASON"

[ -f "$LIVE" ] || { echo "FATAL: live plugin not found: $LIVE"; exit 1; }

live_version() { unzip -p "$LIVE" .claude-plugin/plugin.json | python3 -c 'import json,sys;print(json.load(sys.stdin)["version"])'; }
live_desc()    { unzip -p "$LIVE" .claude-plugin/plugin.json | python3 -c 'import json,sys;print(json.load(sys.stdin)["description"])'; }

if [ "$MODE" = "stage" ]; then
  echo "== STAGE: $PLUGIN ($MODEL model), live version $(live_version) =="

  # Gate S1 — pending-edits manifests for this plugin (the 1.6.4 miss, 2026-06-03)
  if ls "$COWORK/_pending-edits/"*.md >/dev/null 2>&1; then
    HITS=$(grep -li "$PLUGIN" "$COWORK/_pending-edits/"*.md 2>/dev/null || true)
    if [ -n "$HITS" ]; then
      echo "!! PENDING EDITS exist for this plugin — apply them in this rebuild or justify skipping:"
      echo "$HITS" | sed 's/^/     /'
    else
      echo "   pending-edits: none mention $PLUGIN"
    fi
  else
    echo "   pending-edits: queue empty"
  fi

  # Gate S2 — no stale stage reuse (the 2026-05-12 v1.4.6->v1.4.3 incident)
  STALE=$(ls -d "$COWORK"/_stage-* 2>/dev/null || true)
  [ -n "$STALE" ] && { echo "FATAL: stale staging dirs exist — resolve before staging:"; echo "$STALE"; exit 1; }

  # Gate S3 — dated backup (Iron Rule 3)
  BAK="$LIVE.bak-$(date +%Y%m%d-%H%M%S)-$REASON"
  cp "$LIVE" "$BAK"
  echo "   backup: $BAK"

  if [ "$MODEL" = "ephemeral" ]; then
    mkdir "$STAGE"; ( cd "$STAGE" && unzip -q "$LIVE" )
    echo "   staged fresh extract of LIVE at: $STAGE"
  else
    SRC="$COWORK/$PLUGIN"
    [ -d "$SRC" ] || { echo "FATAL: persistent source dir missing: $SRC"; exit 1; }
    TMPX=$(mktemp -d); ( cd "$TMPX" && unzip -q "$LIVE" )
    echo "   persistent model — reconcile check (live vs source):"
    diff -rq "$TMPX" "$SRC" | grep -v ".DS_Store" || echo "   (no drift)"
    rm -rf "$TMPX"
    echo "   edit the SOURCE dir: $SRC  (then promote with the same --reason)"
  fi
  echo "== NEXT: apply edits, then: bash scripts/rebuild-plugin.sh $PLUGIN --promote --bump patch --reason $REASON =="
  exit 0
fi

# ---------------- PROMOTE ----------------
[ -n "$BUMP" ] || { echo "FATAL: --promote requires --bump patch|minor|major"; exit 2; }
if [ "$MODEL" = "ephemeral" ]; then SRCDIR="$STAGE"; else SRCDIR="$COWORK/$PLUGIN"; fi
[ -d "$SRCDIR" ] || { echo "FATAL: source/stage dir not found: $SRCDIR (run --stage first, same --reason)"; exit 1; }

# Failure trap: never delete the stage on a failed promote; rename so it can't be silently reused.
cleanup_fail() {
  if [ "$MODEL" = "ephemeral" ] && [ -d "$STAGE" ]; then
    mv "$STAGE" "$COWORK/_stage-FAILED-$(date +%Y%m%d-%H%M%S)"
    echo "!! promote failed — stage preserved as _stage-FAILED-* for diagnosis"
  fi
  # Persistent-model rollback. $SRCDIR is the LIVE source tree for these plugins, so a
  # failure after the version write would otherwise leave the source permanently bumped
  # and the next promote would double-bump from it. Ephemeral plugins need no rollback:
  # their stage is thrown away above.
  if [ "${VERSION_WRITTEN:-0}" -eq 1 ] && [ "$MODEL" = "persistent" ] && [ -n "${ORIGV:-}" ]; then
    python3 - "$SRCDIR/.claude-plugin/plugin.json" "$ORIGV" <<'PY'
import json, sys
p, v = sys.argv[1], sys.argv[2]
d = json.load(open(p)); d["version"] = v
json.dump(d, open(p, "w"), indent=2, ensure_ascii=False)
PY
    echo "!! version rolled back to $ORIGV in $SRCDIR (persistent source not left bumped)"
  fi
}
trap cleanup_fail ERR

echo "== PROMOTE: $PLUGIN ($MODEL), $(live_version) --bump $BUMP =="

# Gate P1 — version bump computed from LIVE, never from (possibly stale) stage
NEWV=$(python3 - "$(live_version)" "$BUMP" <<'PY'
import sys
v, lvl = sys.argv[1], sys.argv[2]
M, m, p = (int(x) for x in v.split("."))
M, m, p = {"major": (M+1, 0, 0), "minor": (M, m+1, 0), "patch": (M, m, p+1)}[lvl]
print(f"{M}.{m}.{p}")
PY
)
# NOTE: the version WRITE is deliberately deferred until after P2/P3/P4a (see below).
# On a persistent-model plugin $SRCDIR IS the live source tree, so writing the bump up
# front meant any later gate failure left the source permanently bumped with no revert,
# and the next promote double-bumped from that stale state. The cheap gates below need
# no version, so they run first and the write happens in the smallest possible window.
ORIGV=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$SRCDIR/.claude-plugin/plugin.json")

# Gate P2 — plugin.json description is a high-risk surface (2026-05-14 silent rejection)
STAGE_DESC=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["description"])' "$SRCDIR/.claude-plugin/plugin.json")
if [ "$STAGE_DESC" != "$(live_desc)" ] && [ "$ALLOW_DESC" -ne 1 ]; then
  echo "FATAL: plugin.json description differs from live. Server-side validation rejects"
  echo "       description changes under undocumented rules (KB 36025bc3...). Ship SKILL.md"
  echo "       changes first; iterate description in a separate bump with --allow-desc-change."
  false
fi

# Gate P3 — stage hygiene: flag unexpected top-level files before they ship
UNEXPECTED=$(cd "$SRCDIR" && ls | grep -vE '^(\.claude-plugin|skills|hooks|README\.md|LICENSE|index\.md)$' || true)
[ -n "$UNEXPECTED" ] && { echo "FATAL: unexpected top-level files in stage (clean before shipping):"; echo "$UNEXPECTED" | sed 's/^/     /'; false; }

# Gate P4a — SKILL.md description gate (replaces the awk one-liner, Hard Rule 12).
# Fails on >=1024 chars, on folded/literal-block descriptions (unmeasurable), and on
# a row count that does not match the skill-directory count. See 2026-08-05 sweep.
python3 "$SCRIPT_DIR/check-skill-descriptions.py" "$SRCDIR" >/dev/null || {
  echo "FATAL: check-skill-descriptions.py FAILED — rerun without >/dev/null for detail:"
  python3 "$SCRIPT_DIR/check-skill-descriptions.py" "$SRCDIR" | grep -E "FAIL|WARN" | sed 's/^/     /'
  false
}
echo "   check-skill-descriptions.py: PASS"

# Version write — deferred to here (see Gate P1 note). Must precede the zip so the
# candidate carries the new version. VERSION_WRITTEN arms the rollback in cleanup_fail.
python3 - "$SRCDIR/.claude-plugin/plugin.json" "$NEWV" <<'PY'
import json, sys
p, newv = sys.argv[1], sys.argv[2]
d = json.load(open(p))
d["version"] = newv
json.dump(d, open(p, "w"), indent=2, ensure_ascii=False)
PY
VERSION_WRITTEN=1
echo "   version: $ORIGV -> $NEWV"

# Gate P4 + P5 — structural validator, then promote-gate (Iron Rules 5 + 6)
CAND="$COWORK/$PLUGIN.plugin.candidate.zip"
rm -f "$CAND"; ( cd "$SRCDIR" && zip -qr "$CAND" . -x "*.DS_Store" )
python3 "$SCRIPT_DIR/validate-plugin.py" "$CAND" >/dev/null || { echo "FATAL: validate-plugin.py FAILED — candidate left at $CAND"; false; }
echo "   validate-plugin.py: PASS"
PROMO_OUT=$(python3 "$SCRIPT_DIR/validate-plugin-promotion.py" "$LIVE" "$CAND" ${OVERRIDES[@]+"${OVERRIDES[@]}"} 2>&1) || {
  echo "FATAL: promote-gate BLOCKED — candidate left at $CAND"
  echo "$PROMO_OUT" | grep -E "FAIL:|RESULT:" | sed 's/^/     /'
  false
}
echo "   validate-plugin-promotion.py: PROMOTE-OK"

# Promote
mv "$CAND" "$LIVE"
echo "   promoted: $LIVE @ $NEWV"

# rpm live-copy sync — every installed copy of this plugin in any session dir.
# NOTE: must use find + quoted paths; "Application Support" contains a space, so an
# unquoted glob word-splits and silently matches nothing (caught live 2026-06-03).
SYNCED=0
while IFS= read -r pj; do
  [ -f "$pj" ] || continue
  NAME=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("name",""))' "$pj" 2>/dev/null || true)
  if [ "$NAME" = "$PLUGIN" ]; then
    RPMDIR=$(dirname "$(dirname "$pj")")
    # Sync every component dir the bundle actually has. A plugin may legitimately
    # ship hooks with no skills (diagnostics, enforcement-only bundles) — an
    # unguarded cp on a missing skills/ exits non-zero AFTER the promote already
    # succeeded, which reads as "promote failed" and invites a double-bump retry.
    # Caught live 2026-08-06 on hook-probe.
    for COMP in skills hooks; do
      if [ -d "$SRCDIR/$COMP" ]; then
        mkdir -p "$RPMDIR/$COMP"
        cp -R "$SRCDIR/$COMP/." "$RPMDIR/$COMP/"
      fi
    done
    cp "$SRCDIR/.claude-plugin/plugin.json" "$pj"
    SYNCED=$((SYNCED+1))
    echo "   rpm synced: $RPMDIR"
  fi
done < <(find "$HOME/Library/Application Support/Claude/local-agent-mode-sessions" -maxdepth 6 -path "*/rpm/plugin_*/.claude-plugin/plugin.json" 2>/dev/null)
[ "$SYNCED" -eq 0 ] && echo "   rpm sync: no installed copies found (fresh install will pick up the bundle)"

# Stage cleanup — trap-exempt success path (Iron Rule: mandatory immediate cleanup)
trap - ERR
[ "$MODEL" = "ephemeral" ] && rm -rf "$STAGE" && echo "   stage cleaned"

# Gate P6 — backlinks (CLAUDE.md Hard Rule 11: repackage is a trigger)
bash "$SCRIPT_DIR/check-backlinks.sh" >/dev/null && echo "   check-backlinks.sh: PASS" || { echo "FATAL: check-backlinks.sh failed — fix the backlink web"; exit 1; }

echo "== DONE: $PLUGIN $NEWV live. Reminder: Cowork app reinstall picks up the bundle; verify 'Installed plugin:' in ~/Library/Logs/Claude/main.log after UI install (validate-plugin PASS is necessary, not sufficient). =="
