---
name: governance-skill-template
description: Template for writing a domain-governance skill — the pattern of encoding a domain's tool-selection rules, defaults, known bugs, and pre-write checks as an on-demand skill instead of always-on context. Use when the user says "create a governance skill for {{DOMAIN}}", "codify the rules for [tool/domain]", "we keep making the same mistake with [tool]", or after the same operational failure recurs twice in one domain. Copy this template, replace every token, delete sections that don't apply.
---

# {{DOMAIN}} Governance

Governance layer for {{DOMAIN}} operations. Loaded on demand when a request touches this
domain — never auto-loaded. The pattern: rules that would otherwise live in always-on
context (paid for on every request) live here and load only when relevant.

> **Filling this template:** replace `{{DOMAIN}}` (e.g. "Gmail", "Calendar", "Drive"),
> `{{TOOL}}` (the MCP/CLI surface), and `{{CANONICAL_RECORD}}` (where outcomes get
> logged). Keep the four canonical sections — Golden Rule, Tool Selection, Pre-Flight
> Checklist, Known Issues — and delete optional ones that don't apply. One skill per
> domain; a skill that governs two domains gets split.

## The Golden Rule

> One sentence that captures the domain's most expensive failure mode, framed as the
> question to ask after every operation. Example shape: "After any write, ask: will every
> related record reflect what just happened? If not, you're not done."

## Tool Selection

Which tool to use for which operation — the table that prevents using the wrong surface:

| Goal | Tool | Notes |
|------|------|-------|
| [FILL: e.g. read a record] | {{TOOL}}.read | first choice; fast and reliable |
| [FILL: e.g. search] | {{TOOL}}.search | caveat: result cap / filter limits |
| [FILL: e.g. write] | {{TOOL}}.write | requires find-first step — see checklist |

Document the DEFAULTS the user expects (timezone, naming format, notification behavior,
title conventions) — wrong defaults are silent failures that a checklist catches.

## Pre-Flight Checklist

Before the first write in this domain, answer every item yes/no — no silent skips:

- [ ] Did I search for an existing record first (update beats create)?
- [ ] Am I using exact field/property names (check the trap table below)?
- [ ] Are relations/links wired from the correct side?
- [ ] [FILL: Domain-specific check 3-5 — derived from your actual failure history]

## Known Issues

_Confirmed failure modes from actual runs. Every five-whys in this domain appends a row._

| Date | Issue | Resolution |
|------|-------|------------|
| [FILL: YYYY-MM-DD] | [FILL: What broke, with the exact error or wrong behavior] | [FILL: The workaround or rule that prevents it] |

## Two Strikes Rule

If a {{TOOL}} call fails or returns unexpected results twice for the same operation,
STOP. Do not retry a third time with variations. Research (this file's Known Issues →
vendor docs → issue tracker), document the finding in the table above, then proceed or
report. A blind third retry that "works" masks the bug and corrupts documented behavior.

## Validation (after every write)

Restate the evidence the tool actually returned — IDs, thread/page references, resolved
parameters. No self-grading; cite returns. Log the outcome to {{CANONICAL_RECORD}} when
the domain's records feed other workflows. If validation surfaces a mismatch, stop and
tell the user — do not fix silently.

## Optional sections (delete if unused)

- **Operation Checklists** — step-by-step recipes for the domain's 3-5 recurring
  multi-step operations (each step names its tool and its verification)
- **Recovery** — symptom → diagnosis → fix table for when something already went wrong
- **Integration With Other Skills** — which sibling skills call or get called by this one

## Adaptation points

- `{{DOMAIN}}` — the domain this skill governs
- `{{TOOL}}` — the tool surface (MCP server, CLI, API)
- `{{CANONICAL_RECORD}}` — where operation outcomes get logged for cross-session memory
