// The gate's decision, kept free of the engine so tests and readers can see it whole.
//
// A rule says "this tool needs these guide skills loaded first":
//   mcp__notion__* => notion-guide
//   mcp__mail__send* => mail-guide, compliance-guide
//   /__(create|update)_event$/ => calendar-guide
// Rules are separated by ";" or newlines. A plain pattern is a glob over the tool's full
// name, where "*" matches anything. A pattern wrapped in slashes is a regular expression
// that may match anywhere in the name; anchor it with ^ and $ when that matters.
// A guide is a skill name; a "plugin:" prefix is ignored.

export type Rule = { pattern: string; re: RegExp; guides: string[] }
export type Rules = { rules: Rule[]; errors: string[] }
export type Mode = 'enforce' | 'warn'
export type Match = 'all' | 'first'
export type Decision =
  | { kind: 'allow' }
  | { kind: 'deny' | 'warn'; reason: string }

export const GENERATOR = 'write-guide-skill'

// "my-plugin:notion-guide" and "notion-guide" are the same guide skill.
export const bare = (skill: string): string => skill.slice(skill.lastIndexOf(':') + 1).trim()

const globToRegExp = (glob: string): RegExp =>
  new RegExp('^' + glob.split('*').map(s => s.replace(/[.+?^${}()|[\]\\]/g, '\\$&')).join('.*') + '$')

const toRegExp = (pattern: string): RegExp =>
  pattern.length > 2 && pattern.startsWith('/') && pattern.endsWith('/')
    ? new RegExp(pattern.slice(1, -1))
    : globToRegExp(pattern)

export function parseRules(text: string): Rules {
  const rules: Rule[] = []
  const errors: string[] = []
  for (const raw of text.split(/[;\n]/)) {
    const line = raw.trim()
    if (!line || line.startsWith('#')) continue
    const m = /^(\S+)\s*=>\s*(.+)$/.exec(line)
    const guides = m ? m[2]!.split(',').map(bare).filter(Boolean) : []
    if (!m || guides.length === 0) {
      errors.push(`"${line}" is not of the form "tool-pattern => guide[, guide]"`)
      continue
    }
    try {
      rules.push({ pattern: m[1]!, re: toRegExp(m[1]!), guides })
    } catch (err) {
      errors.push(`"${m[1]}" is not a valid regular expression (${String(err)})`)
    }
  }
  return { rules, errors }
}

// Tools the gate must never wave through when it cannot decide: every MCP tool, and
// any tool a readable rule names. Built-in tools no rule names stay untouched, so a
// broken gate cannot take Read, Edit or Bash down with it.
export const isGuarded = (tool: string, r: Rules): boolean =>
  tool.startsWith('mcp__') || r.rules.some(rule => rule.re.test(tool))

// The guide skills a tool needs: from every matching rule, or only the first one.
export function neededGuides(tool: string, r: Rules, match: Match): string[] {
  const hits = r.rules.filter(rule => rule.re.test(tool))
  const chosen = match === 'first' ? hits.slice(0, 1) : hits
  return [...new Set(chosen.flatMap(rule => rule.guides))]
}

const fix = `If no skill by that name exists yet, use the ${GENERATOR} skill to create it.`

export function decide(
  tool: string,
  loaded: ReadonlySet<string>,
  r: Rules,
  opts: { mode: Mode; strict: boolean; match?: Match },
): Decision {
  const verdict = (reason: string): Decision => ({ kind: opts.mode === 'warn' ? 'warn' : 'deny', reason })

  if (r.errors.length > 0 && isGuarded(tool, r)) {
    return verdict(
      `read-first: blocked ${tool} because the gate's rules setting has errors, so it cannot tell ` +
        `which guide skill this tool needs. ${r.errors.join('; ')}. Fix the rules with /plugin configure.`,
    )
  }

  const needed = neededGuides(tool, r, opts.match ?? 'all')

  if (needed.length === 0) {
    if (opts.strict && tool.startsWith('mcp__')) {
      return verdict(
        `read-first: blocked ${tool} because no guide skill is mapped to it and strict mode is on. ` +
          `Use the ${GENERATOR} skill to write one for this tool, then add a rule for it.`,
      )
    }
    return { kind: 'allow' }
  }

  const missing = needed.filter(g => !loaded.has(g))
  if (missing.length === 0) return { kind: 'allow' }

  const names = missing.join(', ')
  const plural = missing.length > 1
  return verdict(
    `read-first: blocked ${tool} until the ${names} guide skill${plural ? 's are' : ' is'} loaded. ` +
      `Load ${plural ? 'them' : 'it'} with the Skill tool, then retry this same call. ${fix}`,
  )
}
