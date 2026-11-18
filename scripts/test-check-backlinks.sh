#!/usr/bin/env bash
# test-check-backlinks.sh — fixture-based parsing tests for check-backlinks.sh
#
# Exercises the awk extraction blocks against three registry-row shapes:
#   1. Plain        — "| **Local folder** | `path/` |"
#   2. Annotated    — "| **Local folder** | `path/` *(annotation with `nested/` backticks)* |"
#   3. Pending      — "| **Local folder** | *Not yet created* |"
#
# Exit codes: 0 = all pass, 1 = at least one fixture diverged from expected output.

set -u

FIXTURE=$(mktemp)
trap 'rm -f "$FIXTURE"' EXIT

cat > "$FIXTURE" <<'EOF'
## Active Projects

### Plain Project
| Key | Value |
|-----|-------|
| **Local folder** | `plain/` |
| **Memory file** | `memory/projects/plain.md` |

### Annotated Project
| Key | Value |
|-----|-------|
| **Local folder** | `annotated/` *(folder note — see `annotated/downloads/`)* |
| **Memory file** | `memory/projects/annotated.md` *(in progress)* |

### Pending Project
| Key | Value |
|-----|-------|
| **Local folder** | `pending/` *(pre-sign; graduates post-sign per rule `abc-123`)* |
| **Memory file** | *Not yet created* |

## Archived Projects

### Should Be Ignored
| Key | Value |
|-----|-------|
| **Local folder** | `should-not-appear/` |
| **Memory file** | `memory/projects/should-not-appear.md` |
EOF

