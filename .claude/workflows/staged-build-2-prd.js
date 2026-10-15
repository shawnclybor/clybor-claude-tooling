export const meta = {
  name: 'staged-build-2-prd',
  description: 'Staged build 2/5: draft the PRD, review it three ways in parallel, then revise',
  whenToUse: 'After staged-build-1-understand and sign-off on the inventory. Next: staged-build-3-plan. args: {brief}',
  phases: [
    { title: 'Read brief', detail: 'paths from the brief' },
    { title: 'Draft PRD', detail: "the repo's PRD skill, binary success criteria" },
    { title: 'Review PRD', detail: 'simplifier, adversarial reviewer and chaos engineer in parallel' },
    { title: 'Revise PRD', detail: 'fix what matters, list the rest with reasons' },
  ],
}

// One stage per workflow, as the docs advise for sign-off between stages. Every agent runs inside a
// phase listed in meta.phases, so the progress view shows exactly this stage's steps.
// The brief contract is in staged-build-1-understand.js.

if (!args || !args.brief) return { error: 'pass args.brief: the path to the brief markdown file' }
const BRIEF = args.brief
const READ_ONLY = 'Read-only: change no file. Quote paths exactly, list only files you opened, and mark anything you did not verify UNVERIFIED.'
const CHANGELOG = "If this repo's CLAUDE.md requires a change log entry, add one."
const SCOPE = 'Report only issues that affect correctness or the stated requirements: at most 8, most severe first.'

phase('Read brief')
const brief = await agent(`Read the brief at ${BRIEF}. Return its docs and app paths and its "Areas to map" bullets exactly as written. List any required section that is missing in "missing". ${READ_ONLY}`, {
  label: 'read brief', effort: 'low',
  schema: {
    type: 'object', required: ['docs', 'app', 'areas', 'missing'],
    properties: {
      docs: { type: 'string' }, app: { type: 'string' },
      areas: { type: 'array', items: { type: 'object', required: ['name', 'paths'], properties: { name: { type: 'string' }, paths: { type: 'string' } } } },
      missing: { type: 'array', items: { type: 'string' } },
    },
  },
})
if (!brief) return { error: 'could not read the brief' }
if (brief.missing.length) return { error: `the brief is missing: ${brief.missing.join(', ')}` }
const DIR = brief.docs
const APP = brief.app

phase('Draft PRD')
await agent(`Write ${DIR}/PRD.md using this repo's PRD skill. Inputs: the brief at ${BRIEF} (goal, why now, constraints) and ${DIR}/inventory.md. Every constraint in the brief appears in the PRD. Success criteria must be binary, so that a script or a single command can check each one.`,
  { label: 'draft PRD' })

phase('Review PRD')
const LENSES = [
  { type: 'simplifier', ask: 'Find over-engineering: anything the goal does not need.' },
  { type: 'adversarial-reviewer', ask: 'Find claims without a source, success criteria that are not binary, and constraints from the brief that the PRD dropped.' },
  { type: 'chaos-engineer', ask: 'Find failure modes the PRD does not handle: slow or failed calls, bad input, missing sources, stale data shown as current.' },
]
const reviews = (await parallel(LENSES.map(l => () =>
  agent(`Review ${DIR}/PRD.md against the brief at ${BRIEF}. ${l.ask} ${SCOPE} ${READ_ONLY}`,
    { label: l.type, agentType: l.type, phase: 'Review PRD' })))).filter(Boolean)
if (reviews.length < LENSES.length) log(`${LENSES.length - reviews.length} reviewer(s) returned nothing`)

phase('Revise PRD')
await agent(`Revise ${DIR}/PRD.md using these reviews. Fix what affects correctness or requirements. List the rest under "Review notes not taken", with a one-line reason each. ${CHANGELOG}\n${reviews.join('\n---\n')}`,
  { label: 'revise PRD' })
return { reviews: reviews.length, next: `approve ${DIR}/PRD.md, then run /staged-build-3-plan` }
