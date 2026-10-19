#!/usr/bin/env bash
# test-validate-artifact.sh — prove the publish gate bites, and does not bite clean pages.
# A guard that passes its own known-bad case manufactures confidence.
#   run:  bash scripts/test-validate-artifact.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
V="$HERE/validate-artifact.mjs"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

expect() { # name want_exit file [args...]
  local name="$1" want="$2" f="$3"; shift 3
  node "$V" "$f" "$@" >"$TMP/out" 2>&1; local got=$?
  if [ "$got" = "$want" ]; then printf '  ok   %s\n' "$name"; pass=$((pass+1))
  else printf '  FAIL %s (want exit %s, got %s)\n' "$name" "$want" "$got"; sed 's/^/       /' "$TMP/out" | head -12; fail=$((fail+1)); fi
}

FILLER="$(printf 'Rendered content line. %.0s' $(seq 1 20))"
page() { # file body-script [extra-head]
  printf '<!doctype html><html><head>%s</head><body><main id="app"></main>\n<script>%s</script></body></html>\n' "${3:-}" "$2" > "$1"
}

page "$TMP/good.html" "const DATA={items:[1,2]}; document.getElementById('app').innerHTML='<ul class=list><li>$FILLER</li></ul>';"
page "$TMP/syntax.html" "{items:[1,2], total:2}.items; document.getElementById('app').textContent='x';"
page "$TMP/runtime.html" "const DATA={}; document.getElementById('app').textContent=DATA.items.length+'$FILLER';"
page "$TMP/empty.html" "const DATA={items:[]};"
page "$TMP/jsonld.html" "document.getElementById('app').textContent='$FILLER';" '<script type="application/ld+json">{"@context":"https://schema.org"}</script>'
page "$TMP/sloppy.html" "var o={a:1}; with(o){ document.getElementById('app').textContent='$FILLER'+a; }"

echo "syntax gate:"
expect "missing assignment is a syntax error"          1 "$TMP/syntax.html" --syntax-only
expect "JSON-LD block is not checked as JavaScript"    0 "$TMP/jsonld.html" --syntax-only
expect "classic script checked in sloppy mode"         0 "$TMP/sloppy.html" --syntax-only
expect "missing file argument is a usage error"        2 --min-text

echo "runtime gate:"
node "$V" "$TMP/good.html" >"$TMP/probe" 2>&1
if [ $? -eq 3 ]; then echo "  skip runtime cases: no browser on this machine"; else
  expect "clean page passes"                           0 "$TMP/good.html" --require '#app .list'
  expect "runtime error caught"                        1 "$TMP/runtime.html"
  expect "page that renders nothing caught"            1 "$TMP/empty.html"
  expect "missing required selector caught"            1 "$TMP/good.html" --require '#chart'
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
