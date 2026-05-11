# Commands

Slash commands — thin orchestrators that invoke skills or agents. Each is a single-purpose entry point.

## Bundled

- **/quality-review** — Run the full 3-agent team (simplifier + adversarial + chaos) against a plan, file, or proposal.
- **/adversarial** — Single-lens review using only the adversarial-reviewer (Opus). Use when you want the reasoning challenge without simplification or robustness analysis.
- **/simplify** — Single-lens review using only the simplifier (Sonnet). Use when you want only the KISS / YAGNI lens.
- **/chaos** — Single-lens review using only the chaos-engineer (Sonnet). Use when you want only the robustness / edge-case lens.
- **/five-whys** — Walk the five-whys root-cause protocol when something broke unexpectedly.
- **/dev-loop** — Run the 7-stage development workflow against a new feature or non-trivial change.

## Adding commands

Each command is a single `.md` file with YAML frontmatter (`description`). Commands should be thin — push real logic into a skill that the command invokes.

Project-specific commands belong in the project's own `.claude/commands/`, not here.
