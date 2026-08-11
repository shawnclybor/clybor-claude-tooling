---
name: plugin-builder
description: Build, package, and ship a Cowork plugin (`.plugin`) from one or more skills. Covers plugin structure and packaging (zip from inside the plugin dir so `.claude-plugin/plugin.json` sits at the archive root), the mandatory version bump on every rebuild, backing up the prior bundle, the 1024-char SKILL.md description cap, presenting via sandbox paths, marketplace registration, and how PreToolUse hooks behave in Cowork — they fire and hard-block on Bash and Write on both local and cloud, but fail open when the hook script crashes, so the real gate stays in the skill's own script, never only in a hook. Use when creating a new plugin, adding a skill to one, rebuilding or repackaging, wiring a plugin hook, registering in the marketplace, or presenting a `.plugin` for install. Triggers — "build a plugin", "package this as a plugin", "add a hook to the plugin", "rebuild the plugin", "bump the plugin version", "ship a plugin".
---

# Plugin Builder

Build a Cowork plugin — a bundle of one or more skills, optionally with hooks — and ship it. A `.plugin` is a zip; the source of truth is the unpacked tree, never the zip. This is the plugin counterpart to a single-skill builder.

## Plugin layout

Plugins live under `plugins/<name>/` and are registered in `.claude-plugin/marketplace.json` (mirror an existing plugin under `plugins/`):

```
plugins/<name>/
├── .claude-plugin/plugin.json     name, version, description, author
├── skills/<skill>/SKILL.md        one dir per skill
├── hooks/hooks.json               optional — PreToolUse/PostToolUse gates
└── .mcp.json                      optional — MCP servers
```

`plugin.json` is the manifest; `marketplace.json` lists the plugin with a `git-subdir` source pinned to a `sha`. A published sha is permanent — a bad publish is fixed only by a new commit + re-pin, so treat publish as a deliberate act.

## Build rules

1. **Zip from inside the plugin dir.** `cd plugins/<name> && zip -r <name>.plugin .` — `.claude-plugin/plugin.json` must sit at the archive root. Zipping the parent (`zip -r out.plugin <name>/`) nests it one level and install fails with "missing .claude-plugin/plugin.json".
2. **Bump `plugin.json` `version` on every rebuild.** Cowork caches by version, so a rebuild without a bump serves the old bundle silently. Patch = content fix; minor = skill added; major = skill removed/renamed. Update `version`, `description`, and `keywords` together.
3. **Back up before overwrite.** `cp <name>.plugin <name>.plugin.bak-$(date +%Y%m%d-%H%M%S)` before repacking.
4. **Every SKILL.md `description` ≤ 1024 chars.** Over the cap fails install with a generic "PLUGIN VALIDATION FAILED" and no length hint. Measure every skill before packaging:
   ```bash
   awk '/^---$/{c++;next} c==1 && /^description:/{sub(/^description: */,"");printf "%d %s\n",length,FILENAME}' skills/*/SKILL.md | sort -rn
   ```
   Trim over-cap descriptions by cutting prose examples; keep triggers and anchor terms.
5. **Present via sandbox paths.** `mcp__cowork__present_files` resolves the sandbox namespace, not the host: `/sessions/<id>/mnt/outputs/<name>.plugin`, not a host path under the repo.
6. **Source of truth is the unpacked tree.** Edit `skills/<skill>/SKILL.md`, then repack. Never edit the `.plugin` zip. Read a shipped manifest with `unzip -p <name>.plugin .claude-plugin/plugin.json`.
7. **Cowork write-protection.** In a Cowork session, `.claude/` is write-protected. New plugin source goes under the plugin dir (e.g. `plugins/<name>/skills/...` or `cowork/<name>/skills/...`), not under `.claude/skills/`.

## Hooks — what a plugin hook can and cannot do

Plugins are the only way to run hooks in Cowork: `settings.json` hooks are inert there; the plugin `hooks/hooks.json` slot is the path that loads. A PreToolUse hook **fires on every tool and can hard-block** a call (exit 2, or a JSON `permissionDecision:deny`) — confirmed on both local and cloud Cowork, including the render path (the Bash tool `mcp__workspace__bash` and `Write`).

But a hook **fails open**: if the hook script exits non-zero without an explicit deny (a crash), the tool runs anyway, silently. So:

- **A hook is a backstop, never the sole gate.** Put the real enforcement in the skill's own script — the script refuses the bad action itself and exits non-zero. The hook adds harness-level blocking only while it runs cleanly.
- **Key the matcher on a precise signal**, e.g. a Bash command that invokes the sanctioned script. A loose substring-keyed deny also blocks your own greps, audits, and diagnostics that merely mention the phrase.
- **Paths:** `CLAUDE_PROJECT_DIR` and `PWD` point at the ephemeral session-outputs dir, not the repo. Resolve scripts from `CLAUDE_PLUGIN_ROOT` or an absolute path.
- **Logging:** the hook runs in a different filesystem namespace than the workspace tool, so a log the hook writes to `/tmp` is not visible to workspace bash. Write to a shared sink, and add a visible canary so a skipped hook is not silent.
- A hook log captures serialized tool **input** (commands, file paths — which can include sensitive identifiers), not tool output. Treat it as sensitive: per-session, access-controlled, and kept out of any public repo.

## Pre-flight checklist

- [ ] `plugin.json` `version` bumped vs the last shipped bundle
- [ ] `description` and `keywords` mention every skill in the bundle
- [ ] every SKILL.md `description` ≤ 1024 chars (awk check above)
- [ ] prior `.plugin` backed up with a dated suffix
- [ ] zipped from inside the plugin dir (manifest at archive root); verify `unzip -l`
- [ ] `plugin.json` and `marketplace.json` are valid JSON (`jq .`)
- [ ] if a skill was added: router row present and names the skill by its exact frontmatter `name`
- [ ] hook (if any) keys on a precise signal, resolves paths absolutely, and is backed by an in-script gate
- [ ] presenting via a sandbox path

## Validate

Run the skill gates on each skill before packaging (`validate-skill.py` or equivalent, plus the skill's own anchor test). Then `jq . plugins/<name>/.claude-plugin/plugin.json` and `unzip -l <name>.plugin` to confirm structure.
