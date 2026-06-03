---
name: meeting-workflow
description: Transform meeting transcripts (pasted text, .vtt/.srt/.txt uploads, or your meeting tool's export) into structured records — a summary note with decisions and open questions, plus tracked tasks for every action item. Use whenever the user pastes or uploads a meeting transcript, says "log this meeting", "process this transcript", "here are my meeting notes", "what happened in this call", "meeting summary", or "turn this into notes". Handles extraction and structuring, then writes to the record system your project uses.
---

# Meeting Workflow

Takes a raw meeting transcript and turns it into structured records — a note with a clean
summary, decisions, and context, plus one tracked task per action item.

The workflow has three phases: **Extract**, **Structure & Confirm**, and **Write** (to
{{RECORD_SYSTEM}}). Extraction requires careful reading and judgment about what matters;
the write requires your record system's exact conventions; keeping them separate prevents
each from corrupting the other.

## Input Formats

- **Pasted text** in the conversation
- **Uploaded file** — `.vtt`, `.srt`, or `.txt`
- **A summary from the user** — sometimes the user describes what happened rather than
  providing a verbatim transcript. Extract what you can from whatever is provided.

If the input is `.vtt` or `.srt`, strip timestamp lines to get clean text before
processing. Keep speaker names — they're needed for owner attribution.

**Verbatim beats AI summaries.** If your meeting tool offers both a verbatim transcript
and an AI-generated summary, always extract from the verbatim. Tool summaries routinely
flip attribution ("X offered to do Y" becomes "Y assigned to X") and fabricate causality.
If ONLY a summary is available, label the resulting note `DEGRADED MODE — AI summary
only` and list action items as "summary-derived claims (require user verification)"
instead of filing them as tasks.

## Phase 1: Extract

Read the full transcript carefully. You're looking for six things:

### 1. Summary (2-4 sentences)

What was this meeting about? Who was there? What was the main outcome? Write it the way
you'd brief someone who missed the call — concise, factual, no filler.

### 2. Decisions

Anything where the group agreed on a direction, chose an option, or committed to an
approach. These are often implicit ("ok let's go with option B") rather than formally
announced. If no decisions were made, say so — don't manufacture them.

### 3. Action Items

Each action item needs:
- **What**: clear, actionable description (not "follow up on the thing")
- **Who**: the person responsible. Match speaker names to known contacts where possible;
  if the owner is ambiguous, flag it for the user to clarify.
- **When**: due date if one was mentioned. Many won't have explicit dates — leave the
  date blank rather than guessing.
- **Priority**: infer from context. Blockers and time-sensitive items = High;
  "when you get a chance" = Low; default Medium.

### 3.5 Action Item Decomposition (CRITICAL)

> Named action items in summaries are usually workstream labels, not atomic tasks.

A line like "Deliver the Phase 1 proposal Friday" reads as one action but typically
contains 4-10 distinct sub-tasks. Filing one task per literal bullet captures roughly a
quarter of the actual work. For each action item, run five expansion lenses:

1. **Atomic check** — one action or a workstream? Heuristic: >30 min of focused work, or
   a multi-part deliverable → workstream → expand.
2. **Pre-requisite work** — what design / decision / coordination must happen first?
   Each becomes its own task.
3. **Deliverable decomposition** — if the action produces a bundled deliverable
   (proposal, plan, deck), enumerate the pieces; each is usually its own task.
4. **Conditional follow-on** — what work depends on this action's outcome? Stage as
   conditional tasks (Medium priority, no due date, "Conditional: triggers on X" in the
   description). Cap at ~6 conditionals per workstream — beyond that, file a single
   "scope the follow-up" placeholder.
5. **Coordination** — does executing this require alignment with another stakeholder?
   That's a separate task with a clear owner.

Carry the expanded list into the confirmation step — never present the literal-only list.

### 4. Open Questions

Raised but not resolved. These often become the next meeting's agenda.

### 5. Key Context

Notable quotes, data points, or references with lasting value beyond the meeting itself —
a specific metric, a URL shared, a document referenced. Don't transcribe everything.

### 6. Synthesis Signals

Flag anything that updates, contradicts, or extends what's already known about the
project or client: a decision that reverses a previous one, new information about
priorities or timeline, a technical finding that changes the architecture, a stakeholder
change, a scope change. Many meetings produce none — don't force it. When present,
they're the most valuable part of the meeting because they update the state of the world.

### Second-pass re-read (mandatory)

After decomposition and before confirmation, re-read the FULL source and diff it against
your extraction. First-pass extraction satisfices and misses 15-25% of extractable
content. For every missed item: add it, or flag it if it changes the shape of what you're
about to file.

## Phase 1.5: Structure & Confirm

Before writing anything, present the extracted data to the user:

```
**Meeting**: [inferred title in "Purpose (Attendees)" format]
**Date**: [meeting date if known, otherwise today]
**Project**: [best guess from transcript content]

## Summary
[2-4 sentences]

## Decisions
- [...]

## Action Items (after decomposition — expanded sub-tasks, not literal summary lines)
1. [task] — Owner — Due: [date or TBD] — Priority: [H/M/L]

## Open Questions
- [...]

## Synthesis Signals (if any)
- [...]

**Ready to write? Any corrections?**
```

Common corrections: wrong project mapping, misattributed owners, a missed implicit
decision, priority adjustments. Wait for confirmation before Phase 2.

## Phase 2: Write to {{RECORD_SYSTEM}}

Write one note (summary + attendees + decisions + action-item checklist + open questions
+ key context) and one task per action item to {{TASK_TRACKER}}, following your record
system's conventions — exact field names, relations to the project and contacts,
search-before-create to avoid duplicating an existing prep note for the same meeting.
If a prep note exists, update it rather than creating a duplicate, and say so.

## Phase 3: Compile and Synthesize

Skip entirely if Phase 1 produced no synthesis signals. Otherwise:

- **Supersession**: find the record where a now-reversed decision was logged and add an
  "Updated by [this meeting] on [date]" callout — future sessions must not act on stale
  decisions.
- **Scope/timeline change**: update the project record only if the change is confirmed;
  tentative mentions stay in the meeting note.
- **Cross-reference**: if the meeting continued a prior discussion or resolved a prior
  open question, link both records.
- Report what was updated in 2-3 lines; if nothing matched, skip the report.

## Edge Cases

- **Multiple unrelated projects in one meeting** → one note per project; flag during
  confirmation.
- **No action items** → fine; note only, no tasks.
- **Messy or partial transcript** → work with what you have; flag unclear attribution in
  the confirmation. A partial note beats no note.
- **Tentative synthesis signal** → include it in the confirmation marked "Tentative —
  confirm before updating project records." Don't update project records on ambiguity.

## Adaptation points

- `{{RECORD_SYSTEM}}` — where notes live (a wiki DB, a docs/ folder, your CRM...)
- `{{TASK_TRACKER}}` — where action items become tracked tasks (often the same system)
