#!/usr/bin/env bash
# check-knowledge.sh — enforce knowledge-wiki + project-rule invariants.
# Exits non-zero on violation. Safe in repos without these structures (skips absent checks).
# Designed to be reusable: lives in clybor-claude-tooling and is copied per project.
set -uo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 0
fail=0
err(){ echo "  ✗ $1" >&2; fail=1; }

# ---- Configuration -----------------------------------------------------------
# Defaults match the original hardcoded behavior. Override per-repo in
# .claude/knowledge-check.conf (plain shell assignments, sourced if present):
#
#   WATCH_PATHS="src/ pipelines/ knowledge/wiki/ .env"   # log-on-change trigger set
#   SKILL_ROUTER_CHECK=0                                 # disable the router gate
#
# WATCH_PATHS is a space-separated list of path prefixes, matched against staged
# filenames. A repo whose real work lives outside these paths has that work
# UNGATED — set WATCH_PATHS to wherever the work actually is.
WATCH_PATHS="${WATCH_PATHS:-automations/ knowledge/wiki/ .env}"
SKILL_ROUTER_CHECK="${SKILL_ROUTER_CHECK:-1}"
# shellcheck source=/dev/null
[ -f .claude/knowledge-check.conf ] && . .claude/knowledge-check.conf

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

# 2. log-on-change: staged edits under any WATCH_PATHS prefix require a log.md entry
if [ -f knowledge/log.md ]; then
  staged="$(git diff --cached --name-only 2>/dev/null || true)"
  pattern=""
  for p in $WATCH_PATHS; do
    esc="$(printf '%s' "$p" | sed 's/[.[\*^$\\]/\\&/g')"
    pattern="${pattern:+$pattern|}^$esc"
  done
  if [ -n "$pattern" ] && printf '%s\n' "$staged" | grep -qE "$pattern"; then
    printf '%s\n' "$staged" | grep -qx 'knowledge/log.md' \
      || err "watched path changed ($WATCH_PATHS) but knowledge/log.md has no new entry (append one, newest-first)"
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

# 4. Router gate: every installed skill must be named in CLAUDE.md.
#    A skill the router never mentions is unreachable — a cold session follows the
#    routing table, not a directory listing. Disable with SKILL_ROUTER_CHECK=0.
if [ "$SKILL_ROUTER_CHECK" = "1" ] && [ -f CLAUDE.md ] && [ -d .claude/skills ]; then
  shopt -s nullglob
  for s in .claude/skills/*/; do
    sb="$(basename "$s")"
    grep -q "$sb" CLAUDE.md \
      || err "CLAUDE.md does not reference installed skill .claude/skills/$sb — add a router row (unrouted = unreachable)"
  done
fi

if [ "$fail" -ne 0 ]; then
  echo "knowledge invariants FAILED (see ✗ above). Fix, or override once with: git commit --no-verify" >&2
  exit 1
fi
echo "knowledge invariants OK"
