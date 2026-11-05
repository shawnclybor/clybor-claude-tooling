---
name: client-refresh
description: Manual knowledge refresh for one client engagement, run before a working session. Checks the CRM (Notion), our recent git commits and any client repo, then the client's email and calendar, and logs what is missing - Notion notes, tasks and the project's current-state block, an optional registry line, and new attachments filed and byte-verified. Working-brief changes are proposed, never applied. Built against stale information - it dedupes on content rather than titles, and a newer first-party record always beats an older one. Client specifics live in the consuming repo's .claude/refresh-sources.md, never in this file. Triggers - "refresh <client>", "catch me up", "is everything logged", "<contact> sent more", "before we work".
---

# Client Refresh

Goal: before a work session, every new client fact sits in the right place and nothing you rely on is stale.
Manual, interactive, on the host. Writes are autonomous except the working brief, which gets proposals only.

**Client specifics live in `.claude/refresh-sources.md`** in the consuming repo, alongside the
`notion-governance` overlay `.claude/notion-project-ids.md`. Missing → ask the user for each field below in one
message, write the file, then continue. Never guess an ID, path or domain.

```markdown
# Refresh sources — <client>
- Email domains: client.example, prime.example        # every party whose mail counts
- Key people: <name> (<role>), ...                    # who to watch for; note anyone who often leaves the user off
- Calendar match: attendee domains above, title words: <word>, ...
- CRM downloads (canonical): <abs path>               # attachments land here first
- Repo downloads (copy): <repo-relative path>         # optional mirror
- Stamp command: <cmd> <file>                         # optional, e.g. a frontmatter/sidecar stamper
- Registry file + edit command: <path>, <cmd>         # optional; replace-in-place editor
- Memory log: <abs path>                              # optional dated log; append at END only
- Working brief(s): <path>                            # proposals only
- Client repo to fetch: <path> <remote> <branch>      # optional; fetch only
- Counting script: <cmd> <inputs> -> <counts.json>   # optional; source of every count in a draft
- Coverage gaps: <channels this skill cannot see>     # e.g. chat apps, meetings without transcripts
```

## 0. Route and set the window

1. Classification line in chat: `Notion, Gmail, Calendar, git, CRM files`.
2. Load the governance skills your environment provides for Gmail, Calendar and Notion (and Zapier if attachments
   go through it), as the next tool calls. Any load fails → STOP. If a hook demands a thinking/pre-flight step
   before writes, run it; never route around a hook.
3. Date gate: run `date`. Window `FLOOR = today − 7 days` unless the user gives a date. Step 4 dedupes, so a
   generous window is cheap; a short one is how an unlogged email from five days ago goes unseen.

## 1. Baseline — what is already known (read only)

- **Project page** (Project ID from the Notion overlay): its current-state block and date stamp. Two blocks, a
  near-miss heading, or a truncated fetch → no block edits this run; flag it.
- **Notes and tasks** related to the Project, created or edited on/after FLOOR, plus every open task. Fetch Note
  bodies: you match on content later, not titles.
- Registry entry, working brief, last 30 lines of the memory log (whichever the overlay names).
- **Git, ours:** `git log --since=FLOOR --format='%h %ad %s' --date=short`.
- **Git, client repo:** `git fetch <remote>`, then `git log --oneline <local>..<remote>/<branch>` and `--stat`.
  Fetch only — never pull, merge, switch or push.

## 2. Email — read only

No drafts, replies, labels or trash in this skill.

- Search every overlay domain as from/to/cc, `after:FLOOR`, **paginating until no `nextPageToken`**. Union by thread.
- **Never trust search counts or snippets** (Gmail `search_threads` truncates `messages[]` and under-reports
  `messageCount`). For every thread, enumerate true message IDs (`get_thread`, MINIMAL), then FULL-read every
  message dated on/after FLOOR. An oversized result saved to a file is content, not failure: parse it host-side.
- Per message: ID, date (UTC), from, to/cc, facts, asks (who owes what, by when), attachments (name, declared size).
- **User left off:** a forward ("I think X meant to CC you"), a reply to a thread the user isn't on, or "as I
  told Y" means the user may be missing mail. Flag it.

## 3. Calendar

Enumerate calendars first, then list FLOOR to today + 21 days on each that can hold client events. Keep events
matching the overlay. Compare with the brief's dates and the current-state block: new, moved, cancelled, or RSVP
changed = a finding. A calendar event proves scheduling, never that a meeting happened.

## 4. Manifest — the dedupe and staleness gate

