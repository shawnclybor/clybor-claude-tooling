---
name: build-estimate
description: Project a build's remaining effort onto the calendar from MEASURED rates, not guesses. Reads a calibration ledger of past builds (tasks landed per hour under a named process profile), scales by task kind and status, walks the calendar past weekends and holidays, and returns low/mid/high finish dates with a fit verdict against a target date. Two modes — `project` (before or during a build) and `calibrate` (after a build, append the actuals so the next estimate is better). Use when a plan needs its "Estimated effort" section, when someone asks "will this fit by <date>", when the calendar needs reassessing mid-build, or when a build finishes and its actuals should be recorded. Triggers — "estimate the build", "how long will this take", "will we make the date", "reassess the calendar", "record the actuals", "calibrate the estimate".
---

# build-estimate

**The rule: an effort estimate is a calculation from the ledger, not a number typed into a table.**
`plan.md`'s *Estimated effort* section is produced by this tool and cites the rate it used. A
hand-written "3–4 days" has no basis anyone can check, and on the settlement-verifier build it was
wrong by a factor of two within four days (written Aug 23 for 61 tasks; 21 of them then landed in
15.5 hours).

Tool: `estimate.py` beside this file. Ledger: `calibration.json` beside it. Stdlib Python only.

## When

| Moment | Mode | Who calls it |
|---|---|---|
| `build-plan` Phase 5, writing *Estimated effort* | `project` | build-plan — the section is this tool's output pasted in |
| Mid-build, "are we still on track" / a scope or date question | `project` | you, on request; re-run whenever tasks land or the target moves |
| `build-evaluate` PASS, before closing the slug | `calibrate` | build-evaluate — the actuals go into the ledger or the next build estimates blind |

## `project` — from a spec to a calendar

1. **Write the spec** at `.claude/PRPs/<slug>/estimate/estimate-<YYYY-MM-DD>.json` (the
   `estimate/` directory is opaque to the PRP naming hook; the JSON is data, not an artifact).
   Fields, all named in `estimate.py --help`:
   - `process` — which profile the build runs under. `intensive` = build-execute with mandatory
     per-iteration adversarial review and a mutation harness (the only MEASURED profile today).
     `standard` and `light` are ASSUMED multipliers and the output says so.
   - `tasks` — the open tasks, each with a `kind` from the ledger's `task_kinds` and a `status`
     (`not-started` / `staged` / `in-review`). **Read the task text and the staging area before
     assigning these** — a task whose code is staged and green is 40% of a task, not 100%.
   - `fixed` — gate steps with a known clock (build-evaluate, quality-review) in minutes.
   - `optional` — a second scenario (e.g. the tasks a real-matter demo adds). Reported separately
     so the human sees what fits without them and what it costs to add them.
   - `start`, `start_hours_left`, `hours_per_day`, `holidays`, `target`. Look the holidays up
     and compute them — US Labor Day is the *first Monday* of September, and the first estimate
     on the settlement-verifier build put it a week early from memory.
2. **Run** `python3 .claude/skills/build-estimate/estimate.py project <spec>`.
3. **Paste the output** into `plan.md` § *Estimated effort*, replacing whatever was there, with
   the date and the spec path. Keep the *assumptions carried* block — it is what a later reader
   uses to see why the number was what it was.
4. **State the verdict in one line to the human**: fits / marginal / does not fit, at which
   estimate, and which optional items would push it over. The decision to cut or move the date
   is theirs; the tool's job is to make the arithmetic un-arguable.

Do not add a "review" or "contingency" line on top: a task unit already contains its review
rounds and repairs, because that is how the ledger measured it. If the build is not running the
measured process, change `process`, not the task list.

## `calibrate` — closing the loop

After `build-evaluate` returns PASS (or the build is abandoned with tasks landed — those count too):

1. Count from evidence, not memory: iteration-report mtimes or timestamps, tasks flipped in
   `state.json` / the plan checklist, hours actually at the keyboard with overnight and meeting
   gaps excluded.
2. Write a record JSON (`estimate.py --help` shows the shape) with a `note` saying what made the
   run typical or atypical — single operator, task mix, anything that would make the rate not
   transfer.
3. `python3 .claude/skills/build-estimate/estimate.py calibrate <record.json>`; it appends and
   prints the profile's new resolved rate.
4. **Promote** — `~/gits/clybor-claude-tooling/scripts/promote.sh .claude/skills/build-estimate`
   — and commit there. The ledger's value is cumulative across projects; a record left in one
   project's copy calibrates nothing else, and the drift gate will block the next commit anyway.

If a build ran under a profile that has no measured record, calibrating it is what turns that
profile's ASSUMED multiplier into data. Add the profile to `calibration.json` first if it is a
genuinely different process; do not stretch an existing profile to cover it.

## Adding a task kind

A kind is a *shape of work with a measured cost*, not a topic. Add one only when a finished build
shows a class of task that consistently ran at a different multiple of the median, and write the
observation into its `basis`. Kinds with no basis are guesses wearing a label.

## Anti-patterns

- **Typing the estimate.** If the section in `plan.md` has no `rate per task unit` line, it was
  not produced by this tool.
- **Re-using a stale projection.** The Aug 23 figure was still governing on Aug 28 after half the
  tasks had landed. Re-run on every "will we make it" question; it costs seconds.
- **Counting calendar days as working days.** Weekends and holidays are in the spec for a reason.
- **Estimating optional scope as required.** Put it under `optional` so the human sees the split.
- **Calibrating from memory.** "It felt like two days" is not a record.
