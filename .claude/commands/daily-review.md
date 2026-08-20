# Daily CRM Review

Review yesterday's activity across Gmail, Google Drive, Google Calendar, and update
the life-crm Notion workspace accordingly. Use the notion-governance rules for all writes.

## Environment Detection

**Do NOT use `search_mcp_registry`** — it is Cowork-only and will always return empty
in Claude Code. Instead, test each tool directly with a lightweight call:

1. **Notion** (required): Try `notion-search` with a simple query. If it fails, abort.
2. **Gmail** (optional): Try `gmail_search_messages` for yesterday's date. If it fails, skip.
3. **Google Calendar** (optional): Try `gcal_list_events` for yesterday. If it fails, skip.
4. **Google Drive** (optional): Try `google_drive_search` for recent files. If it fails, skip.

Report which sources were available and which were skipped before proceeding.

## Workflow

### Step 1: Gather Data

For each available source, collect yesterday's activity:

**Gmail** (if available):
- Search for emails from yesterday (use `after:YYYY/M/D before:YYYY/M/D`)
- Flag emails that involve: existing contacts, active projects/clients, action items, new contacts

**Google Calendar** (if available):
- List all events from yesterday
- Identify meetings with project/client relevance

**Google Drive** (if available):
- List files created or modified in the last 24 hours
- Identify documents related to active projects

### Step 2: Cross-Reference with Notion

For each item found:
1. Search Notion for the related Contact, Project, and Client
2. Check if a Note already exists for this interaction (avoid duplicates)
3. Identify gaps — interactions that happened but aren't logged

### Step 3: Update Notion

Follow the notion-governance operation checklists (`.claude/rules/notion-governance.md`)
for each update:
- Log meetings/calls as Notes with proper tags and relations
- Create tasks for action items with correct Project links
- Update project statuses if warranted
- Add new contacts if discovered in emails
- Update client pipeline stages if relevant

### Step 4: Report

Summarize what was found and updated:
- Sources checked (and any that were unavailable)
- New Notes created
- Tasks created or updated
- Contacts added or updated
- Project/Client status changes
- Items that need manual attention
