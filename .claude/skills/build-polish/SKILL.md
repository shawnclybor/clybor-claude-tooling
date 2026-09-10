---
name: build-polish
description: "The final stage of a whole build, and the stage that owns done. Once the build's planned versions and increments are finished, build-polish runs the real thing rapidly until it matches its goldens, then marks the deliverable complete; build-evaluate is not run again. Phase 0 is a preflight gate: it writes the definition of done (the release standard, a named golden set with numeric floors, two independent witnesses, the end-user journey) and nothing runs until the owner confirms it. Then up to three rounds: one serialized run of the core function into a frozen snapshot; comparison against the goldens; parallel read-only subagents that check it and walk the user journey; an evidence-gated sequential-thinking checklist deciding whether each anomaly is really a problem; the smallest fix, under a KISS/YAGNI veto and code review. The end check stays small: real results, plus single mutation rows or sets whose output drives a fix. Triggers - polish the build, final polish, get it to done, is it done, /build polish."
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent, Skill, AskUserQuestion, mcp__sequential-thinking__sequentialthinking
user-invocable: true
argument-hint: "<slug>"
---

# Build Polish

**Get to done.** While a build is being built, each version or increment gets its own
build-evaluate verdict — and none of those verdicts is the deliverable being done. The Yellow
Sheet went through 1.0 to 1.4 that way, evaluated many times and never done. Polish is the end of
the build: the owner defines done once, the real thing runs until it matches, and polish marks the
deliverable complete.

Three measured facts shape it.

- **45% of all must-fix findings** across 21 review rounds sat in text the previous round's repair
  wrote (`mem:gate_philosophy`). Polish reviews by rule and by harness, not by panel.
- **Exit codes and counts have called builds done that were not** — a green renderer over an empty
  tab, "workbook written" over 0 of 70 money cells, a floor 40 below its count. The done check
  reads the artifact, never the exit code.
- **Two drivers on one shared tree cost a whole measurement round** on 2026-09-10 — the reason for
  the one-run cap below.

## Where it sits

```text
while the build is being built, per version or increment:
    prd → probe → validate → plan → estimate → execute → evaluate
at the end of the build, once:
    POLISH → the deliverable is done
```

Polish replaces any further evaluate. It never runs the full suite or the full mutation table:
those did their job while the versions were built. It checks the finished thing against real
examples, and uses single mutation rows, or small sets of them, where their output drives a fix.

## Preconditions — REFUSE if unmet

- The owner has called the build at its end: no planned version or increment is left to execute.
- Polish runs on the last version's slug: `.claude/PRPs/{slug}/prd.md` and `state.json` exist, and
  the last increment's build-execute reported `success`.
- If `probes/run.sh` exists, it was re-run this session with 0 MISMATCH.
- The build names a core-function command and at least one golden with an oracle. With no golden
  there is nothing to polish against; that is build work — stop and say so.

## Fixed caps

Three rounds. Stagnation — two rounds in which no ledger row left OPEN — runs `five-whys`, then
stops. Three FAILs on one target stop the loop as a process defect (Hard Rule 9). No clock, ever
(Hard Rule 8). One run of the core function at a time.

## What the owner sees

| When | The owner sees | The owner is asked |
|---|---|---|
| Start | The done definition, pre-filled from the release standard, the last PRD, state and every version's evaluate | Once: Confirm / Adjust / Stop |
| Rounds | Nothing. No status reports at round boundaries | Only for a target change, a scope call, or a fact only a human holds — after the repo was searched for it (Hard Rules 4 and 11) |
| End | The deliverable marked complete, or stopped, and the report (§ Close) | Only the questions the ledger could not settle |

## Phase 0 — define DONE (the preflight gate)

Read the deliverable's release standard (the owner's words for what shipping means), the last
version's `prd.md` and `state.json`, every version's `evaluate.md`, and the build's corpus skill if
it has one. Pre-fill the definition — the owner confirms, never authors. Write it as the
`## Phase 0` section of the ledger (§ Ledger):

| # | Field | Must contain |
|---|---|---|
| 1 | DONE | The release standard in one sentence, quoted, with its source line |
| 2 | GOLDEN SET | Every item by name, never a glob, and the count N. Per item: the oracle command, its expected result, and a numeric floor equal to the item's latest recorded count, cited file:line |
| 3 | WITNESSES | W1, the driver's own tally. W2, a program that reads the surface the persona reads — never the file W1 reads. Each with its literal expected output |
| 4 | RUN | The core-function command, the live-driver patterns, and the output paths to snapshot |
| 5 | GUARDS | How to run one mutation row, or a set, alone (`--only`), from the directory it needs. Never the full table |
| 6 | JOURNEY | The persona and the surface they read, from the build's own memory; the decision the output supports; the acceptance bar in the user's words; the steps — what they see, what must be true, which golden evidences it |
| 7 | NOT THIS SESSION | The named out-of-scope items, including every corpus item left out of the golden set and every journey step no source documents |

