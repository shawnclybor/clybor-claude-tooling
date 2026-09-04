---
name: yellow-sheet-corpus
description: >-
  Run the Yellow Sheet chain end to end against ANY matter, from the original PDFs, and read the
  result honestly. Use whenever someone asks what has been tested end to end, whether a matter
  produces a usable sheet, how to onboard a NEW matter, or asks to re-run after a code change.
  Carries the intake mechanism that makes a new matter a JSON file rather than a code change, the
  one command, the measurement that actually says whether a sheet is usable, the STRUCTURAL vs
  UNREAD refusal split, and the traps that have produced wrong answers to this question before.
  Triggers — "what cases have we tested end to end", "run the corpus", "does it work on real
  matters", "add a new matter", "onboard this packet", "re-run after this change", "which matters
  produce a sheet".
---

# Yellow Sheet — the end-to-end run

Read `mem:yellow_sheet/core` first if you have not. This skill is the *operational* half: how to
point the chain at a matter, what to run, and how to read what comes back.

## The one command

```bash
cd .claude/PRPs/build-a-yellow-sheet/case-folder
python3 tests/run_corpus.py                    # every matter the corpus declares
python3 tests/run_corpus.py matter-r matter-s  # named matters only
python3 tests/run_corpus.py --summary          # re-print the table, run nothing
python3 tests/run_corpus.py --intake-only      # check every manifest against its folder, run nothing
```

Fresh case folder per matter under `~/{{CLIENT}}-cases/_corpus-<matter>`, `extract_sources` over the
packet PDFs, then `yellow-sheet.sh`. Nothing hand-staged and nothing seeded by
`import_yellow_sheet` — a record seeded from the firm's own sheet cannot test whether we can
produce one. Logs land in `~/{{CLIENT}}-cases/_corpus-logs/`.

**Its exit code is a verdict, not a status.**

| exit | means |
|---|---|
| **0** | complete — every matter ran and no document is refused as UNREAD |
| **1** | INCOMPLETE — the chain ran, and one or more documents were refused as UNREAD with their figures still on the page |
| **2** | an intake violation, or a matter that could not run. Nothing was measured |

⚠ **Exit 1 is the normal state today** and it is not a failure of the run. It is the open list.

## ⛔ Before you write what a document says

**Run `python3 investigate.py <sources/<key>.txt | case-dir> <claim>` and cite the `file:line` it
returns.** If it prints `NOT IN TEXT`, write exactly that: it is a fact about our extraction, not
about the page, so render the page before saying the document lacks the figure. A line marked
`weak` matched only a bare integer (a date, a count, a box number) and binds to no column.
`.claude/hooks/check-document-claims.py` denies an uncited absolute claim about a named document in
this skill, the yellow-sheet memories and PRP prose; when you repeat someone else's claim, quote it
rather than restate it.

## Onboarding a matter — the whole mechanism

**A matter IS a folder holding an `intake.json`.** Nothing else makes one: not its name, not a list
in a script, not a position in a table. Drop a packet in a folder under the corpus root, write one
JSON file beside it, and the runner discovers it.

```bash
export YS_CORPUS_ROOT=/path/to/the/packets     # defaults to the 2026-08-23 testing sets
python3 tests/run_corpus.py --draft-intake      # proposes a manifest, then REFUSES to run
```

`--draft-intake` writes `intake.json.draft` and stops. **It never writes `intake.json`, and the
rename is the confirmation** — the runner only discovers the confirmed name, so an unreviewed guess
cannot run. That refusal is not caution for its own sake: a classifier pointed at the corpus today
picks a 2-page cover letter over the 11-page itemization it shadows, because the two differ only by
a `$16,445.28` suffix in the filename.

### What a manifest says

```json
{
  "matter": "matter-x",
  "sources": {
    "prolaw": "Medical Summary.pdf",
    "lien":   "Machinify Lien.pdf",
    "bill:av-emergency": "AV Emergency Bill.pdf",
    "sheet":  "Yellow Sheet.docx"
  },
  "not_sources": {
    "Costs Report.pdf": "case costs, not medical charges -- no reader consumes it",
    "*.eml":            "carrier correspondence; states no figure the grid reads"
  }
}
```

- `matter` — the letter this matter is referred to by. ⚠ **Client surnames never appear in a
  tracked file** — the pre-commit PHI gate blocks them, correctly. The manifests live beside the
  packets, outside both git repos.
- `sources` — source key → glob, resolved against the matter's own folder. A glob matching zero or
  more than one file **refuses**; it never takes a first match.
