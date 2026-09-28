---
name: voice-profile-test
description: >
  Test how accurately a voice profile lets a writer predict what a real person would say or write,
  on an occasion the profile never saw. Blind, held-out, multi-run, two-judge. Use when a request
  says "test this voice profile", "which profile is better", "does this profile work", "compare
  our profile with theirs", "score the voice profile", "held-out test", or before any voice profile
  is trusted, shipped, merged with another, or replaced. Works for any person and any profile
  format, spoken or written. The method is three prompts (extract, predict, judge) that run by
  copy-paste in Copilot, Quick or any chat. It carries the freeze-first rule, blind one-set-per-chat
  judging, the quote-or-it-doesn't-count rule, the two-judges-agree rule and the run-range tie rule.
  Optional rig scripts fill the prompts and add up the table for repeated validation runs.
---

# Voice profile test

A voice profile is a claim: *"a writer holding this document can sound and think like this
person."* This skill tests the claim the only honest way: take something the person actually said
or wrote, hide it, ask writers to predict it from the profile alone, and have blind judges score the
predictions against the real thing.

**The method is the prompts.** `references/prompts.md` is written to be pasted into Copilot, Quick,
Claude or any chat, with copy-paste, new chats and a small table filled in by hand. That is the
deliverable. Nothing in it needs Python, a repo or subagents, and every step has to stay that way.

**The scripts are a rig for us, not the product.** `scripts/build_briefs.py`,
`scripts/build_packets.py` and `scripts/score.py` fill the same prompts and add up the same table.
They make repeated runs cheap while we validate the method. A change that only works through the
scripts is not a change to the method. Port it into the prompts, or drop it.

## The rules that make the result trustworthy

Each one exists because the test gave a wrong answer without it.

1. **Hold out an occasion the profile never saw.** If the profile, or anything it was built from,
   contains the held-out material, the test measures recall rather than prediction. Grep every
   profile for a distinctive phrase from the held-out and record the result.
2. **Freeze first.** Extract the questions and seal the real answers **before** building or editing
   any profile under test. A separate agent (or person) does the extraction. The orchestrator reads
   the questions only, and never the sealed answers until scoring is done.
3. **Match the held-out to the use.** A spoken held-out (interview, podcast, talk) tests spoken
   prediction. A written held-out (posts, bylines) tests written prediction. A profile built for
   one can pass or fail the other for reasons that say nothing about its quality. State which you
   ran.
4. **Several runs per profile.** One prediction run is noise. Run at least three per profile, each a
   fresh writer with the identical brief. **A difference that stays inside the run-to-run range is a
   tie.**
5. **Blind by construction.** Each judge chat sees **one set of predictions**: one profile, one run.
   It is never told which profile wrote them. There is nothing to randomise or decode, so a
   marketer can run it by hand. (The first runs used blind pairwise packets with X and Y
   randomised per question. That needs tooling, so it was replaced on 2026-09-28. Whether
   single-set judging discriminates as well is being measured.)
6. **A score without a quote does not count.** The judge quotes the real answer for every score,
   including a 0. Measured: a judge that skipped quotes on 20 of 32 lines scored one profile 13
   against 2. The same packet under a quoting judge scored it 10 against 11.
7. **Two judges from different models.** Trust only the items where they agree within 1 point, and
   **list** the disagreements rather than averaging them away. Different models differ in leniency.
   One judge was about 6 points more generous than the other, yet the two ranked the profiles the
   same, so rank matters more than level.
8. **Record by set.** Log each judge's THINKING and SOUND per set in the table at the end of the
   prompts, then take the mean and range per profile.

## Procedure

**Work folder.** Client material stays out of git. Use a gitignored folder with this layout. The
scripts expect it:

