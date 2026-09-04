#!/usr/bin/env bash
# probes/run.sh — run every probe, diff emitted against expected, verify the source lock.
#
# Exit 0  only when every probe matches AND sources.lock verifies.
# Exit 1  a probe MISMATCHed, or a locked source moved.
# Exit 2  misconfiguration (missing expected.tsv, a probe named in expected.tsv that does not exist).
#
# UNPROVABLE entries never fail the run. They are printed, counted, and carried into
# build-validate as premises -- because that is what an unprovable claim is.
#
# Nothing here writes. If you find yourself adding a write, you have built a different tool.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE" || exit 2

EXPECTED="$HERE/expected.tsv"
LOCK="$HERE/sources.lock"

[ -f "$EXPECTED" ] || { echo "FATAL: no expected.tsv beside run.sh"; exit 2; }

ok=0; mismatch=0; unprovable=0; missing=0

printf '%s\n' "== probes =="
while IFS=$'\t' read -r id want why; do
  case "$id" in ''|'#'*) continue ;; esac

  if [ "$want" = "UNPROVABLE" ]; then
    unprovable=$((unprovable+1))
    printf '  UNPROVABLE   %-28s %s\n' "$id" "$why"
    continue
  fi

  probe="$HERE/p-$id.sh"
  if [ ! -f "$probe" ]; then
    missing=$((missing+1))
    printf '  NO PROBE     %-28s named in expected.tsv, file absent\n' "$id"
    continue
  fi

  # A probe prints ONE value. Anything on stderr is noise and is kept out of the comparison.
  got="$(bash "$probe" 2>/dev/null | tr -d '\r' | head -1)"

  if [ "$got" = "$want" ]; then
    ok=$((ok+1))
    printf '  ok           %-28s %s\n' "$id" "$want"
  else
    mismatch=$((mismatch+1))
    printf '  MISMATCH     %-28s expected %-18s got %-18s (%s)\n' "$id" "$want" "${got:-<empty>}" "$why"
  fi
done < "$EXPECTED"

# ---- source lock ------------------------------------------------------------
# Catches a cited document being rewritten underneath the build. This has happened:
# a plan folded from a sibling slug's task bodies while a concurrent session cut that
# slug from 14 tasks to 10, and every citation silently pointed at different work.
locked=0; moved=0; gone=0
if [ -f "$LOCK" ]; then
  printf '%s\n' "== sources =="
  while IFS=$'\t' read -r path want_sha want_size; do
    case "$path" in ''|'#'*) continue ;; esac
    locked=$((locked+1))
    if [ ! -f "$path" ]; then
      gone=$((gone+1)); printf '  GONE         %s\n' "$path"; continue
    fi
    got_sha="$(shasum -a 256 "$path" | cut -d' ' -f1)"
    if [ "$got_sha" != "$want_sha" ]; then
      moved=$((moved+1))
      got_size="$(wc -c <"$path" | tr -d ' ')"
      printf '  CHANGED      %s\n               was %s bytes, now %s\n' "$path" "$want_size" "$got_size"
    fi
  done < "$LOCK"
  [ "$moved" -eq 0 ] && [ "$gone" -eq 0 ] && printf '  ok           %s file(s) unchanged\n' "$locked"
else
  printf '%s\n' "== sources ==\n  NO LOCK      sources.lock absent -- citations are unpinned"
fi

# ---- verdict ----------------------------------------------------------------
printf '\n%s\n' "== summary =="
printf '  %s ok / %s MISMATCH / %s UNPROVABLE / %s missing-probe\n' "$ok" "$mismatch" "$unprovable" "$missing"
printf '  sources: %s locked, %s changed, %s gone\n' "$locked" "$moved" "$gone"

if [ "$missing" -gt 0 ]; then
  printf '\nFATAL: %s probe(s) named in expected.tsv do not exist.\n' "$missing"; exit 2
fi
if [ "$mismatch" -gt 0 ] || [ "$moved" -gt 0 ] || [ "$gone" -gt 0 ]; then
  printf '\nFAIL: the PRD disagrees with the world.\n'
  printf 'Fix the PRD, or fix the probe -- never edit expected.tsv to match a probe. That makes the gate a mirror.\n'
  exit 1
fi
printf '\nPASS: %s claim(s) emitted as asserted; %s source(s) unchanged.\n' "$ok" "$locked"
[ "$unprovable" -gt 0 ] && printf '%s claim(s) UNPROVABLE -- carry them to build-validate as premises.\n' "$unprovable"
exit 0
