---
name: five-whys
description: Root-cause analysis protocol for when something breaks unexpectedly. Use when a tool call fails twice, a service returns unexpected results, a workflow produces wrong output, or any situation where retrying blindly would waste time. Triggered by "why did that break", "what went wrong", "debug this", or the Two Strikes Rule. Use proactively — if you catch yourself about to retry the same failing call a third time, stop and invoke this instead. Diagnosis ends at a VERDICT, not at a governance write — six verdicts are legal, including "cause not established" and "external defect outside my control". Do NOT use for routine errors with obvious fixes (typos, missing params, wrong file path).
---

# Five Whys — Root Cause Analysis

When something breaks and the cause isn't obvious, walk through this protocol **before** retrying or working around the problem.

Why this matters: blind retries are the #1 source of wasted time and compounding errors. A wrong guess can corrupt data, send to the wrong destination, or overwrite files with stale state. Five minutes of root-cause analysis now saves thirty minutes of cleanup later.

## What this protocol produces

> **A verdict. Not a governance update.**

Diagnosis ends when you can name what happened and how well you know it. What to *do* about it is a separate decision, made after the verdict, from the verdict. Six verdicts are legal (Step 4). Writing a rule is one possible consequence of one of them.

**Why this is stated first.** An earlier version of this skill ended "Every Five Whys should end with a governance update." That single line corrupted the diagnosis upstream of itself. If the only legal ending is a rule, the search stops at the first cause that can be *written as* a rule, not at the true cause. Causes that aren't rule-shaped have nowhere to go, so the protocol pressures you to reframe them until they are.

## When to invoke

- A tool call fails twice with the same or similar error (Two Strikes Rule)
- A service returns unexpected/wrong data (stale, empty, mis-routed)
- A workflow produces incorrect output despite correct-looking inputs
- The user reports something broke that previously worked
- You catch yourself about to retry something that already failed twice

## The Protocol

### Step 1 — State the problem, and get the input before diagnosing the output

Write one sentence: what happened vs. what was expected. Be specific. Include the tool name, the exact input, and the actual output.

A vague problem statement ("the X thing broke") leads to a vague investigation. Specificity narrows the search space immediately.

#### HARD GATE — no input, no root-cause claim

> **You must have the actual input that produced the failure. Not a reconstruction of it. Not an inference from the error text. The real thing.**

An error message is a **floor** on what went wrong, not a ceiling. Distinct bugs routinely converge on byte-identical errors — a parameter that was *omitted* and a parameter that was *sent but mangled in serialization* both arrive `undefined` and produce the same message. **The error cannot tell you which one you have.**

If you do not have the input:

1. **Go get it.** Scroll the transcript, read the log, or ask the user for the raw call. This is usually one question and it is cheaper than every step that follows.
2. **If you cannot get it, you have NOT found a root cause.** That is **Verdict D** (Step 4) — a legal, complete ending to this protocol. Go there. Do not manufacture a cause just to have something to write.
3. **Never** substitute a reconstructed input for the real one and then proceed as though you had identified the cause.

**Reproduction is a sufficiency test, not an identification.** Successfully reproducing a candidate cause proves it *can* produce the symptom. It proves nothing about whether it *did*. Green probes against a reconstruction feel like proof and are not — and confirming evidence quiets the instinct that would otherwise notice the story is straining.

**Distrust a cause that arrives pre-written.** If the explanation is already in a governance file and fits the symptom perfectly, that is grounds for *more* scrutiny, not less. Availability plus fit is exactly the condition under which diagnosis converges on the wrong answer while feeling rigorous. Checking a documented cause is only diligence once you have ruled out the alternatives that produce the same symptom.

**The tell to watch for.** If your causal chain requires an implausible actor — someone who read half a sentence, ignored a rule they'd just consulted, or made an error they had every reason not to make — that strain is data. A true account usually needs no such assumption. Ask what else produces this symptom without requiring anyone to behave absurdly.

