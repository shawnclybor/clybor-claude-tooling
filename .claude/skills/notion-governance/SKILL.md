---
name: notion-governance
description: Governance for reading and writing the Clybor life-CRM Notion workspace from a build repo. Use whenever a request touches Notion — logging a decision, creating or closing a task, reading project or client state, filing a note or KB entry, or invoking any notion-search / notion-fetch / notion-create-pages / notion-update-page tool. Carries the six database IDs, the relation-replace trap that silently destroys multi-value relations, retrieval routing (enumerate vs locate vs comprehend), the trailing-space property names that fail silently when guessed, and the rule that "what is active" is a filtered query and never a semantic search. Triggers — "log this in Notion", "create a task", "update the project", "what's active", "file this", "check Notion", or any request implying a CRM record should change. Cheap to consult; expensive to replace a relation you meant to append to.
---

# Notion Governance

Governance for Notion operations against the Clybor life-CRM workspace from any build repo. Loaded on demand — never auto-loaded.

## Project and Client IDs live in an overlay, never in this file

Every record a repo creates relates to **both** a `Project` and a `Client` — not one of them. The
IDs are per-repo and are **not** stored here. Read them from:

```
.claude/notion-project-ids.md
```

If that file is absent, look the IDs up with `notion-query-data-sources` against the Project and
Client data sources below, then write the overlay so the next session does not repeat the lookup.

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
record IDs. If the overlay is missing, resolve the IDs with `notion-fetch` on the database URL and
write it.

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
