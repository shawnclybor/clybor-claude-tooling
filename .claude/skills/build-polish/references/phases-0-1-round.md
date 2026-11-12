<!-- build-polish reference: Phase 0, Phase 1, the round (moved verbatim from SKILL.md) -->
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

**Carried items.** A parking-lot entry whose last line ends `→ build-polish` is on this run's list —
`grep -n '→ build-polish$' .claude/parking-lot.md` finds them. Each joins round 1's candidates as
`lot-<n>` and goes through triage like any other; an entry polish takes moves into the ledger and
leaves the lot.

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

