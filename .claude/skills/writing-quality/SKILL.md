---
name: writing-quality
description: >
  Audit and rewrite content to remove AI writing patterns ("AI-isms") from deliverables,
  emails, and any written output. Use this skill whenever generating deliverable content
  (Phase 1 curation in any client deliverable skill), drafting client emails longer than
  3 sentences, writing proposals or SOWs, creating reports, or when the user says "clean
  up the writing", "remove AI-isms", "make this sound less like AI", "audit the writing",
  "check for AI patterns", or "writing quality check". Also invoke automatically before
  any deliverable formatting step — do not skip. If you just wrote or curated content
  that will go to a client, run this skill on it before finalizing. Adapted from
  conorbronsdon/avoid-ai-writing v3.3.0 (MIT license).
---

# Writing Quality — AI-ism Audit & Rewrite

You are editing content to remove AI writing patterns ("AI-isms") that make text sound
machine-generated. This matters because client-facing deliverables can't afford AI-scented prose. AI-isms undermine the expert authority a paid deliverable is supposed to convey.

## Modes

**`rewrite`** (default) — Flag AI-isms and rewrite the text to fix them. Use this during
deliverable curation (Phase 1) and email drafting.

**`detect`** — Flag AI-isms only, no rewriting. Use when auditing existing content, when
patterns might be intentional, or for a quick check before sending.
Trigger detect mode when the user says "detect," "flag only," "audit only," "just flag,"
"scan," or similar. Default to rewrite mode otherwise.

---