- `sheet` is not an extraction key: the `.docx` is copied into the case folder, which is where
  `read_sheet` globs for it.
- `not_sources` — glob → **the reason the chain does not read it**. Declaring is a decision a human
  made; the reason is what makes it reviewable later.

### ⛔ Every file in the packet must be named exactly once

A file matching neither heading is **reported by name and refuses the run before anything starts**.
This is the point of the mechanism, not a formality. Before it existed, **34 files across six
matters matched nothing and were silently skipped** — among them three EOBs, a MedPay report, and a
provider's billing statement that arrived as a `.jpg`. The chain read none of them and said nothing.

Declaring a file under `not_sources` is not the same as dismissing it. Several of the corpus
declarations say, in the reason field, that the document carries money we have no reader for. That
is a gap on the record rather than a gap nobody can see.

## ⛔ How to read the result — the mistake that has been made twice

**Count money cells and chase leads. NEVER "workbook written".**

`yellow-sheet.sh` prints `workbook written: yes` whenever the checker returns exit 0, and exit 0
means *nothing broken to report* — not *the sheet has numbers in it*. A refused document writes no
figure, a blank cell is a legitimate result, so the chain completes cleanly and emits an **empty
workbook**. Measured 2026-09-03: four matters rendered a workbook and one carried **0 of 70** money
cells. Reporting those four as "good to share with the settlement team" was wrong.

The runner's table is the honest measurement:

| column | means |
|---|---|
| `money` | governed cells on the provider grid — a figure a document supports |
| `leads` | Records Needed rows carrying an unverified figure — *a figure that exists and needs chasing* |
| `payoff` | the lien amount in Case Info, written only where the lien's cover `Claim Amount` and its remaining-amount column total agree |
| `refused` | documents refused, split **STRUCTURAL / UNREAD**. The split is the whole point — see below |

**Shawn's completion bar:** *"a figure exists and needs chasing — a call to the provider, a
corrected date, a write-off confirmed."* `money + leads` is that count. A row with no document
behind it correctly stays blank; that is the firm not having sent the paper, not the tool failing.

**Baseline, 2026-09-04 — quiet tree, `YS_PROVIDER_DIRECTORY` set, suite 816/0, demo 110/0,
probes 10/10:**

```
matter     exit prov    money leads     payoff   wb          refused
matter-d      0    6    12/30     2    5229.79  yes 2 struct/0 UNREAD
matter-l      0    7     7/35     5          -  yes 0 struct/0 UNREAD
matter-o      0    5     2/25     4     280.00  yes 0 struct/0 UNREAD
matter-r      0    2     0/10     5     770.00  yes 0 struct/0 UNREAD
matter-n      0   14     0/70     2          -  yes 0 struct/2 UNREAD
matter-s      0    5     0/25     6     320.00  yes 0 struct/0 UNREAD

45 figures a paralegal can act on · 2 STRUCTURAL / 2 UNREAD · run exit 1, INCOMPLETE
```

⚠ **matter-l's `refused` went 1 → 0 without a grid figure moving.** Its hospital file is a packet
of two statements (`bill-av-hospital.txt:18`, `:41`), and since 2026-09-04 `read_bill` reads it
under the declared reading beside the packet — both statements proven, printed totals summed to
6,594.40 — and then binds it nowhere, so the sum reaches no row. The two UNREAD left are matter-n's:
its lien (the 0.37 page-3 delta) and its hospital file, whose sidecar declares one of the three
statements the file prints and is refused by name for it.

Across the six: **39 providers · 24 contacts resolved, 15 ambiguous · 4 providers carry read visits
(53 breakdown rows) · exactly 1 qualifies for break-out · `hi_lien_printed_total` recorded on 5 of 6
· 9 unattributed lien entries carrying money on Records Needed · 14 money cells carry `not-provided` from the firm's sheet (l 2, n 8, o 4).** A run materially under that has
regressed.

⚠ **36 → 45 is the lien tracker, not new money.** Zero grid figures moved across the day's three
changes (measured cell by cell against a morning snapshot). The nine new leads are lien entries that
reached no sheet row and are now named with their amount — five of them on matter-r, whose entire
770.00 lien across five physicians was invisible before. `money` is unchanged on every matter.

⚠ **matter-o's `refused` went 1 → 0 without a figure landing.** Its chiropractor's bill is now READ
— the document's only money token is `$0.00` under a header ending in `Balance`, a stated zero
outstanding balance — and then correctly **not written**, because the bill's name sits on a line
carrying a phone number and the digit-free candidate rule never proposes it. A read gap became a
bind gap; the grid cell is still blank; the run says which.

