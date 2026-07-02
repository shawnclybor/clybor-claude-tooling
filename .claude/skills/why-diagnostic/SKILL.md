---
name: why-diagnostic
description: A framing diagnostic for "why did this happen?" moments during agent and tool work. Use when the user says "why did this fail", "why did the agent do that", "why is this output wrong", "why isn't this working", or otherwise asks for an explanation of agent/tool behavior. Reads like an incident report — frame the question, surface the assumptions doing silent work, walk the reasoning back, name where the chain honestly ends, point at what to test first.
---

# Why Diagnostic

## Purpose

When something happens in agent or tool work and the user asks "why," the temptation is to produce a tidy causal story: *X happened because Y*. That story is usually wrong, or right for the wrong reason, because it skips the frame the question is being asked inside.

This skill runs a three-step diagnostic borrowed from Wittgenstein's *On Certainty*:

1. **Name the language-game.** What practice is the "why" being asked inside? Debugging? Prompt design? Architecture justification? The same event has different "real" causes in each.
2. **Surface the hinges.** What's being held fast — unexamined — for the explanation to even make sense? These are the assumptions doing silent work.
3. **Name the stop point.** Where does the chain of "because" actually give out? Don't fake further depth. State it.

That analytical structure stays intact — those labels (language-game, hinges, chain of because, stop point, the hinge-worth-testing) are the methodology, and they're how the model reasons through the question internally. But the user-facing **output** is a translation: connected prose in incident-report shape, not labeled blocks. The user never sees the labels; they see a short post-mortem-style write-up that reflects what the labeled analysis produced.

## When to use

Trigger when the user asks "why" about anything in the agent/tool workflow:

- **A tool failed or behaved oddly** — "why did the MCP call return nothing", "why did Brave Search return zero results", "why did this script error"
- **An agent's output isn't what expected** — "why did the agent format this as a table when I said plain English", "why did it ignore the rubric"
- **A design choice needs justifying** — "why am I using Langfuse here vs. GitHub Actions", "why should the scorer be flat instead of nested"

Do NOT use for:
- Factual lookups ("why is the sky blue") — just answer
- Emotional/personal "why" questions — that's not what this is for
- Cases where the user just wants the direct fix and the "why" is rhetorical

**Human-behavior questions** (why did a person do X) are admissible only after recasting as design-of-the-surrounding-system questions (e.g. "why did the governance design fail to interrupt at point of failure"). If the recast doesn't fit, this skill isn't the right tool — moralizing about the person is the failure mode it produces.

If unsure whether the trigger applies, run the diagnostic anyway — it's short.

## Internal analysis (model's reasoning, not shown to user)

Before writing anything, work through the analysis using the original labels. The model needs to identify these explicitly to produce a good output:

- **Language-game:** what practice is the "why" being asked inside?
- **Hinges (held fast):** what assumptions, 2-3 of them, are doing silent work?
- **Chain of because:** walk back, 3 steps max.
- **Stop point:** where does the chain honestly give out?
- **If a hinge is wrong:** which hinge, flipped, would most change the answer?

This labeled structure is the methodology. It is not the output.

## The output (what the user sees)

Translate the analysis into a short incident-report-style write-up. No labels. No bullet lists for the assumptions. One bold header that restates the question, then five short paragraphs of connected prose.

```
**[Question, restated as one line.]**

[Paragraph 1, 1-2 sentences: name what kind of question this actually is — the language-game in plain words. What practice is the "why" inside? The point is to redirect away from the wrong frame the question might invite.]

[Paragraph 2, 2-4 sentences: name 2-3 hinges in connected prose, not bullets. These are the things being held fast for the explanation to make sense — the conditions that have to be true for the chain to work. Write them so the reader can challenge any one of them.]

[Paragraph 3, 2-4 sentences: walk the chain of because. Three "becauses" max, in prose. Each "because" should make the next one feel inevitable. No numbered steps; write it as a movement.]

[Paragraph 4, 1-2 sentences: name the stop point honestly. Phrases like "because that's how the API works" or "because the model was trained that way" are valid endpoints. Name them as endpoints, not as deeper explanations.]

[Paragraph 5, 1-2 sentences: lead with the hinge worth testing first. Which assumption from paragraph 2, if wrong, would most change the answer? Tie it to a concrete next move.]
```

## Hard rules

