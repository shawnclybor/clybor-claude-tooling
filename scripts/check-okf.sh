#!/usr/bin/env bash
# check-okf.sh — OKF frontmatter drift gate across every project folder.
#
# WHY NOT A GIT HOOK: client project folders are gitignored (.gitignore line 51),
# so a pre-commit hook structurally cannot see them. check-spine.py works as a
# hook precisely because index.md IS tracked. This runs from the weekly
# integrity review (via check-deliverables.sh) instead.
#
# WHY NOT deliverables-projects.tsv: that map exists for the deliverables gate,
# which needs a Notion page per project to diff against. This gate needs no such
# thing — it just walks folders. Binding it to a hand-maintained list means every
# new project folder starts life unwatched, which is the same honor-system
# failure this gate was built to catch. So: discover directories, exclude
# explicitly. Coverage fails SAFE — a new folder is checked by default.
#
# BASH 3.2 COMPATIBLE. macOS ships 3.2; `mapfile` (bash 4+) is not available.
# A first draft used it, and the gate reported PASS while checking zero folders.
# Hence the vacuous-pass guard at the bottom: a gate that cannot fail is not a
# gate. If it inspects nothing, it exits non-zero.
#
# Written 2026-07-28 after a five-whys found OKF compliance at 1.9%: the
# standard and the checker both existed; nothing ran the checker.
# Hard Rule 12 — codify as scripts, not prose. KB 3ab25bc3-529a-8142.
#
# Usage:  bash scripts/check-okf.sh          # list every offending path
#         bash scripts/check-okf.sh --quiet  # per-folder counts only

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

# Infrastructure, not project knowledge. Everything else is walked.
EXCLUDE_DIRS="git claude scripts memory node_modules cowork outputs venv __pycache__ docs"

is_excluded_dir() {
  case " $EXCLUDE_DIRS " in
    *" ${1#.} "*) return 0 ;;
  esac
  return 1
}

# VERBATIM MIRRORS. A folder holding byte-identical copies pulled from a client
# system (a client cloud share via rclone, a SharePoint sync, a Drive export) cannot
# carry inline frontmatter without breaking the fidelity that makes it a mirror:
# add frontmatter and `rclone check` reports a size difference, which reads as a
# FAILED TRANSFER. The contract and the mirror want opposite things, so the gate
# has to know which kind of file it is looking at.
#
# Declared per-folder by dropping an `.okf-mirror` file in it. Explicit by
# design, same reasoning as EXCLUDE_DIRS above — a new mirror folder is NOT
# silently exempt, someone has to say so. Reported, never counted as drift,
# exactly like LOCKED. Sidecars still work here and are still encouraged; they
# sit beside the file instead of inside it.
in_mirror() {
  d="$(dirname "$1")"
  while [ "$d" != "." ] && [ "$d" != "/" ]; do
    [ -f "$d/.okf-mirror" ] && return 0
    d="$(dirname "$d")"
  done
  return 1
}

drift=0
total=0
total_locked=0
total_mirror=0
total_badproj=0
checked_dirs=0
scanned_files=0

echo "=== OKF frontmatter check ==="

TARGETS=""
for d in */; do
  d="${d%/}"
  is_excluded_dir "$d" && continue
  [ -d "$d" ] && TARGETS="$TARGETS $d"
done
# docs/handoffs is knowledge despite living under the otherwise-excluded docs/.
[ -d "docs/handoffs" ] && TARGETS="$TARGETS docs/handoffs"

for slug in $TARGETS; do
  missing=0
  locked=0
  mirror=0
  badproj=0
  found=0

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ -f "$f" ] || continue        # dangling symlink
    found=$((found + 1))
    scanned_files=$((scanned_files + 1))
    if [ "$(head -n1 "$f" 2>/dev/null)" != "---" ]; then
      if in_mirror "$f"; then
        # Verbatim copy of a client-system file. Frontmatter would break
        # byte-fidelity against the source. Reported, not drift.
        mirror=$((mirror + 1))
        [ $QUIET -eq 0 ] && echo "        MIRROR (verbatim client copy): $f"
      elif [ ! -w "$f" ]; then
        # Deliberately read-only (mode 400) — protected source material.
        # Reported, not counted as drift: lifting the lock is a human decision,
        # not something a sweep should force.
        locked=$((locked + 1))
        [ $QUIET -eq 0 ] && echo "        LOCKED (read-only): $f"
      else
        missing=$((missing + 1))
        [ $QUIET -eq 0 ] && echo "        $f"
      fi
    fi
  done <<EOF
$(find "$slug" -type f -name '*.md' \
     ! -path '*adams-msj*' \
     ! -name 'CLAUDE.md' \
     ! -name 'index.md' 2>/dev/null | sort)
