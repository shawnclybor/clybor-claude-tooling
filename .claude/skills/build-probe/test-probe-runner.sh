#!/usr/bin/env bash
# test-probe-runner.sh — negative control for templates/run.sh.
#
# A gate nobody has seen fail is not a gate. Six cases, both directions: the runner must go
# green on a healthy probe set and must go red, with the right exit code, on each way it can rot.
#
#   1  healthy set                      -> exit 0
#   2  a probe's value drifts           -> exit 1, MISMATCH named
#   3  a locked source is rewritten     -> exit 1, CHANGED named
#   4  expected.tsv names a missing probe -> exit 2, FATAL
#   5  a locked source is deleted       -> exit 1, GONE named
#   6  restored                          -> exit 0
#
# Run from anywhere:  bash test-probe-runner.sh

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN="$HERE/templates/run.sh"
[ -f "$RUN" ] || { echo "FATAL: templates/run.sh not found beside this test"; exit 2; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cp "$RUN" "$T/run.sh"
cd "$T" || exit 2

pass=0; fail=0
check() { # check <label> <want_exit> <got_exit> [grep-pattern] [output-file]
  local label="$1" want="$2" got="$3" pat="${4:-}" out="${5:-}"
  if [ "$got" != "$want" ]; then
    fail=$((fail+1)); printf '  FAIL  %-40s exit %s, wanted %s\n' "$label" "$got" "$want"; return
  fi
  if [ -n "$pat" ] && ! grep -q "$pat" "$out"; then
    fail=$((fail+1)); printf '  FAIL  %-40s exit ok but %s not reported\n' "$label" "$pat"; return
  fi
  pass=$((pass+1)); printf '  ok    %-40s\n' "$label"
}

seed() {
  printf 'hello\n' > src.txt
  printf '#!/usr/bin/env bash\necho 7\n' > p-rows.sh
  printf '#!/usr/bin/env bash\necho 21437.79\n' > p-sum.sh
  printf 'rows\t7\tanchor rows\nsum\t21437.79\tanchor sum\nframe\tUNPROVABLE\ta judgment, not a measurement\n' > expected.tsv
  printf 'src.txt\t%s\t%s\n' "$(shasum -a 256 src.txt | cut -d' ' -f1)" "$(wc -c <src.txt | tr -d ' ')" > sources.lock
}

echo "== probe runner negative control =="
seed
bash run.sh > o1.txt 2>&1; check "1 healthy set passes" 0 $? "PASS:" o1.txt

printf '#!/usr/bin/env bash\necho 6\n' > p-rows.sh
bash run.sh > o2.txt 2>&1; check "2 drifted probe value is caught" 1 $? "MISMATCH" o2.txt
printf '#!/usr/bin/env bash\necho 7\n' > p-rows.sh

printf 'hello world\n' > src.txt
bash run.sh > o3.txt 2>&1; check "3 rewritten source is caught" 1 $? "CHANGED" o3.txt
printf 'hello\n' > src.txt

printf 'ghost\t9\tnamed but absent\n' >> expected.tsv
bash run.sh > o4.txt 2>&1; check "4 missing probe file is FATAL" 2 $? "NO PROBE" o4.txt
grep -v '^ghost' expected.tsv > e.tmp && mv e.tmp expected.tsv

rm -f src.txt
bash run.sh > o5.txt 2>&1; check "5 deleted source is caught" 1 $? "GONE" o5.txt
printf 'hello\n' > src.txt

bash run.sh > o6.txt 2>&1; check "6 restored set passes again" 0 $? "PASS:" o6.txt

# An UNPROVABLE entry must never fail the run, and must never be silent.
grep -q "UNPROVABLE" o6.txt || { fail=$((fail+1)); echo "  FAIL  UNPROVABLE entry was not reported"; }

echo
printf '%s passed / %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
echo "PROBE RUNNER: PASS"
