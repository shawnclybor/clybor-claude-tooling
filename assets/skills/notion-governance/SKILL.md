---
name: notion-governance
description: Governance for reading and writing the Clybor life-CRM Notion workspace from a build repo. Use whenever a request touches Notion — logging a decision, creating or closing a task, reading project or client state, filing a note or KB entry, or invoking any notion-search / notion-fetch / notion-create-pages / notion-update-page tool. Carries the six databases and the overlay that supplies their IDs, the record-type-to-database mapping that says which one a decision, lesson, event, or commitment belongs in, the per-database title conventions, the relation-replace trap that silently destroys multi-value relations, retrieval routing (enumerate vs locate vs comprehend), the trailing-space property names that fail silently when guessed, and the rule that "what is active" is a filtered query and never a semantic search. Triggers — "log this in Notion", "create a task", "update the project", "what's active", "file this", "check Notion", or any request implying a CRM record should change. Cheap to consult; expensive to replace a relation you meant to append to.
---

# Notion Governance

Governance for Notion operations against the Clybor life-CRM workspace from any build repo. Loaded on demand — never auto-loaded.

## Project and Client IDs live in an overlay, never in this file

Every record a repo creates relates to **both** a `Project` and a `Client` — not one of them. The
IDs are per-repo and are **not** stored here. Read them from:

```
.claude/notion-project-ids.md
```

If that file is absent, bootstrap the chain with a NAME, not an ID you remember: `notion-search`
the database by title ("AA Task", "Knowledge Base") to recover its data-source ID, then
`notion-query-data-sources` against Project and Client for this repo's records. Write the overlay
so the next session does not repeat the lookup.

⚠ **IDs in this workspace share long prefixes.** Records created in the same period can match on
their first eight or more hex characters and diverge only afterwards — a Project and its own Client
routinely do. A guessed, half-remembered, or pattern-inferred ID lands on the **wrong record**, and
Notion reports success either way. Copy IDs verbatim from the overlay or from a live lookup. Never
reconstruct one from a pattern, and never assume two similar-looking IDs are the same record.

## The Golden Rule

> After any write, ask: will every related record reflect what just happened? A Notion write that
> updates one page and leaves its parent, its task, or its client record stale is not done — it is
> half-done, and the half that is missing is the half future sessions read.

## The six databases

| Database | Holds |
|---|---|
| Contact | People |
| Note | Meeting records, decisions, findings |
| Project | Engagements |
| AA Task | Actionable work |
| Client | Organisations |
| Knowledge Base | Durable reference |

**Data source IDs are tokens and are not stored in this skill** — this repo is public. They live
in the consuming repo's `.claude/notion-project-ids.md`, alongside that repo's Project and Client
record IDs. Missing overlay → recover each ID by **searching the database name**, then `notion-fetch`
that ID to confirm the schema before writing. Never seed the chain from a remembered ID.

## Which database does this record belong in?

The IDs are useless without this mapping — the common failure is not a wrong ID, it is a
decision filed as a Note when it should have updated a Task, or a reusable lesson buried in a
meeting Note where nothing will ever retrieve it.

| You have… | It goes in | Because |
|---|---|---|
| What happened at a point in time — a meeting, a call, a session, a status update | **Note** | Notes are dated events. They are the raw record; they are not retrieved by topic. |
| A decision made, with its rationale | **Note** (the event) **+ the affected record** (the state) | A decision is both. File the discussion in the Note, then update the Project/Task it actually changes. A decision recorded only in a Note leaves the project page lying. |
| A reusable lesson, pattern, gotcha, or framework — true beyond this project | **Knowledge Base** | KB is retrieved by topic across projects. If a future session on a *different* project would want it, it is KB, not a Note. |
| Something that must be DONE, with an owner and an end state | **AA Task** | Tasks carry status. Anything with "should", "need to", "will follow up" is a Task, not a sentence in a Note. |
| A change to a task's status, owner, or due date | **update the existing AA Task** | Never a new Task and never a Note. A second Task for the same work splits its history. |
| Durable state about the engagement — scope, phase, health, links | **Project** | Project is the answer to "where do things stand". |
| Durable state about the relationship — the org, terms, commercial context | **Client** | |
| A person — role, org, email, how they relate | **Contact** | |

**The two tests that resolve most ambiguity:**

1. *Would a future session on a different project want to retrieve this?* Yes → Knowledge Base.
   No → Note.
