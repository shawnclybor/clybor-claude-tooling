import { describe, expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

// Run with: claude plugin test plugins/read-first
// Every test here has a mutant in scripts/mutate.sh that must make it fail.

const RULES =
  'mcp__notion__* => notion-guide; mcp__mail__send* => mail-guide, compliance-guide'

// The floor stands for the engine beneath the plugin: it "runs" a tool by counting,
// and expands a skill by echoing it. env is mocked so $.env.get has an answer.
function floor(on: On, env: Record<string, string> = {}) {
  const ran: string[] = []
  mock.env(on, env)
  on('tool.call', async (_$, e) => {
    ran.push(e.tool)
    return { result: 'ran' }
  })
  on('skill.prompt', async (_$, e) => ({ text: e.text }))
  return ran
}

// A plugin's deny reaches the caller either as { deny } or as an errored result.
const denial = (r: { deny?: string; isError?: boolean; text?: string }) =>
  r.deny ?? (r.isError ? r.text : undefined)

describe('enforce mode', () => {
  test('a tool no rule names runs untouched', { options: { rules: RULES } }, async ($, on) => {
    const ran = floor(on)
    const r = await $.tool.call({ tool: 'mcp__weather__forecast', city: 'Paris' })
    expect(denial(r)).toBeUndefined()
    expect(ran).toEqual(['mcp__weather__forecast'])
  })

  test('a mapped tool is blocked until its guide is loaded', { options: { rules: RULES } }, async ($, on) => {
    const ran = floor(on)
    const r = await $.tool.call({ tool: 'mcp__notion__fetch', id: 'x' })
    expect(denial(r)).toContain('notion-guide')
    expect(denial(r)).toContain('write-guide-skill')
    expect(ran).toEqual([])
  })

  test('loading the guide lets the same call through', { options: { rules: RULES } }, async ($, on) => {
    const ran = floor(on)
    await $.skill.prompt({ skill: 'notion-guide', text: 'rules' })
    const r = await $.tool.call({ tool: 'mcp__notion__fetch', id: 'x' })
    expect(denial(r)).toBeUndefined()
    expect(ran).toEqual(['mcp__notion__fetch'])
  })

  test('a guide loaded under its plugin prefix counts', { options: { rules: RULES } }, async ($, on) => {
    const ran = floor(on)
    await $.skill.prompt({ skill: 'my-guides:notion-guide', text: 'rules' })
    const r = await $.tool.call({ tool: 'mcp__notion__fetch', id: 'x' })
    expect(denial(r)).toBeUndefined()
    expect(ran).toEqual(['mcp__notion__fetch'])
  })

  test('a different guide does not unlock the tool', { options: { rules: RULES } }, async ($, on) => {
    const ran = floor(on)
    await $.skill.prompt({ skill: 'mail-guide', text: 'rules' })
    const r = await $.tool.call({ tool: 'mcp__notion__fetch', id: 'x' })
    expect(denial(r)).toContain('notion-guide')
    expect(ran).toEqual([])
  })

  test('a tool needing two guides names only the one still missing', { options: { rules: RULES } }, async ($, on) => {
    const ran = floor(on)
    await $.skill.prompt({ skill: 'mail-guide', text: 'rules' })
    const r = await $.tool.call({ tool: 'mcp__mail__send_message', to: 'a' })
    expect(denial(r)).toContain('compliance-guide')
    expect(denial(r)).not.toContain('mail-guide,')
    expect(ran).toEqual([])
  })
})

describe('strict mode', () => {
  test('an MCP tool with no rule is blocked and pointed at write-guide-skill',
    { options: { rules: RULES, strict: true } }, async ($, on) => {
      const ran = floor(on)
      const r = await $.tool.call({ tool: 'mcp__weather__forecast', city: 'Paris' })
      expect(denial(r)).toContain('write-guide-skill')
      expect(ran).toEqual([])
    })

  test('without strict the same tool runs', { options: { rules: RULES, strict: false } }, async ($, on) => {
    const ran = floor(on)
    const r = await $.tool.call({ tool: 'mcp__weather__forecast', city: 'Paris' })
    expect(denial(r)).toBeUndefined()
    expect(ran).toEqual(['mcp__weather__forecast'])
  })
})

describe('warn mode', () => {
  test('a mapped tool runs, and Claude is told which guide it skipped',
    { options: { rules: RULES, mode: 'warn' } }, async ($, on) => {
      const ran = floor(on)
      const r = await $.tool.call({ tool: 'mcp__notion__fetch', id: 'x' })
      expect(denial(r)).toBeUndefined()
      expect(ran).toEqual(['mcp__notion__fetch'])
      expect((r.context ?? []).join(' ')).toContain('notion-guide')
    })
})

describe('when the gate cannot decide, it blocks', () => {
  test('an unreadable rule blocks MCP calls with the reason',
    { options: { rules: 'mcp__notion__* notion-guide' } }, async ($, on) => {
      const ran = floor(on)
      const r = await $.tool.call({ tool: 'mcp__notion__fetch', id: 'x' })
      expect(denial(r)).toContain('rules setting has errors')
      expect(ran).toEqual([])
    })

  test('a crash inside the gate blocks a guarded call even with its guide loaded',
    { options: { rules: RULES } }, async ($, on) => {
      const ran = floor(on, { READ_FIRST_FAULT: '1' })
      await $.skill.prompt({ skill: 'notion-guide', text: 'rules' })
      const r = await $.tool.call({ tool: 'mcp__notion__fetch', id: 'x' })
      expect(denial(r)).toContain('gate failed')
      expect(ran).toEqual([])
    })
})

describe('regex rules and first match', () => {
  const ORDERED = '/__gmail_/ => mail-guide; /^mcp__zapier__/ => zapier-guide'

  test('a /regex/ rule matches anywhere in the tool name', { options: { rules: ORDERED } }, async ($, on) => {
    const ran = floor(on)
    const r = await $.tool.call({ tool: 'mcp__abc123__gmail_send', to: 'a' })
    expect(denial(r)).toContain('mail-guide')
    expect(ran).toEqual([])
  })

  test("with match=all, every matching rule's guide skill is required",
    { options: { rules: ORDERED, match: 'all' } }, async ($, on) => {
      const ran = floor(on)
      await $.skill.prompt({ skill: 'mail-guide', text: 'rules' })
      const r = await $.tool.call({ tool: 'mcp__zapier__gmail_send', to: 'a' })
      expect(denial(r)).toContain('zapier-guide')
      expect(ran).toEqual([])
    })

  test('with match=first, only the first matching rule counts',
    { options: { rules: ORDERED, match: 'first' } }, async ($, on) => {
      const ran = floor(on)
      await $.skill.prompt({ skill: 'mail-guide', text: 'rules' })
      const r = await $.tool.call({ tool: 'mcp__zapier__gmail_send', to: 'a' })
      expect(denial(r)).toBeUndefined()
      expect(ran).toEqual(['mcp__zapier__gmail_send'])
    })

  test('an invalid regex is a rules error, not a silent pass',
    { options: { rules: '/__gmail_(/ => mail-guide' } }, async ($, on) => {
      const ran = floor(on)
      const r = await $.tool.call({ tool: 'mcp__abc__gmail_send', to: 'a' })
      expect(denial(r)).toContain('not a valid regular expression')
      expect(ran).toEqual([])
    })
})
