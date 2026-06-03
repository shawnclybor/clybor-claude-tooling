#!/usr/bin/env bash
# install-global.sh — install the global "promote to clybor-claude-tooling" enforcement:
#   1. global git pre-commit drift gate (git config --global core.hooksPath)
#   2. promotion rule in ~/.claude/CLAUDE.md
#   3. prints the SessionStart hook snippet for ~/.claude/settings.json (apply manually)
# Reversible: git config --global --unset core.hooksPath
set -euo pipefail
CANON="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$HOME/.config/git/hooks"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"

# 1. global git hooks dir + chaining pre-commit
mkdir -p "$HOOKS_DIR"
cp "$CANON/global/pre-commit" "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"
git config --global core.hooksPath "$HOOKS_DIR"
echo "[1/3] global core.hooksPath=$HOOKS_DIR (drift gate; preserves each repo's .git/hooks/pre-commit)"

# 2. ~/.claude/CLAUDE.md rule (append once)
mkdir -p "$(dirname "$CLAUDE_MD")"; touch "$CLAUDE_MD"
if grep -q "Reusable tooling → clybor-claude-tooling" "$CLAUDE_MD"; then
  echo "[2/3] promotion rule already present in $CLAUDE_MD"
else
  printf '\n' >> "$CLAUDE_MD"; cat "$CANON/global/CLAUDE.global.snippet.md" >> "$CLAUDE_MD"
  echo "[2/3] appended promotion rule to $CLAUDE_MD"
fi

# 3. SessionStart snippet (settings edits are gated — apply by hand)
echo "[3/3] add to ~/.claude/settings.json under \"hooks\":"
cat <<'JSON'
    "SessionStart": [
      { "hooks": [
        { "type": "command", "command": "bash ~/gits/clybor-claude-tooling/global/session-promote-detector.sh" }
      ] }
    ]
JSON
echo "Done. Reverse the git gate with: git config --global --unset core.hooksPath"
