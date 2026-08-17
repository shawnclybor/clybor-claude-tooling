---
name: excel-connector-governance
description: Governs driving Excel Online (Business) through a Microsoft Copilot Studio agent against SharePoint-hosted .xlsx. Triggers — "Copilot Studio", "Excel Online (Business)", "add a row", "update a row", "delete a row", "connector 502 / BadGateway", "Office Script", "pin the File input", "spreadsheet agent", "SharePoint xlsx agent". Loudest bug — the File pin stores an opaque 34-character drive-item ID and shows no filename anywhere in the UI, so a tool pinned to the wrong workbook fails identically every time, and against a healthy workbook would silently write to the wrong client's file. Resolve every File pin back to a filename before trusting a write. Cheap to consult; expensive to write a row into the wrong client's workbook, or to record a working connector as a permanent limitation.
---

# Excel Connector Governance (Copilot Studio → Excel Online → SharePoint)

Governance for driving **Excel Online (Business)** through a **Microsoft Copilot Studio**
agent against `.xlsx` files hosted in **SharePoint**. Loaded on demand — never auto-loaded.

Every claim below was verified live against a real tenant on **2026-08-14** unless marked
`UNVERIFIED (doc-sourced)`. Several of these findings contradict, or simply do not appear in,
Microsoft's documentation. Do not re-derive them from the docs.

**Tenant-neutral by design.** Bot IDs, environment GUIDs, site names, drive-item IDs and
workbook names are deliberately absent — record those in the project's own governance, not
here. What lives here is connector behaviour that holds across tenants.

## The Golden Rule

> A pinned File input is an opaque ID, not a filename. Until you have resolved that ID back
> to a filename yourself, you do not know which workbook the tool writes to — and a
> wrongly-pinned tool is more dangerous than an unpinned one, because it fails identically
> every time and, against a healthy workbook, would not fail at all.

## Verification context

Findings were established with Standard orchestration (reached via "Other ways to build", not
the GitHub Copilot harness), a draft unpublished agent, and end-user credentials on the
connection. A purpose-built smoke-test workbook with one formatted table and a unique key
column was used as the control — **build one before trusting any finding against a client
file.** A control workbook is what separates "the connector is broken" from "this workbook is
broken."

## Operation coverage — what actually works

| Operation | Connector action | Status |
|---|---|---|
| Read | `List rows present in a table` (`GetItems`) | Works. ~5s observed. |
| Create | `Add a row into a table` (`AddRowV2`) | Works. ~80s observed. |
| Update | `Update a row` (`PatchItem`) | Works. Verified at XML level. ≤20s observed. |
| Delete | — | **No connector action exists.** Requires an Office Script via `Run script`. |

Copilot Studio exposes **13** Excel Online (Business) actions; none deletes a row, though the
underlying connector REST API supports it. Searching "delete" inside the connector returns
nothing.

Delete requires a script authored **inside Excel on the web** (Automate → New Script). A
hand-built `.osts` uploaded to the library has never been shown to bind — do not assume it does.

**Latencies above are single observations, not benchmarks.** Treat them as order-of-magnitude
only; they are recorded to set expectations about slowness, not to budget a workflow.

## Pre-Flight Checklist — gates any write tool pointed at client data

No item is skipped silently. Each maps to a named failure mode below.

1. **File pin resolved to a filename?** Take the pinned drive-item ID, resolve it against the
   library listing, and read the `name` back. Yes/no. → *Finding 1.*
2. **All five write inputs pinned?** Location · Document Library · File · Table · Key Column.
   None left on "Dynamically fill with AI". Yes/no. → *Finding 1.*
3. **Key column uniqueness confirmed?** Read the whole table and check the key column for
   duplicates. If uniqueness is not guaranteed, an Update is a coin flip — route through an
   Office Script that handles all matches, or do not wire the tool. Yes/no. → *Finding 5.*
4. **Update confirmation gate decided?** `Update a row` executes with no prompt by default.
   Decide explicitly whether it stays ungated before the tool touches client data — do not
   inherit the default by omission. Yes/no. → *Finding 4.*
5. **Verification method cache-busted?** The read used to confirm the write must carry
   `cache: 'no-store'` **and** a cache-busting query parameter. Yes/no. → *Finding 3.*

**Validate after every write:** re-read the stored `.xlsx` and cite what the file actually
contains. Never cite the agent's own confirmation text — see *Finding 2*.

## Finding 1 — Pin all five write targets, then verify the File pin resolves to a filename

`Add a row` and `Update a row` ship with **Location, Document Library, and File** all set to
"Dynamically fill with AI". Pin all three, plus **Table** and **Key Column**.

**Pinning is not sufficient.** The pin stores an opaque 34-character drive-item ID with no
filename shown anywhere in the UI. Observed live: an `Update a row` tool was found pinned to a
*different workbook in the same library* than intended. Every update returned `502 BadGateway`
— which read exactly like "Copilot Studio cannot update rows" and nearly became a permanently
recorded limitation.

