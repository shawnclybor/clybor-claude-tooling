#!/usr/bin/env bash
# new-project.sh — scaffold a new project (project folder convention + Hard Rule 11).
# Creates {slug}/{deliverables,drafts,downloads,working}, memory/projects/{slug}.md stub,
# a registry section under "## Active Projects", then runs check-backlinks.sh.
#
# Usage: [DRY_RUN=1] new-project.sh <slug> "<Display Name>"
#   slug: kebab-case folder name, e.g. acme-ai-strategy
#   Display Name: registry heading, e.g. "Acme Corp — AI Strategy"
# Hand-assembled projects are the #1 source of missed backlinks — use this script.

set -eu
if [ "$#" -lt 2 ]; then
  echo "usage: [DRY_RUN=1] $0 <slug> \"<Display Name>\""
  exit 1
fi

SLUG="$1"
NAME="$2"

case "$SLUG" in
  *[!a-z0-9-]*|-*|*-) echo "FATAL: slug must be kebab-case (lowercase letters, digits, hyphens)"; exit 1 ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGISTRY="$REPO_ROOT/docs/project-registry.md"
MEMFILE="$REPO_ROOT/memory/projects/${SLUG}.md"
PROJDIR="$REPO_ROOT/${SLUG}"

[ -e "$PROJDIR" ] && { echo "FATAL: ${SLUG}/ already exists"; exit 1; }
[ -e "$MEMFILE" ] && { echo "FATAL: memory/projects/${SLUG}.md already exists"; exit 1; }
grep -Fq "### ${NAME}" "$REGISTRY" && { echo "FATAL: registry already has a section '### ${NAME}'"; exit 1; }

if [ "${DRY_RUN:-0}" = "1" ]; then
  echo "[DRY RUN] Would create:"
  echo "  ${SLUG}/{deliverables,drafts,downloads,working}/ (+ .gitkeep)"
  echo "  memory/projects/${SLUG}.md (stub)"
  echo "  registry section '### ${NAME}' under ## Active Projects"
  echo "  then run scripts/check-backlinks.sh"
  exit 0
fi

# 1. Project folders
mkdir -p "$PROJDIR/deliverables" "$PROJDIR/drafts" "$PROJDIR/downloads" "$PROJDIR/working"
touch "$PROJDIR/deliverables/.gitkeep" "$PROJDIR/drafts/.gitkeep" \
      "$PROJDIR/downloads/.gitkeep" "$PROJDIR/working/.gitkeep"

# 2. Memory stub
cat > "$MEMFILE" <<EOF
# ${NAME}

> Scaffolded by scripts/new-project.sh — fill every TODO, then delete this line.

## Engagement

- Client: TODO
- Status: TODO — one-line current state
- Notion Project ID: TODO (create via notion-governance, then backfill the registry row too)
- Notion Client ID: TODO

## Key Facts

- TODO

## Backlinks

- Registry: \`docs/project-registry.md\` → "### ${NAME}"
- Folder: \`${SLUG}/\` (\`deliverables/\`, \`drafts/\`, \`downloads/\`, \`working/\`)
EOF

# 3. Registry section (inserted directly under ## Active Projects)
TMP=$(mktemp)
awk -v slug="$SLUG" -v name="$NAME" '
  { print }
  /^## Active Projects$/ {
    print ""
    print "### " name
    print ""
    print "| Key | Value |"
    print "|-----|-------|"
    print "| **Notion Project ID** | *Not yet created — TODO* |"
    print "| **Notion Project URL** | *Not yet created — TODO* |"
    print "| **Notion Client ID** | *Not yet created — TODO* |"
    print "| **Client** | TODO |"
    print "| **Status** | TODO — one-line engagement summary |"
    print "| **Local folder** | `" slug "/` |"
    print "| **Memory file** | `memory/projects/" slug ".md` |"
    print ""
    print "---"
  }
' "$REGISTRY" > "$TMP" && mv "$TMP" "$REGISTRY"

echo "[CREATED] ${SLUG}/ + memory stub + registry section."

# 4. Backlink check
bash "$REPO_ROOT/scripts/check-backlinks.sh" || true

echo ""
echo "Next steps: fill TODOs in the registry section and memory/projects/${SLUG}.md;"
echo "create the Notion Project + Client (notion-governance) and backfill the IDs."
