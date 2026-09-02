---
name: build-probe
description: >
  Turn a PRD's asserted facts into EMITTED facts. Writes one executable probe per measured claim in
  the PRD — each prints a single value — plus a lockfile pinning every source the PRD cites. PASS =
  every probe runs and prints exactly what the PRD says, and no cited source has moved. Runs after
  build-prd and before build-validate, and re-runs in seconds at every later stage as the drift
  detector. Use when a PRD asserts a number, a count, a filename, a line reference, or an "every X /
  none of X" claim. Triggers — "probe the PRD", "prove the anchors", "are the numbers still true",
  "recheck the sources", "/build probe".
---

# Build Probe

**A number in a PRD is a rumour until a script prints it.**

This stage exists because of a measured fact about the previous pipeline: across 21 recorded review
rounds, a freshly-written plan carried a mean of **11.9 must-fix**, and roughly half of every
finding was a checkable claim about the world that nobody had checked. A five-agent panel found
those at a cost of ~45 minutes. A 20-line script finds them in seconds, finds them the same way
every time, and — unlike a panel — can be re-run tomorrow.

## What this replaces

The old Stage 3 ran one detector (an LLM reviewer panel) against three different failure classes.
They have wildly different cheapest detectors:

| Class | Cheapest detector | Stage |
|---|---|---|
| **Facts** — numbers, counts, filenames, line refs, "every/none" claims | a script | **build-probe** (this) |
| **Plan incoherence** — unwritten fields, dependency inversions, unfalsifiable checks | `check-plan-soundness.py` | mechanical gate |
| **Premises** — is the frame right, is this the correct oracle | a human, or one scoped review | `build-validate` |

Probe first. What survives is judgment, and judgment is all `build-validate` should ever see.

## When to use

- After `build-prd`, before `build-validate`. Every measured claim in the PRD gets a probe.
- Before `build-plan`, `build-execute` and `build-evaluate` — re-run, seconds, as the drift gate.
- Any time someone asks "is that still true".

## When NOT to use