Before any write, one table, one row per fact (not per email), printed in chat:

| # | Source (msg / event / commit) | Source date | Fact or ask | Home(s) | Already logged? | Stale record? |

- **Home:** Note (event) · new task (ask with owner) · existing task (status/date change) · current-state line ·
  registry · attachment · brief proposal. Most facts have two homes.
- **Already logged?** = the detail is in the record's text, quoted. A rightly titled Note missing the detail is
  NOT logged. A thread already covered by a Note gets that Note extended, not a new one.
- **Stale record?** = a block line, registry phrase, open task (its **title** as well as its body) or brief line
  that says otherwise. Quote it. Task titles carry claims too, and they are what a list view shows.
- **Order by source date; newer wins.** An older message never overwrites a record built from a newer one. Two
  in-window sources disagree → flag both, edit neither. Hedged ("likely", "TBD") → log as hedged; no state change.

Proceed without an approval wait. Empty manifest → name the searches, the window, and the record that would
have shown a positive, then skip to step 7.

## 4b. Reading, counting and drafting — scripts, not care

Reminders to "verify" do not stop reading and counting errors. These scripts do, and each failure stops
the work.

- **Read every document you rely on** with `python3 scripts/read-source.py <file> <scratch dir>`. Open every
  image it lists under VIEW THESE IMAGES. Exit 1 means unreadable: report it, and never use an older note or
  summary in its place while the file is on disk.
- **Count from the files, never from notes.** Any count that goes in a draft comes from a counting script
  that writes a JSON file. Put the project's counting script in the overlay.
- **Before anything goes to the client or a partner,** run
  `python3 scripts/check-draft.py <draft> --sources <read-source .txt files> --counts <counts.json>` and fix
  every finding.

## 5. Write

Follow `notion-governance`'s pre-flight checklist for every Notion write (both relations from the overlay,
`parent` top-level, child-side relations, exact property names incl. trailing spaces).

1. **Attachments first** (Notes cite them). Skip inline signature images. Download host-side to the CRM
   downloads folder as `YYYY-MM-DD-<original name>` (email date). Same name present → compare hashes; identical →
   skip, different → `-v2`. Check bytes = declared size and the magic header. ZIPs: also expand. Run the stamp
   command if set. Copy to the repo downloads folder if set; `cmp` both.
2. **Notes:** one per thread per day, scope-first title, body with what was said, by whom, message IDs, files
   filed, asks. Extend an existing thread Note instead of duplicating.
3. **Tasks:** one per new ask with owner and due date; update the existing task when an email answers, moves
   or closes it. Never two tasks for the same work.
4. **Current-state block:** rewrite a line only when the evidence is first-party, dated on/after the block stamp,
   unhedged and uncontradicted, citing the Note on the same line; move the old line to Superseded. A fact present
   in a Note but missing from the block gets a new line. Never bump the block's date stamp (it means "fully
   reviewed through"). **Money or contract/legal status → never edit**: flag it and file one task. A commitment
   to or from the client may be edited only when the committing party's own message was read in full this run.
5. **Memory log:** one dated line per run at the END (never above existing lines).
6. **Registry:** replace the stale phrase in place with the overlay's editor; don't append. Same money/contract rule.
7. **Brief: proposals only** — current text, proposed text, source. The user applies them.

Commit nothing. Report what is uncommitted.

## 6. Validate

Re-fetch every page written: relations resolve to the overlay IDs **in full**, tag set, body present. Grep the
registry for the new phrase. `cmp` every filed attachment. Cite what the tools returned. A mismatch → stop and
report; don't fix silently.

## 7. Report

Big picture in a few sentences (window, sources, what was new, what was logged), then **first** what the user
owes next: every open task they own that is due within 2 days or before the next client meeting, by deadline,
plus any unanswered question to them found this run (logging it as owed is not telling them). Then: logged items by what
they are; stale-and-fixed vs stale-and-flagged; brief proposals; client-repo changes; the overlay's coverage
gaps every run, with one question (*anything from <gap> since FLOOR to log?*); numbered next steps marking which
need the user.

## Known issues

- Gmail `search_threads` truncation and `messageCount` under-reporting (step 2). Never skip the enumeration pass.
- Another agent may edit the same current-state block. Re-fetch right before writing; a no-match on a targeted
  edit means the page moved under you: re-fetch and redo, never overwrite from a stale snapshot.
- Notion page citations: `<mention url="https://app.notion.com/p/<id>"/>`; `<mention-page>` is legacy.
