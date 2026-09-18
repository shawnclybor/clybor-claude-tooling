#!/usr/bin/env bash
# install-archify.sh — install the third-party Archify diagram skill into the USER-level
# skills dir, at a pinned release, so every project gets it from one copy.
#
# Archify is not ours, so it is not vendored here: this script and its pin ARE the canonical
# artifact. A machine rebuild runs this and is back where it was. Vendoring 8 MB of upstream
# JavaScript into every project would put a repo we do not control behind the drift gate.
#
#   usage: scripts/install-archify.sh [--force] [--dest <dir>]
set -euo pipefail

PIN_TAG="v2.16.0"
PIN_COMMIT="c826e6c3a7abad19c0f3cd1ca57207d54b1ad8de"
REPO_URL="https://github.com/tt-a1i/archify"
DEST="${HOME}/.claude/skills/archify"
FORCE=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --dest)  DEST="$2"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

command -v node >/dev/null 2>&1 || { echo "node not found; Archify needs Node >=18" >&2; exit 2; }
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[ "$NODE_MAJOR" -ge 18 ] || { echo "node $NODE_MAJOR is too old; Archify needs >=18" >&2; exit 2; }

if [ -f "$DEST/.archify-pin" ] && [ -z "$FORCE" ]; then
  HAVE="$(sed -n '1p' "$DEST/.archify-pin")"
  if [ "$HAVE" = "$PIN_TAG $PIN_COMMIT" ]; then
    echo "already at $PIN_TAG ($DEST); --force to reinstall"
    exit 0
  fi
  echo "installed pin is '$HAVE'; replacing with $PIN_TAG"
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/archify-install.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

git -c advice.detachedHead=false clone --depth 1 --branch "$PIN_TAG" -q "$REPO_URL" "$TMP/src" 2>/dev/null
GOT="$(git -C "$TMP/src" rev-parse HEAD)"
[ "$GOT" = "$PIN_COMMIT" ] || {
  echo "REFUSING: $PIN_TAG resolves to $GOT, not the pinned $PIN_COMMIT." >&2
  echo "A moved tag is a supply-chain event. Verify upstream before changing the pin." >&2
  exit 3
}

# Only the skill subdirectory ships. The rest of the repo is gallery assets and site builders.
rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
cp -R "$TMP/src/archify" "$DEST"
printf '%s %s\n%s\n' "$PIN_TAG" "$PIN_COMMIT" "installed $(date -u +%Y-%m-%dT%H:%M:%SZ) by scripts/install-archify.sh" > "$DEST/.archify-pin"

ARCHIFY_UPDATE_CHECK_DISABLED=1 node "$DEST/bin/archify.mjs" doctor >/dev/null || {
  echo "doctor FAILED after install; leaving $DEST in place for inspection" >&2
  exit 4
}

echo "archify $PIN_TAG installed: $DEST"
echo "  doctor: ok"
echo "  set ARCHIFY_UPDATE_CHECK_DISABLED=1 to stop its optional update ping"
