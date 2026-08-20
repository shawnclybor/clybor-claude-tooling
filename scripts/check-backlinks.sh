#!/usr/bin/env bash
# check-backlinks.sh — life-crm backlink linter
#
# Validates bidirectional linkage between docs/project-registry.md, memory/projects/*.md,
# and active project folders. See .claude/skills/backlink-governance/SKILL.md for spec.
#
# Exit codes: 0 = clean, 1 = gaps found.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGISTRY="$REPO_ROOT/docs/project-registry.md"
MEMORY_DIR="$REPO_ROOT/memory/projects"

GAPS=0
GAP_LOG=""

log_gap() {
  GAPS=$((GAPS + 1))
  GAP_LOG+="  [GAP] $1"$'\n'
  GAP_LOG+="      FIX: $2"$'\n'
}

log_ok()   { echo "  [OK]   $1"; }
section()  { echo ""; echo "=== $1 ==="; }

echo "life-crm backlink linter"
echo "Repo: $REPO_ROOT"

[[ -f "$REGISTRY"   ]] || { echo "FATAL: $REGISTRY not found"; exit 1; }
[[ -d "$MEMORY_DIR" ]] || { echo "FATAL: $MEMORY_DIR not found"; exit 1; }


# --- Parse registry into temp files (avoids subshell scoping issues) ---
TMP_ACTIVE=$(mktemp)
TMP_MEMORY=$(mktemp)
TMP_FOLDER=$(mktemp)
trap 'rm -f "$TMP_ACTIVE" "$TMP_MEMORY" "$TMP_FOLDER"' EXIT

# Active sections: ### headings under ## Active Projects (until next ## heading)
awk '
  /^## Active Projects/ { in_active = 1; next }
  /^## / && in_active   { in_active = 0 }
  /^### / && in_active  { sub(/^### /, ""); print }
' "$REGISTRY" > "$TMP_ACTIVE"

# Memory-file rows: "| **Memory file** | `path` |"
# Folder rows:      "| **Local folder** | `path` |"
# Annotated rows may include trailing italic notes:
#   "| **Local folder** | `path/` *(folder not yet initialized — see `path/downloads/`)* |"
# Pending rows use an italic placeholder instead of a backticked path:
#   "| **Memory file** | *Not yet created* |"
# We extract the FIRST backtick-quoted token on the value side; if there is no
# backtick but an italic placeholder is present, emit __PENDING__ so downstream
# checks can skip on-disk validation without flagging the row.
awk '
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
' "$REGISTRY" > "$TMP_MEMORY"

awk '
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
' "$REGISTRY" > "$TMP_FOLDER"


# --- Check 1: every active registry row has Memory file + Local folder ---
section "Check 1: registry rows have Memory file + Local folder"
while IFS= read -r sec; do
  [[ -z "$sec" ]] && continue
  mem=$(grep -F "$(printf '%s\t' "$sec")" "$TMP_MEMORY" || true)
  fol=$(grep -F "$(printf '%s\t' "$sec")" "$TMP_FOLDER" || true)
  if [[ -z "$mem" ]]; then
    log_gap "Registry row '$sec' is missing the Memory file field." \
            "Add '| **Memory file** | \`memory/projects/<file>.md\` |' to the row."
  fi
  if [[ -z "$fol" ]]; then
    log_gap "Registry row '$sec' is missing the Local folder field." \
            "Add '| **Local folder** | \`<folder>/\` |' to the row."
  fi
  [[ -n "$mem" && -n "$fol" ]] && log_ok "$sec"
done < "$TMP_ACTIVE"

# --- Check 2: every registry-named Memory file exists on disk ---
section "Check 2: registry-named Memory file exists on disk"
while IFS=$'\t' read -r sec mem_path; do
  [[ -z "$sec" ]] && continue
  if [[ "$mem_path" == "__PENDING__" ]]; then
    log_ok "$sec → (pending — memory file not yet created)"
    continue
  fi
  full="$REPO_ROOT/$mem_path"
  if [[ ! -f "$full" ]]; then
    log_gap "Registry row '$sec' points to '$mem_path' which does not exist." \
            "Create the memory file or fix the path in docs/project-registry.md."
  else
    log_ok "$sec → $mem_path"
  fi
