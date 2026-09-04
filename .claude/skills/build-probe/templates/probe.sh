#!/usr/bin/env bash
# p-<id>.sh — <one line: which PRD claim this settles, quoted>
#
# CONTRACT (all five matter; run.sh depends on the first two):
#   1. Print exactly ONE value on stdout. Nothing else. No labels, no units, no trailing prose.
#   2. Do not judge. expected.tsv holds the expectation; this file holds the measurement.
#   3. Read the SOURCE — the PDF, the corpus, the code. NEVER the record the build wrote:
#      a probe reading the build's own output proves only that the build agrees with itself.
#   4. Never write. A probe that mutates anything has corrupted its own next run.
#   5. Be re-runnable and deterministic. No timestamps, no randomness, no network.
#
# Format the value the way the PRD states it, so a human can diff the two by eye:
#   money   -> 21437.79      (no thousands separators, two decimals)
#   counts  -> 7
#   strings -> the literal string, unquoted
#   line refs -> the integer line number
set -euo pipefail

python3 - <<'PY'
import re
# ... read the source, compute ONE value ...
print(value)
PY
