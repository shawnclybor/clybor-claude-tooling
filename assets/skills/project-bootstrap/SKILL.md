---
name: project-bootstrap
description: Guided install of reusable Claude tooling from the clybor-claude-tooling catalog into a new project. Reads catalog.json, asks up to 4 project-profile questions, proposes a matching install set with rationales, copies assets into .claude/, fills the catalog-declared adaptation tokens in one batch-confirm round, and writes a TOOLING.md manifest recording what was installed. Use when the user says "bootstrap this project", "set up claude tooling for this project", "install tooling from the catalog", "what tooling from my catalog fits this project", or "init this repo from clybor-claude-tooling". Works for both Claude Code and Cowork projects.
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, AskUserQuestion
---

# Project Bootstrap

Sets up a new project with tooling from the catalog. Six steps, one at a time.

The catalog lives at the clybor-claude-tooling repo root: `catalog.json` indexes every
asset under `assets/skills/<id>/` with its domains, requirements, and adaptation tokens.
This skill is the consumer side: filter, propose, install, personalize, record.

## Step 1 — Read the catalog, profile the project

Locate the catalog repo (default `~/gits/clybor-claude-tooling/`; ask if not found).
Read `catalog.json`. Then ask the user AT MOST 4 questions, in one round:

1. **Project type** — consulting engagement / coding project / research / mixed?
2. **Client surface** — Claude Code, Cowork, or both? (filters on each asset's `targets`)
3. **Domains in play** — pick from the domain values present in the catalog (show them).
4. **Seed values** — the project/client name and any obvious adaptation values
   (e.g., where notes and tasks should live, if known).

If the user's request already answers a question, don't re-ask it. Fewer than 4 is
better than 4.

## Step 2 — Propose the install set

Filter the catalog on `targets` + `domains`. Present the proposed set as a short list,
one line per asset: name, one-line rationale drawn from its `summary`, and its
adaptation tokens. Mark anything borderline as optional. Wait for approval or edits.

## Step 3 — Copy assets in

For each approved asset, copy `assets/skills/<id>/` into the project's
`.claude/skills/<id>/`. Copy semantics (never destructive):

- If the destination file does not exist → copy.
- If it exists → write the new version alongside as `<file>.new` and tell the user to
  diff before merging. Never overwrite.

## Step 4 — Fill adaptation tokens (one batch-confirm round)

Collect every token declared in the installed assets' `adaptation_points`. Propose a
value for each in ONE message, using Step 1's seed answers — assumptions in [brackets]
so the user can verify or swap. Example: `{{...RECORD_SYSTEM}}` → "[Notion Note DB]".
After the user confirms or corrects, apply all fills with Edit. Do not ask token-by-token
questions; one confirmation round total.

## Step 5 — Write TOOLING.md

At the project root, write a manifest. One line per installed asset, exactly:

```
# TOOLING.md — installed from clybor-claude-tooling

- <asset-id> (catalog_version: X.Y.Z, source: clybor-claude-tooling)
```

Use the `catalog_version` from the catalog.json you read in Step 1. This manifest is
what a later sync pass diffs against the catalog.

## Step 6 — Verify and report

- `grep -r "{{" .claude/skills/` in the project must return nothing (all tokens filled;
  unfilled tokens mean Step 4 missed one — fix before reporting).
- `chmod +x` any installed hook files (no-op when the install set contains no hooks —
  v1 catalog ships skills only; keep the step for future hook assets).
- Report: assets installed, tokens filled, manifest path. Two or three sentences.

## Ground rules

- One step at a time. Don't run Steps 1-6 in a single message wall.
- Skips are fine. If the user passes on a step (or wants no token fills), move on.
- Keep each message short — a few sentences plus the proposal or question, not a wall.
- A mid-flow skill invocation is expected. If the user triggers another skill while
  bootstrapping, help with it briefly, then return to where you left off — don't let
  the skill invocation end the setup.

## Edge cases

- **No catalog found** — ask for the repo path; offer to clone if the user gives a URL.
- **Asset already installed** (TOOLING.md exists listing it) — propose only the delta;
  re-installs follow the `.new` rule from Step 3.
- **An asset's `requires.mcp` names a server the project lacks** — flag it in Step 2's
  proposal ("needs X connected") rather than silently installing.
