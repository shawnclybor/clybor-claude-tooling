---
description: Coordinated three-lens adversarial review (chaos + simplifier + adversarial-reviewer) against a PRD, build plan, validation report, code, or proposal — with a fixed must-fix rubric, a mechanical pre-gate, and drift detection on the review itself.
---

# /adversarial-review

Invoke the `adversarial-review` skill against a target.

## Usage

```
/adversarial-review <target> [--round-note "why a 4th+ round is warranted"]
```

`<target>` is a file path (`.claude/PRPs/foo/plan.md`, `src/api/auth.ts`), or a pasted proposal.

## What happens

1. Load `rubric.md` **before** reading the target — must-fix is defined before anything is graded
2. Classify the target type; run the mechanical checker if one applies, and stop if it fails
3. Drift pre-check — if the review has been ratcheting, surface it and ask before proceeding
4. Spawn `chaos-engineer`, `simplifier`, `adversarial-reviewer` in parallel, one question each
5. Synthesise: dedup, re-grade against the rubric, count self-inflicted findings separately
6. Record the round, re-check drift, report a verdict

## What makes it different from /quality-review

`/quality-review` spawns the same three agents with no rubric, no stop condition, and no memory of
previous rounds. That is fine for a one-off look at a proposal. Use this one when the target will be
reviewed **more than once**, because that is where review processes fail — the count ratchets, the
bar rises silently, and findings the last round introduced get reported as the target degrading.

## Do NOT auto-apply fixes

The skill reports. The user decides what lands. It never edits the target.

## When to skip

- A routine code diff → `/code-review`
- A build plan's pre-execution gate with a profile and mirror → `build-validate`
- Trivial changes, or questions rather than proposals
- **The stop condition already fired.** Three rounds with the checker green and zero must-fix means
  review is done. Build the thing.
