# Routing Protocol

The full 5-step ritual that runs on every non-trivial request. CLAUDE.md has the one-line summary; this file is the canonical version.

## The Five Steps

### 1. Classify

Tag the request with one or more domains. Project-specific examples include:
`design` · `code` · `data` · `docs` · `proposal` · `failure-diagnosis` · `subagent` · `infra`

State the classification out loud in one line before loading anything. Multi-domain requests are normal — say all the tags.

### 2. Load

Load ONLY the matching skills, agents, or rule files on demand. Do not preload. Use the routing table in CLAUDE.md.

If a request is ambiguous between two skills, load both. The cost of loading is far less than the cost of acting without governance.

### 3. Think (Sequential Thinking)

Run `sequentialthinking` after classification when the request requires judgment. **Mandatory** for:

- Anything that produces a write (file edit, DB write, API call with side effects)
- Cross-reference between two sources
- Failure recovery (Two Strikes triggered, blocker hit)
- Quality review (any 3-agent invocation)
- Irreversible decisions (schema, API contract, public-facing copy)

**Exempt** — single-op pure-retrieval requests where the answer is one tool call away with zero judgment, zero cross-reference, zero write.

When in doubt, use ST.

### 4. Pre-Flight Checklist

Before the first write, emit a Pre-Flight Checklist as explicit ticked items in the ST trace. Every item gets a yes/no. No item skipped silently.

**Tool-audit gate (universal, applies to every request that creates or transforms a file):** Before `npm install`, `pip install`, or writing generation code, ask: does a CLI tool already do this in one line? `pandoc` for md↔docx/pdf/html, `ffmpeg` for media, `jq` for JSON, `convert`/ImageMagick for images, `rsync` for file transfer, `soffice`/LibreOffice for Office format conversion. If yes, use the CLI. Only reach for a library when the CLI can't express what you need.

**Date-window gate (applies to any operation whose correctness depends on today's date):** Echo the env date verbatim and show env → today → yesterday → window endpoints on explicit lines.

**Iteration gate (applies to any v(N+1) of a deliverable):** If a prior version exists and new source material has arrived, do an adversarial diff against v(N) before drafting v(N+1). The diff IS the new version's rationale.

**Extraction gate (applies to extracting from transcripts, attachments, or fetched documents that will feed a client-facing deliverable):** Run a second-pass adversarial re-read against the source after the first synthesis. First-pass extraction satisfices and routinely misses 15–25%.

If a checklist item can't be answered "yes," fix the gap before writing.

### 5. Validate

After every write, restate the evidence the tool actually returned: tool-call IDs, thread IDs, page IDs, resolved params. Cite what the tool actually returned — no self-grading, no "looks good," no "should be fine."

If the validation surfaces a mismatch (wrong target, wrong page, missing relation), stop and report. Do not try to fix silently.

**Multi-write completeness:** When one operation creates multiple records, Step 5 applies to every created record — not just the last. Fetch each returned ID, confirm properties and relations landed, spot-check one parent rollup.

## Why This Order

- **Classify first** so you load the right skills, not all of them
- **Load before think** so the ST trace can reference the loaded rules
- **Think before checklist** so the checklist is informed by the plan
- **Checklist before write** so failure modes get caught before they become incidents
- **Validate after write** because silent half-writes are the most expensive failure mode

## Governance Placement

Domain-specific rules belong in a per-project rule file or a Cowork plugin, NOT in this template's `.claude/rules/`. The template only carries always-relevant rules: this routing protocol and KISS/YAGNI principles.

Rule of thumb: if a rule isn't relevant to every project that uses this template, it doesn't belong here.
