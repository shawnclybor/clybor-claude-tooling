---
name: search-governance
description: Governance for all web search and research-grade content fetching. Brave returns SNIPPETS ONLY, so never ship a Brave-only synthesis for research-shaped output. Enforces three rules — (1) Brave (`brave_web_search` via MCP) is for discovery, finding URLs, while a fetch tool, a search-and-scrape tool or a headless browser is for ingestion, reading them; (2) any research-shaped request (comparison, deep-dive, briefing, report, "look up X and tell me about it") uses the two-step Discover then Ingest pattern; (3) deep research escalates to parallel research-lane subagents with structured JSONL returns. The built-in WebSearch tool is blocked. Use whenever you search the web, look something up, draft research, fact-check a claim, or instinctively reach for WebSearch or WebFetch — even if the user just says "look up", "search for", "find out", "google", or "what is the latest on". If in doubt, use this skill — cheap to consult, expensive to ship snippet-only research.
---

# Search Governance

These rules apply to ALL web search and content-fetching operations.

## The Three Hard Rules

1. **Brave returns snippets only — never synthesize from Brave alone.** `brave_web_search` returns title + ~150-char description + URL. That is the lede / meta-description, not the article. Any answer that requires article-level depth MUST follow the Discover → Ingest pattern below.

2. **Discovery and ingestion are different tools. Match the tool to the job.** Brave for finding URLs. An ingestion tool for reading them — a fetch tool (an MCP `web_fetch`, or built-in `WebFetch`), a search-and-scrape tool (e.g. Apify `rag-web-browser`), or a headless browser (e.g. Playwright MCP). The built-in `WebSearch` tool is blocked: it bypasses the MCP layer and its results are less controllable.

3. **Research-shaped requests escalate.** "Fact-check the dose on this medication" is a single-fact lookup. "Research report on X", "deep-dive on Y", "compare these vendors", "competitive analysis", or "brief me on Z" is research-grade — it runs the two-step pattern at minimum and considers the deep-research handoff for anything multi-source. Brave-only synthesis on a research-shaped request is a bug, not a feature.

## Discovery vs Ingestion — the Core Distinction

| Phase | Question it answers | Tool | What you get |
|---|---|---|---|
| **Discovery** | "Which URLs talk about this?" | `brave_web_search` | Title, ~150-char snippet, URL — for 10–20 results |
| **Ingestion (single URL)** | "What does THIS URL say?" | Fetch tool (MCP `web_fetch` preferred, built-in `WebFetch` otherwise) | Full text body of one URL |
| **Ingestion (multi-URL search-and-scrape)** | "What do the top N pages on this topic say, in full?" | Search-and-scrape tool (e.g. Apify `rag-web-browser`) | Markdown of the top N results, scraped end-to-end |
| **Ingestion (JS / paywall / interactive)** | "This page needs a real browser." | Headless browser — navigate, then snapshot / evaluate | Rendered DOM, screenshots, executed JS |

`brave_web_search` is the ONLY approved discovery tool. `brave_local_search` is approved for location-based queries.

## Trigger Taxonomy → Required Pattern

Classify the request before searching. The shape of the request dictates the shape of the search.

| Request shape | Examples | Required pattern |
|---|---|---|
| **Single-fact lookup** | "When did X release Y?", "What is Z's current price?" | Brave only, **if** the answer is fully visible in the snippet. If the snippet only hints at it, escalate to Ingestion. |
| **Doc / API reference** | "Notion API filter syntax", "Anthropic Skills spec" | Brave to find the canonical doc URL → fetch it. Never paraphrase from the snippet. |
| **Troubleshooting** | "Why does X return 403", error-message lookup | Brave to find the Stack Overflow answer / GitHub issue → fetch and read the actual answer. |
| **Research-grade** | "Current state of context engineering?", "Compare vendor X and Y", "Brief me on Z" | **Two-step minimum** — Brave for 5–10 candidate URLs → ingest the top 3–5 in full. Synthesis from articles, not snippets. |
| **Deep research** | "Research report on X", multi-section deep-dive, anything that justifies a structured deliverable | Escalate to **research-lane subagents** (Deep Research Handoff below). |
| **Credibility / fact-checking a claim** | "Is this paper retracted?", "Is this author reputable?" | Lateral reading patterns (below). Multiple sources, not one. |

## The Two-Step Pattern (default for research-grade)

```
Step 1 — Discover
  brave_web_search(query="...", count=10)
  → Pick 3–5 highest-quality URLs (canonical docs, primary sources,
    expert posts; skip SEO farms and aggregators).

Step 2 — Ingest
  Option A (breadth, search-and-scrape):
    one call returns full markdown of the top N search hits.
  Option B (control, one URL at a time):
    fetch each URL you picked in Step 1.
  Option C (JS-heavy / paywall / login):
    headless browser — navigate, then snapshot.
```