- **Maximum 3 hinges, maximum 3 steps in the chain.** If it needs more, the language-game is wrong — restart.
- **The stop point is not a final answer.** It's the honest edge. Phrases like "because that's how the API works" or "because the model was trained that way" are valid stop points — name them as stop points, not explanations.
- **Don't smuggle in a fix.** The diagnostic explains; the user decides what to do with it. If a fix is obvious, mention it in one line *after* the prose output, not inside it.
- **Output is prose, not labels.** The Wittgensteinian labels are internal scaffolding. The user-facing write-up reads as connected prose. If you find yourself writing "Language-game:" or "Hinges:" in the output, stop and translate.
- **No banned words** (per the user's preferences): no *leverage, robust, comprehensive, seamless, navigate, foster, facilitate*, etc. Plain language.
- **No em dashes.**

## Example 1: Agent output didn't match instruction

**the user:** Why did the scorer come back as a nested rubric again when I told the agent flat plain-English checks?

**Internal analysis (not shown in output):**

- Language-game: prompt design for an LLM scorer (not code execution)
- Hinges: "rubric" reads as structured/tabular by default; "flat" is a weak signal versus the noun "rubric"; the agent doesn't reread prior turns as binding constraints
- Chain: last format-shaping phrase pulled toward "rubric" → training pairs "evaluation scorer" with nested structures → "flat" too weak to override
- Stop point: model format priors from pretraining
- Hinge to test first: whether the agent IS rereading prior constraints

**Output:**

```
**Why did the scorer come back as a nested rubric when I asked for flat plain-English checks?**

This is a question about prompt design for an LLM scorer, not about code execution. The model is doing something its training pulled it toward; the real question is which training pattern won.

Three things have to be true for this explanation to work. The model treats "rubric" and "checks" as near-synonyms for structured tabular output. The instruction "flat" is a weak format signal compared to the noun "rubric." And the agent doesn't reread prior turns as binding constraints; each turn re-derives format from the local prompt.

So the chain runs: the output came back nested because the prompt's last format-shaping phrase pulled toward "rubric." That phrase pulled toward "rubric" because training data overwhelmingly pairs "evaluation scorer" with nested structures. And the agent doesn't override that training prior with "flat" because "flat" is too weak a signal against the strong noun.

The chain ends at the model's format priors from pretraining. Pushing further leaves prompt design entirely and enters "why is the base model like this," which isn't answerable from inside this workflow.

The assumption worth testing first: whether the agent is rereading prior constraints. If it is, the issue is prompt ordering and the fix is to move "flat plain-English, no nesting, no tables" to the final line. If it isn't, the issue is signal strength and the fix is to remove the word "rubric" entirely.
```

## Example 2: Tool failed silently after success signal

**the user:** Why did the Vapi `transfer_personal_trainer` tool fail? The result said "Transfer initiated" but the call dropped immediately.

**Internal analysis (not shown in output):**

- Language-game: voice-agent telephony debugging (SIP-layer protocol mismatch, not static config)
- Hinges: "Transfer initiated" means tool invocation succeeded, not call connected; destination number format is separable from SIP method; `sipVerb` is a config field because carriers differ
- Chain: carrier rejected SIP REFER → REFER is SIP-to-SIP signaling, PSTN transfers need a bridge → config used "refer" explicitly rather than the default
- Stop point: carrier-side SIP support
- Hinge to test first: whether "Transfer initiated" actually means the call connected

**Output:**

```
**Why did the Vapi `transfer_personal_trainer` tool fail when the result said "Transfer initiated"?**

This is a voice-agent telephony question — specifically a SIP-layer protocol mismatch between Vapi and the downstream carrier. It's not about the tool config as a static document.

Three things have to be true here. "Transfer initiated" in the tool result means the tool invocation succeeded, not that the call connected. The destination number format and reachability are separable from the SIP method used to transfer. And Vapi exposes `sipVerb` as a config field precisely because carriers actually differ on what they accept.

So the chain runs: the transfer failed immediately because the carrier rejected the SIP REFER request. The carrier rejected REFER because REFER is a SIP-to-SIP signaling method, and transfers to PSTN phone numbers usually need a bridge (media-relay) instead. The config used `"sipVerb": "refer"` because it was set explicitly rather than left to the bridge default.

The chain ends at carrier-side SIP support. Pushing further leaves the workflow and enters "why does this specific carrier reject REFER for PSTN," which is a telco-config question, not a Vapi question.

The assumption worth testing first: whether "Transfer initiated" actually means the call connected. If it does, the failure is downstream — no answer, voicemail, dropped — and the fix is on the receiving phone, not the sipVerb. If it doesn't, change `"sipVerb": "refer"` to `"sipVerb": "bridge"` or remove the field.
```

## What this skill is not

- Not a debugger. It doesn't run code or inspect logs.
- Not a root-cause-analysis framework. RCA assumes the chain bottoms out at a fixable root; this skill assumes the chain bottoms out at a hinge, which may or may not be fixable.
- Not philosophy for its own sake. The methodology is Wittgensteinian under the hood, but the output reads as an incident report. The point is operational clarity: knowing which assumption to test first.

## Related skill: five-whys

`why-diagnostic` and `five-whys` are paired, not redundant. Use both — they answer different questions.

- **five-whys** is for **incident response.** Something broke that previously worked, the chain bottoms out at a fixable root cause, and the deliverable is a governance update so the failure can't repeat silently. Output ends in a documented fix.
- **why-diagnostic** is for **frame clarification.** The thing isn't necessarily broken; the question is whether you're asking inside the right language-game and what hinges are doing silent work. The chain bottoms out at a hinge, not a root. Output reads as an incident report: it ends at an honest stop point and points at the hinge worth testing first.

When to reach for which:
- Tool failed twice, retry is dangerous, need a documented fix → **five-whys**
- "Why did the agent do X" / "why is this design the right one" / "where am I confused about what this even is" → **why-diagnostic**
- Both can fit → run **why-diagnostic** first to make sure you're in the right language-game, then **five-whys** if a fix is the actual goal.