### Step 2 — Ask "Why?" iteratively

Use Sequential Thinking for the chain. Each thought = one "Why?" iteration. Set `totalThoughts: 5` initially. Use `isRevision: true` if a later "Why?" invalidates an earlier assumption.

Each answer becomes the subject of the next "Why?" Stop when you reach a cause that explains the symptom — you don't always need all five levels.

```
Problem: Draft landed on wrong record
Why 1?  → The tool resolved the wrong target ID
Why 2?  → ID resolution uses fuzzy matching, not exact lookup
Why 3?  → We passed instructions text instead of an explicit ID
Why 4?  → We didn't search for the target first to get its ID
CAUSE: No find-first step before the write
```

Keep going past the surface-level "what" and into the structural "why." "The API returned an error" is a symptom. "We sent a property name with a missing trailing space" is a cause.

**Stop when the cause explains the symptom — not when it becomes actionable.** These are different stopping points and the second one is a trap. "Actionable" smuggles in "actionable *by me*," which quietly excludes every cause that lives in someone else's code. A cause you cannot act on is still the cause.

### Step 3 — Locate the cause: inside or outside your control

> **Before asking what to do, ask whose defect it is.** This single question is what keeps the protocol from converting other people's bugs into your process burden.

| Locus | Meaning | Examples |
|---|---|---|
| **Ours — process** | We have a step and didn't follow it, or we don't have a step and should | Skipped find-first; no pre-flight check for date windows |
| **Ours — mechanism** | Our code, config, script, prompt, or data | A wrong ID in a lookup table; a broken one-liner; a bad hook |
| **Theirs — external** | A defect in a component we neither own nor can patch | A third-party MCP server bug; a vendor API quirk; a client app's cache |

The bucket determines which verdicts are available in Step 4. Getting it wrong is the most expensive error in this protocol, because the failure is silent — you end up with a plausible rule, a real bug still in place, and no signal that anything went wrong.

#### The anti-pattern this bucket exists to stop

> **An external defect earns a FACT you look up. It never earns a BEHAVIOR you must perform.**

A fact (a Known Issues row, a diagnostic signature, a canonical call shape) is free until you hit the symptom, and then it saves you. A behavior (a hard rule, a mandated pre-flight step, a "remember to always…") costs you on every unrelated request forever — and **cannot fix someone else's bug**, because the bug is not in your behavior.

The shape this takes in practice: a third-party tool has an intermittent serialization defect. Five-whys runs on it and produces a page of behavioral prose about how to call the tool so the defect doesn't fire. The prose doesn't work — the defect fires anyway, sometimes while the rule is open in context. Meanwhile, measurement shows the tool *erroring* in a few percent of sessions and *never being called at all* in most of them. The loud, explained minority absorbed the attention the silent majority needed — and the majority was ours, and closed by a hook script that blocks the write until the tool has actually run. Writing governance about someone else's bug feels like progress, which is exactly what makes it expensive.

When the cause is external, reach for a mechanism or a fact. Never a behavior.

Also check, before proposing anything — is this a **known** issue?

1. Search the relevant rule file's **Known Issues** section
2. Check the **Pre-Flight Checklist** — did we skip a step?
3. If the issue IS documented and we missed it → that's **Verdict C**. The gap is adherence or discoverability, not a missing rule. Writing the rule a second time is not the fix.

### Step 4 — Reach a verdict

Name one. This is where diagnosis ends.

