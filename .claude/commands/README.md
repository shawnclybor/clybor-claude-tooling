# Commands

Slash commands — thin orchestrators that invoke skills or agents.

## Bundled

- **/quality-review** — Full 3-agent team (simplifier + adversarial + chaos) against a plan, file, or proposal
- **/adversarial** — Single-lens review using only the adversarial-reviewer (Opus)
- **/simplify** — Single-lens review using only the simplifier (Sonnet)
- **/chaos** — Single-lens review using only the chaos-engineer (Sonnet)
- **/five-whys** — Walk the five-whys root-cause protocol when something broke
- **/ralph-loop** — Start a Stop-hook-driven autonomous ralph loop with a single prompt and a completion-promise

## Adding commands

Each command is a single `.md` file with YAML frontmatter (`description`). Push real logic into a skill that the command invokes.

Project-specific commands belong in the project's own `.claude/commands/`, not here.