# Mirror the active-section filter from check-backlinks.sh
active=$(awk '
  /^## Active Projects/ { in_active = 1; next }
  /^## / && in_active   { in_active = 0 }
  /^### / && in_active  { sub(/^### /, ""); print }
' "$FIXTURE")

expected_active="Plain Project
Annotated Project
Pending Project"

if [[ "$active" != "$expected_active" ]]; then
  echo "FAIL: Active-section filter"
  diff <(echo "$expected_active") <(echo "$active")
  exit 1
fi
echo "PASS: Active-section filter"

# Local-folder extraction
fol=$(awk '
  /^### / { sub(/^### /, ""); section = $0; next }
  /^## /  { section = "" }
  /\| \*\*Local folder\*\* \|/ {
    if (section != "") {
      if (match($0, /`[^`]+`/)) {
        val = substr($0, RSTART + 1, RLENGTH - 2)
        print section "\t" val
      } else if (match($0, /\*[^*]+\*/)) {
        print section "\t__PENDING__"
      }
    }
  }
' "$FIXTURE")

expected_fol="Plain Project	plain/
Annotated Project	annotated/
Pending Project	pending/
Should Be Ignored	should-not-appear/"

if [[ "$fol" != "$expected_fol" ]]; then
  echo "FAIL: Local-folder extraction"
  diff <(echo "$expected_fol") <(echo "$fol")
  exit 1
fi
echo "PASS: Local-folder extraction (plain + annotated + nested-backtick annotation)"

# Memory-file extraction
mem=$(awk '
  /^### / { sub(/^### /, ""); section = $0; next }
  /^## /  { section = "" }
  /\| \*\*Memory file\*\* \|/ {
    if (section != "") {
      if (match($0, /`[^`]+`/)) {
        val = substr($0, RSTART + 1, RLENGTH - 2)
        print section "\t" val
      } else if (match($0, /\*[^*]+\*/)) {
        print section "\t__PENDING__"
      }
    }
  }
' "$FIXTURE")

expected_mem="Plain Project	memory/projects/plain.md
Annotated Project	memory/projects/annotated.md
Pending Project	__PENDING__
Should Be Ignored	memory/projects/should-not-appear.md"

if [[ "$mem" != "$expected_mem" ]]; then
  echo "FAIL: Memory-file extraction"
  diff <(echo "$expected_mem") <(echo "$mem")
  exit 1
fi
echo "PASS: Memory-file extraction (backtick path + annotated path + italic pending sentinel)"

# age30 FILE...: set mtime to 30 days ago (portable: BSD touch on macOS has no -d '30 days ago')
age30(){ python3 -c 'import os,sys,time; t=time.time()-30*86400; [os.utime(p,(t,t)) for p in sys.argv[1:]]' "$@"; }
# --- Check 7 fixtures: check-unlinked-deliverables.py (each fixture names its folders in a registry row,
# so these pass with or without the optional layout block) ---
C7=$(dirname "$0")/check-unlinked-deliverables.py
T=$(mktemp -d)
mkdir -p "$T/.claude/rules" "$T/docs/registry" "$T/memory/projects" "$T/proj/drafts/_superseded" "$T/proj/deliverables"
printf '```layout\nsystem: docs\nprojects: proj\nareas: nothere\nproject-shape: drafts deliverables\nproject-root-files: index.md\n```\n' > "$T/.claude/rules/filing.md"
printf '### Proj\n| **Local folder** | `proj/` |\n| **Memory file** | `memory/projects/proj.md` |\ndraft: `proj/drafts/linked-in-registry.docx`\n' > "$T/docs/registry/proj.md"
echo 'see sibling-report.md' > "$T/memory/projects/proj.md"
echo 'bundle: kit-v1' > "$T/proj/index.md"
for f in linked-in-registry.docx sibling-report.pdf unlinked-agreement.docx .hidden linked-in-registry.docx.okf.yaml; do : > "$T/proj/drafts/$f"; done
mkdir -p "$T/proj/deliverables/kit-v1"
: > "$T/proj/deliverables/old-unlinked.docx"; age30 "$T/proj/deliverables/old-unlinked.docx"

out=$(python3 "$C7" --root "$T"); rc=$?
got=$(printf '%s\n' "$out" | grep '^UNLINKED')
if [[ $rc -ne 1 || "$got" != "UNLINKED proj/drafts/unlinked-agreement.docx" ]] || ! grep -q 'evaluated=4 unlinked=1 skipped_older=1' <<< "$out"; then
  echo "FAIL: Check 7 must flag only the unlinked recent file (rc=$rc)"; echo "$out"; exit 1
fi
echo "PASS: Check 7 flags the unlinked file; registry, sibling-.md and index.md links pass; old file skipped and counted"

echo 'unlinked-agreement.docx' >> "$T/proj/index.md"
python3 "$C7" --root "$T" > /dev/null; rc=$?
[[ $rc -eq 0 ]] || { echo "FAIL: Check 7 should be clean once linked (rc=$rc)"; exit 1; }
echo "PASS: Check 7 clean once the file is named"

mv "$T/proj" "$T/gone"; python3 "$C7" --root "$T" > /dev/null; rc=$?
[[ $rc -eq 2 ]] || { echo "FAIL: no project folders must exit 2, got $rc"; exit 1; }
rm "$T/.claude/rules/filing.md"; python3 "$C7" --root "$T" > /dev/null; rc=$?
[[ $rc -eq 2 ]] || { echo "FAIL: no layout and no project folders must exit 2, got $rc"; exit 1; }
echo "PASS: Check 7 exits 2 when it cannot check (no folders; no layout)"
rm -rf "$T"

# Robustness fixtures: broken symlink, short-stem false pass, NFD name, crash
T=$(mktemp -d)
mkdir -p "$T/.claude/rules" "$T/docs/registry" "$T/memory/projects" "$T/proj/drafts"
printf '```layout\nsystem: docs\nprojects: proj\nareas: nothere\nproject-shape: drafts deliverables\nproject-root-files: index.md\n```\n' > "$T/.claude/rules/filing.md"
python3 -c "import unicodedata,sys;open(sys.argv[1],'w').write('### Proj\n| **Local folder** | \`proj/\` |\nBanana.docx ' + unicodedata.normalize('NFC','ñandú.docx'))" "$T/docs/registry/proj.md"
ln -s /nonexistent-target "$T/proj/drafts/broken.docx"
: > "$T/proj/drafts/a.docx"
python3 -c "import unicodedata,sys;open(sys.argv[1]+'/'+unicodedata.normalize('NFD','ñandú.docx'),'w')" "$T/proj/drafts"
out=$(python3 "$C7" --root "$T" 2>&1); rc=$?
got=$(printf '%s\n' "$out" | grep '^UNLINKED' | sort | tr '\n' ' ')
if [[ $rc -ne 1 || "$got" != "UNLINKED proj/drafts/a.docx UNLINKED proj/drafts/broken.docx " ]]; then
  echo "FAIL: chaos fixtures (rc=$rc got='$got')"; echo "$out"; exit 1
fi
echo "PASS: Check 7 survives a broken symlink, rejects 'Banana.docx' as a link for a.docx, matches an NFD name"
mkdir -p "$T/proj/deliverables"; chmod 000 "$T/proj/deliverables"
python3 "$C7" --root "$T" > /dev/null 2>&1; rc=$?; chmod 755 "$T/proj/deliverables"
[[ $rc -eq 2 ]] || { echo "FAIL: a crash (unreadable folder) must exit 2, got $rc"; exit 1; }
echo "PASS: Check 7 turns a crash into exit 2 (could not check), never exit 1"
# Naming conventions: brace shorthand and folder-covers-zip
T2=$(mktemp -d); mkdir -p "$T2/.claude/rules" "$T2/docs/registry" "$T2/memory/projects" "$T2/proj/drafts" "$T2/proj/deliverables"
cp "$T/.claude/rules/filing.md" "$T2/.claude/rules/filing.md"
printf '### Proj\n| **Local folder** | `proj/` |\n| **Memory file** | `memory/projects/proj.md` |\n' > "$T2/docs/registry/proj.md"
echo 'see `2026-11-12-offer.{md,pdf}` and `deliverables/kit-v2/`; kit-v3 notes pending' > "$T2/memory/projects/proj.md"
: > "$T2/proj/drafts/2026-11-12-offer.pdf"; : > "$T2/proj/deliverables/kit-v2.zip"; : > "$T2/proj/deliverables/kit-v3.zip"
out=$(python3 "$C7" --root "$T2"); rc=$?
got=$(printf '%s\n' "$out" | grep '^UNLINKED')
[[ $rc -eq 1 && "$got" == "UNLINKED proj/deliverables/kit-v3.zip" ]] || { echo "FAIL: brace/folder conventions (rc=$rc got='$got')"; exit 1; }
echo "PASS: Check 7 honours name.{md,pdf} shorthand and folder-covers-zip, still flags kit-v3.zip"
rm -rf "$T2"
rm -rf "$T"

# Own-project scoping, case, folder dating, sidecar noise
T3=$(mktemp -d); mkdir -p "$T3/.claude/rules" "$T3/docs/registry" "$T3/memory/projects" "$T3/proj/drafts" "$T3/proj/deliverables" "$T3/other/drafts"
printf '```layout\nsystem: docs\nprojects: proj other\nareas: nothere\nproject-shape: drafts deliverables\nproject-root-files: index.md\n```\n' > "$T3/.claude/rules/filing.md"
printf '### Proj\n| **Local folder** | `proj/` |\n| **Memory file** | `memory/projects/proj.md` |\n\n### Other\n| **Local folder** | `other/` |\n| **Memory file** | `memory/projects/other.md` |\n' > "$T3/docs/registry/all.md"
echo 'owned elsewhere: only-in-other.docx' > "$T3/memory/projects/other.md"
echo 'index' > "$T3/memory/projects/proj.md"
echo 'report-q4.docx is the deck' > "$T3/proj/index.md"
: > "$T3/proj/drafts/only-in-other.docx"; : > "$T3/proj/drafts/Report-Q4.docx"
mkdir -p "$T3/proj/deliverables/bundle" "$T3/proj/deliverables/oldbundle"
: > "$T3/proj/deliverables/bundle/new.txt"; age30 "$T3/proj/deliverables/bundle"
: > "$T3/proj/deliverables/oldbundle/old.txt"; age30 "$T3/proj/deliverables/oldbundle/old.txt"
: > "$T3/proj/deliverables/oldbundle/old.txt.okf.yaml"; age30 "$T3/proj/deliverables/oldbundle"
out=$(python3 "$C7" --root "$T3"); rc=$?
got=$(printf '%s\n' "$out" | grep '^UNLINKED' | sort | tr '\n' ' ')
want="UNLINKED proj/deliverables/bundle UNLINKED proj/drafts/only-in-other.docx "
if [[ $rc -ne 1 || "$got" != "$want" ]] || ! grep -q 'skipped_older=1 unmapped_folders=0' <<< "$out"; then
  echo "FAIL: scoping/case/folder-dating (rc=$rc got='$got')"; echo "$out"; exit 1
fi
echo "PASS: Check 7 counts only the project's own notes, ignores case, dates folders by content, ignores sidecar churn"
rm -rf "$T3"

# check-backlinks.sh guard: Check 7 exit 1 with no UNLINKED lines, and exit 2, must each be a gap
S=$(mktemp -d)
printf 'import sys\nprint("Traceback: boom")\nsys.exit(1)\n' > "$S/one.py"
printf 'import sys\nprint("cannot read layout")\nsys.exit(2)\n' > "$S/two.py"
F=$(mktemp -d); mkdir -p "$F/scripts" "$F/docs" "$F/memory/projects"
for x in check-backlinks.sh registry-full.py registry_lib.py build-registry-index.py; do
  [[ -f "$(dirname "$0")/$x" ]] && cp "$(dirname "$0")/$x" "$F/scripts/"
done
printf '# Project Registry\n\n## Active Projects\n' > "$F/docs/project-registry.md"
CB="$F/scripts/check-backlinks.sh"
out=$(CHECK7_SCRIPT="$S/one.py" bash "$CB" 2>&1); rc=$?
[[ $rc -eq 1 ]] && grep -q 'Check 7 exited 1 with no UNLINKED lines' <<< "$out" || { echo "FAIL: guard for exit 1 without findings (rc=$rc)"; exit 1; }
out=$(CHECK7_SCRIPT="$S/two.py" bash "$CB" 2>&1); rc=$?
[[ $rc -eq 1 ]] && grep -q 'Check 7 could not run (exit 2)' <<< "$out" || { echo "FAIL: guard for exit 2 (rc=$rc)"; exit 1; }
echo "PASS: check-backlinks.sh logs a gap when Check 7 exits 1 with no findings, or exits 2"
rm -rf "$S" "$F"

echo ""
echo "All parsing fixtures passed."
