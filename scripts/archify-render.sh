#!/usr/bin/env bash
# archify-render.sh — compile every Archify diagram source in a directory to <dir>/out/<name>.html
#
# Sources are named "<name>.<type>.json" (type: architecture | workflow | sequence |
# dataflow | lifecycle). The JSON is the source of truth; the HTML is a build product
# and belongs in .gitignore. Archify itself is installed once, user-level, by
# scripts/install-archify.sh.
#
#   usage: archify-render.sh [dir] [name ...]
#     dir     defaults to <git root>/docs/diagrams
#     name    render only these (bare name, no extension); omit for all
set -euo pipefail

DIR="${1:-}"
[ $# -gt 0 ] && shift || true
if [ -z "$DIR" ]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  DIR="$ROOT/docs/diagrams"
fi
[ -d "$DIR" ] || { echo "no such directory: $DIR" >&2; exit 2; }
DIR="$(cd "$DIR" && pwd)"

CLI="${ARCHIFY_CLI:-$HOME/.claude/skills/archify/bin/archify.mjs}"
[ -f "$CLI" ] || { echo "archify not installed at $CLI" >&2
  echo "  run: $(dirname "$0")/install-archify.sh" >&2; exit 2; }

mkdir -p "$DIR/out"
found=0
rc=0
for src in "$DIR"/*.json; do
  [ -e "$src" ] || break
  base="$(basename "$src")"
  name="${base%%.*}"                        # yellow-sheet-run
  kind="${base%.json}"; kind="${kind##*.}"  # sequence
  case "$kind" in
    architecture|workflow|sequence|dataflow|lifecycle) ;;
    *) echo "skip  $base -- name it <name>.<type>.json" >&2; continue ;;
  esac
  if [ "$#" -gt 0 ]; then
    want=""; for a in "$@"; do [ "$a" = "$name" ] && want=1; done
    [ -n "$want" ] || continue
  fi
  found=1
  out="$DIR/out/$name.html"
  if ARCHIFY_UPDATE_CHECK_DISABLED=1 node "$CLI" deliver "$kind" "$src" "$out" \
       --quality showcase --json > "$DIR/out/$name.render.json" 2>&1; then
    echo "ok    $name  ($kind)  ->  out/$name.html"
  else
    echo "FAIL  $name  ($kind)  -- diagnostics in out/$name.render.json" >&2
    python3 - "$DIR/out/$name.render.json" <<'PY' >&2 || true
import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception: sys.exit()
for x in d.get("diagnostics",[])[:6]: print("      -", x.get("message","")[:220])
PY
    rc=1
  fi
done
[ "$found" = 1 ] || { echo "nothing to render in $DIR" >&2; exit 2; }
exit $rc
