# clybor-claude-tooling — PRD

**Status:** v0.1.0 — initial bundle 2026-05-10

## 1. Problem

Every new project starts with the same `.claude/` setup ritual: copy the routing protocol, paste the KISS/YAGNI rules, lift the adversarial-reviewer / simplifier / chaos-engineer agents from wherever they last lived. The boilerplate drifts across projects. Skills get stale. The "should I use the team here?" question is asked and answered re-discoverably each time.

This repo solves that by being the canonical bootstrap — one git-controlled source of truth for the standardized tooling that ships into every new project.

## 2. Scope

### In scope (v0.1)

- `CLAUDE.md.template` — boilerplate router with project-name placeholder
- 3 quality agents: `adversarial-reviewer` (Opus), `simplifier` (Sonnet), `chaos-engineer` (Sonnet)
- 4 skills: `quality-review`, `five-whys`, `writing-quality`, `skill-validator`
- 5 commands: `/quality-review`, `/adversarial`, `/simplify`, `/chaos`, `/five-whys`
- 1 hook: `compact-recovery.sh` (Stop / compact matcher)
- 2 rules (auto-loaded): `routing-protocol.md`, `kiss-yagni.md`
- 1 init script: `scripts/init.sh` — one-shot drop-in
- This PRD

### Out of scope (intentional)

- Domain governance (Notion, Gmail, Drive, Slack, Supabase, etc.) — per-project or plugin
- Document generators (docx, pptx, xlsx) — per-project
- Project-scoped rules — per-project
- Migration tooling between bundle versions — YAGNI until v0.2 has actually shipped

## 3. The adversarial review team

Three lenses, no overlap:

| Agent | Model | Lens | Asks |
|---|---|---|---|
| `simplifier` | Sonnet | KISS / YAGNI | *Is this the simplest way?* |
| `adversarial-reviewer` | Opus | Evidence / reasoning | *Is this the right thing?* |
| `chaos-engineer` | Sonnet | Robustness / edge cases | *What breaks this?* |

`quality-review` skill orchestrates all three in parallel, synthesizes findings, and supports a Round 2 re-engagement when context shifts.

## 4. Init pattern

```
bash /path/to/clybor-claude-tooling/scripts/init.sh /path/to/new-project [project-name]
```

What it does:
1. `cp -R .claude/. <target>/.claude/` (overwrites matching files; preserves files only target has)
2. Creates `<target>/.claude/settings.json` from `settings.json.template` (only if missing)
3. Copies `templates/CLAUDE.md.template` → `<target>/CLAUDE.md` (or `.new` if target already has one)
4. Substitutes `{{PROJECT_NAME}}`
5. `chmod +x` on hooks

Single bash script. No submodules, no install dance, no version-pinning ceremony. Re-runnable; safe against partially-initialized targets (existing `CLAUDE.md` is preserved as `.new` for diff).

## 5. Ralph loop — skill validation

### Goal

Validate that authored or lifted skills actually work on representative real-world inputs. Reviewing a SKILL.md by eye catches obvious gaps but misses the failures that only show up under real input. The ralph loop runs the skill, scores the output, patches the skill, and re-runs until pass.

### Pattern

Continuous-iteration eval loop:

```
while !pass and budget_remaining:
    output = run_skill(SKILL, sample(TARGET_REPO))
    scores = score(output, PASS_CRITERIA)
    if all_pass(scores) for two consecutive iterations:
        return PASS
    patch = propose_fix(SKILL, failed_criteria)
    apply(patch)
    log(iteration)
return FAIL(unmet_criteria)
```

Implemented as the `skill-validator` skill (`.claude/skills/skill-validator/SKILL.md`) — see that file for the operational protocol.

### Pass / fail definitions

- **PASS** — every criterion green for two consecutive iterations against every representative input. (Two consecutive guards against fluke runs.)
- **FAIL (budget exhausted)** — `.skill-validator/<skill>/SUMMARY.md` produced with the unmet criteria list and the last failure mode per criterion.
- **FAIL (regression detected)** — patch reverted, regression logged, loop continues if any clean patch path remains; otherwise exits FAIL.

### Budget

Default: 5 iterations × 30 minutes per skill. Hard cap; loops without budgets are runaway loops, not validators. Adjust per-skill in the validator invocation.

### Anti-patterns

- **Optimizing for the criteria.** The criteria are a proxy. If the skill passes them but the output is obviously wrong, the criteria need rewriting, not the skill.
- **Patching past two-strike.** If two consecutive iterations apply patches and the score doesn't move, stop and ask. Continued patching is confirmation bias dressed as iteration.
- **Skipping the audit log.** Each iteration's input / output / score / diagnosis / patch lands in `.skill-validator/<skill>/iteration-<N>.json`. The log is the artifact, not the final pass/fail.

### Phasing

| Phase | What |
|---|---|
| Phase 1 | Build `skill-validator` skill — DONE |
| Phase 2 | Author binary PASS_CRITERIA per skill being validated |
| Phase 3 | Run validator against the chosen target repo |
| Phase 4 | Iterate skill or criteria based on results |

Phase 2 is gating. Don't run the validator until criteria are explicit and binary — vibes-criteria produce vibes-results.

## 6. Versioning

Bundle version lives in this PRD's status line. Bump when:

- Any agent prompt changes semantically (not just typos)
- Any rule file changes operational meaning
- The init script changes its target directory contract
- A skill is added, removed, or renamed

Downstream projects pull updates by re-running `init.sh`. The script overwrites matching files in `.claude/` but preserves the project's own `CLAUDE.md` (writes new template to `.new` for diff).

## 7. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Init script overwrites a project's customized agent prompt | Common as projects diverge | Document the "preserve customizations" workflow: cherry-pick individual files instead of running full init |
| `{{PROJECT_NAME}}` placeholder leaks into a project that re-runs init after editing CLAUDE.md | Rare (init writes to `.new` if CLAUDE.md exists) | Already mitigated in init.sh; verified in smoke test |
| `skill-validator` runs against a target repo and inadvertently writes there | Possible if a write flag is mis-passed | Read-only by default; explicit flag required for any target write |
| Bundle drifts from downstream copies | Likely over months | This repo IS the canonical version; downstream projects pull via re-run of `init.sh` |
| Ralph loop confirmation-bias loops (skill scores ↑ but real quality ↓) | Likely if criteria are vibes | Two-strike rule on patches; criteria must be binary; manual review of skill diff before promotion |

## 8. Success signals (v0.1)

- `init.sh` produces a working `.claude/` tree against an empty target directory ✅ (verified 2026-05-10)
- All three quality agents run in parallel from `quality-review` skill against a sample proposal ⏳
- `skill-validator` produces a PASS verdict on at least one validated skill against a representative target ⏳
- One downstream project successfully runs the bundle for ≥2 weeks without needing template-side changes ⏳
