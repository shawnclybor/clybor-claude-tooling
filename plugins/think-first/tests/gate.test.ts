import { describe, expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

// Run with: claude plugin test plugins/think-first
// Every test here has a mutant in scripts/mutate.py that must make it fail.

const ST = 'mcp__plugin_think-first_sequential-thinking__sequentialthinking'
const WRITE = 'mcp__notes__create_page'
const READ = 'mcp__notes__get_page'
const THINK = { thoughtNumber: 1, totalThoughts: 1, nextThoughtNeeded: false, thought: 'plan' }

// The floor stands for the engine: tools in `failing` answer with an error, the rest run.
function floor(on: On, opts: { failing?: Record<string, string>; env?: Record<string, string> } = {}) {
  const ran: string[] = []
  mock.env(on, opts.env ?? {})
  on('tool.call', async (_$, e) => {
    ran.push(e.tool)
    const err = opts.failing?.[e.tool]
    return err ? { result: err, text: err, isError: true } : { result: 'ran', text: 'ran' }
  })
  on('prompt.submit', async (_$, e) => ({ text: e.text }))
  return ran
}

const denial = (r: { deny?: string; isError?: boolean; text?: string }) =>
  r.deny ?? (r.isError && r.text?.startsWith('think-first') ? r.text : undefined)

describe('writes', () => {
  test('a write is blocked before any thinking step', async ($, on) => {
    const ran = floor(on)
    const r = await $.tool.call({ tool: WRITE, title: 'x' })
    expect(denial(r)).toContain('is a write')
    expect(ran).toEqual([])
  })

  test('a read is never blocked', async ($, on) => {
    const ran = floor(on)
    const r = await $.tool.call({ tool: READ, id: 'x' })
    expect(denial(r)).toBeUndefined()
    expect(ran).toEqual([READ])
  })

  test('a thinking step unlocks writes for the rest of the turn', async ($, on) => {
    const ran = floor(on)
    await $.tool.call({ tool: ST, ...THINK })
    const a = await $.tool.call({ tool: WRITE, title: 'a' })
    const b = await $.tool.call({ tool: WRITE, title: 'b' })
    expect(denial(a)).toBeUndefined()
    expect(denial(b)).toBeUndefined()
    expect(ran).toEqual([ST, WRITE, WRITE])
  })

  test('a new user message needs a new thinking step', async ($, on) => {
    const ran = floor(on)
    await $.tool.call({ tool: ST, ...THINK })
    await $.prompt.submit({ text: 'next request', wait: false, origin: { kind: 'composer' } })
    const r = await $.tool.call({ tool: WRITE, title: 'x' })
    expect(denial(r)).toContain('is a write')
    expect(ran).toEqual([ST])
  })
})

describe('what counts as a new request', () => {
  test('a background task finishing does not reset the thinking step', async ($, on) => {
    const ran = floor(on)
    await $.tool.call({ tool: ST, ...THINK })
    await $.prompt.submit({ text: 'task done', wait: false, origin: { kind: 'task-notification' } })
    const r = await $.tool.call({ tool: WRITE, title: 'x' })
    expect(denial(r)).toBeUndefined()
    expect(ran).toEqual([ST, WRITE])
  })

  test('a scheduled task firing does reset it', async ($, on) => {
    const ran = floor(on)
    await $.tool.call({ tool: ST, ...THINK })
    await $.prompt.submit({ text: 'scheduled', wait: false, origin: { kind: 'scheduled-trigger' } })
    const r = await $.tool.call({ tool: WRITE, title: 'x' })
    expect(denial(r)).toContain('is a write')
    expect(ran).toEqual([ST])
  })
})

describe('retries', () => {
  test('a tool that just failed is blocked until a thinking step runs', async ($, on) => {
    const ran = floor(on, { failing: { [READ]: 'boom' } })
    await $.tool.call({ tool: READ, id: 'x' })
    const r = await $.tool.call({ tool: READ, id: 'x' })
    expect(denial(r)).toContain('last call failed')
    expect(ran).toEqual([READ])
  })

  test('after a thinking step the retry runs', async ($, on) => {
    const ran = floor(on, { failing: { [READ]: 'boom' } })
    await $.tool.call({ tool: READ, id: 'x' })
    await $.tool.call({ tool: ST, ...THINK })
    const r = await $.tool.call({ tool: READ, id: 'x' })
    expect(denial(r)).not.toContain('think-first')
    expect(ran).toEqual([READ, ST, READ])
  })

  test('thinking earlier in the turn does not cover a later failure', async ($, on) => {
    const ran = floor(on, { failing: { [WRITE]: 'boom' } })
    await $.tool.call({ tool: ST, ...THINK })
    await $.tool.call({ tool: WRITE, title: 'x' })
    const r = await $.tool.call({ tool: WRITE, title: 'x' })
    expect(denial(r)).toContain('last call failed')
    expect(ran).toEqual([ST, WRITE])
  })

  test('a different tool is not held back by another tool failing', async ($, on) => {
    const ran = floor(on, { failing: { [READ]: 'boom' } })
    await $.tool.call({ tool: READ, id: 'x' })
    const r = await $.tool.call({ tool: 'mcp__notes__list_pages' })
    expect(denial(r)).toBeUndefined()
    expect(ran).toEqual([READ, 'mcp__notes__list_pages'])
  })
})

describe('when the thinking tool itself fails', () => {
  test('two real errors mark it unavailable and writes go through with a note', async ($, on) => {
    const ran = floor(on, { failing: { [ST]: 'connection refused' } })
    await $.tool.call({ tool: ST, ...THINK })
    await $.tool.call({ tool: ST, ...THINK })
    const r = await $.tool.call({ tool: WRITE, title: 'x' })
    expect(denial(r)).toBeUndefined()
    expect((r.context ?? []).join(' ')).toContain('unavailable')
    expect(ran).toEqual([ST, ST, WRITE])
  })

  test('one error is not enough to give up on it', async ($, on) => {
    const ran = floor(on, { failing: { [ST]: 'connection refused' } })
    await $.tool.call({ tool: ST, ...THINK })
    const r = await $.tool.call({ tool: WRITE, title: 'x' })
    expect(denial(r)).toContain('is a write')
    expect(ran).toEqual([ST])
  })

  test('a malformed call is a caller mistake, never unavailable', async ($, on) => {
    const ran = floor(on, { failing: { [ST]: 'MCP error -32602: invalid params' } })
    await $.tool.call({ tool: ST, ...THINK })
    await $.tool.call({ tool: ST, ...THINK })
    const r = await $.tool.call({ tool: WRITE, title: 'x' })
    expect(denial(r)).toContain('is a write')
    expect(ran).toEqual([ST, ST])
  })
})

describe('modes and failures of the gate', () => {
  test('warn mode lets the write run and tells Claude', { options: { mode: 'warn' } }, async ($, on) => {
    const ran = floor(on)
    const r = await $.tool.call({ tool: WRITE, title: 'x' })
    expect(denial(r)).toBeUndefined()
    expect((r.context ?? []).join(' ')).toContain('is a write')
    expect(ran).toEqual([WRITE])
  })

  test('a custom writes setting replaces the default', { options: { writes: 'mcp__notes__get_*' } }, async ($, on) => {
    const ran = floor(on)
    const a = await $.tool.call({ tool: READ, id: 'x' })
    const b = await $.tool.call({ tool: WRITE, title: 'x' })
    expect(denial(a)).toContain('is a write')
    expect(denial(b)).toBeUndefined()
    expect(ran).toEqual([WRITE])
  })

  test('a broken pattern blocks MCP calls with the reason', { options: { writes: '/create(/' } }, async ($, on) => {
    const ran = floor(on)
    const r = await $.tool.call({ tool: READ, id: 'x' })
    expect(denial(r)).toContain('settings have errors')
    expect(ran).toEqual([])
  })

  test('a crash inside the gate blocks a write even after thinking', async ($, on) => {
    const ran = floor(on, { env: { THINK_FIRST_FAULT: '1' } })
    await $.tool.call({ tool: ST, ...THINK })
    const r = await $.tool.call({ tool: WRITE, title: 'x' })
    expect(denial(r)).toContain('gate failed')
    // The thinking call is passed through on purpose: blocking it would leave no way out.
    expect(ran).toEqual([ST])
  })
})