A wrongly-pinned target is worse than an unpinned one: it fails identically every time, and
against a healthy workbook it would not error at all — it would silently write to the wrong
client's file.

**The check — resolve the ID back to a name:**

```
GET https://{tenant}.sharepoint.com/sites/{site}/_api/v2.0/drives
GET https://{tenant}.sharepoint.com/sites/{site}/_api/v2.0/drives/{driveId}/root/children
```

Match `id` → `name`. Run this after pinning or changing any File input, before trusting the tool.

## Finding 2 — Never trust the agent's success message; re-read the stored file

Two narration failures were observed, **both with a correct underlying write**:

- On a duplicate key, the agent reported the before-value of the *other* duplicate row.
- On an oblique phrasing it emitted a refusal ("no information available confirming it has
  moved") and then performed the update anyway, in the same turn.

The writes were correct; the prose describing them was not. **Any workflow that logs or
forwards the agent's confirmation text is logging fiction.** Log the re-read, not the narration.

## Verification procedure

Fetch the stored `.xlsx` and inspect its XML. Do not rely on the agent, the Excel web UI's
rendered view, or an uncached SharePoint read.

**Cache-busting fetch — both parts are required:**

```js
const url = `https://{tenant}.sharepoint.com/sites/{site}` +
  `/_api/web/GetFileByServerRelativeUrl('${serverRelativePath}')/$value` +
  `?cb=${Date.now()}`;                     // cache-busting query parameter
const res = await fetch(url, {
  cache: 'no-store',                       // and no-store
  headers: { Accept: 'application/octet-stream' },
});
```

**XML paths to check inside the unzipped `.xlsx`:**

| Path | What it tells you |
|---|---|
| `xl/tables/table1.xml` | The table `ref` — did the range grow on an Add? |
| `xl/worksheets/sheet1.xml` | Cell positions and value/type references |
| `xl/sharedStrings.xml` | The actual string values the cells point at |

**Corroborating metadata** (useful, but not a substitute for reading the bytes): `Length`,
`UIVersionLabel`, `TimeLastModified`, `ETag`.

## Finding 3 — Cache-bust every verification read

`/_api/web/GetFileByServerRelativeUrl('...')/$value` **serves stale bytes.** Observed live: it
reported a file as byte-identical after a successful write, while the metadata (`Length`,
`UIVersionLabel`, `TimeLastModified`, `ETag`) was already showing the new version.

Without both `cache: 'no-store'` **and** a cache-busting query parameter, verification
produces confident false negatives — the most expensive failure mode in this area, because it
makes working code look broken and invites a permanent "limitation" that does not exist.

## Finding 4 — Confirmation gates are asymmetric, and backwards

`Add a row` prompts *"I am about to add a new row… Confirm to proceed?"*. `Update a row` does
**not** — it executes immediately. **The additive operation is gated; the destructive one is not.**

Treat the current asymmetry as a defect to correct, not a default to inherit. Decide the
Update gate explicitly (Pre-Flight item 4) before any tool is pointed at client data.

**Config trap:** setting *"Ask the end user before running: Yes"* saves successfully with an
empty message field, then fails **every** invocation at runtime with `InvalidContent`. The
message field only appears after toggling Yes — so it is easy to save a gate that bricks the tool.

## Finding 5 — Duplicate keys are silently permitted; Update hits the first match only

`Add a row` will create a second row with an existing key — no warning, no error. `Update a
row` then modifies **only the first match**, silently. Verified directly: two rows sharing a
key, update by that key, only the earlier row changed.

For any table where the key column is not guaranteed unique, an update is a coin flip. Confirm
uniqueness before wiring an Update tool, or route the operation through an Office Script that
handles all matches explicitly.

## Finding 6 — Batch work does not belong on this connector

Writes are per-row and slow. Anything batch-shaped — bulk reconciliation, multi-row status
sweeps, column-wide rewrites — needs **Office Scripts**, not a loop over `Add a row` /
`Update a row`.

## Finding 7 — A workbook can be intrinsically defective, and it is not a connector limit

A single workbook can return `502 BadGateway` on **every** workbook-level operation while other
files in the same library work normally — including against a freshly uploaded clean copy of
the same file. SharePoint deterministically reprocesses such a file on upload and quarantines
unparseable parts into `[trash]` entries; that is a **symptom, not the cause**.

Hypotheses worth eliminating early, all of which have been ruled out at least once: strict Open
XML · `[trash]` parts · absence of a formatted table · stale upload · the generating library
(a working control file produced by the same `openpyxl` version behaved fine).

**This class of defect reproduces identically in Power Automate, Office Scripts, and the Graph
API.** It is not a Copilot Studio limitation. Regenerating the workbook is the only known path.
The diagnostic that separates it from Finding 1: a wrong File pin also yields uniform 502s —
resolve the pin to a filename *first*, then suspect the workbook.

## Behaviour that held up (verified, not assumed)

Tool selection was correct on **6/6** varied phrasings, including two that required inference
from natural language to the right column and value — e.g. a retire-this-asset phrasing
resolving to the `Status` column, and a colloquial "it moved offices" phrasing resolving both
the row identity and the `Location` column.

A key matching nothing fails cleanly: HTTP `404`, `No row was found with Id '<key>'`.

⚠ **The raw connector error is surfaced verbatim to the end user.** Acceptable in testing; not
acceptable in a client-facing deployment — wrap or suppress it before anyone outside the build
sees the agent.

## Environment gotchas

- **Backgrounded Chrome tabs render nothing.** `document.visibilityState === "hidden"` means
  blank screenshots and an unrendered SPA. A prior session recorded "Excel on the web never
  renders" and "Copilot Studio breaks on deep links" as platform facts; **both were this.**
  Foreground the tab before concluding a page is broken.
- **An empty dynamic dropdown is a downstream symptom, not a UI bug.** Table and Key Column
  return "Could not find suggestions" *because the File pin above them is wrong*. Once the
  File is corrected, Table resolves normally. Treat an empty dropdown as a signal to check the
  pin above it — never work around it with "Enter custom value".
- **Table accepts either the table name or its braced GUID.** Binding is by GUID, so it survives
  a rename but breaks if the table is deleted and recreated.
- **Copilot Studio blocks navigation with a "Leave the page?" dialog** on a stale dirty flag,
  even after a successful save.
- **The test panel caches the agent version** — start a "New test session" after any config
  change, or you are testing the previous build.

## Two Strikes

Same operation fails or returns wrong twice → **STOP.** Research, append to Known Issues,
report. No blind third retry. In this domain the two most likely causes of a repeated failure
are a wrong File pin (Finding 1) and a stale verification read (Finding 3) — check both before
concluding the connector cannot do the thing.

## Integration with other skills

| Load alongside | When |
|---|---|
| `ms365-governance` | Any SharePoint read/write, tenant scope, or access-state question. |
| The project's own workbook/tracker governance | The target workbook is a governed client file — that skill owns its schema, write rules, and any known defects. |
| `five-whys` | A repeated failure here — the 502 incident is the worked example of misattributing a caller bug to a platform limit. |

## Known Issues

| Date | Issue | Resolution |
|------|-------|------------|
| 2026-08-14 | **Finding 1** — File pin stores an opaque 34-char drive-item ID with no filename in the UI; an `Update a row` tool was found pinned to the wrong workbook in the same library, producing a uniform `502 BadGateway` that read as a connector limitation. | Resolve every File pin ID → filename via `_api/v2.0/drives/{driveId}/root/children`. Pre-Flight item 1. |
| 2026-08-14 | **Finding 2** — Agent narration misreports writes: reported the before-value of the wrong duplicate row; emitted a refusal then performed the update in the same turn. Underlying writes were correct. | Never log or forward the agent's confirmation text. Verify by re-reading the stored `.xlsx`. |
| 2026-08-14 | **Finding 3** — `GetFileByServerRelativeUrl(...)/$value` serves stale bytes; reported a file byte-identical after a successful write while metadata showed the new version. | Every verification fetch needs `cache: 'no-store'` **and** a cache-busting query parameter. |
| 2026-08-14 | **Finding 4** — Confirmation gates asymmetric and backwards: `Add a row` prompts, `Update a row` executes immediately. Separately, "Ask the end user before running: Yes" saves with an empty message field and then fails every invocation with `InvalidContent`. | Decide the Update gate explicitly per deployment. Never save the ask-first toggle without filling the message field. |
| 2026-08-14 | **Finding 5** — Duplicate keys silently permitted by `Add a row`; `Update a row` modifies only the first match, silently. | Confirm key-column uniqueness before wiring an Update tool, or route through an Office Script handling all matches. |
| 2026-08-14 | **Finding 6** — No delete action exists among the 13 exposed Excel Online (Business) actions, though the connector REST API supports it. | Delete (and all batch work) via an Office Script authored inside Excel on the web (Automate → New Script). A hand-built uploaded `.osts` has not been shown to bind. |
| 2026-08-14 | **Finding 7** — A single workbook returned `502 BadGateway` on every workbook-level operation, including a freshly uploaded clean copy, while siblings in the same library worked. Not a Copilot Studio limitation; reproduces in Power Automate, Office Scripts, Graph API. | Rule out the File pin first, then regenerate the workbook. Do not re-investigate the eliminated hypotheses listed in Finding 7. |
| 2026-08-14 | Backgrounded Chrome tabs render nothing (`visibilityState === "hidden"`), previously misrecorded as "Excel on the web never renders" and "Copilot Studio breaks on deep links". | Foreground the tab before concluding a page is broken. |
| 2026-08-14 | Empty Table / Key Column dropdowns ("Could not find suggestions") caused by a wrong upstream File pin, not a UI defect. | Check the pin above the dropdown; do not use "Enter custom value" as a workaround. |
| 2026-08-14 | Raw connector errors (e.g. `No row was found with Id '<key>'`) are surfaced verbatim to the end user. | Acceptable in testing only. Wrap or suppress before any client-facing deployment. |
