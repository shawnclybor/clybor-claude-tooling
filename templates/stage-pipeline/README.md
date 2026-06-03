# Stage Pipeline Template

For stage-shaped work only: a fixed sequence of steps where a human reviews the output
between steps (research → draft → final; data → eval → report). Not for hub-style or
event-driven work.

## Usage

1. Copy this folder to where the work lives (e.g., `working/{pipeline-name}/` or
   `docs/PRDs/{slug}/stages/`)
2. Rename/renumber stages to fit — zero-padded prefixes encode execution order;
   reordering = renaming folders
3. Fill each stage's `CONTEXT.md` contract (Inputs / Process / Outputs) — keep it
   under 80 lines
4. Run stages in folder order. A stage reads ONLY its declared Inputs (usually the
   previous stage's `output/` plus named reference files) and writes to its own
   `output/`

**The gate:** the human inspects a stage's `output/` before the next stage runs.
Edited or not, the next stage picks up whatever they left — every output is an
edit surface.

Pattern source: Van Clief & McDermott, Interpretable Context Methodology
(arXiv:2603.16021).