Synthesize from the ingested content, not from search snippets. Cite the specific URL each claim comes from.

- **Option A** when you want breadth — one call, several full-content sources.
- **Option B** when you've already curated specific URLs and want exact control over what you read.
- **Option C** when a fetch returns empty, blocked, or JS-loaded content.

### Adversarial re-read on ingested content (mandatory)

When ingested content feeds a research-grade deliverable (briefing, multi-source synthesis, deep-dive), run `adversarial-re-read` against the ingested page text after the first-pass synthesis and before producing the deliverable. First-pass extraction satisfices and misses 15–25%, and it matters more on multi-source ingest where each page got a quick scan. Skip only for single-fact lookups where the ingested content directly answered the question.

## Deep Research Handoff (research-lane topology)

For anything that would produce a multi-section deliverable (research report, briefing, deep competitive analysis), do NOT do it sequentially in the main thread. Use parallel research-lane subagents with structured returns.

1. Decompose the research question into 2–4 independent topic lanes (e.g. thesis & definitions / pillars & primitives / signals & warnings).
2. Spawn one parallel subagent per lane. Explore-type agents for thoroughness-driven discovery; general-purpose agents for claim verification with heavier reasoning.
3. Each lane runs Discover → Ingest within its scope and returns a **structured JSONL contract — never raw page dumps.** Required fields per source:
   - `source_id` (globally unique, e.g. S-001, S-002)
   - `url`, `title`, `author`, `date_published`, `date_accessed`
   - `source_category` (Vendor Official | Practitioner Blog | Academic | Forum | Internal/First-party)
   - `relevance_score` (0.0–1.0)
   - `extracted_claims` (array; each has `claim_text`, `claim_type`, section assignment)
   - `direct_quotes` (array; max 3 per source; each has `quote`, `context`, position)
   - `error` if the URL failed (skip it — never fake content)
4. The main thread reads the JSONL summaries — never raw page content. Synthesis happens against the structured returns.

**Why:** the lane contract forces ingestion + claim extraction + provenance before anything reaches synthesis — the structural fix for snippet synthesis dressed up as research.

- Two-step is enough: "summarize Anthropic's stance on Skills"
- Topology required: "research report on the shift from prompt to context engineering, covering definitions, drivers, primitives, anti-patterns"

## Brave Search Quick Reference

```
brave_web_search(
  query="your search query",   # max 400 chars, 50 words
  count=10,                     # results per page (1-20, default 10)
  offset=0                      # pagination (max 9, default 0)
)

brave_local_search(
  query="businesses near X",
  count=5
)
```

**Effective queries:**
- Be specific: `"Notion MCP query-data-source filter syntax"` beats `"Notion API"`.
- Site-scope when you know the source: `site:developers.notion.com query data source`.
- Quote exact error messages.
- Date-scope time-sensitive lookups: include the year or version.
- Use boolean operators: `"context engineering" -site:reddit.com`.

## Brave Error Handling

Do NOT blind-retry the same query. The move depends on the error.

| Error | Likely cause | Fix |
|---|---|---|
| 429 / rate limit | Per-second request limit — bursts of 3+ rapid or parallel queries trip it. Independent of plan tier; not a monthly-quota issue. | Pause 5–10s, then resume, pacing queries ~1s apart. If sustained, switch to a search-and-scrape tool for the remaining queries. |
| 400 / "query too long" | Query exceeded 400 chars or 50 words. | Trim — drop quotes, narrow the scope. |
| Empty results | Query too narrow OR too broad. | Reformulate — drop a quoted phrase, swap a synonym, add or drop a `site:` scope, or split a compound query. After 2–3 reformulations with nothing, report that rather than guessing from memory. |
| MCP transport flake | Server hiccup. | One retry is fine. A second failure is **Two Strikes** — stop, report, and run `five-whys`. Do NOT fall back to built-in `WebSearch`. |

Switching to a search-and-scrape tool is an acceptable detour when Brave is unavailable for legitimate reasons (rate limit, repeated transport errors). It is NOT a fallback for "I don't want to wait for the cool-down" — pace your queries instead.

### No Brave tool in the session at all

A *missing* tool is not a degraded tool, and it is not a licence to fall back. If no Brave tool is present, that is a blocker:

1. **Do not use `WebSearch`.**
2. **Record the gap as a finding** — write **`NOT PROBED — no approved web search tool in this session`** next to whatever the search would have established, and name what would settle it.
3. **Say so in chat.** A skill that silently cannot do its job is worse than one that refuses out loud.

