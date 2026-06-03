#!/usr/bin/env bash
# check-knowledge.sh — enforce knowledge-wiki + project-rule invariants.
# Exits non-zero on violation. Safe in repos without these structures (skips absent checks).
# Designed to be reusable: lives in clybor-claude-tooling and is copied per project.
set -uo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 0
fail=0
err(){ echo "  ✗ $1" >&2; fail=1; }

# 1. Wiki article invariants (only if a wiki exists)
if [ -d knowledge/wiki ]; then
  shopt -s nullglob
  for f in knowledge/wiki/*.md; do
    base="$(basename "$f" .md)"
    fm="$(head -n 12 "$f")"
    printf '%s\n' "$fm" | grep -q '^status:'  || err "wiki/$base.md missing 'status:' frontmatter"
    printf '%s\n' "$fm" | grep -q '^sources:' || err "wiki/$base.md missing 'sources:' frontmatter"
    printf '%s\n' "$fm" | grep -q '^updated:' || err "wiki/$base.md missing 'updated:' frontmatter"
    if [ -f knowledge/index.md ]; then
      grep -q "\[\[$base\]\]" knowledge/index.md || err "wiki/$base.md not linked in knowledge/index.md (add [[$base]])"
    fi
  done
  [ -f knowledge/index.md ] || err "knowledge/wiki exists but knowledge/index.md is missing"
  [ -f knowledge/log.md ]   || err "knowledge/wiki exists but knowledge/log.md is missing"
fi

# 2. log-on-change: staged edits to automations/ , knowledge/wiki/ , or .env require a log.md entry
if [ -f knowledge/log.md ]; then
  staged="$(git diff --cached --name-only 2>/dev/null || true)"
  if printf '%s\n' "$staged" | grep -qE '^(automations/|knowledge/wiki/|\.env)'; then
    printf '%s\n' "$staged" | grep -qx 'knowledge/log.md' \
      || err "automations/ or knowledge/wiki/ changed but knowledge/log.md has no new entry (append one, newest-first)"
  fi
fi

# 3. CLAUDE.md must reference each project rule (excludes the shared template rules)
if [ -f CLAUDE.md ] && [ -d .claude/rules ]; then
  shopt -s nullglob
  for r in .claude/rules/*.md; do
    rb="$(basename "$r")"
    case "$rb" in routing-protocol.md|kiss-yagni.md|README.md) continue;; esac
    grep -q "$rb" CLAUDE.md || err "CLAUDE.md does not reference project rule .claude/rules/$rb"
  done
fi

if [ "$fail" -ne 0 ]; then
  echo "knowledge invariants FAILED (see ✗ above). Fix, or override once with: git commit --no-verify" >&2
  exit 1
fi
echo "knowledge invariants OK"
