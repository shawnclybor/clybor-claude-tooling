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
echo "[1/8] copied .claude/ tree"

# 2. settings.json from template (only if missing)
if [ ! -f "$TARGET/.claude/settings.json" ]; then
  if [ -f "$TARGET/.claude/settings.json.template" ]; then
    cp "$TARGET/.claude/settings.json.template" "$TARGET/.claude/settings.json"
    echo "[2/8] created .claude/settings.json from template"
  fi
else
  echo "[2/8] .claude/settings.json already exists — left untouched"
fi

# 3. CLAUDE.md (or .new if existing)
if [ -f "$TARGET/CLAUDE.md" ]; then
  cp "$REPO_ROOT/templates/CLAUDE.md.template" "$TARGET/CLAUDE.md.new"
  sed -i.bak "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$TARGET/CLAUDE.md.new" && rm "$TARGET/CLAUDE.md.new.bak"
  echo "[3/8] CLAUDE.md exists — wrote new template to CLAUDE.md.new (diff before merging)"
else
  cp "$REPO_ROOT/templates/CLAUDE.md.template" "$TARGET/CLAUDE.md"
  sed -i.bak "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$TARGET/CLAUDE.md" && rm "$TARGET/CLAUDE.md.bak"
  echo "[3/8] created CLAUDE.md with PROJECT_NAME=$PROJECT_NAME"
fi

# 4. PRD + plan templates into docs/PRDs/_templates/ (so they ship but do not pollute docs/PRDs/)
mkdir -p "$TARGET/docs/PRDs/_templates"
cp "$REPO_ROOT/templates/prd-template.md" "$TARGET/docs/PRDs/_templates/prd-template.md"
cp "$REPO_ROOT/templates/plan-template.md" "$TARGET/docs/PRDs/_templates/plan-template.md"
echo "[4/8] copied PRD + plan templates to docs/PRDs/_templates/"

# 5. Executable hooks
if [ -d "$TARGET/.claude/hooks" ]; then
  chmod +x "$TARGET/.claude/hooks/"*.sh 2>/dev/null || true
  chmod +x "$TARGET/.claude/hooks/"*.py 2>/dev/null || true
  echo "[5/8] made hooks executable"
fi

# 6. Gate scripts + git pre-commit hook
#    check-context-budget.sh ships alongside check-knowledge.sh because CLAUDE.md's
#    Hard Rule 8 instructs running it — a rule citing an uninstalled script is not a gate.
mkdir -p "$TARGET/scripts" "$TARGET/.githooks"
cp "$REPO_ROOT/scripts/check-knowledge.sh" "$TARGET/scripts/check-knowledge.sh"
cp "$REPO_ROOT/scripts/check-context-budget.sh" "$TARGET/scripts/check-context-budget.sh"
cp "$REPO_ROOT/.githooks/pre-commit" "$TARGET/.githooks/pre-commit"
chmod +x "$TARGET/scripts/check-knowledge.sh" "$TARGET/scripts/check-context-budget.sh" "$TARGET/.githooks/pre-commit"
if [ ! -f "$TARGET/.claude/knowledge-check.conf" ]; then
  cp "$REPO_ROOT/templates/knowledge-check.conf.template" "$TARGET/.claude/knowledge-check.conf"
fi
if git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$TARGET" config core.hooksPath .githooks
  echo "[6/8] installed check-knowledge.sh + check-context-budget.sh + pre-commit gate (core.hooksPath=.githooks)"
else
  echo "[6/8] copied check-knowledge.sh + check-context-budget.sh + .githooks/pre-commit (run 'git init' then 'git config core.hooksPath .githooks' to arm the gate)"
fi

# 7. .gitignore (never clobber an existing one — append-worthy entries are the user's call)
if [ -f "$TARGET/.gitignore" ]; then
  cp "$REPO_ROOT/templates/gitignore.template" "$TARGET/.gitignore.new"
  echo "[7/8] .gitignore exists — wrote baseline to .gitignore.new (diff before merging)"
else
  cp "$REPO_ROOT/templates/gitignore.template" "$TARGET/.gitignore"
  echo "[7/8] created baseline .gitignore"
fi

# 8. .gitkeep in every scaffolded directory that would otherwise be empty.
#    Git does not track empty directories: without these, a clone of this repo is
#    missing structure that only exists on the machine that ran init.sh.
for d in "$TARGET/scripts" "$TARGET/.githooks" "$TARGET/docs/PRDs"; do
  [ -d "$d" ] || continue
  if [ -z "$(ls -A "$d" 2>/dev/null)" ]; then touch "$d/.gitkeep"; fi
done
echo "[8/8] .gitkeep placed in any empty scaffolded directory"

echo
echo "Done. Next steps:"
echo "  1. cd $TARGET"
echo "  2. Review CLAUDE.md and edit the project-specific section"
echo "  3. Add domain governance as a skill in .claude/skills/ (each must be referenced in CLAUDE.md — the gate enforces it)"
echo "  4. Set WATCH_PATHS in .claude/knowledge-check.conf if work lands outside automations/"
echo "  5. (Optional) create a knowledge/ wiki: mkdir -p knowledge/{raw,wiki} && touch knowledge/{raw,wiki}/.gitkeep knowledge/index.md knowledge/log.md"
echo "     (.gitkeep is required — git does not track empty directories, so they vanish on clone)"
echo "  6. (Optional) create ROADMAP.md so the compact-recovery hook can re-inject it"
echo "  7. Verify: bash scripts/check-knowledge.sh && bash scripts/check-context-budget.sh"
echo "  8. Start a feature with: claude code (then invoke /dev-loop)"