| # | Verdict | When it applies | Available consequences |
|---|---|---|---|
| **A** | **Root found — governance change warranted** | Locus is *ours — process*. The behavior genuinely closes the gap, and the pattern has recurred or the blast radius justifies permanent cost. | Rule / pre-flight item / Known Issues row. Prefer a script that exits non-zero over prose — honor-system gates fail. |
| **B** | **Root found — no governance change** | Locus is *ours*, but the fix is a mechanism (code, config, ID, script), or it's a genuine one-off where a rule would over-fit to n=1. | Just fix it. Write nothing. |
| **C** | **Root found — already documented** | The issue is in Known Issues and we missed it. | Fix the instance. Ask why it wasn't found — that's a discoverability problem, possibly a routing gap. Do NOT re-document. |
| **D** | **Cause not established** | You don't have the real input, or several paths produce this symptom and you can't discriminate. | Enumerate candidate paths. Name the check that would discriminate. Label it `CANDIDATE PATHS — cause not established`. **Stop.** |
| **E** | **External defect** | Locus is *theirs*. You cannot patch it. | Ladder, in order — (1) mechanical containment (script, wrapper, hook); (2) a **fact** (Known Issues row with a diagnostic signature); (3) escalate upstream (file the bug); (4) accept and name it. **Never a behavioral rule.** |
| **F** | **Wrong skill** | The chain bottoms out at a silent framing assumption, not a fixable root. | Hand to `why-diagnostic`. |

**Every verdict is a complete, legal ending.** D and E are not failures of the protocol — they are frequently the correct answer, and the honest one. A run that ends "this is a bug in a tool we don't own, here's the signature so we recognize it faster next time, we can't fix it" is a *successful* run.

**A is the narrowest verdict, not the default.** It requires all three — locus is ours, the locus is process specifically, and the behavior actually closes the gap. Miss any one and you're in B, C, or E.

### Step 5 — Act on the verdict

Do only what the verdict licenses (right-hand column above). Two guardrails:

- **Cascade check.** If the fix spawns a new error class, or scope multiplies through accumulated governance, stop and escalate.
- **The gate points one way.** Promoting a hard rule should require a five-whys run. Running five-whys does not require promoting a rule. This protocol is the gate for rule-writing, not a pipeline into it.

### Step 6 — Report

Tell the user:

- **What broke** (Step 1)
- **The cause** (Step 2), or that it isn't established (Verdict D)
- **Whose defect it is** (Step 3) — ours-process, ours-mechanism, or theirs
- **The verdict** (Step 4), by letter and name
- **What you did** — and what you deliberately did *not* do. If you declined to write governance, say so and say why. A silent non-write is indistinguishable from forgetting.
- **Whether anything needs manual intervention**

## Key principle

> The goal is to know what actually happened — accurately enough to act, or honestly enough to say you can't yet.
>
> "Make it never break this way again" is a good outcome when the breakage is yours to prevent. When it isn't, insisting on that outcome produces a rule that can't work and a bug that doesn't care. **Governance cannot fix what you do not control.**

## When to use debugger or error-coordinator instead

- **`debugger`** — if the failure has a reproducible trigger and you need to find a root cause rather than walk a protocol. Reproduction-first, evidence-driven. Use `debugger` first; fall back to five-whys if `debugger` cannot reproduce or cannot find a root cause. (Reproduction still only proves a cause *can* produce the symptom — see the Step 1 gate.)
- **`error-coordinator`** — if multiple parallel agents or tasks failed in the same run and the failures might share an upstream cause. Correlates symptoms; surfaces shared root causes.

Five-whys is the protocol for unexpected failures with no reproduction. `debugger` is the executor when reproduction exists. Both end in a verdict.

## Related skill: why-diagnostic

`five-whys` and `why-diagnostic` are paired, not redundant.

- **five-whys** (this skill) is for **incident response.** Something broke that previously worked, and the chain bottoms out at a cause you can name. RCA assumes a cause exists — it does not assume the cause is yours, or fixable.
- **why-diagnostic** is for **frame clarification** — "why did this happen" moments where the question may be asked inside the wrong frame. The chain bottoms out at a silent assumption, not a fixable root.

Tool failed twice and retry is dangerous → **five-whys**. "Why did the agent do X" / "why is this design right" → **why-diagnostic**. Both fit → **why-diagnostic** first to check the frame, then **five-whys**.