Below the table, the output of `shasum -a 256 <absolute path>...` for every golden file and every
oracle and witness program — one `hash  path` line each. `polish.sh pin` refuses a Phase 0 without
these lines or whose lines do not match the files, and re-checks them on every later call.

**The target rule** — stated here, cited by name everywhere else: only the owner moves DONE, a
golden, a floor, a witness, a PRD number, a pin, a contract, a pinned constant or a refusal limb.
The session never does, whatever a round measured. On `PIN MOVED` or `GOLDEN MOVED`, stop: show
the owner what changed, ask the Phase 0 question again, record their answer in
`state.json → decisions`, and only then run `polish.sh pin {slug} --repin` — the script refuses a
re-pin until `decisions` has grown.

**Reject the definition** if it has: (a) pass, green or exit 0 with no count; (b) an
existence-only check such as "workbook written"; (c) a criterion only an opinion can judge; (d) a
witness, floor or golden the session can edit; (e) an answer key a human keyed by hand used as a
gating golden — it carries figures no document states, and fixing toward it writes them into the
output; (f) a golden set smaller than the corpus, unless each omitted item is named in NOT THIS
SESSION; (g) a witness that reads a log, or the file the other witness reads, instead of the
surface the persona reads; (h) a journey step marked UNDOCUMENTED — it moves to NOT THIS SESSION
before the pin.

Then `bash .claude/skills/build-polish/polish.sh pin {slug}` and ONE AskUserQuestion — the DONE
sentence, N, the floors and the journey steps, with options Confirm / Adjust / Stop. That answer
is the owner's approval of done: when the done checklist later passes, nothing is asked again.
`polish.sh run` refuses without the pin, so nothing runs before that answer.

## Phase 1 — load what is already known