**Answer-key diff — our record against the firm's finished sheets, all six matters** (measured by
{{CLIENT}}-64, 2026-09-03, against this run; byte-identical to the same diff before the day's three
changes):

```
matter   rows paired            both state: agree/differ   key-only cells   ours-only   lien
d        6/6                    7 / 5                       18               0           agree
l        7/7                    1 / 1                       19               5           agree
o        5/5                    2 / 0                       10               0           agree
r        2/2 (+1 ours-only)     0 / 0                        0               0           agree
n        14/14 (+4 key-only)    0 / 0                       45               0           ours none, key states
s        5/5                    0 / 0                        8               0           ours only, key blank
six:     39 rows paired · 10 agree / 6 differ where both state · 100 key-only cells · 5 ours-only
```

**The 100 cells the firm filled and we leave blank, classified:** 47 the firm wrote a **zero** (one is
now a bind gap, not a read gap; at least three are conventions rather than readings) · 37 no supplied
document states the figure · 11 the ProLaw summary states and the tool holds back — **2 of those 11
disagree with the firm's own sheet**, which is the negative control for the rule that ProLaw never
governs · 5 providers that appear nowhere in the packet. **The 100 overstates our gap by an unknown
amount.** The six *differ* cells are findings for a human, not the tool; the one worth looking at
first is a hospital row 3× off in two columns at once, which reads like one statement read where
the firm totalled several.

⚠ This diff is a **measurement**, never an input: no figure flows from the key to the record. That
separation is what makes the comparison mean anything, and it is why the tool is run and reported
rather than wired into the chain.


⚠ **The corpus tree is shared and a peer session may be running it.** `run_corpus.py` DELETES each
`_corpus-<matter>` folder before rebuilding it, so a case passes through a state where its record
names bills whose text is not written yet. Check log mtimes before trusting a number, and take a
baseline only on a quiet tree.

⚙ **And the firm's own sheet agrees, on a matter other than the one the rule was derived from.**
The break-out limb was settled 2026-08-31 against the reference tracker; matter-o's finished Yellow
Sheet is independent corroboration. Settled by a `w:tbl → w:tr → w:tc` walk — one table, 8 rows: a
header, six provider-grid rows and a `Total` row.

```
rows carrying an 'Acct #' label   6    (5 medical providers + the lienholder)
  ... holding an identifier       3
  ... blank 'Acct #:'             3
  ... holding MORE THAN ONE       0    <- the break-out limb
```

So under the limb **the firm breaks out nothing on that matter either** — its empty tab and the
firm's own grain agree. That is a far better warrant for *EMPTY, AND CORRECTLY SO* than our output
merely looking thin.

### ⛔ Reading account numbers out of a firm `.docx` — two traps, both measured

Three attempts by two sessions produced three different answers before a parse settled it. The
property above survived all three; every per-row count was wrong at least once.

- ⚠ **Anchor the tag name.** `<w:t[^>]*>` also matches `<w:tcPr>`, `<w:tcW>` and `<w:tbl>`, so a
  scan captures Word's own markup and reads `rsidR` / `paraId` / column-width attributes as account
  numbers. The loose pattern reported two rows carrying multiple identifiers where there are none.
  Use `<w:t(?:\s[^>]*)?>`.
- ⚠ **The account number is NOT a column.** The provider cell is ONE cell holding the name, the
  phone(s), `Acct #: …` and `W9:` together. A scan looking for a cell whose text *starts with*
  `Acct #` returns zero rows — which is a clean, obvious failure and the good outcome. A flat text
  sweep returns a confident wrong number, which is the bad one.
- ⚠ **The LIENHOLDER row carries an `Acct #` label and a number like any other row.** Both wrong
  counts had that one row as their single cause, from opposite directions — one read dropped it,
  the other failed to find its identifier.

⚙ **The durable lesson, and it is this build's recurring one:** a scan that cannot report the thing
it names does not fail loudly, it returns a specific plausible number. Walk the rows and cells; do
not sweep the text.

⚠ **The corpus tree is shared and a peer session may be running it.** `run_corpus.py` DELETES each
`_corpus-<matter>` folder before rebuilding it, so a case passes through a state where its record
names bills whose text is not written yet. Check log mtimes before trusting a number, and take a
baseline only on a quiet tree.

## ⛔ A REFUSAL IS NOT A TERMINAL STATE

