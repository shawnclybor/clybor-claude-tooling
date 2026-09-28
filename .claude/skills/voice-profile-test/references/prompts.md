---
title: "Voice profile test — portable prompts (extract, predict, judge)"
type: prompt
updated: 2026-09-28
---

# Voice profile test — portable prompts

These prompts test whether a voice profile lets someone predict what a person would say or write,
on an occasion the profile never saw. They work in any AI chat (Claude, Copilot, Quick, ChatGPT).
**Run each prompt in a new chat**, so that no step sees another step's material.

**What you need:**
- the profile or profiles you want to test;
- one **held-out** occasion that none of the profiles drew on:
  - **Spoken voice:** a verbatim transcript of an interview or talk. A Teams or Stream caption
    export (`-en-US.docx`) is one.
  - **Written voice:** three to six pieces the person published (posts, bylines).

**Placeholders** to fill before pasting:
- `[PERSON]`: the person's name.
- `[SETTING]`: where the real answers were given, for example "a podcast interview, spoken aloud" or
  "a LinkedIn post under her own name".
- `[LENGTH]`: the word range the real answers span, for example "80 to 150".

---

## Prompt 1A — Pull the questions from a spoken held-out (paste the transcript at the end)

You are preparing a test. Below is a transcript of [PERSON] being interviewed. Read all of it.

Pick 4 moments where [PERSON] is asked something and the answer shows judgment: a position, a
diagnosis, a tradeoff, or a correction of the question. Prefer these over descriptions of a product.
Use only answers that are clearly [PERSON]'s. If a passage's speaker is unclear, do not use it.

Return two sections:

QUESTIONS: Q1 to Q4. Each is the question as asked, lightly shortened, with enough context to
answer it. Give no hint of how [PERSON] answered.

ANSWERS: for each question, [PERSON]'s full answer, word for word as in the transcript. Leave out
everything the interviewer says inside the answer ("right", "sure", a follow-up question): keep
only [PERSON]'s words, and mark each cut with [...].

TRANSCRIPT:
[PASTE THE HELD-OUT TRANSCRIPT HERE]

## Prompt 1B — Pull the assignments from a written held-out (paste the pieces at the end)

You are preparing a test. Below are pieces [PERSON] published under their own name. Read all of
them.

Pick 4 where [PERSON] takes a position, reads data, or makes a call. Prefer these over announcements
and congratulations. Prefer different topics.

Return two sections:

QUESTIONS: Q1 to Q4. Each is the writing assignment a ghostwriter would receive: the occasion or
news hook, and any facts or figures the piece uses. Give **no** hint of [PERSON]'s take, conclusion,
framing, closing line or phrasing.

ANSWERS: for each, the piece word for word.

PIECES:
[PASTE THE HELD-OUT PIECES HERE]

*For both 1A and 1B: copy the QUESTIONS section on its own for Prompt 2. Keep the ANSWERS section
away from the ghostwriter, and do not read it yourself until the judging step.*

---

## Prompt 2 — Predict (for each profile, run three times, each in a new chat)

You are a ghostwriter who has never met [PERSON]. Your only knowledge of [PERSON] is the voice
profile below.

For each question, write what [PERSON] would say or write, in their voice, for [SETTING]:
[LENGTH] words. Reach the conclusion the profile says they would reach, by the route it says they
would take. Use figures and names the question gives. Where they would cite any other number, write
[figure] instead of inventing one, and do not invent names of people, companies or places. Do not
copy runs of six or more words from quotes in the profile.

Return only: `Q1` and the answer, then `Q2`, and so on. No notes, no commentary.

PROFILE:
[PASTE ONE PROFILE HERE]

QUESTIONS:
[PASTE THE QUESTIONS FROM PROMPT 1 HERE]

---

## Prompt 3 — Judge (a new chat for each set of predictions)

Judge **one set of predictions per chat**: one profile, one run. Do not say which profile wrote them.
That keeps the judge blind, with nothing to shuffle or decode afterwards.

You are a judge. Below are questions [PERSON] was actually asked or assignments [PERSON] actually
wrote to, what [PERSON] actually said or wrote, and a predicted answer for each, written by a
ghostwriter who never saw the real answer.

Score each prediction against the real answer, 0 to 2 on each:
- conclusion: does it reach the same position? (2 same, 1 partly, 0 different)
- route: does it get there by the same moves, in roughly the same order?
- evidence: does it reach for the same kind of support (a story, data, a product mechanism, a
  customer experience)?
- sound: would someone who knows [PERSON] take it for them?

For every score, give one line quoting the words in the real answer that justify it, in quotation
marks. **A score with no quote from the real answer does not count.** Every score quotes, including
a 0: for a 0, quote what the real answer did instead. That is 4 quoted lines per question. Judge
substance, not polish or length.

Return:
1. One markdown table, one row per question: `| question | conclusion | route | evidence | sound |`.
2. Under it, the quoted justification lines, grouped by question.

Do not add up the scores. The table is the result.

QUESTIONS:
[PASTE]

WHAT WAS ACTUALLY SAID OR WRITTEN:
[PASTE THE ANSWERS FROM PROMPT 1]

PREDICTIONS:
[PASTE ONE SET: Q1 and its prediction, Q2 and its prediction, and so on]

---

## Scoring, after the judges

**Add up each judge's table yourself**, or paste it into Excel. Do not ask the AI chat for the
totals. Copilot's own totals disagreed with its own table in 6 of 9 test runs. For each set:
- **THINKING** = conclusion + route + evidence, over all questions;
- **SOUND** = sound, over all questions.

**Use two judges from different AI models**, for example Copilot and Quick, and run every set of
predictions past both. Keep a table like this, one row per set:

| Profile | Run | Judge A thinking | Judge A sound | Judge B thinking | Judge B sound |
|---|---|---|---|---|---|

1. For each profile and judge, give the **mean and range** of THINKING (out of 24 for four
   questions) and SOUND (out of 8) over the three runs.
2. **If two profiles' ranges overlap, it is a tie.** Report a difference only when both judges show
   it.
3. Where the two judges' totals for one set differ by more than 3 points, list that set. Do not
   average the disagreement away.

A missed conclusion can be a timely talking point rather than a gap in the profile. If every
profile missed the same answer, check what the person's messaging was that season.