2. *Does this describe an event, or a current state?* Event → Note. State → update the
   Project / Client / Task record that holds that state. Most real inputs are both — write both.
   Writing only the Note is the standard half-done write the Golden Rule above is about.

## Naming — the convention differs by database

> **Knowledge Base is type-first. Note is scope-first.**

- **Knowledge Base** — prefix with the record type: `Finding: …` or `Framework: …`, then the
  claim. KB is retrieved by topic across projects; the prefix is what distinguishes a reusable
  mechanism from a one-off observation in a list view.
- **Note** — prefix with the scope: `<client or workstream> — <claim>`
  (`Acme Intel Phase 2 — …`, `Northwind P5 — …`). Notes are dated events; scope is what makes a
  chronological list readable.

Neither is length-capped — live titles run past 160 characters. The claim—em-dash—consequence
shape is house style, not a defect. Check a sibling with the same tag before inventing a form.

## The relation-replace trap (most expensive failure)

`update_properties` **REPLACES** a multi-value relation. It never appends. Writing one related
task to a page that already has five leaves that page with one.

**Rule:** set relations from the CHILD side. The dual relation auto-syncs the parent. Never write
a multi-value relation from the parent side. If you genuinely must write from the parent, read the
existing values first and send the full list including them.

## Retrieval routing — route on the QUESTION TYPE

| Question type | Shape | Tool |
|---|---|---|
| **Enumerate** — "all tasks due this week", "what moved in June" | Filtered query with explicit filters | `notion-query-data-sources` with a filter |
| **Locate** — "the note about the pricing call" | Keyword or semantic discovery, then fetch | `notion-search`, then `notion-fetch` on the ID |
| **Comprehend** — "what does this page say" | Direct fetch | `notion-fetch` |

A composite question gets DECOMPOSED into these, never fused into one search.

**"What is active" is an ENUMERATION, not a search.** `notion-search` is semantic-only, capped at
25 results, and cannot filter by status. It is for keyword discovery and nothing else. Using it to
answer "what's active" silently truncates and silently drops status.

## Pre-flight checklist (before the first write)

Answer each yes/no — no silent skips:

- [ ] Have I run this record through *Which database does this record belong in?* above — including the "is it also a state change" half?
- [ ] Does the title follow that database's naming convention (KB type-first, Note scope-first)?
- [ ] Do I have the exact database ID, not a guess?
- [ ] Am I writing any multi-value relation from the parent side? (If yes — stop, write from the child.)
- [ ] Have I read the current values of every property I am about to overwrite?
- [ ] Am I setting **BOTH** `Project` and `Client`? Setting only one is the most common defect — the record looks filed and is half-filed. `Project` does not populate `Client`; the relations are independent.
- [ ] Are both IDs copied verbatim from the overlay (or a live lookup) rather than typed or inferred?
- [ ] Have I checked the property name character-for-character, including trailing spaces?

## Known issues

- **Property names carry trailing spaces.** Several properties in this workspace end in a space.
  A guessed name fails SILENTLY — the write returns success and the property stays empty. Read the
  schema and copy the name verbatim; never type it from memory.
- **Truncated IDs are not fetchable.** IDs quoted inline in prose are usually the first 16 hex
  characters of a UUID, shortened for readability. `notion-fetch` needs the full 32-hex UUID or a
  page URL. Resolve a short ID via `notion-search` first.
- **"Record exists" is not "finding is logged."** Verify the specific detail appears in the
  record's content, not merely that a record with the right title is present.

## After every write

Restate what the tool returned — page ID, URL, resolved parameters. Cite the actual response.
No self-grading, no "looks good". If validation surfaces a mismatch, stop and report it.

**`update_properties` returns only `{page_id}`.** It confirms the call was accepted, not that any
value stuck. It is not evidence of anything you wrote.

**Re-fetch the page and read the properties block.** For a note, confirm all of these resolved:

- [ ] `Project` → a URL whose trailing hex **matches the overlay's Project ID in full**, not just its prefix
- [ ] `Client` → likewise, matched in full against the overlay's Client ID
- [ ] `Tag ` → the value you intended (note the trailing space in the property name)
- [ ] The body content is present, not just the title

An empty relation renders as `[]` or is absent from the properties block. If a relation you set is
missing, the ID was wrong or the property name was wrong — both fail silently. Fix and re-verify;
do not report the write as done.
