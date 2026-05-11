#!/usr/bin/env bash
# init.sh — initialize a new project with the clybor-claude-tooling bundle
#
# Usage:
#   bash /path/to/clybor-claude-tooling/scripts/init.sh <target-dir> [project-name]

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: bash init.sh <target-dir> [project-name]" >&2
  exit 2
fi

TARGET="$1"
PROJECT_NAME="${2:-$(basename "$TARGET")}"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

if [ ! -d "$TARGET" ]; then
  echo "Target directory does not exist: $TARGET" >&2
  echo "Create it first (mkdir -p \"$TARGET\") and re-run." >&2
  exit 2
fi

echo "Initializing $PROJECT_NAME at $TARGET"
echo "  source: $REPO_ROOT"
echo

# 1. .claude/ tree
mkdir -p "$TARGET/.claude"
cp -R "$REPO_ROOT/.claude/." "$TARGET/.claude/"
echo "[1/5] copied .claude/ tree"

# 2. settings.json from template (only if missing)
if [ ! -f "$TARGET/.claude/settings.json" ]; then
  if [ -f "$TARGET/.claude/settings.json.template" ]; then
    cp "$TARGET/.claude/settings.json.template" "$TARGET/.claude/settings.json"
    echo "[2/5] created .claude/settings.json from template"
  fi
else
  echo "[2/5] .claude/settings.json already exists — left untouched"
fi

# 3. CLAUDE.md (or .new if existing)
if [ -f "$TARGET/CLAUDE.md" ]; then
  cp "$REPO_ROOT/templates/CLAUDE.md.template" "$TARGET/CLAUDE.md.new"
  sed -i.bak "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$TARGET/CLAUDE.md.new" && rm "$TARGET/CLAUDE.md.new.bak"
  echo "[3/5] CLAUDE.md exists — wrote new template to CLAUDE.md.new (diff before merging)"
else
  cp "$REPO_ROOT/templates/CLAUDE.md.template" "$TARGET/CLAUDE.md"
  sed -i.bak "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$TARGET/CLAUDE.md" && rm "$TARGET/CLAUDE.md.bak"
  echo "[3/5] created CLAUDE.md with PROJECT_NAME=$PROJECT_NAME"
fi

# 4. PRD + plan templates into docs/PRDs/_templates/ (so they ship but do not pollute docs/PRDs/)
mkdir -p "$TARGET/docs/PRDs/_templates"
cp "$REPO_ROOT/templates/prd-template.md" "$TARGET/docs/PRDs/_templates/prd-template.md"
cp "$REPO_ROOT/templates/plan-template.md" "$TARGET/docs/PRDs/_templates/plan-template.md"
echo "[4/5] copied PRD + plan templates to docs/PRDs/_templates/"

# 5. Executable hooks
if [ -d "$TARGET/.claude/hooks" ]; then
  chmod +x "$TARGET/.claude/hooks/"*.sh 2>/dev/null || true
  chmod +x "$TARGET/.claude/hooks/"*.py 2>/dev/null || true
  echo "[5/5] made hooks executable"
fi

echo
echo "Done. Next steps:"
echo "  1. cd $TARGET"
echo "  2. Review CLAUDE.md and edit the project-specific section"
echo "  3. Add domain-specific rules to .claude/rules/ if needed"
echo "  4. (Optional) create ROADMAP.md so the compact-recovery hook can re-inject it"
echo "  5. Start a feature with: claude code (then invoke /dev-loop)"
