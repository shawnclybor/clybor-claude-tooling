---
name: ooda
description: Runs John Boyd's OODA decision cycle as a working protocol on a task the user has explicitly asked to work that way. Requires an Orientation Block — the current model of the situation, what changed since the last cycle, and what evidence would falsify it — before any decision is committed, then returns to Observe after acting. Reasons through a structured-thinking tool, one pass per phase. Invoke only on explicit request — "run OODA", "OODA this", "/ooda", "use the OODA loop", "give this a method" — or when the user opens a long multi-stage piece of work and asks for a method to run it. This skill does not select itself; if it was not asked for, it does not run. For a failure that already happened use five-whys. For pre-deploy robustness review use chaos-engineer.
---

# OODA

A decision cycle for work whose conditions change while you are doing it. Observe what is true,
orient on what it means, decide, act, then observe again because acting changed the situation.

The version most people carry — four boxes in a circle, run them in order, go faster — is not the
model Boyd built, and running that version produces ceremony. Boyd drew the loop once, in *The
Essence of Winning and Losing* (1996), as a network whose arrows run several directions, including
two links that leave Orient and skip Decide entirely. Orient is the center of the thing. Speed is
not the point.

## Gate — run this before anything else

**Was this skill explicitly asked for?** The user named OODA, typed `/ooda`, or opened a long
multi-stage piece of work and asked for a method to run it.

- **No** — say so in one line and stop. Do not run the cycle because a task felt uncertain. This
  skill is invoked, not selected.
- **Yes, but the work has known steps and stable inputs** — say that, name the two or three steps,
  and stop. A decision cycle on work that needs no decisions is the failure mode this design exists
  to avoid.
- **Yes, and conditions will move** — continue.

## Structured thinking is the reasoning substrate

Every phase transition opens with a call to a structured-thinking tool (the sequential-thinking MCP,
or whatever the host repo uses) naming the phase and its input. The phases are numbered thoughts in
a traceable chain, not headings in a chat reply. The Orientation Block is written *inside* a thought,
which is what makes it auditable rather than decorative.

If that tool errors, retry once — a malformed call is the common cause, not a dead server. If it is
genuinely unavailable, run the cycle inline and stamp every reply and artifact:

    OODA DEGRADED — inline reasoning; structured thinking unavailable: <verbatim error>

Do not halt. A decision loop that refuses to run when tooling is unstable refuses exactly when it is
most useful. The stamp is the requirement. Reasoning inline is acceptable; reasoning inline without
a record is not.

## The four phases

### Observe

Gather what is true right now. Every observation carries its source. An observation with no source
is an inference and gets labeled one. Separate what changed since the last cycle from what has been
true all along — the second category is background, the first is signal.

### Orient

The phase everyone skips, because it is the one with no obvious deliverable. So it gets a deliverable.

Write an **Orientation Block** with exactly these four fields:

    MODEL       — the current understanding of the situation, one paragraph
    CHANGED     — what is different since the last cycle
    CONTRADICTS — which of my prior assumptions this evidence breaks, or "none"
    FALSIFIES   — the specific evidence that would prove this model wrong

No decision is committed until that block exists. If CONTRADICTS is non-empty, the model just broke —
see the Orient to Observe link below before going further.

### Decide

Name the options. Name what each costs if it is wrong. Pick one. Reversible decisions get made and
moved past. Irreversible ones stop and ask the user.

### Act

Do the smallest thing that produces new information. The action is chosen for what it reveals as much
as for what it accomplishes. Then observe again, because the act changed the situation.

## The two links that make this OODA and not a checklist

**Orient to Observe.** When CONTRADICTS is non-empty, the current model is stale. Go back to Observe.
Do not push forward through Decide and Act on a model the evidence just broke. Refining a stale frame
does not fix the mismatch; only new observation does.

**Orient to Act.** When the situation matches a pattern already well understood, go straight to Act
and skip a formal Decide. This is Boyd's implicit-guidance link, and it is what keeps easy cycles from
becoming ritual. State that the shortcut is being taken and name the pattern being matched — a
shortcut on a *superficial* match is how this link fails, and naming the pattern exposes that.

Any phase can be re-entered from any other when conditions move mid-cycle. If the cycle only ever runs
1-2-3-4, it has become the cartoon version.

## Exit conditions

Stop looping when any one of these holds:

1. **The Orientation Block's structured fields stop moving.** Compare the four fields against the
   prior cycle's — not the prose, which will be reworded every time and would never match. If CHANGED
   and CONTRADICTS are both empty two cycles running, the situation has stopped moving.
2. **The user's stated goal is met.**
3. **The remaining decisions are reversible and cheap.** Stop cycling, just do them.
4. **Three cycles with no new information.** Report being stuck — what was tried, what is still
   unknown, what would break the tie. Do not run a fourth.

State which condition fired.

## Output

A short report, not a transcript — the thinking chain is already the trace. Give the cycles run, the
final Orientation Block, the decisions made with their reasons, what was acted on, and which exit
condition fired.

## Known limitation

The gate at the top is prose, and prose gates are honor-system. The mechanical alternative is
`disable-model-invocation: true` in this frontmatter, which makes the skill invocable only by explicit
request and stops it competing for selection at all. Prefer it in any repo where this skill starts
firing on work nobody asked it to structure.

Related: a negative clause in a description ADDS the tokens it means to exclude, because skill
selection is similarity matching rather than logic. That is why the boundary above is stated
positively and by naming sibling skills, not by listing topics to avoid.
