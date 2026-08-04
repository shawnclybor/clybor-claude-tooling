# Scheduled Task Template: Plugin-Rebuild Queue Drain

**Pattern.** Governance edits to installed Cowork plugins queue as manifest files in
`cowork/_pending-edits/`; a weekly Cowork scheduled task drains the queue through the
repo's gated rebuild script. Installed plugins stay in sync with queued governance
without manual rebuild ceremony, while every change still passes the same gates.

**Why a queue at all.** Cowork sessions run plugins from a read-only cache — a skill
edit only goes live through rebuild + reinstall of the bundle. Edits that aren't worth
an immediate rebuild get a manifest in the queue; the scheduled task applies them in
batch. The directory IS the state: no separate tracking list to go stale.

**Reference implementation:** life-crm (`~/gits/life-crm`) — `scripts/rebuild-plugin.sh`
plus its gates `scripts/validate-plugin.py` and `scripts/validate-plugin-promotion.py`.
When a repo adopts Cowork plugins, copy those three scripts; they are portable except
the per-plugin source-of-truth table at the top of `rebuild-plugin.sh` (edit per repo).
The originating repo (life-crm) keeps its own specialized task; this template is the
generalized version.

## The contract

1. **Queue dir** — `cowork/_pending-edits/`. One manifest (`.md`) per edit.
2. **Manifest content** — target plugin, target file inside the bundle, edit type, and
   DETERMINISTIC apply instructions (exact `old_string`/`new_string` anchors copied
   from the live bundle). Ambiguity makes a manifest non-drainable: it gets flagged
   for a human, never improvised.
3. **Gate script** — every rebuild runs `scripts/rebuild-plugin.sh <plugin> --stage`
   then `--promote --bump patch`. The script enforces dated backup, fresh extract from
   the live bundle, version monotonicity, content-superset check, structural
   validation, install-copy sync, and stage cleanup. The task NEVER zips, bumps, or
   edits plugin metadata by hand.
4. **Autonomy boundary** — patch bumps only. Skill add/remove/rename, `plugin.json`
   description changes (a known silent-rejection surface in Cowork install
   validation), or anything needing a minor/major bump is out of scope for the
   autonomous run: leave it queued and open a tracker task for a human-gated rebuild.
5. **Failure mode** — any gate failure stops that plugin's drain. No retries, no
   manual fallback. The stage dir is left renamed `_stage-FAILED-*` for diagnosis;
   manifests stay queued.
6. **Run cadence** — weekly, early on a low-traffic morning (e.g. Monday 07:30).
   An empty queue is a successful run.

## Scheduled-task prompt (fill placeholders, register via Cowork scheduled tasks)

Placeholders: `{{REPO_PATH}}` = absolute repo path (e.g. `/absolute/path/to/my-repo`),
`{{TASK_TRACKER}}` = where human-gated follow-ups get filed (e.g. Notion task DB,
GitHub issues).

```text
You are running the weekly plugin-rebuild queue drain for {{REPO_PATH}}
(mounted in Cowork at /sessions/*/mnt/<workspace>/).

State a classification line first, then load the repo's plugin-governance and
filesystem-governance skills (if installed) before any governed tool call.

Objective: apply every deterministic manifest in cowork/_pending-edits/ to its
target plugin through the gated rebuild chain.

1. List cowork/_pending-edits/. No *.md manifests -> report "queue empty" and
   stop. That counts as a successful run.
2. Read every manifest; group by target plugin.
3. Autonomy boundaries, checked BEFORE touching a plugin: deterministic anchors
   only; patch bumps only; never --allow-desc-change; never edit plugin.json
   description. Anything outside the boundary: leave queued, file a task in
   {{TASK_TRACKER}} ("Manual plugin rebuild needed: <plugin> — <reason>").
4. Per eligible plugin, run ON THE HOST via Desktop Commander start_process
   (never the VM workspace shell — the promote step syncs installed copies under
   ~/Library, unreachable from the VM):
   a. cd {{REPO_PATH}} && bash scripts/rebuild-plugin.sh <plugin> --stage
      --reason pending-edits   (capture the printed stage path)
   b. Apply each manifest's edit to the staged file with edit_block, using the
      manifest's old_string/new_string EXACTLY. Anchor not found -> abort this
      plugin, leave manifests, flag in report. Do not improvise.
   c. cd {{REPO_PATH}} && bash scripts/rebuild-plugin.sh <plugin> --promote
      --bump patch --reason pending-edits
   d. Exit 0 -> delete the applied manifests. Non-zero -> stop for this plugin,
      no retry; report the gate output verbatim.
5. Report per plugin: old -> new version (cite script output), manifests applied
   and deleted, gates passed, anything left queued and why.

Constraints: rebuild steps only through scripts/rebuild-plugin.sh; already-open
sessions keep cached skill text — new sessions pick up rebuilt content.
```

## Adoption checklist for a new repo

1. Copy `rebuild-plugin.sh`, `validate-plugin.py`, `validate-plugin-promotion.py`
   from the reference repo into `scripts/`; edit the source-of-truth table.
2. `mkdir -p cowork/_pending-edits`.
3. Fill the placeholders above; register the prompt as a weekly Cowork scheduled task.
4. Add a router row for the queue domain in the repo's `CLAUDE.md`.
