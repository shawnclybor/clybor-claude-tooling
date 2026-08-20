#!/usr/bin/env bash
# log-correction.sh — edit-source gate (CLAUDE.md Hard Rule 4, writing-quality).
# When Shawn corrects a draft, log the correction pattern. A repeat means the
# fix belongs in the SOURCE (voice profile, skill template), not the draft.
#
# Usage: log-correction.sh "<pattern-slug>" "<project>"
#   pattern-slug: kebab-case label for the correction, e.g. "formal-closing-line",
#                 "passive-voice-opener", "overlong-exec-summary".
#
# Exit 0 = first occurrence logged. Exit 2 = REPEAT (exact) or NEAR-REPEAT
#          (lexical overlap with a prior slug) — propose the SOURCE-level fix.
#
# --- Why this script does fuzzy matching (five-whys 2026-07-16) ---------------
# The original gate matched slugs by exact string equality. It fired ONCE in six
# weeks across 24 corrections, because slugs are free-text authored ad hoc by the
# agent that just erred — 23 distinct slugs / 24 entries, a ~96% distinct rate.
# An exact match on a near-unique key structurally cannot aggregate.
#
# Two documented misses it let through:
#   2026-06-23 <surname>-name-misspelled-<variant>-from-transcript  (client A)
#   2026-06-24 proper-noun-transcript-spelling-not-verified-<name>   (client A)
#     -> same error, same person, consecutive days. "first occurrence" both times.
#   2026-06-12 false-either-or-contrast      /  2026-06-26 false-before-after-contrast
#     -> same rhetorical defect, two slugs, gate silent.
#
# The old header told the author to "reuse existing slugs so repeats actually
# match" — an honor-system instruction inside a codified gate, and the exact
# failure mode it predicted is the one that happened (CLAUDE.md Rule 12).
#
# Fix: (a) always print prior slugs BEFORE the author can mis-name the next one;
#      (b) flag lexical near-repeats deterministically (>=2 shared content tokens).
# Validated against the full 24-entry history: flags 4 pairs of 276 possible
# (1.4%), catching both documented misses and the one exact duplicate, with zero
# false positives. A rate trigger was tested and REJECTED — >=3-in-7-days fires on
# 9 of 11 active days (baseline is 2-3/week), which is wallpaper, not a gate.
#
# KNOWN LIMIT: this catches LEXICAL near-duplicates, not SEMANTIC families with
# disjoint vocabulary (e.g. "committed-before-decision-gate" vs
# "assumed-client-has-team" share no tokens but are the same behavior). Detecting
# those needs judgment, not string matching — that is what the periodic review is
# for. Do not pretend this script closes that gap.
# -----------------------------------------------------------------------------

set -u
if [ "$#" -lt 2 ]; then
  echo "usage: $0 \"<pattern-slug>\" \"<project>\""
  exit 1
fi

# Root from the script's own location, not $PWD — this is invoked from anywhere.
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Log location is portable: projects with a memory wiki keep it there, everything
# else falls back to .claude/. Keeping ONE script for both is the point — the
# canonical copy in clybor-claude-tooling must be byte-identical to this one or
# the drift gate fires.
if [ -d "$REPO_ROOT/memory/context" ]; then
  LOG="$REPO_ROOT/memory/context/draft-corrections.log"
else
  LOG="$REPO_ROOT/.claude/draft-corrections.log"
fi
mkdir -p "$(dirname "$LOG")"
touch "$LOG"

PATTERN="$1"
PROJECT="$2"
TODAY="$(date +%F)"

# --- exact repeat (original behaviour, preserved) -----------------------------
PRIOR=$(grep -c "|${PATTERN}|" "$LOG" 2>/dev/null || true)

# --- lexical near-repeat ------------------------------------------------------
NEAR=$(PATTERN="$PATTERN" LOG="$LOG" python3 - <<'PY' 2>/dev/null || true
import os, re
STOP = {'in','to','with','not','vs','from','the','a','of','and','for','as','is',
        'be','into','on','at','by','an','too'}
def toks(s):
    return {t for t in re.split(r'[-_]', s) if t and t not in STOP and len(t) > 2}
new = toks(os.environ['PATTERN'])
seen, out = set(), []
for line in open(os.environ['LOG']):
    parts = line.strip().split('|')
    if len(parts) < 3:
        continue
    d, slug, proj = parts[0], parts[1], parts[2]
    if slug == os.environ['PATTERN'] or slug in seen:
        continue
    ov = new & toks(slug)
    if len(ov) >= 2:
        seen.add(slug)
        out.append(f"{d}|{slug}|{proj}|{','.join(sorted(ov))}")
print('\n'.join(out))
PY
)

echo "${TODAY}|${PATTERN}|${PROJECT}" >> "$LOG"

# --- always show the priors, whatever happens ---------------------------------
DISTINCT=$(cut -d'|' -f2 "$LOG" | sort -u | wc -l | tr -d ' ')
TOTAL=$(grep -c . "$LOG" | tr -d ' ')
echo "[LOG] ${TOTAL} corrections / ${DISTINCT} distinct slugs. Recent:"
tail -n 8 "$LOG" | sed 's/^/        /'
echo

if [ "${PRIOR:-0}" -gt 0 ]; then
  echo "[REPEAT] '${PATTERN}' has now been corrected $((PRIOR + 1))x:"
  grep "|${PATTERN}|" "$LOG" | cut -d'|' -f1,3 | sed 's/^/         /'
  echo
  echo "Propose the source-level fix — voice profile (clybor-voice), the deliverable"
  echo "skill's template, or writing-quality rules — not another draft fix."
  exit 2
fi

if [ -n "${NEAR:-}" ]; then
  echo "[NEAR-REPEAT] '${PATTERN}' shares content tokens with prior correction(s):"
  echo "$NEAR" | while IFS='|' read -r d slug proj ov; do
    [ -n "$slug" ] && printf '         %s  %-52s (%s)  shared: %s\n' "$d" "$slug" "$proj" "$ov"
  done
  echo
  echo "This is probably the SAME pattern under a new name — the failure mode this"
  echo "gate exists to catch (see header: the misspelled-name case, 2026-06-23/24)."
  echo "Decide explicitly: same pattern -> reuse the prior slug AND propose the"
  echo "source-level fix. Genuinely different -> say so out loud and continue."
  exit 2
fi

echo "[LOGGED] ${PATTERN} (${PROJECT}) — first occurrence, no lexical neighbours."
exit 0