The readers classify every refused document, and the two classes must never be read as one thing:

| class | means | what to do |
|---|---|---|
| **STRUCTURAL** | the document cannot carry the figure — a one-column Medi-Cal lien asked for charges, a bill whose text holds no money token, a bill every one of whose printed totals is zero | correct and closed. Nothing |
| **UNREAD** | the figures **are on the page** and this scan did not read them — a lien whose items miss its own printed total by a delta, a totals row that came back with no amount, a packet, positive candidates none of which is columnar | ⚠ recoverable. The run names the recovery for each |

The one definition lives in `case-folder/refusals.py`; the readers emit `REFUSAL <CLASS> <key>` on
**stderr**, followed for UNREAD by a `RECOVERY` line saying what to actually do. `grep RECOVERY` in
the matter's log.

**Why this exists.** On 2026-09-03 a session built the declared-reading route to recover one
matter's refused lien and then, in the same session with the route green, reported another matter's
refusal as *"a degraded scan we correctly refused"*. That page was cleanly typeset and fully
legible; reading it moved the matter from 4 money cells to 7. Nothing in the output distinguished
the two refusals, so a human classified them by eye and got it wrong.

⚠ **Do not let this become "re-read every refusal."** Structural refusals are correct and must stay
silent, or the loud ones stop being loud.

⚠ **The recovery is NOT uniform, and the RECOVERY line says which.** A declared reading is a built,
proven route for a **lien**, and — since 2026-09-04 — for a **bill refused as a packet** (limb 7, a
packet; limb 8, a totals row whose amount the scan lost): the same `readings/<label>.json` that
feeds DOS Breakdown rows then carries the charges figure, under Shawn's decision that a packet's
statements **may** be summed when every statement's printed total is read and witnessed. A bill
refused at limb 1 or 2 has no route — no printed total for a reading to anchor to — and its
recovery says so; that is a re-scan, not a sidecar.

## When a lien will not OCR — the declared reading

**This is a built route, not a workaround, and it is the first thing to reach for when a lien
refuses UNREAD.** Recorded policy: when no engine reconciles, read the rendered page yourself and
let the document's own printed total judge the reading.

```bash
python3 -c "import pypdfium2 as p; p.PdfDocument('<lien>.pdf')[2].render(scale=4).to_pil().save('/tmp/p3.png')"
# then Read /tmp/p3.png and write the sidecar
```

Write it to **`<corpus>/<Matter>/readings/lien.json`** — beside the packet, so `run_corpus.py`
copies it in. A sidecar written directly into `~/{{CLIENT}}-cases/_corpus-*` is destroyed on the next
run, which rebuilds each folder from scratch.

```json
{"lien": "lien", "read_by": "model", "read_at": "YYYY-MM-DD", "note": "...",
 "printed": ["531.00", "320.00", "320.00"],
 "rows": [{"provider": "...", "date": "...", "claim": "...",
           "amounts": ["196.00", "110.00", "110.00"]}]}
```

`read_lien` tries it **only where the deterministic read already failed** — substituting it on a
lien that reconciles would let a claim overwrite a good machine read — and proves it three ways,
every failure named rather than the first:

- **the anchor** — `printed` must equal the totals row the CODE read. The model does not get to
  state the document's own total.
- **the parts** — every amount must occur in some deterministic pass, primary or the second-scale
  corroboration file. Stops a reading inventing a line, summing it correctly, and buying a place on
  the sheet.
- **the sum** — the rows must sum per column to that printed total. Stops a reading DROPPING a line
  and staying perfectly self-consistent.

⚠ **Exactly ONE unwitnessed amount is allowed**, and only where `printed total − witnessed rows`
forces it — arithmetic on the document, not the model being trusted. Two are refused however they
sum. Counted as OCCURRENCES, not distinct values.

⚠ A transcription is a claim about a source, **never a source**. It does not go into `sources/*.txt`
and is never named in `sources_manifest.files`.

⚠ **The parts clause needs the second-scale pass to check against.** A case folder staged before
`extract_sources` wrote `sources/<key>.alt.txt` will refuse a perfectly good reading, and the
refusal names the document for what is the staging's fault. Check the folder holds an `.alt.txt`
before believing one.

## When a bill is a packet — the declared reading for limbs 7 and 8