```
<work>/heldout/source.*          the held-out transcript or written pieces
<work>/heldout/questions.md      SETTING: …  / optional LENGTH: …  / Q1–Q4   (from Prompt 1)
<work>/heldout/SEALED-answers.md A1–A4                                       (from Prompt 1)
<work>/profiles/<name>.md        one file per profile under test
<work>/briefs/<name>.txt         built by build_briefs.py
<work>/predictions/<name>-r<N>.md  one file per profile per run, Q1–Q4
<work>/packets/PNN.txt           built by build_packets.py
<work>/KEY-do-not-open/key.json  built by build_packets.py
<work>/judges/<judge>/PNN.md     one file per judge per packet
```

1. **Choose the held-out.** Pick an occasion of the right kind (rule 3), ideally recent, and one the
   profiles did not use.
   - **Spoken:** get a verbatim transcript. In Microsoft 365, the Teams or Stream caption export
     (`-en-US.docx`) is one. Outside it, use a good speech-to-text model: a fast one garbles enough
     words to move scores.
   - **Written:** collect the pieces verbatim, with URLs and dates.
2. **Extract** with Prompt 1A (spoken) or 1B (written), in a fresh agent or chat. Four items. The
   extractor writes `questions.md` and `SEALED-answers.md` and never quotes the answers back.
3. **Put the profiles in `profiles/`** unchanged. If you are testing a merge, build it now, after
   the freeze, and tag every imported block with its source.
4. **Build the briefs:**
   `python3 scripts/build_briefs.py <work> --person "Name"`. This fills Prompt 2 with the setting and
   length from `questions.md`.
5. **Predict:** for each profile, run N ≥ 3 fresh writers on its brief. Each reads the brief only
   and writes `predictions/<name>-r<N>.md`.
6. **Build the packets:** `python3 scripts/build_packets.py <work> --person "Name" --runs 3`. This
   gives one Prompt 3 per profile per run. Packet numbers are shuffled, and the key is kept apart.
7. **Judge:** each packet goes to a fresh judge chat, for each of two judges from different models.
   Save each reply as `judges/<judge>/PNN.md`, with the score table as markdown:
   `| question | conclusion | route | evidence | sound |`. A chat UI's copy button may flatten
   tables, so rebuild them from the page.
8. **Score:** `python3 scripts/score.py <work>`. It reports:
   - per judge, per profile: thinking and sound per run, with mean and range;
   - the agreed items, and every disagreement;
   - for each packet: rows parsed, quotes counted, and whether the judge's own totals match its
     table.
9. **Report numbers with bounds.** State the kind of held-out, the setting, the profile lengths
   (a longer profile is a confound), any topic overlap between the profiles' sources and the
   held-out, whether predictions and a judge share a model, the sample size, and the leak check.
   A result file with no bounds is not a result.

## Reading the result

- **Thinking** is conclusion + route + evidence, out of 6 per question. **Sound** is out of 2.
- **Within-judge ranges that don't overlap** show a difference for that judge. Report it as real
  only when both judges show it, or the agreed items do.
- **A low score can be a talking point rather than a voice gap.** If every profile missed the same
  conclusion, check whether the answer was that season's messaging.
- **A profile of rules** (bans, framing rules, audience modes) with no evidence of how the person
  actually talks tends to score low on sound and can push writers to invent specifics. Look for
  invented names or numbers in its predictions.

## Known results

- **2026-09-28, spoken held-out, 3 profiles × 3 runs, Claude and Copilot judges.**
  - A profile built from recordings, and the same profile merged with a communications team's
    rules, tied on every measure.
  - The rules-only profile scored lower on thinking under both judges. On sound, the judges agreed
    on every item: 0.48 against 1.48 out of 2.
  - The two judges ranked the profiles identically. Copilot was more lenient: it scored higher on
    27 of the 31 items where the judges disagreed.
- **2026-09-28, written held-out (4 LinkedIn posts), same 3 profiles, single-set judging.**
  - A three-way tie, but in the opposite direction: the rules-only profile led on the Claude judge.
  - The merged profile tied the best profile in both tests, so it is the only one that is never
    behind.
  - Copilot scored near the maximum (21–24 of 24), so it barely separated the profiles.
  - **Copilot's own totals disagreed with its own table in 6 of 9 packets.** Never let the judge
    add up. The person adds the table.
