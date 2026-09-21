# Archify — the layout limits, and where its own docs are

Companion to `scripts/install-archify.sh`. Archify ships good documentation; none of it
states the geometry below, which is what actually decides whether a diagram renders.
Measured against `v2.16.0` (`c826e6c`) by building six diagrams.

## Its own documentation, on disk at the pin

| File | What it covers |
|---|---|
| `~/.claude/skills/archify/SKILL.md` | The generation contract, quality profiles, Mermaid input |
| `references/authoring-contract.md` | Per-type placement guidance — read § Mode placement first |
| `references/viewer-runtime.md` | What a reader can do with a finished page |
| `references/delivery-contract.md` | What `deliver` guarantees and how failures come back |
| `schemas/*.schema.json` | The real field list per type; `common.schema.json` holds the shared enums |
| `node bin/archify.mjs guide "<question>"` | Which diagram type fits, and a copy-ready prompt |

When geometry is the question, the renderer is the document: `renderers/<type>/render-<type>.mjs`
opens with a `layout` object holding every constant.

## The readability floor governs everything

A finished page is rejected by `composition/desktop-readability` unless

    sourceFontPx x (930 / viewBoxWidth) >= 6

930px is the diagram width available at a 1440px desktop viewport. Context text (the
sublabel) is the smallest text, and its size differs per type — 9px architecture, ~8px
workflow, 7px dataflow.

**The trap that costs the most time: narrowing nodes does not help.** The context font
scales with node width, so a narrower node shrinks the text as fast as it shrinks the
canvas, and the ratio barely moves. The only real fixes are fewer columns, shorter copy,
or splitting the diagram.

Practical ceilings that follow: about a dozen nodes on one canvas, viewBox width under
~1240 at 8px context text and under ~1085 at 7px.

## Per type

**Architecture** — free `pos`/`size` coordinates, or `layout.mode: "grid"` with `row`/`col`.
The only type accepting `--repo-root` source evidence, and that needs a **public**
`github.com` origin (`renderers/shared/repository-evidence.mjs:108`), so it is unavailable
to a private repository.

**Workflow** — `col` is capped at **0..5** and lanes are the vertical axis. Author new ones
at `schema_version: 2` for the `readable-v2` layout; v1 is `fixed-v1` legacy geometry. Every
`mainPath` step needs a real edge between it and the next. Two nodes may share a column when
they sit in different lanes, which is how a gate is drawn beside the step it gates — and how
a seven-step pipeline fits in five columns.

**Sequence** — participants across the top, messages carry an explicit `y` (minimum 160).
Participant boxes are a fixed 86px unless `meta.column_fit: "spread"` is set, which almost
any real sublabel needs. Messages must land above `viewBox[1] - 65`. `segments` label time
bands; start the first one clear of the participant row or its label renders behind it.

**Dataflow** — the tightest geometry of the five, and the one to plan on paper first
(`render-dataflow.mjs`, the `layout` object):

- Stage centres at x = 100, 315, 530, 745, 960; `colGap` 215.
- **Rows are 0..4 only**, at fixed y = 128, 242, 356, 470, 584, each node 58 tall.
- Stages are 2..5.
- A node must satisfy `x >= 24`, so a **stage-0 node cannot exceed 152px wide**.
- At that width the clear gap between stage columns is **63px** — narrower than most edge
  labels, so nearly every label needs an explicit `labelAt`.
- Flows want to move forward exactly one stage. Same-stage arrows draw, but their endpoints
  fight the side-direction check.

Clear bands to place labels in, at width 152: vertical x = 182-233, 397-448, 612-663,
827-878; horizontal y = 200-236, 314-350, 428-464, 542-578. Computing all of them in one
pass beats fixing collisions one diagnostic at a time.

**Lifecycle** — main phases use columns 0..4; event and terminal bands use 0..2, where band
column N aligns with main column N+2.

## How to work it

Author the JSON, run `deliver --json`, and read `diagnostics[]`. Each entry carries a stable
`code`, the exact subject, measured evidence, and `supportedFixes` — and where it offers a
`labelAt` point, use that point rather than estimating another offset. Three rounds is normal.

Two failures on the same check means stop guessing and open the renderer's `layout` object.