**Built 2026-09-04, and it reuses the sidecar you already write for DOS Breakdown.** A bill file
carrying more than one statement refuses at limb 7 (each page reconciles to its own printed TOTAL
and carries its own identifier) or at limb 8 (a totals row came back with no amount), because any
one figure read off it is one statement's total presented as the whole document's. Write
`<corpus>/<Matter>/readings/<label>.json` in TC6's shape — `statements[]`, each with `page`,
`printed_total` and its `rows` — declaring **every statement the file prints**, and `read_bill`
tries it only behind those two limbs and proves it three ways: the **anchor** (as many statements as
the file prints totals rows, counted off the reconciled pages plus the lost totals rows; every
printed total a money token in a deterministic pass, primary or `.alt.txt`), the **parts** (every row
amount in a pass, at most ONE per statement forced by that statement's printed total), the **sum**
(each statement's rows sum to its total). The printed totals are then summed into `total_charges`
and nothing else; binding is untouched.

⚠ **A reading of SOME of a packet is refused by name**, and the RECOVERY line then says the sidecar
EXISTS and was NOT USED and why. That is the honest state for matter-n's hospital file: its sidecar
declares one statement and the file prints three totals rows (`bill-av-hospital.txt:364`, `:433`
are the two whose amount the scan lost), and the sidecar's own note records the other two totals as
in neither pass. Re-scan those pages; do not widen the reading to get past the anchor.

## The third money token — `not-provided`

The firm's sheets carry three kinds of money cell: a figure, a `0`, and the words **"Not provided"**
— typed when the provider was called and refused. The record has that status, the checker flags it
(*"was asked for and refused ... check the lien"*), and the renderer prints the word; until
2026-09-03 nothing set it. Now `read_sheet` does, under a licence Shawn gave that day:

- the cell must read the **bare** words (whole cell; *"Not provided - see lien"* stays a note);
- the cell must still be `unknown`, and carry **no lien, bill or call figure** — paper beats a
  refusal, and `promote_figures` writes `stated` over the status wherever a source governs;
- it sets the **status only** — never a `value`, `used_source` or `per_source`. Premise P2 holds:
  the sheet still supplies no row and no figure.

Measured: **14 of the 15 real cells** across three matters are marked; the 15th is a cell a lien
answers and is correctly left alone. The census shows zero value changes and exactly 14 status
changes. A cell reading `not-provided` on a generated workbook is therefore the firm's own phone
call, surfaced — not the tool's inference.

## Two blanks that are not the same fact

Both were found by a human asking, not by the run. Both now print their reason.

**Contact columns.** `Phone(s)` and every contact detail render blank unless the chain is given
`--directory=<the firm's export>`. `run_corpus.py` reads `YS_PROVIDER_DIRECTORY` and, when unset,
**says the columns will be blank for that reason** rather than shipping a sheet that looks like the
firm supplied nothing.

```bash
YS_PROVIDER_DIRECTORY=~/Downloads/Providers.csv python3 tests/run_corpus.py
```

⚠ `Acct #(s)` stays blank for a **different** reason and the directory does not touch it: those come
from the firm's own sheet via `read_sheet`, and one matter writes them as bare cell values rather
than a labelled `Acct #:`.
⚠ An unambiguous directory hit can still be a number the firm does not call — one matter's emergency
group resolves to a 781 billing office while the firm dials its 855 number. The ambiguity guard says
nothing about whether the chosen number is right.

**The DOS Breakdown tab.** The tab is SELECTIVE by design: a provider is broken out only when it
carries **more than one distinct billing identifier**, and the firm's own filled tracker breaks out
6 of 31 providers. So an empty tab has two causes and they are not the same fact —

- *correct*: providers carry read visits and none carries more than one identifier;
- *not held*: the matter carries no provider bill at all;
- **read but unbound**: bills DO carry proven declared readings and no provider row carries one —
  the readings exist and bind nowhere;
- *a gap*: no bill has a proven declared reading, so nothing **could** qualify.

The run prints which, per matter. ⚠ The third and fourth read almost identically off a row count
and are opposite facts: one matter holds 2 of 2 bills WITH declared readings and still shows an
empty tab, and calling that a missing reading sends a paralegal to write a sidecar that already
exists.

## What each matter is for

One worked example, not the content of this skill. **The letters are not the folder names** —
`intake.json` maps them, and the runner names them on every run. ⚠ **Two matters share an initial, and `matter-s` is NOT the one you would guess.** The letters are settled in `.git/phi-matter-map.txt` (mode 600, never committed) and carried by `intake.json`; the 8-letter folder is `matter-n`. Never infer a letter from an initial -- two sessions got this backwards on the day it was settled, one of them by copying the previous version of this file.

| matter | what it exercises | expected shape |
|---|---|---|
| **matter-d** | the full chain; the anchor | most money cells; 2 DOS breakdown rows; payoff 5,229.79 |
| **matter-l** | a DHCS lien; a packet bill read under its declared reading and bound nowhere | two bills bind; the packet reads and reaches no row; DOS tab correctly empty |
| **matter-o** | lien reads EXACTLY and places nothing | grain mismatch — see below |
| **matter-r** | complete as sent, no bills, no money stated | 2 rows, no charges, **payoff 770.00 is the deliverable** |
| **matter-n** | a scanned Medi-Cal lien; the file-picking trap | lien and bills refuse; 2 leads; 0 of 70 money cells |
| **matter-s** | a lien whose itemization OCR broke | roster + notes; **declared reading** carries it; payoff 320.00 |

⛔ **A seventh folder is not automatically a seventh matter.** One in the corpus root holds three
loose documents and no ProLaw Medical Summary, so the chain blocks at `empty:case` and always will.
It carries no manifest and is therefore not discovered — the runner names it as a folder without
one. It lives at `~/{{CLIENT}}-fixtures/matter-m-2026-08-17/`; read its README before citing it.

⚠ **The corpus is the EASY matters by design.** The firm was asked for "the simpler packages for
now"; six arrived against a target of ten. A green run across all six is weaker evidence than its
breadth suggests.

Each packet was sent 20–21 Aug 2026 with its finished Yellow Sheet as an answer key, indexed at
`~/gits/life-crm/{{CLIENT}}/downloads/2026-08-23-testing-sets/CLAUDE.md`. **Read that index before
running a matter for the first time** — it carries the settlement team's own rules, four of which
make a checker report a *correct* sheet as wrong.

## Traps that have produced a wrong answer to this question

- **Two files differing only by a `$16,445.28` suffix** — a 2-page cover letter and an 11-page
  itemization. Point the tool at the cover and every row fails corroboration, loudly but
  misattributed to the document rather than to the pick. The manifest names the right one and
  declares the other explicitly.
- **`~/{{CLIENT}}-cases/<matter>` without the `_corpus-` prefix is STALE**, left by earlier sessions.
  `run_bill_reader.sh` and `run_source_reader.sh` read those folders and fail assertions against
  the drift — **pre-existing, verified against pre-session code 2026-09-03**. Confirm before you go
  chasing it as a regression from your own change.
- **A peer session may write into `~/{{CLIENT}}-cases/` mid-session.** Check mtimes before trusting a
  count, and enumerate by content, never by a `bill-*.txt` glob.
- **`.alt.txt` is a WITNESS, never a document.** `extract_sources` writes a second-scale pass for
  every scanned file. Anything enumerating `sources/` must exclude it or it reads the same document
  twice.

## What no code change reaches

- **Sheet grain ≠ lien grain.** Two matters' liens name individual physicians while their sheets
  name clinics. Neither sheet's notes name a physician — measured — so the note route that solved
  the anchor matter cannot fire. Reconciling the two is the settlement team's judgment call and the
  tool may never infer it.
- **One matter's ambulance bill defeats both bind routes**, each for a recorded reason: OCR merged
  the address and the company onto one line so the digit-free candidate rule never proposes the
  name, and its account number is hyphenated where the identifier rule is digits-only on purpose.
- **Twelve of one matter's fourteen providers have no figure anywhere** — ProLaw states none and no
  bill was sent. Blank is correct. The firm's own sheet has figures, and it must NOT be used: the
  answer key is not an input to the build, and that separation is what makes the comparison mean
  anything.

## After a code change

```bash
bash tests/run-tests.sh          # synthetic; MIN_ASSERTIONS must move with any new assertion
bash tests/run-mutations.sh      # BASELINE_PASS must equal the suite's count or it FATALs
bash tests/run_intake.sh         # the intake gate, against a synthetic corpus and the real one
bash tests/run_demo.sh           # the demo acceptance driver
bash tests/run_bill_reader.sh    # the three real-data reader drivers -- a pin in one of these
bash tests/run_source_reader.sh  #   outlives the code by a day if they are skipped (measured
bash tests/run_prolaw_reader.sh  #   2026-09-04: four stale reds from the previous evening)
python3 tests/run_corpus.py      # then this
```

⚠ If you raise `MIN_ASSERTIONS`, raise `BASELINE_PASS` in `run-mutations.sh` in the same edit. A
mutation run whose baseline is stale reports **every** mutation as caught, for the wrong reason —
an unfalsifiable green. Kill and re-run rather than reading it.