- A claim that is a **judgment**, not a measurement ("this is the right oracle", "the frame is
  audit not generate"). Probes cannot settle those. That is `build-validate`'s one job.
- A claim about something not yet built. A probe measures the world as it is; if the PRD asserts
  what the build *will* produce, that is the acceptance driver's job, not a probe's.

## The layout

```
.claude/PRPs/{slug}/probes/
  run.sh            runs every probe, diffs emitted vs expected, verifies the lock, exits non-zero on any mismatch
  expected.tsv      probe_id <TAB> expected_value <TAB> what it proves     (one line per claim)
  p-<id>.sh         one probe per claim. Prints ONE value on stdout and nothing else.
  sources.lock      path <TAB> sha256 <TAB> size    for every file the PRD cites
```

Copy `templates/run.sh` and `templates/probe.sh` from this skill's directory. Do not invent a
different shape — the point is that any reader can run `bash probes/run.sh` without instructions.

## Phase 1: HARVEST every checkable claim

Read the PRD and list every claim that a script could settle. Be exhaustive; this is the cheap part.

- every number, sum, count, total, delta
- every filename, path, and line reference (line numbers drift — a probe re-checks them for free)
- every quoted string or label attributed to a document
- **every "every X" / "none of X" claim** — these break most often, because a subset was checked
  and generalised
- every suite or baseline count — probe it by RUNNING the suite, never by reading a prior report

A claim you cannot write a probe for is either a judgment (hand it to `build-validate`) or
unfalsifiable (which is itself a finding — say so, do not quietly drop it).

## Phase 2: WRITE one probe per claim

Each `p-<id>.sh` prints exactly one value on stdout. No commentary, no formatting, no exit-code
signalling — `run.sh` owns comparison and exit codes.

```bash
#!/usr/bin/env bash
# p-anchor1-rows.sh — PRD Anchor 1 item 1: the roster has 7 provider rows
set -euo pipefail
python3 - <<'PY'
import re, pdfplumber
with pdfplumber.open("...") as pdf:
    t = "\n".join((p.extract_text() or "") for p in pdf.pages)
print(len([l for l in t.splitlines() if ROW.match(l)]))
PY
```

Rules that keep probes honest:

1. **A probe reads the SOURCE, never the record.** Probing a value out of a file the build wrote
   proves the build agrees with itself. Read the PDF, the corpus, the code.
2. **One value, one probe.** A probe printing three numbers cannot say which one moved.
3. **Never write.** Probes are read-only. A probe that mutates a case tree has corrupted its own
   next run.
4. **Prints, does not judge.** `expected.tsv` holds the expectation, so the same probe re-used
   under a different expectation stays honest.
5. **A probe that cannot be written is a finding.** Record it in `expected.tsv` with expected value
   `UNPROVABLE` and a reason. `run.sh` counts these and prints them; it does not fail on them, and
   it never hides them.

## Phase 3: LOCK the sources

For every file the PRD or plan cites — including other slugs' `plan.md` and `prd.md` — record path,
`sha256`, and size in `sources.lock`.

This catches the class no reviewer can: **a cited document being rewritten underneath you.** It has
happened; a plan was folded from a sibling slug's task bodies while a concurrent session cut that
slug from 14 tasks to 10, and every citation silently pointed at different work.

```bash
while read -r p; do printf '%s\t%s\t%s\n' "$p" "$(shasum -a 256 "$p" | cut -d' ' -f1)" "$(wc -c <"$p")"; done < cited-paths.txt > sources.lock
```

## Phase 4: RUN and report

```bash
bash .claude/PRPs/{slug}/probes/run.sh
```

Output is one line per probe — `OK`, `MISMATCH expected/got`, or `UNPROVABLE reason` — then the lock
verification, then a summary. Exit 0 only when every probe matches and the lock verifies.

**PASS = every probe OK, lock verified, zero MISMATCH.** `UNPROVABLE` entries do not block, but they
are carried into `build-validate` as premises, because that is what they are.

On MISMATCH the PRD is wrong, not the probe — fix the PRD and re-run. Never adjust `expected.tsv` to
match a probe's output; that converts the gate into a mirror. If a probe itself is wrong, fix the
probe and say so in the commit.

## Phase 5: REPORT

Write `.claude/PRPs/{slug}/probe.md`:

```markdown
## Probe: {slug}  —  {ISO date}

| probe | claim | expected | emitted | verdict |
|---|---|---|---|---|

**Sources locked:** N files, sha256 recorded.
**Verdict:** PASS / FAIL ({N} mismatches)
**Carried to build-validate as premises:** {list of UNPROVABLE entries — the judgment calls}
```

## Re-running later

Every subsequent stage begins with `bash probes/run.sh`. It costs seconds. A red probe at plan time
means a number moved or a source was rewritten, and that is worth more than any amount of re-reading.

Do NOT re-harvest claims at every stage. Harvest once, at PRD time. New claims arrive only when the
PRD changes, and a PRD change is exactly when a new probe should be written.

## Output

```
## Probes: {slug}

**Written:** N probes, M sources locked
**Result:** {N} OK · {N} MISMATCH · {N} UNPROVABLE
**Verdict:** PASS / FAIL

### Next step
PASS → `build-validate {slug}` — premises only, and the UNPROVABLE list above is its agenda.
FAIL → fix the PRD (not the expectations) and re-run.
```

## Guidelines

- Probes are committed. They are the build's memory of why anyone believed a number.
- A probe is cheap to write and free to re-run. When in doubt, write it.
- Do not probe what the build will produce. Probe what the world already contains.
- If harvesting turns up more than ~20 checkable claims, the PRD is probably asserting things it
  does not need. That is a signal about the PRD, not a reason for 40 probes.
