---
name: graduate-project
description: Graduate a life-crm project into its own ~/gits dev repo and wire the OKF spine between them. Use when a life-crm project needs its own dev or build space (the move to Claude Code), or the user says graduate this project, spin up a repo for it, give it its own repo, or move it to gits. Scaffolds the repo from clybor-claude-tooling (build) or the ClaudeOS or OKF template (knowledge), writes the spine pointers anchored on the Notion Project ID, flips the life-crm folder to role crm, and registers plus backlinks. Done when check-spine.py and validate-okf.py pass.
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# graduate-project

Turns a life-crm project folder into a graduated `~/gits/<slug>` repo and connects the two via the OKF spine (Clybor OKF profile — `~/gits/life-crm/docs/okf-profile.md`). The **Notion Project ID** is the join key; `check-spine.py` keeps the link honest. Six steps, one at a time. Confirm the destination before scaffolding; never mutate a NEW repo without the user's OK.

## Step 0 — Read the registry row (source of truth)
Read `~/gits/life-crm/docs/project-registry.md` for the project's section: **Notion Project ID**, **Local folder**, existing **Related repos**. If the project isn't in the registry, STOP and ask — graduation assumes a signed/active project. Never guess the Notion ID.

## Step 1 — Pick repo type + slug
Ask (one round): **build** repo (code/deploys → `init.sh` flavor) or **knowledge** repo (OKF KB → ClaudeOS template) — or both. Default slug = the project's local-folder name. Confirm the destination `~/gits/<slug>` with the user.

## Step 2 — Scaffold the repo
- **build:** `mkdir -p ~/gits/<slug> && git -C ~/gits/<slug> init`, then `bash ~/gits/clybor-claude-tooling/scripts/init.sh ~/gits/<slug> "<Display Name>"` (copies the `.claude/` tree, `CLAUDE.md`, PRD templates, `check-knowledge.sh` + pre-commit gate).
- **knowledge:** copy your ClaudeOS OKF-bundle master template (the self-replicating `.claudeos-template` knowledge base) per its `procedures/new-project.md` (the marker travels with the copy; first-run configures the instance). NEVER write content into a folder while its `.claudeos-template` marker is present.
- Then invoke `project-bootstrap` to install matching catalog assets + write `TOOLING.md`.

## Step 3 — Write the spine (the bridge)
Anchor on the Notion Project ID from Step 0.
- **life-crm side** — set `~/gits/life-crm/<folder>/index.md` frontmatter: `role: crm`, `notion_project: <id>`, `canonical_repo: ~/gits/<slug>` (or a `repos:` list for multi-repo). If the folder has no `index.md`, create one to the Clybor OKF profile (`schema: okf-adapted-v0.1`); reframe local deliverables as client-delivery **renders** (canon now lives in the repo).
- **gits side (two-way ONLY — optional):** add `~/gits/<slug>/index.md` with `role: build|knowledge`, `notion_project: <id>`, `crm_home: ~/gits/life-crm/<folder>`. Skip unless the user opens the repo standalone. One-way is the default.

## Step 4 — Register + backlink
- Update the project's `docs/project-registry.md` row: add `~/gits/<slug>/` under **Related repos**.
- Run `backlink-governance`, then `bash ~/gits/life-crm/scripts/check-backlinks.sh`.

## Step 5 — Verify (definition of done)
- `python3 ~/gits/life-crm/scripts/check-spine.py` → the project shows ✓ (add `--two-way` if you wrote the reverse pointer).
- If the repo is an OKF bundle: `python3 <repo>/validate-okf.py .` → exit 0.
- Report: repo scaffolded, spine pointers written, gate results. 2–3 sentences.

## Guardrails
- KISS / YAGNI · Two Strikes · Blocker Protocol · read before writing · no fabrication · audit your writes.
- One-way spine by default; reverse pointer only on an explicit standalone-repo need.
- Confirm before scaffolding a NEW repo. Never touch a `.claudeos-template` master.
- Destructive moves are reversible (`_to_delete/` / `_superseded/`); nothing hard-deleted without confirmation.
