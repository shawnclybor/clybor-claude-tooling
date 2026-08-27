---
name: search-governance
description: >
  Governance layer for all web search operations in the life-crm workflow.
  Enforces the mandatory use of Brave Search (`brave_web_search` via MCP) and
  blocks the built-in `WebSearch` tool. Use this skill whenever you are about
  to perform a web search, look something up online, search for documentation,
  find current information, or any request that involves querying the web —
  even if the user just says "look up", "search for", "find out", "google",
  or "what is the latest on." Also use when you instinctively reach for
  WebSearch or WebFetch — this skill redirects you to the correct tool. If in
  doubt about whether a web lookup is involved, use this skill — it's cheap to
  consult and expensive to use the wrong search tool.
---

# Search Governance Rules

These rules apply to ALL web search operations in the life-crm workspace.

## The Rule

> **ALWAYS use `brave_web_search` (Brave Search MCP) for web lookups.
> NEVER use the built-in `WebSearch` tool.**

Brave Search is configured as a local MCP server and is the only approved
search tool for this project. The built-in `WebSearch` tool is prohibited
because it bypasses the MCP layer and its results are less controllable.

If `brave_web_search` fails, debug the MCP connection — do not fall back
to `WebSearch`.

## Tool Reference

| Tool | Status | Use When |
|------|--------|----------|
| `brave_web_search` | **Approved** | All web lookups — docs, current events, research, troubleshooting |
| `brave_local_search` | **Approved** | Location-based searches (businesses, places) |
| `WebSearch` | **Blocked** | Never. Not even as a fallback. |
| `WebFetch` | **Allowed** | Fetching a specific URL you already have (not searching) |

## Brave Search Quick Reference

```
brave_web_search(
  query="your search query",   # max 400 chars, 50 words
  count=10,                     # results per page (1-20, default 10)
  offset=0                      # pagination (max 9, default 0)
)
```

**Tips for effective queries:**
- Be specific: `"Notion MCP query-data-source filter syntax"` beats `"Notion API"`
- Use site scoping: `"site:developers.notion.com query data source"`
- For docs: include the product version or date range if relevant
- For troubleshooting: include the exact error message in quotes

**If Brave returns 0 results:** don't fall back to `WebSearch`. Reformulate the query
instead — drop site scoping, loosen exact-match quotes, try synonyms, or break a
compound query into parts. If the topic is genuinely obscure and still returns nothing
after 2–3 reformulations, report that to Shawn rather than guessing from memory.

## When WebFetch Is Fine

`WebFetch` fetches a specific URL — it's not a search engine. It's fine for:
- Reading a documentation page you already have the URL for
- Fetching API references, GitHub READMEs, blog posts
- Downloading content from a known URL

The governance concern is about *searching* (discovering new URLs), not
*fetching* (reading a URL you already have).

## Pre-Flight Checklist

Before any web search:
1. Am I using `brave_web_search`? (not `WebSearch`)
2. Is my query specific enough to get useful results?
3. If Brave fails, am I debugging the MCP connection instead of falling back?