Confirming a server is connected is not the same as exercising the search path. Where a connection has been verified but no live query run, say so, and treat a first failure as a live-path problem rather than as absence of the tool.

## Lateral Reading Patterns (credibility / fact-checking)

Find credibility *outside* the source you're evaluating — never trust a source's own claim about itself.

**Author / organization verification:**
```
"{author name}" site:wikipedia.org
"{author name}" {field} scholar
"{organization}" credibility OR bias OR funding
"{author name}" ORCID
"{author name}" "conflicts of interest" OR disclosure
```

**Predatory journal / retraction checks:**
```
"{journal name}" predatory OR "Beall's list"
"{author name}" retraction OR correction
"{doi}" retracted
```

**Gray literature (high-trust non-academic):**
```
{topic} site:*.gov filetype:pdf
{topic} "working paper" site:*.edu
{topic} site:nber.org OR site:ssrn.com
```

**Open-access version of a paywalled paper:**
```
"{paper title}" filetype:pdf
"{paper title}" preprint OR "author manuscript"
```

## Boundary Rules — What Brave Is NOT For

| Need | Why not Brave | Correct tool |
|---|---|---|
| Reading the full content of a known URL | It's not a fetcher | Fetch tool |
| Multi-source research synthesis | Snippets aren't enough | Two-step pattern or research-lane topology |
| Internal workspace lookups (docs, chat, tickets) | Not on the public web | That workspace's own connector |
| Internal codebase / memory lookup | Not on the public web | `Read` / `Grep` / an Explore agent |
| Fetching API responses (JSON) | Brave doesn't hit endpoints | Fetch tool |

## When a Fetch Tool Is the Right Tool

A fetch tool is the default ingestion tool for a known URL — documentation pages, API references, GitHub READMEs, blog posts, RSS feeds, REST endpoints (CrossRef, OpenAlex, etc.).

If a fetch returns empty or blocked content, escalate to a search-and-scrape tool (single-URL mode) or a headless browser. Don't paraphrase from the Brave snippet as a fallback — that's the failure mode this skill exists to prevent.

## Scrapability Assessment (bulk / repeated extraction)

Before scraping at volume, run the **three-call probe**:

1. **`/robots.txt`** — `Disallow: /` on `*` blocks generic scrapers regardless of render.
2. **One representative page** — server-rendered (scrapable) vs JS shell (needs a headless browser or an API).
3. **`/api/`, `/api/v1/`, `/api/v2/`** — private SPA backends are usually faster than HTML.

Both technical AND policy gates must clear. Technical-yes + policy-no = read-only intel via Brave snippets, or ask for an API. Verify the target isn't your own client's infrastructure before treating it as competitive intel.

## Pre-Flight Checklist

Before any web operation, tick each item explicitly:

1. **Classify the request** — single-fact / doc-ref / troubleshooting / research-grade / deep-research / credibility?
2. **Discovery tool** — am I using `brave_web_search`? (not built-in `WebSearch`, never as a fallback)
3. **Ingestion required?** — if research-shaped, am I planning to ingest after Brave? Or am I about to synthesize from snippets (= bug)?
4. **Topology required?** — if deep research, am I spawning lane subagents with the JSONL contract?
5. **Query specificity** — ≤400 chars, ≤50 words, quoted exact phrases?
6. **Error plan** — if Brave errors, do I know which fix applies (pace / reformulate / switch tools) instead of blind-retrying?
7. **Citation discipline** — does every claim in my synthesis trace to a specific URL I actually ingested?
8. **Bulk-scrape mode?** — ran the three-call probe, verified technical AND policy gates, checked it isn't an owned target?

If any item is "no," fix it before searching.

## Known Issues

| Issue | Workaround |
|---|---|
| Snippet-only synthesis is the recurring failure mode — "research" reports written from search descriptions alone, not full articles. | The two-step pattern is the default for any research-shaped request; deep research escalates to lane subagents. |
| Brave rate-limits bursts of 3+ rapid or parallel queries (per-second limit), independent of plan tier. Parallel Brave calls are the most common trip. | Pace queries sequentially (~1s apart). Switch to a search-and-scrape tool if Brave is unavailable for legitimate reasons. |
| Playwright MCP returns "Browser 'chrome-for-testing' is not installed" and gets treated as a blocker, pivoting the run to another tool. | It's one-time setup, not a failure — run `npx @playwright/mcp install-browser chrome-for-testing`, then retry. Some SPA share pages render inside an iframe — point the browser at the iframe URL, not the wrapper page. |