Read, never re-derive: `mem:index` and the memory it routes this build to (current state, what is
settled, parked, still the owner's); the slug's `state.json → decisions`, `awaiting_human`,
`what_is_NOT_claimed` — a missing key is unknown, not empty, and shapes vary by slug; every
version's `evaluate.md` must-fix and notes; the ledger. Search the parking lot and large memories
with grep.

## The round — at most three

1. **RUN.** `polish.sh run {slug} {round} --driver <pattern>... --keep <path>... -- <command>`.
   It refuses while a driver is live, tees the FULL log, checks that nothing outlived the command,
   and copies the kept paths into a read-only snapshot with a sha256 manifest and a fingerprint of
   the code. Run a long command as a background Bash call. The command's exit code is data,
   printed, never polish's verdict. A kept path the command did not produce is listed in
   `missing.txt` and on the summary line; that item is NOT MEASURED this round, never a clean
   compare.
2. **COMPARE.** Run each item's oracle against the snapshot. Every difference is a candidate.
   A mutation row, or a set of them, may run here too when its output would point at a fix.
3. **READ.** In ONE message, one subagent per golden item — every item in round 1, then only items
   whose manifest lines changed. Two readers, kept apart:
   - *Golden reader*, only for an item no oracle script covers: compares the snapshot with the
     golden and cites the position on both sides.
   - *Journey walker*: gets the snapshot and NO golden, because a reader who knows the answer
     cannot test whether the output explains itself. Walks each JOURNEY step as the persona.

   Both prompts carry the snapshot path and say **findings only** AND **run nothing** (§ Prompts).
   Every finding is a triage candidate — a lead, never a verdict.
4. **TRIAGE.** Per new candidate: `polish.sh seen {slug} <key>`, then the triage checklist, then
   one ledger row.
5. **FIX.** PROBLEM rows that question 7 cleared: the smallest change that closes the anomaly,
   past the veto (§ Reviewers). Then run the mutation rows that pin the lines the fix changed,
   alone (`--only`); every one must be caught. No full suite, no full table.
6. **REVIEW** when § Reviewers says so. The next round re-runs everything, which is what catches a
   fix that broke a different item.

A round with no new PROBLEM and no fix goes straight to the done checklist.

## The gated checklist — one mechanism, two lists

Run it with `mcp__sequential-thinking__sequentialthinking`:

- `totalThoughts` is the list's length. One thought per question, in order. Never skip, reorder or
  add a question.
- Each thought starts `Q<n>:`, quotes the command it ran and its verbatim output (or a
  `file:line` and the quoted line), and ends `→ YES` or `→ NO`.
- **A thought without quoted evidence takes the fail-closed branch**: in triage the row stays OPEN
  and blocks DONE; in the done check it is NO.
- **An opinion never answers a question**, the model's or a subagent's. A reader's report is a
  lead for a question, never its evidence.
- The first terminal answer ends it (`nextThoughtNeeded: false`) and emits one ledger row or one
  verdict line.

### Triage — is this problem really a problem?

Questions 1 to 4 are exits: a YES ends the checklist with that class. Questions 5 and 6 classify:
YES at either is a PROBLEM, and NO at both is a NOTE that ends the checklist. Question 7 routes a
PROBLEM.

1. **SETTLED?** `polish.sh seen` prints a VERDICT line — a ledger row, an `evaluate.md` verdict or
   a `state.json` decision — for this key and value → SETTLED, cite it. A LEAD line (parking lot,
   memory) is a lead, never a verdict. Two keys reopen instead: a FIXED row's key seen again means
   the fix did not hold — go to question 7 as a PROBLEM; a NOISE row's key seen again on a fresh
   snapshot goes on to question 2.
2. **NOISE?** The snapshot artifact itself — never the log, never a summary — does not show it →
   NOISE, and the row names the cause: a trimmed log, a live driver, a moved HEAD, a stale
   snapshot. "Did not reproduce" is not a cause; with none named, answer NO.
3. **GOLDEN WRONG?** The source line our value cites, opened in the snapshot and quoted, states
   that value, and the golden's figure has no such line — or the golden predates the source →
   NOTE, ASKED. A citation alone is our reading of the source, not the source. Before saying an
   input was not supplied, open the input packet.
4. **SELF-INFLICTED?** A fix from this session touched its path → revert that fix; the row stays
   OPEN until the next round's snapshot. Gone there → the revert stands, row CLOSED. The original
   anomaly back instead → PROBLEM, ASKED: the fixes oscillate, and the owner picks.
5. **LIMB 1.** Does any value a persona reads change, whether or not a JOURNEY step names it?
6. **LIMB 2.** Does any output state a check, PASS, agreement or coverage that no source line
   supports? On a path no golden exercises, a one-variable synthetic reproducer answers this.
7. **TARGET?** The fix falls under the target rule → the row stays PROBLEM with status ASKED, and
   the owner is asked this round. NO → fix it this round.

Two standing rules. A stochastic reading path — OCR, a model reading a page — is not tested by
repetition: a figure carrying a check the paper does not support is a PROBLEM the first time. The
journey can promote a finding and never demote one; an intact step still goes through question 6.

### Done — is done really done?

The first NO ends it: NOT DONE.

1. `polish.sh pin {slug}` exits 0 and prints `pin OK`, `goldens unchanged` and `snapshot fresh:` —
   the definition, the goldens and the witness programs are as the owner confirmed them, and the
   latest snapshot measured the code as it stands. A first pin or a re-pin prints none of these.
2. The latest snapshot holds all N items, counted from W1's output inside it.
3. Every item meets its floor, read by W2 from the surface the persona reads.
4. Nothing NOT MEASURED or SKIPPED is counted as PASS; each has its own NOTE row, or is named in
   NOT THIS SESSION.
5. W2 agrees with W1 on every item.
6. Every mutation row polish ran was caught, and every line polish changed is pinned by a row that
   ran or was reviewed under § Reviewers.
7. `grep -cE '\| PROBLEM \| (OPEN|ASKED) \|'` on the ledger prints 0.
8. Every JOURNEY step has a walker's `found: YES` whose position the session opened in the latest
   snapshot and quoted.
9. The release scorecard: every clause of DONE and every criterion of the last version's PRD scores
   PASS from the latest snapshot — one thought each, quoted evidence. SKIPPED and NOT MEASURED are
   listed on their own line, never counted as PASS.

## Reviewers

**KISS/YAGNI is the dominant reviewer, applied as a rule to every fix before it lands.** Veto the
fix if its diff adds a file, flag, config key, class, abstraction or schema — unless removing that
addition brings the anomaly back. If the lines that do not close the anomaly outnumber the lines
that do, veto. A vetoed fix goes back to step 5, smaller.

**Correctness comes before size.** The real results, the pinned rows and the code reviewer decide
whether a fix is right; the veto then picks the smallest right fix.

Spawn `simplifier` and `code-reviewer` together — findings only, run nothing — in two cases:

- a round whose fix changes a line no mutation row pins and no golden item exercises;
- once before the done checklist, over polish's own combined diff, if polish changed any code.

The code reviewer blocks only on the must-fix bar: a wrong result a human relies on, or the tool
claiming something it has not verified (Hard Rule 9). The simplifier blocks only through the veto.
Everything else they say is a note for the close report and never re-enters the loop. After each
review, record it and check for drift; drift means stop reviewing that file.

```bash
python3 .claude/hooks/review-drift.py record <file> --must N --should N --note N --self-inflicted N
python3 .claude/hooks/review-drift.py check <file>
```

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
