<!-- build-polish reference: ledger, audit template, prompts, worked example, guidelines (moved verbatim from SKILL.md) -->
## Ledger — the knowledge harness

One file: `.claude/PRPs/{slug}/review/review-polish-audit.md`. `review` is an existing kind, and
`audit` in the name exempts it from the no-postmortem gate, so verdicts may carry dates.

```markdown
---
type: note
title: "Polish audit — {slug}"
related: [".claude/PRPs/{slug}/prd.md"]
updated: YYYY-MM-DD
status: current
schema: okf-adapted-v0.1
---
# Polish audit — {slug}

## Phase 0
(the seven fields, then the sha256 lines)

## Anomalies
| key | class | status | cite | round |
|---|---|---|---|---|
| matter-d/total_charges=0.00 | PROBLEM | FIXED | record.json:41 | 1 |
```

- **key** is item/field=observed value. A CLOSED row is never re-triaged unless its class is NOISE;
  a FIXED row whose key comes back reopens as a PROBLEM. A new value opens a new row.
- **class** SETTLED, NOISE, NOTE, PROBLEM. **status** OPEN, FIXED, CLOSED, PARKED, ASKED.
- One anomaly per physical line; a bare `file:N` cite, never in backticks, never a `.log`. Never
  the claims-ok marker — one occurrence disables the document-claims gate for the whole file.
- A verdict with no cite or decision number stays OPEN: the loop cannot settle its own findings
  without evidence.
- Matters and people are letters or roles. No quoted document text.

## Close

- **DONE** — the done checklist passed, so the deliverable is complete. On the last version's slug,
  set `state.json → state` to `complete` and `polish.state` to `done`, and the PRD's
  `status: complete`; record the deliverable as done, with the date, in the build's state memory.
  No second question: the owner approved this definition of done in Phase 0.
- **STOPPED** — cap, stagnation, three FAILs, or any PROBLEM row OPEN or ASKED. A wrong result
  waiting on the owner is still a wrong result: the verdict is STOPPED, never "done with notes".

Route every open row before reporting. NOTE → `.claude/parking-lot.md` at its next free number,
PARKED. Every ASKED row → `state.json → awaiting_human`, list or object as the slug already has
it. A trap seen in two sessions → a Serena memory plus its `mem:index` row.

Report in build-execute's four-part session-report shape, no jargon, plus the ledger counts by
class and, for each JOURNEY step, the snapshot position beside its golden.

## Prompts

### Journey walker

```text
You are {persona} ({memory and section it comes from}). This matter is live. Using ONLY the
snapshot at {path} — no golden, no code — try each journey step: {steps}. For each step: would you
know what to do, could you find it, would you recognise it, would you know you are done? Apply
U1-U6. Findings only. RUN NOTHING: no driver, generator or test. You may Read files, or print one
with a single python3 line that only opens it. Refer to matters by letter.
Per step:
step: <n> | task: <what you tried>
found: YES|NO — <tab!cell, or the words you used>
stuck: <the verbatim words that stopped you> | none
trust: act | check | reject — <one clause>
tag: PROBLEM(U#) | NOTE(U#) | CLEAN
```

| U | Check — a NO is a finding, pre-tagged so a reader cannot inflate it | NO is |
|---|---|---|
| U1 | Every figure names its source: a document and line, or a call with who and when | PROBLEM |
| U2 | Every blank and every total says what it does not cover | PROBLEM |
| U3 | No status claims more than was checked | PROBLEM |
| U4 | Every difference from the golden carries a reason or says UNKNOWN | PROBLEM |
| U5 | Every flag names one next action | NOTE; PROBLEM if the action is wrong |
| U6 | The output uses the reader's order and words, once | NOTE |

### Golden reader

"Compare {item} in the snapshot at {path} with its golden at {golden}. For each difference, cite
the position on both sides. List differences only; no verdicts. Findings only. RUN NOTHING."

## Worked example — the Yellow Sheet

- **DONE**: the release standard in the parking lot's header — every figure from every document
  reaches the workbook, and every penny of difference against the firm's finished sheet is
  accounted for or named UNKNOWN with a plainly stated reason.
- **RUN**: `bash -c 'cd <case-folder> && python3 tests/run_corpus.py'`; drivers `run_corpus.py`,
  `run_1_`, `run-mutations.sh`, `yellow-sheet.sh`; keep each case folder under the cases root
  (`_corpus-matter-<x>`) by name, plus `_corpus-logs`. That tree also holds case folders named before the letter scheme,
  which is why items are named and never globbed.
- **GOLDEN SET**: all six matters. Oracle `tests/check_real_matter.py <case-dir>`, the
  printed-total identity — grep its output for SKIP, which also exits 0. Floor: each matter's money
  cells at their latest recorded count, cited; an intended decrease is a target change for the
  owner.
- **W1** the table in `summary.json`, which `run_corpus.py` computes from `record.json`. **W2** the
  money cells counted in each matter's `output/yellow-sheet.xlsx` with openpyxl — the workbook the
  persona opens, not the record W1 already read. `run_corpus.py` exits 1 while an UNREAD refusal
  is outstanding — data, not failure.
- **GUARDS**: `(cd <case-folder> && bash tests/run-mutations.sh --only=<rows>)` — one row, or a
  comma-separated set.
- The firm's finished sheets go through `answer_key_diff.py`. The release standard asks that every
  difference carry a reason or say UNKNOWN (U4) — never that the sheet match them (reject rule e).
- **JOURNEY**: personas and surfaces from `mem:yellow_sheet/output_format`.

## Guidelines

- One change per anomaly; a round may carry several.
- Never edit the golden, the witness or the definition to make a round pass — the target rule.
- Polish owns done for the deliverable: the only stage that marks it complete, and only when its
  done checklist passes. A version's evaluate verdict is an input to Phase 0, never the
  deliverable's done.