done < "$TMP_MEMORY"

# --- Check 3: every registry-named Local folder exists on disk ---
section "Check 3: registry-named Local folder exists on disk"
while IFS=$'\t' read -r sec fol_path; do
  [[ -z "$sec" ]] && continue
  if [[ "$fol_path" == "__PENDING__" ]]; then
    log_ok "$sec → (pending — folder not yet initialized)"
    continue
  fi
  full="$REPO_ROOT/$fol_path"
  if [[ ! -d "$full" ]]; then
    log_gap "Registry row '$sec' points to folder '$fol_path' which does not exist." \
            "Create the folder, move it to _archived/, or fix the registry path."
  else
    log_ok "$sec → $fol_path"
  fi
done < "$TMP_FOLDER"


# --- Check 4: every memory file has a registry row ---
section "Check 4: every memory/projects/*.md has a registry row"
for mf in "$MEMORY_DIR"/*.md; do
  [[ -e "$mf" ]] || continue
  base=$(basename "$mf")
  rel="memory/projects/$base"
  # skip meta index if present
  [[ "$base" == "index.md" || "$base" == "README.md" ]] && continue
  if grep -Fq "\`$rel\`" "$REGISTRY"; then
    log_ok "$rel"
  else
    log_gap "Memory file '$rel' has no registry row referencing it." \
            "Add a '| **Memory file** | \`$rel\` |' row to docs/project-registry.md."
  fi
done

# --- Check 5: every memory file has Related Resources + Local Files sections ---
section "Check 5: memory file structure (Related Resources + Local Files)"
for mf in "$MEMORY_DIR"/*.md; do
  [[ -e "$mf" ]] || continue
  base=$(basename "$mf")
  [[ "$base" == "index.md" || "$base" == "README.md" ]] && continue
  rel="memory/projects/$base"
  has_rr=$(grep -c '^## Related Resources' "$mf" || true)
  has_lf=$(grep -c '^## Local Files' "$mf" || true)
  has_notion=$(grep -c 'https://www.notion.so/' "$mf" || true)
  if (( has_rr == 0 )); then
    log_gap "$rel is missing '## Related Resources' section." \
            "Add '## Related Resources' with Notion URL + Drive folder + canonical meeting note."
  fi
  if (( has_lf == 0 )); then
    log_gap "$rel is missing '## Local Files' section." \
            "Add '## Local Files' describing each subfolder's purpose."
  fi
  if (( has_notion == 0 )); then
    log_gap "$rel contains no notion.so URL." \
            "Add the Notion Project URL under Related Resources."
  fi
  if (( has_rr > 0 && has_lf > 0 && has_notion > 0 )); then
    log_ok "$rel"
  fi
done


# --- Check 6: every active project folder has a matching memory file ---
section "Check 6: every active project folder has a memory file"
# Collect active folders from the registry (Check 3 already validated they exist)
while IFS=$'\t' read -r sec fol_path; do
  [[ -z "$sec" ]] && continue
  if [[ "$fol_path" == "__PENDING__" ]]; then
    log_ok "$sec ↔ (pending — folder not yet initialized)"
    continue
  fi
  # Strip trailing slash for name matching
  fol_clean="${fol_path%/}"
  # Heuristic: memory filename may not match folder exactly (e.g., acme/ → acme-corp.md),
  # so check the registry section row for a Memory file entry instead.
  mem=$(grep -F "$(printf '%s\t' "$sec")" "$TMP_MEMORY" || true)
  if [[ -z "$mem" ]]; then
    log_gap "Project folder '$fol_clean' (registry '$sec') has no linked Memory file." \
            "Create 'memory/projects/<name>.md' and add 'Memory file' row to the registry."
  else
    log_ok "$fol_clean ↔ memory file linked"
  fi
done < "$TMP_FOLDER"

# --- Report ---
section "Summary"
if (( GAPS == 0 )); then
  echo "  All checks passed. Backlink web intact."
  exit 0
else
  echo "  $GAPS gap(s) found:"
  echo ""
  printf '%s' "$GAP_LOG"
  echo ""
  echo "See .claude/skills/backlink-governance/SKILL.md for the full spec."
  exit 1
fi
