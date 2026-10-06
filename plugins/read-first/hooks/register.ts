import type { Register } from 'claude-code'
import { bare, decide, isGuarded, parseRules, type Rules } from './rules.ts'

export const register: Register = (on, options) => {
  let rules: Rules
  try {
    rules = parseRules(String(options.rules ?? ''))
  } catch (err) {
    // A rules setting the parser cannot read must not stop the module loading:
    // an unloaded gate lets everything through. Record it and block guarded tools.
    rules = { rules: [], errors: [`the rules setting could not be read (${String(err)})`] }
  }
  const mode = options.mode === 'warn' ? 'warn' : 'enforce'
  const strict = options.strict === true
  const match = options.match === 'first' ? 'first' : 'all'

  // Guide skills loaded this session. Fires for /name, the Skill tool, and a subagent's
  // preloaded skills alike, and only once the skill actually expanded.
  const loaded = new Set<string>()

  on('skill.prompt', async ($, e, next) => {
    const result = await next(e)
    loaded.add(bare(e.skill))
    return result
  })

  on('tool.call', async ($, e, next) => {
    if ((await $.env.get('READ_FIRST_FAULT')) === '1') {
      throw new Error('fault injected with READ_FIRST_FAULT=1')
    }
    const d = decide(e.tool, loaded, rules, { mode, strict, match })
    if (d.kind === 'deny') return { deny: d.reason }
    const result = await next(e)
    if (d.kind === 'warn' && result.deny === undefined) {
      return { ...result, context: [...(result.context ?? []), d.reason] }
    }
    return result
  }).catch(async ($, e, next) => {
    // The gate itself failed. Block what it guards rather than wave it through.
    if (isGuarded(e.tool, rules)) {
      return {
        deny:
          `read-first: blocked ${e.tool} because the gate failed while checking it ` +
          `(${String(next.error)}). It blocks rather than allow when it cannot decide.`,
      }
    }
    return next(e)
  })
}
