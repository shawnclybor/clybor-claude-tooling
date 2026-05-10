---
description: Run the 3-agent quality review (simplifier + adversarial-reviewer + chaos-engineer) against a plan, file, or proposal.
---

# /quality-review

Invoke the `quality-review` skill against a target. Spawns the three review agents in parallel and synthesizes findings.

## Usage

```
/quality-review <target>
```

Where `<target>` is one of:
- A file path (`docs/PRD.md`, `src/api/auth.ts`)
- A description of an in-progress proposal in chat
- A pasted block of plan / design text

## What happens

1. Load the `quality-review` skill
2. Spawn `simplifier`, `adversarial-reviewer`, `chaos-engineer` in parallel against the target
3. Synthesize findings (where do they agree, where do they disagree)
4. Present a numbered, prioritized report
5. Wait for user decision

Do NOT auto-apply fixes. The skill produces recommendations; the user decides what lands.

## When to skip

- Trivial changes (single-file edits, typos, config tweaks)
- Information requests (this command is for proposals, not questions)
- Already-implemented code where the design is locked — use a code-review pass instead
