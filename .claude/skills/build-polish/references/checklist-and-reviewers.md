<!-- build-polish reference: gated checklist, triage, done, reviewers (moved verbatim from SKILL.md) -->
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

