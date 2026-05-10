#!/usr/bin/env bash
# init.sh — initialize a new project with the clybor-claude-tooling bundle
#
# Usage:
#   bash /path/to/clybor-claude-tooling/scripts/init.sh <target-dir> [project-name]
#
# Example:
#   bash ~/gits/clybor-claude-tooling/scripts/init.sh ~/gits/new-project "New Project"
#
# Behavior:
#   - Copies .claude/ tree to <target-dir>/.claude/ (overwriting matching files)
#   - Renames .claude/settings.json.template -> .claude/settings.json (only if missing)
#   - Copies templates/CLAUDE.md.template -> <target-dir>/CLAUDE.md if missing,
#     or to CLAUDE.md.new if present (so user can diff)
#   - Replaces {{PROJECT_NAME}} in the new CLAUDE.md
#   - Makes hooks executable
#   - Prints next steps

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

# 1. Copy .claude/ tree (overwrites matching files; preserves files target has and we don't)
mkdir -p "$TARGET/.claude"
cp -R "$REPO_ROOT/.claude/." "$TARGET/.claude/"
echo "[1/4] copied .claude/ tree"

# 2. Rename settings template to settings.json if no settings.json exists yet
if [ ! -f "$TARGET/.claude/settings.json" ]; then
  if [ -f "$TARGET/.claude/settings.json.template" ]; then
    cp "$TARGET/.claude/settings.json.template" "$TARGET/.claude/settings.json"
    echo "[2/4] created .claude/settings.json from template"
  fi
else
  echo "[2/4] .claude/settings.json already exists — left untouched (template is at .claude/settings.json.template)"
fi

# 3. Place CLAUDE.md (or CLAUDE.md.new if one exists)
if [ -f "$TARGET/CLAUDE.md" ]; then
  cp "$REPO_ROOT/templates/CLAUDE.md.template" "$TARGET/CLAUDE.md.new"
  sed -i.bak "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$TARGET/CLAUDE.md.new" && rm "$TARGET/CLAUDE.md.new.bak"
  echo "[3/4] CLAUDE.md exists — wrote new template to CLAUDE.md.new (diff before merging)"
else
  cp "$REPO_ROOT/templates/CLAUDE.md.template" "$TARGET/CLAUDE.md"
  sed -i.bak "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$TARGET/CLAUDE.md" && rm "$TARGET/CLAUDE.md.bak"
  echo "[3/4] created CLAUDE.md with PROJECT_NAME=$PROJECT_NAME"
fi

# 4. Make hooks executable
if [ -d "$TARGET/.claude/hooks" ]; then
  chmod +x "$TARGET/.claude/hooks/"*.sh 2>/dev/null || true
  echo "[4/4] made hooks executable"
fi

echo
echo "Done. Next steps:"
echo "  1. cd $TARGET"
echo "  2. Review CLAUDE.md and edit the project-specific section"
echo "  3. Add domain-specific rules to .claude/rules/ if needed (Notion, Supabase, etc.)"
echo "  4. (Optional) create ROADMAP.md so the compact-recovery hook can re-inject it"
echo "  5. Test with: claude code 'run /quality-review on the README'"
