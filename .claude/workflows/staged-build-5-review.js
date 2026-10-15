export const meta = {
  name: 'staged-build-5-review',
  description: 'Staged build 5/5: code, security and PRD-criteria checks of the app, in parallel',
  whenToUse: 'After every feature passes in staged-build-4-build. args: {brief}',
  phases: [
    { title: 'Read brief', detail: 'paths from the brief' },
    { title: 'Review app', detail: 'code reviewer, security auditor and a PRD-criteria check in parallel' },
  ],
}

// One stage per workflow, as the docs advise for sign-off between stages. Every agent runs inside a
// phase listed in meta.phases, so the progress view shows exactly this stage's steps.
// The brief contract is in staged-build-1-understand.js.

if (!args || !args.brief) return { error: 'pass args.brief: the path to the brief markdown file' }
const BRIEF = args.brief
const READ_ONLY = 'Read-only: change no file. Quote paths exactly, list only files you opened, and mark anything you did not verify UNVERIFIED.'

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

phase('Review app')
const CHECKS = [
  { type: 'code-reviewer', ask: `Review ${APP}/ for correctness bugs.` },
  { type: 'security-auditor', ask: `Audit ${APP}/ for injection, path traversal and data written where the brief's constraints forbid it.` },
  { type: 'general-purpose', ask: `Check every success criterion in ${DIR}/PRD.md against ${APP}/ and report green or red for each, with the command output.` },
]
const reports = (await parallel(CHECKS.map(c => () =>
  agent(`${c.ask} The brief is at ${BRIEF}. Flag only issues that affect correctness, security or the PRD's criteria: at most 8, most severe first, each with its file and line. ${READ_ONLY}`,
    { label: c.type, agentType: c.type, phase: 'Review app' })))).filter(Boolean)
if (reports.length < CHECKS.length) log(`${CHECKS.length - reports.length} reviewer(s) returned nothing`)
return { reports }
