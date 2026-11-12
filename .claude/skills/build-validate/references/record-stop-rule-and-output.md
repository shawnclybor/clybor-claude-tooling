<!-- build-validate Phase 4 through Guidelines, moved verbatim from SKILL.md -->

## Phase 4: RECORD AND REPORT

```bash
python3 .claude/hooks/review-drift.py record <premises path> --must N --should N --note N \
  --self-inflicted 0 --round-note "premise review"
```

Write `validate.md`: the pass condition, each premise with its verdict, and the decisions the owner
made. **A premise the owner settled is settled** — record it and never re-open it.

## The stop rule

**One round.** There is no round 2 on premises: a premise is confirmed, contradicted, or decided, and
none of those states improves by reviewing again. If new premises appear later, that is a new frame
and a new single round, not a second pass at this one.

If you find yourself wanting another round, the thing you actually want is either a probe (write it)
or a decision from the owner (ask for it).

## Output

```
## Premises: {slug}

**Reviewed:** N premises ({N} carried from probe.md as UNPROVABLE)
**Settled:** {N} by evidence · {N} by the owner
**Unstated premises surfaced:** {N}
**Verdict:** PASS / FAIL

### Next step
PASS → `build-plan {slug}` — capped at ONE runnable increment.
FAIL → the frame is wrong. Fix the PRD, re-probe, and run this once more.
```

## Guidelines

- This skill is READ-ONLY on the build. It writes `premises.md` and `validate.md` and nothing else.
- If a premise review produces a finding about a task, you are in the wrong stage. Drop it.
- A build with no contested premises should skip this entirely. Record the skip; do not manufacture
  premises to justify a run.
- PASS means the frame is sound. It does not mean the build will work — that is the acceptance
  driver's job, and the driver is written red before any of this is worth anything.
