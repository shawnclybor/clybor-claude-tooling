---
name: adversarial-re-read
description: >
  First-pass extraction systematically misses 15–25% of extractable content because LLMs satisfice; this skill is the gate that catches those misses before they ship to a client-facing deliverable. It's a mandatory second-pass adversarial re-read of source material against the synthesis or extraction it produced. Use whenever a workflow extracts content, consumes transcripts, reviews attachments, or fetches documents and that extraction feeds a downstream deliverable. User says: "second pass," "re-read the source," "verify extraction," "what did I miss in the source," "did I capture everything," "diff my extract against the original."
---
 
## Why this exists
 
First-pass extraction systematically misses 15–25% of extractable content. Three failure modes compound:
 
1. **Truncation by default** — `head 200`, `pdftotext file.pdf | head`, and "summarize this" prompts to subagents silently lose content past the window. The reader doesn't see what they didn't read.
2. **Synthesis pressure** — once you have ~80% of the headline points, the pull toward writing the deliverable is stronger than the pull toward exhausting the source. "I have enough to synthesize" feels like done-ness; it's satisficing.
3. **Table-and-image blindness** — text PDFs get attention; structured comparison tables and images get a quick glance. The cells you skim past are often where the implications hide.
When extraction feeds a client-facing deliverable, the missed 15–25% can include items that change the deliverable shape — a hard requirement you didn't notice, a risk that becomes a new pre-flight task, a constraint that narrows the scope, a piece of context that changes the pricing posture.
 
The mandatory second pass forces the misses to surface before they ship.
 
## When to invoke
 
Triggered by:
 
- A calling skill's pre-flight checklist line: "Run `adversarial-re-read` after Phase 1 curation — do not skip."
- Self-trigger: any time you've just produced a synthesis or extraction that will feed a client-facing deliverable, before presenting the synthesis as final.
## When NOT to invoke
 
- Single-source quick-lookup tasks ("what does this email say")
- Routine retrieval ("summarize this calendar event")
- Content Claude generated itself with no external source to re-read against
- Trivial Q&A or formatting fixes
## The procedure
 
Five steps. None skippable.
 
### 1. Bound the source explicitly
 
Before reading anything, count the source in full:
 
```bash
wc -l <source-file>           # for text/PDF (after pdftotext)
file <image>                  # confirm dimensions for images
```
 
State the count out loud in your reasoning. If the source is multi-file, list every file with its line count or size. The point: future-you cannot claim "I read the whole thing" without having seen the bound.
 
### 2. Read the FULL source — no truncation
 
For text: read every line. No `head`, no `| head -200`, no agent prompts that say "summarize." If the source is too large for one read window, slice it in spans and confirm you covered 100% of the line count from step 1. For PDFs: `pdftotext -layout file.pdf - | wc -l` first, then read every line from line 1 to N.
 
For images: re-view at full resolution, not a thumbnail. For tables, read every cell — every row × every column.
 
For multi-source web ingest: read every page that was fetched, not the search snippets that surfaced them.
 
### 3. Diff the synthesis against the source
 
Open your existing synthesis next to the source. For each section of the source (paragraph, bullet, table row, image cell), ask: **does my synthesis reflect what this says, or did I skim past it?**
 
This is the adversarial step. The mindset is: "I'm trying to find what I missed, not confirm what I got." If everything reflects, the synthesis is solid. If items are missing, list them.
 
### 4. Categorize each missed item
 
For every item the diff surfaces:
 
- **Synthesis addition** — a finding that just needs to land in the existing doc. Add it.
- **Deliverable-shape change** — something that changes how the downstream deliverable should be structured (new section, removed section, reframed section). Flag explicitly to the user before continuing.
- **New task** — something that becomes a pre-flight or pre-deliverable item the calling workflow needs to track. Create the task; don't just note it.
- **Risk** — something that could collapse the engagement scope if missed. Flag urgently to the user.
### 5. Document the second-pass result
 
Before declaring extraction complete, state:
 
- What the source bound was (line count, image dims, page count)
- What the diff produced (Nothing missed / N items found, categorized)
- Whether any items required deliverable-shape changes or new tasks (and which)
This is short — 3–5 lines in the working doc or chat. Its purpose is leaving a trace so future-you (or a fresh session) can tell the second pass actually happened, vs. was claimed.
 
## The output
 
Concrete: an updated synthesis, plus (when applicable) new tasks, deliverable-shape flags, and a 3–5 line second-pass note in the working doc.
 
If the second pass surfaces zero misses, that's a valid outcome. State it explicitly: "Second pass: read all 437 lines + image at full res; nothing missed." Don't skip the documentation.
 
## Why this works
 
1. **Explicit comparison forces close reading.** Diffing synthesis-vs-source forces every cell, every row, every paragraph to be acknowledged. First-pass reading lets the eye skip.
2. **Forces full-source consumption.** "Did I read every line?" is binary. Synthesis-driven reading is continuous and hard to bound.
3. **Decouples extraction from synthesis.** First pass mixes both — read a paragraph, decide if it's important, maybe note it. Second pass separates them — re-read as data, not as input to synthesis.
4. **Catches truncation defaults.** `wc -l` first, then read all of them, surfaces silent truncation that head/limit-style reads hide.
 