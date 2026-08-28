---
name: session-output
description: Generate a session output — a report of what a working session actually did — in one of two modes. Default mode emits a polished self-contained HTML dashboard (light and dark, validated palette) for a technical decision-maker, a client, or your own record. Plain-language mode, invoked as "/session-output simplify" or by asking for plain English, no jargon, or a readable recap, emits prose instead — what was asked for, what the session did, where things stand now, what is still open, and the recommended next step, in complete sentences that name every subject and referent. Use when the user says "session output", "session report", "summarize this session", "recap what you did", "simplify the output", "explain that in plain English", or "no jargon". Both modes report MEASURED outcomes only, never invented, list the skills and tools used, and run the file-hygiene gate over every file the session touched.
---

# Session Output

Turn a working session into something an outsider can read in 90 seconds. It answers, in order:
**what was the issue → what did we do → what shipped → is it verified → what is still open.**

This skill *reports* a session; it does not do new work. All content comes from the session's own
history. Do not research, do not re-run the work, and **do not invent numbers or outcomes.**

## Hard rules (both modes)

1. **Lead with the real issue in plain terms.** Name what the session was actually about in language
   a non-specialist understands. No tool names in the headline.
2. **No invention.** Every number, status, and claim traces to something that actually happened. If
   you did not measure it, do not print it.
3. **Skills and tools used is a required section.**
4. **Explicit status per work item** — Shipped, Pushed, Skipped (decision), or Pending.
5. **Critical loose threads only.** Include one only if it changes what someone must do next. If
   nothing is critical, say so.
6. **Run the file-hygiene gate** (`scripts/session_file_check.py`) over every file the session
   created or edited before claiming anything is clean. Never assert clean files you did not check.

## Gathering content

Build the report from the session transcript, not from memory of roughly what happened. The issue is
the user's first ask or the error that started the work. Outcomes are figures you actually produced.
Delivered items are concrete changes with their real status. Verification is every check you ran and
its result. Loose threads are only the open items needing a human decision.

## Default mode — the HTML dashboard

Fill `assets/template.html` in this order: header (eyebrow, title, one-line lede, meta chips);
outcomes at a glance (3–4 stat tiles, measured numbers only — drop any tile with no real number);
what happened and why it mattered (two cards: the trigger, and the stakes); skills and tools used;
what was delivered (table of item, status, one-line outcome); an optional before/after visual only if
the session moved a countable thing; how we know it is safe (verification evidence); loose threads
(critical only); footer with the method flow.

Keep the CSS and component classes from `assets/template.html` verbatim — the palette is validated
for light/dark and colorblind-safety. Replace only the content. Keep the print button and the
`@media print` block; never swap in a CDN PDF library, which breaks self-containment.

Emit one self-contained HTML file: inline all CSS, no external assets, light and dark via
`prefers-color-scheme`.

## Plain-language mode

Invoked as `/session-output simplify`, or when the user asks for plain English, no jargon, a readable
recap, or a translation of a dashboard. Everything above still governs *what is true*; this mode
changes *how it is said*.

**Output is prose, not a view.** Forcing prose through the dashboard template puts a rendering step
between the reader and the sentences, which is the opposite of the point.

### The five sections

1. **What you asked for** — the original request in one or two sentences, in the user's own words
   where possible.
2. **What the session did** — chronological, plain sentences, each saying what was done and why.
3. **Where things stand now** — the state of every file, record, or system touched; explicit about
   what changed and what did not.
4. **What is still open** — one sentence per item naming the thing, why it is unresolved, and who
   moves next.
5. **What I would do next** — one recommended path with its reason. Alternatives only when the call
   is genuinely close.

### Writing rules — the substance of this mode

- **Every sentence has a named subject.** Not "Fixed the routing bug" but "The session fixed the
  routing bug in the governance hook."
- **No pronoun without a nearby antecedent.** Not "it broke again" but "the sync broke again."
- **No shorthand assuming prior context.** "The v2 issue", "the usual trap", "same as last time" are
  banned. Name the thing.
- **Jargon carries a gloss on first use**, in the same sentence, or it does not appear.
- **No headline fragments standing in for sentences.**
- **No invented outcomes** — same rule as default mode.

Apply `writing-quality`'s banned-pattern list by reference rather than restating it; two copies drift.

### Empty-session guard

If the session produced no files, no records, and no measured outcome, say exactly that in one
sentence and stop. A recap of nothing is worse than no recap, because it reads like substance.

### Recapping something the session did not do

This mode accepts the current session's history (default), a prior session-output artifact, or pasted
text. For the latter two, open with one line naming the source and stating that the content is
summarized from material this session did not produce.

### Before writing any recap to disk

Plain-language mode may be asked to save its prose. A saved recap is the one output here that puts
prose on disk durably, and pasted or cross-session input can carry sensitive material. Before
writing, scan the draft for names of individuals outside the project, client-identifying references,
medical or legal detail about third parties, credentials, tokens, account numbers, and third-party
contact details.

If anything matches, **do not write the file.** Deliver the prose in chat, say which category
triggered the hold, and ask whether to redact and save. Chat output is ephemeral; the file is not.

When a recap is saved, create it exclusively (fail on collision rather than testing for the file and
then writing — two concurrent sessions can both pass a check-then-write test and one will silently
lose). Prune saved recaps on a schedule; a recap is a convenience copy of a conversation, and anything
that deserves to persist belongs in the knowledge store via `insight-crystallizer`.

## File-hygiene gate

Assemble the list of every file the session created or edited, then run:

```bash
python3 scripts/session_file_check.py <file1> <file2> ... [--git <repo_dir>] [--json]
```

It lints by type using stdlib only — Python byte-compile, JSON parse, `bash -n`, HTML parse, and
markdown frontmatter plus a SKILL.md description length check. `--git` appends `git status --porcelain`
so touched files are visible. Exit 0 means all clean. Run it where the files live, and reflect the true
result in the verification section. If a file fails, fix it or list it as a loose thread — never label
a failing file clean.