## In rewrite mode:
1. Audit and identify every AI-ism, citing specific text
2. Rewrite to remove all AI-isms
3. Return the cleaned text with a brief summary of major changes
4. If the user corrects the result, log it: `bash scripts/log-correction.sh "<pattern-slug>" "<project>"` — a REPEAT alert (exit 2) means propose the source-level fix (voice guide, template, this skill's rules), not another draft fix

## In detect mode:
1. Audit and identify every AI-ism, citing specific text
2. Group by severity (P0, P1, P2)
3. Note which flags are clear problems vs. judgment calls

---

## Context Profiles

Auto-detect from content cues. The user can override.

**`deliverable`** (default for anything going to a client) — Strictest. All rules at full
strength. Consulting deliverables can't afford any AI smell. Clients pay for expert
analysis, not generated filler.

**`email`** — Client correspondence. Strict on P0 and P1, relaxed on P2 structural issues
(short emails don't need paragraph variation). Hedging rules relaxed slightly — "perhaps"
is sometimes appropriate in diplomatic emails.

**`technical-blog`** — Long-form with code, architecture, APIs. Technical terms get a pass:
`robust`, `comprehensive`, `seamless`, `ecosystem`, `leverage` (when describing actual
platform APIs), `facilitate`, `underpin`, `streamline` are allowed. Still flag: `delve`,
`tapestry`, `beacon`, `embark`, `testament to`, `game-changer`, `harness`.
**`blog`** — Standard long-form prose (proposals, SOWs, reports not tied to a specific
client deliverable). All rules apply at full strength.

### Auto-detection cues

| Signal | Inferred profile |
|--------|-----------------|
| Content being curated for a deliverable skill | `deliverable` |
| Email draft (salutation, sign-off) | `email` |
| Code blocks, API references, architecture | `technical-blog` |
| No strong signals | `blog` (safest default) |

---

## What to Remove or Fix

### Formatting

**Em dashes (— and --):** Replace with commas, periods, parentheses, or rewrite as
separate sentences. Target: zero per piece. Hard max: one per 1,000 words. Catch both
Unicode em dashes (—) and double-hyphen substitutes (--).

**Bold overuse:** Strip bold from most phrases. One bolded phrase per major section max,
or none. If something's important enough to bold, restructure the sentence to lead with
it instead.

**Excessive bullet lists:** Convert bullet-heavy sections into prose paragraphs. Bullets
only for genuinely list-like content (feature comparisons, step-by-step instructions,
data parameters).
### Sentence Structure

**"It's not X — it's Y" constructions:** Rewrite as a direct positive statement. Max one
per piece, only if it genuinely serves the argument.

**Hollow intensifiers:** Cut "genuine," "truly," "quite frankly," "to be honest," "let's
be clear," "it's worth noting that." Just state the fact.

**Vague endorsement ("worth [verb]ing"):** Cut "worth reading," "worth exploring," etc.
Say *why* something matters instead.

**Hedging:** Cut "perhaps," "could potentially," "it's important to note that." Make the
point directly. (Exception: `email` profile allows diplomatic hedging.)

**Missing bridge sentences:** Each paragraph should connect to the previous one. If
paragraphs could be rearranged without the reader noticing, add connective tissue.

**Compulsive rule of three:** Vary groupings. Use two items, four items, or a full sentence
instead of triads. Max one "adjective, adjective, and adjective" pattern per piece.

### Words and Phrases to Replace

Three tiers based on how reliably they signal AI-generated text.

- **Tier 1 — Always flag.** These appear 5-20x more often in AI text than human text.
- **Tier 2 — Flag in clusters.** Fine alone, but 2+ in the same paragraph is a strong signal.
- **Tier 3 — Flag by density.** Common words AI overuses. Only flag at ~3%+ of total words.
#### Tier 1 — Always replace

| Replace | With |
|---------|------|
| delve / delve into | explore, dig into, look at |
| landscape (metaphor) | field, space, industry |
| tapestry | (describe the actual complexity) |
| realm | area, field, domain |
| paradigm | model, approach, framework |
| embark | start, begin |
| beacon | (rewrite entirely) |
| testament to | shows, proves, demonstrates |
| robust | strong, reliable, solid |
| comprehensive | thorough, complete, full |
| cutting-edge | latest, newest, advanced |
| leverage (verb) | use |
| pivotal | important, key, critical |
| underscores | highlights, shows |
| meticulous / meticulously | careful, detailed, precise |
| seamless / seamlessly | smooth, easy, without friction |
| game-changer / game-changing | describe what specifically changed and why |
| utilize | use |
| watershed moment | turning point, shift |
| the future looks bright | (cut — say something specific or nothing) |
| only time will tell | (cut — say something specific or nothing) |
| nestled | is located, sits |
| vibrant | (describe what makes it active, or cut) |
| showcasing | showing, demonstrating (or cut) |
| deep dive / dive into | look at, examine, explore |
| unpack / unpacking | explain, break down, walk through |
| intricate / intricacies | complex, detailed (or name the specific complexity) |
| holistic / holistically | complete, full, whole |
| actionable | practical, useful, concrete || impactful | effective, significant (or describe the impact) |
| learnings | lessons, findings, takeaways |
| thought leader / thought leadership | expert, authority (or describe their contribution) |
| best practices | what works, proven methods, standard approach |
| at its core | (cut — just state the thing) |
| synergy / synergies | (describe the actual combined effect) |
| interplay | relationship, connection, interaction |
| in order to | to |
| due to the fact that | because |
| serves as | is |
| features (verb) | has, includes |
| boasts | has |
| commence | start, begin |
| endeavor | effort, attempt, try |
| embrace (metaphor) | adopt, accept, use, switch to |

#### Tier 2 — Flag when 2+ appear in the same paragraph

| Replace | With |
|---------|------|
| harness | use, take advantage of |
| navigate / navigating | work through, handle, deal with |
| foster | encourage, support, build |
| elevate | improve, raise, strengthen |
| unleash | release, enable, unlock |
| streamline | simplify, speed up |
| empower | enable, let, allow |
| bolster | support, strengthen |
| spearhead | lead, drive, run |
| resonate / resonates with | connect with, appeal to, matter to || revolutionize | change, transform, reshape |
| facilitate / facilitates | enable, help, allow, run |
| nuanced | specific, subtle, detailed (or name the actual nuance) |
| crucial | important, key, necessary |
| multifaceted | (describe the actual facets, or cut) |
| ecosystem (metaphor) | system, community, network, market |
| myriad / plethora | many, numerous (or give a number) |
| catalyze | start, trigger, accelerate |
| reimagine | rethink, redesign, rebuild |
| cultivate | build, develop, grow |
| illuminate / elucidate | explain, clarify, show |
| paradigm-shifting | (describe what actually shifted) |
| transformative / transformation | (describe what changed and how) |
| cornerstone | foundation, basis, key part |
| paramount | most important, top priority |
| poised (to) | ready, set, about to |
| overarching | main, central, broad |

#### Tier 3 — Flag only at high density

| Word | What to do |
|------|-----------|
| significant / significantly | Replace some with specifics: numbers, comparisons |
| innovative / innovation | Describe what's actually new |
| effective / effectively | Say how or cite a metric |
| dynamic / dynamics | Name the actual forces or changes |
| scalable / scalability | Describe what scales and to what |
| compelling | Say why it compels |
| unprecedented | Name the precedent it breaks (or cut) |
| exceptional / remarkably | Cite what makes it an exception |
| sophisticated | Describe the sophistication |
| instrumental | Say what role it played |
### Template Phrases (avoid)

Slot-fill constructions that signal generated text. If a phrase has a blank where any noun
could go and still sound the same, it's too generic:

- "a [adjective] step towards [adjective] infrastructure" → describe the specific outcome
- "Whether you're [X] or [Y]" → pick the actual audience or cut
- "I recently had the pleasure of [verb]-ing" → just say what happened

### Transition Phrases to Remove or Rewrite

- "Moreover" / "Furthermore" / "Additionally" → restructure, or use "and," "also"
- "In today's [X]" / "In an era where" → cut or state specific context
- "It's worth noting that" / "Notably" → just state the fact
- "Here's what's interesting" / "Here's what caught my eye" → let content signal importance
- "In conclusion" / "In summary" → your conclusion should be obvious
- "When it comes to" → just talk about the thing
- "At the end of the day" → cut
- "That said" / "That being said" → cut or use "but" / "however" sparingly

### Structural Issues

**Uniform paragraph length:** Vary deliberately. Include 1-2 sentence paragraphs and
longer ones. If every paragraph is roughly the same size, fix it.

**Formulaic openings:** If the piece opens with broad context before the point ("In the
rapidly evolving world of..."), lead with the insight. Context can come second.

**Suspiciously clean grammar:** Don't sand away all personality. Deliberate fragments,
sentences starting with "And" or "But," comma splices for effect — keep them if the
natural voice uses them.
### Pattern Categories (condensed — flag all of these)

**Significance inflation:** "marking a pivotal moment in the evolution of..." — state what
happened, let the reader judge. If the sentence works after deleting the inflation, delete it.

**Copula avoidance:** AI avoids "is" and "has" by substituting "serves as," "features,"
"boasts," "presents," "represents." Default to "is" or "has" unless a specific verb adds meaning.

**Synonym cycling:** AI rotates synonyms to avoid repetition: "developers... engineers...
practitioners... builders" in the same paragraph. Human writers repeat the clearest word.

**Vague attributions:** "Experts believe," "Studies show" — without naming the source.
Either cite specifically or drop the attribution.

**Filler phrases:** "It is important to note that," "In terms of," "The reality is that" — cut.

**Generic conclusions:** "The future looks bright," "One thing is certain" — cut or make specific.

**Chatbot artifacts:** "I hope this helps!", "Certainly!", "Great question!", "Feel free to
reach out" — remove entirely. Also: "In this article, we will explore..." and "Let's dive in!"

**"Let's" constructions:** "Let's explore," "Let's break this down" — false-collaborative
openers that delay the point. Just start with the point.

**Superficial -ing analyses:** Strings of present participles as pseudo-analysis: "symbolizing
the commitment, reflecting decades of investment, and showcasing a new era" — cut or replace
with specific facts.

**Promotional language:** Tourism-brochure prose: "a vibrant hub of innovation," "a thriving
ecosystem." Replace with plain description.

**False ranges:** "from ancient civilizations to modern startups" — sounds sweeping, says
nothing. List the actual topics or pick the one that matters.
**Cutoff disclaimers:** "As of my last update," "While specific details are limited" —
model limitations leaking into prose. Find the information or remove the hedge entirely.

**Novelty inflation:** Treating established concepts as discoveries: "He introduced a term,"
"a concept nobody's naming." Describe what the person *did with* the concept, not that they
discovered it.

**Emotional flatline:** Claiming emotions without conveying them: "What surprised me most,"
"I was fascinated to discover." If the thing is surprising, the reader should feel that
from the content, not from the writer announcing it.

**False concession structure:** "While X is impressive, Y remains a challenge" — sounds
balanced without weighing anything. Make the concession specific or pick a side.

**Rhetorical question openers:** "But what does this mean for developers?" — if you know
the answer, just say it.

**Sycophantic tone / Acknowledgment loops:** "Great question!", "You're asking about..." —
remove entirely.

**Reasoning chain artifacts:** "Let me think step by step," "Breaking this down" — internal
scaffolding that doesn't belong in published prose.

### Rhythm and Uniformity

Structure is the #1 AI detection signal. Consistent sentence construction, uniform pacing,
and symmetrical phrasing are harder to mask than swapping flagged words.

- **Sentence length:** Mix short punchy sentences (3-8 words) with longer ones (20+).
  Fragments work. Questions break monotony.
- **Paragraph length:** Some should be one sentence. Some longer. No metronomic uniformity.
- **Read-aloud test:** If it sounds like text-to-speech, it's too uniform.
- **Missing first-person:** Where appropriate, the writer should have opinions and
  preferences. AI is relentlessly neutral.
- **Over-polishing:** Don't sand away all personality. Natural disfluency and idiosyncratic
  word choices keep text human.
### When to Rewrite from Scratch vs. Patch

If the text has 5+ flagged vocabulary hits across multiple categories, 3+ distinct pattern
categories triggered, and uniform sentence/paragraph length — patching won't fix it. The
structure itself is AI-generated. State the core point in one sentence, then rebuild.

---

## Severity Tiers

### P0 — Credibility killers (fix immediately)
- Cutoff disclaimers ("As of my last update")
- Chatbot artifacts ("I hope this helps!", "Great question!")
- Vague attributions without sources ("Experts believe")
- Significance inflation on routine events
- Reasoning chain artifacts leaking into prose

### P1 — Obvious AI smell (fix before publishing)
- Word-list violations (delve, leverage, harness, robust, etc.)
- Template phrases and slot-fill constructions
- "Let's" transition openers
- Synonym cycling within a paragraph
- Formulaic openings ("In the rapidly evolving world of...")
- Bold overuse and em dash frequency (above 1 per 1,000 words)
- Sycophantic tone and acknowledgment loops

### P2 — Stylistic polish (fix when time allows)
- Generic conclusions ("The future looks bright")
- Compulsive rule of three
- Uniform paragraph length
- Copula avoidance (serves as, features, boasts)
- Transition phrases (Moreover, Furthermore, Additionally)

Use P0+P1 for quick passes. Full audit covers all three tiers.
Deliverable profile always does a full audit.
---

## Self-Reference Escape Hatch

When writing *about* AI writing patterns (documentation, skill files, this file), quoted
examples are exempt from flagging. Text inside quotation marks, code blocks, or explicitly
marked as illustrative should not be rewritten.

---

## Output Format

### Rewrite mode (default)

Return your response in two sections:

**1. Cleaned text**
The full rewritten content. Preserve the original structure, intent, and all specific
technical details. Only change what the guidelines require.

**2. What changed**
A brief summary of the major edits. Not every word — just the meaningful changes grouped
by category (e.g., "Replaced 4 Tier 1 words, restructured 2 paragraphs for varied length,
cut 3 filler transitions"). This lets the author learn what to avoid next time.

### Detect mode

**1. Issues found**
Bulleted list of every AI-ism identified, with offending text quoted. Grouped by severity.

**2. Assessment**
For each flag, note whether it's a clear problem or a judgment call. If the text is clean,
say so.

---

## Tone Calibration

The goal is writing that sounds like a competent human wrote it. Direct. Specific.
Five principles for human-sounding rewrites:

1. **Vary sentence length** — mix short with long. Fragments are fine.
2. **Be concrete** — replace vague claims with numbers, names, dates, or examples.
3. **Have a voice** — where appropriate, use first person, state preferences, show reactions.
4. **Cut the neutrality** — humans have opinions. If the piece should take a position, take it.
5. **Earn your emphasis** — don't tell the reader something is interesting. Make it interesting.

If the original writing is already strong, say so and make only necessary cuts. Don't
over-edit for the sake of it. The replacement table provides defaults, not mandates — if
a flagged word is clearly the right choice in context, preserve it.

---

## Integration Points

Run this skill automatically in these cases:

1. **Deliverable curation** — Before formatting any client-facing document, run in `rewrite` mode with the `deliverable` profile.
2. **Client email drafting** — When drafting emails longer than 3 sentences to external contacts, run in `rewrite` mode with the `email` profile. Quick internal replies are exempt.
3. **On-demand audit** — When the user says "check this for AI patterns" or similar, run in whichever mode the user requests.

---

*Adapted from [conorbronsdon/avoid-ai-writing](https://github.com/conorbronsdon/avoid-ai-writing) v3.3.0 (MIT license).*
## Agent integration

- **`evidence-auditor`** — invoked when the content under audit cites external sources (URLs, papers, claims attributed to third parties). Confirms each citation traces accurately before the rewritten version ships. Catches the AI-ism category that this skill itself cannot detect: fabricated or misattributed citations.
