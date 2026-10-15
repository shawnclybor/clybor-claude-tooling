export const meta = {
  name: 'staged-build-3-plan',
  description: 'Staged build 3/5: turn the PRD into a feature list with a check per feature, then audit it',
  whenToUse: 'After staged-build-2-prd and sign-off on the PRD. Next: staged-build-4-build. args: {brief}',
  phases: [
    { title: 'Read brief', detail: 'paths from the brief' },
    { title: 'Write plan', detail: 'features.json, progress.md, init.sh' },
    { title: 'Audit plan', detail: 'every criterion covered by a check that can fail' },
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

phase('Write plan')
await agent(`Use this repo's planning skill on ${DIR}/PRD.md. Write ${DIR}/features.json as an array of {id, title, prd_criteria: [...], check: "<one shell command that exits 0 only when the feature works>", passes: false}, in build order, each small enough for one focused pass. Write ${DIR}/progress.md (a header, then nothing). Write ${APP}/init.sh, which starts the app and exits non-zero if it does not come up.`,
  { label: 'write plan' })

phase('Audit plan')
const audit = await agent(`Check ${DIR}/features.json against ${DIR}/PRD.md. Every success criterion needs at least one feature whose check could actually fail. Name each criterion left uncovered and each check that cannot fail (for example, a file-exists test on a file the plan creates first). ${READ_ONLY}`,
  { label: 'audit plan' })
return { audit, next: 'review the audit, then run /staged-build-4-build' }