EOF

  # Binaries need a sibling .okf.yaml sidecar.
  while IFS= read -r b; do
    [ -z "$b" ] && continue
    # Two accepted sidecar names, resolved in the SAME order as verify-deliverable.py
    # (scripts/verify-deliverable.py, BINARY_EXT branch). Keep these two in sync.
    #   1. <file>.okf.yaml  — full filename incl. extension. Canonical: the only form
    #      that stays unambiguous when two binaries share a stem (e.g. foo.docx + foo.pdf).
    #   2. <stem>.okf.yaml  — legacy majority form. Accepted, but collides on shared stems.
    if [ ! -f "$b.okf.yaml" ] && [ ! -f "${b%.*}.okf.yaml" ]; then
      missing=$((missing + 1))
      [ $QUIET -eq 0 ] && echo "        $b (no .okf.yaml sidecar)"
    fi
  done <<EOF
$(find "$slug/deliverables" "$slug/drafts" -type f \
     \( -name '*.docx' -o -name '*.pptx' -o -name '*.xlsx' -o -name '*.pdf' -o -name '*.html' \) \
     2>/dev/null | sort)
EOF

  # `project:` VALUE FORM. Presence was already checked (it is one of five OR'd
  # provenance keys in verify-deliverable.py); nothing ever checked what was IN it.
  # Audit 2026-08-05: 19 of 161 sidecars had drifted into four mutually incompatible
  # forms — display names, a folder slug, and the literal string `docs/project-registry.md`.
  # The name forms are the live hazard: one project was renamed mid-engagement and five sidecars
  # carried four different names for one project. Surviving a rename is the entire reason
  # to key on a UUID. Contract: docs/okf-profile.md § Provenance.
  #
  # COUNTS AS DRIFT (promoted 2026-08-06, same day it was written). It shipped as a
  # report-only warn because 17 pre-existing files would have failed it on run one, and a
  # gate that fails on day one gets disabled rather than fixed. The backfill landed the
  # same session — 8 files repointed to verified UUIDs, 9 had `project:` removed because
  # no Notion Project record exists for them (stale prospect and one-off folders) —
  # so the count reached 0 and the warn was promoted to a real failure per Hard Rule 12.
  # A check that cannot fail is not a gate.
  while IFS= read -r y; do
    [ -z "$y" ] && continue
    pv="$(grep -m1 '^project:' "$y" 2>/dev/null \
          | sed 's/^project:[[:space:]]*//; s/^"//; s/"$//; s/[[:space:]]*$//')"
    [ -z "$pv" ] && continue
    if ! printf '%s' "$pv" | grep -Eq \
        '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$|^https://(www\.)?notion\.so/[0-9a-f]{32}$'; then
      badproj=$((badproj + 1))
      missing=$((missing + 1))
      [ $QUIET -eq 0 ] && echo "        PROJECT-FORM (not a Notion UUID): $y -> $pv"
    fi
  done <<EOF
$(find "$slug" -type f -name '*.okf.yaml' 2>/dev/null | sort)
EOF
  total_badproj=$((total_badproj + badproj))

  [ $found -eq 0 ] && continue     # folder holds no markdown; not a project
  checked_dirs=$((checked_dirs + 1))
  total_locked=$((total_locked + locked))
  total_mirror=$((total_mirror + mirror))

  if [ $missing -eq 0 ]; then
    exempt=""
    [ $locked -gt 0 ] && exempt="$locked locked/read-only"
    [ $mirror -gt 0 ] && exempt="${exempt:+$exempt, }$mirror verbatim mirror"
    if [ -n "$exempt" ]; then
      echo "OK    $slug — complete ($exempt, not drift)"
    else
      echo "OK    $slug"
    fi
  else
    echo "DRIFT $slug — $missing file(s) missing frontmatter/sidecar"
    drift=1
    total=$((total + missing))
  fi
done

echo
echo "Folders checked: $checked_dirs   Markdown files scanned: $scanned_files"

# Vacuous-pass guard. A gate that inspects nothing must not report success —
# that is how the gap this script exists to close went unnoticed for 16 days.
if [ $checked_dirs -eq 0 ] || [ $scanned_files -eq 0 ]; then
  echo "FAIL — gate inspected nothing. Broken discovery, wrong cwd, or a shell"
  echo "       incompatibility. Treat as a failure, never as a pass."
  exit 2
fi

if [ $total_badproj -gt 0 ]; then
  echo "       ^ $total_badproj sidecar(s) above have a non-UUID \`project:\` value."
  echo "         Contract: docs/okf-profile.md § Provenance. Resolve via the labelled"
  echo "         \`Notion Project ID\` row in docs/project-registry.md, or OMIT the field"
  echo "         (valid — provenance is satisfied by resource:/related:/source:/sources:)."
fi

if [ $drift -eq 0 ]; then
  echo "PASS — 0 OKF frontmatter gaps ($total_locked locked/read-only, $total_mirror verbatim mirror; both exempt)."
else
  echo "FAIL — $total file(s) missing OKF frontmatter."
  echo "Fix: python3 scripts/backfill-okf-all.py     (all folders)"
  echo "     python3 scripts/backfill-okf-frontmatter.py --project <slug> --notion-id <uuid>"
  echo "Contract: docs/okf-profile.md"
fi
exit $drift
