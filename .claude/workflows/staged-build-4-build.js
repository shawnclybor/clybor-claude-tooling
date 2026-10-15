export const meta = {
  name: 'staged-build-4-build',
  description: 'Staged build 4/5: build up to 4 open features, one at a time, each independently verified',
  whenToUse: 'After staged-build-3-plan. Run again until every feature passes. Next: staged-build-5-review. args: {brief}',
  phases: [
    { title: 'Read brief', detail: 'paths from the brief' },
    { title: 'List features', detail: 'features still failing, in order' },
    { title: 'Build and verify', detail: 'per feature: build, then an independent verifier; two strikes stops the run' },
    { title: 'Record', detail: 'mark the features that passed' },
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

phase('List features')
const MAX = 4
const todo = await agent(`Read ${DIR}/features.json and return the features with passes: false, in order. ${READ_ONLY}`, {
  label: 'list open features', effort: 'low',
  schema: { type: 'object', required: ['features'], properties: { features: { type: 'array', items: { type: 'object', required: ['id', 'title', 'check'], properties: { id: { type: 'string' }, title: { type: 'string' }, check: { type: 'string' } } } } } },
})
if (!todo) return { error: 'could not read features.json' }
if (!todo.features.length) return { next: 'no open features; run /staged-build-5-review' }
const queue = todo.features.slice(0, MAX)
log(`${todo.features.length} open feature(s); building ${queue.length} this run${todo.features.length > MAX ? ', the rest wait for the next run' : ''}`)

phase('Build and verify')
const VERDICT = { type: 'object', required: ['passes', 'evidence'], properties: { passes: { type: 'boolean' }, evidence: { type: 'string', description: 'the commands run, what they returned, and every failure found' } } }
const results = []
// One feature at a time: features share files, and a fresh agent per feature keeps context small.
for (const f of queue) {
  let feedback = ''
  let verdict = null
  for (let attempt = 1; attempt <= 2; attempt++) {
    await agent(`Start by reading ${DIR}/progress.md, the last 10 git log lines and ${DIR}/PRD.md, then run ${APP}/init.sh. Implement ONLY feature ${f.id} (${f.title}) in ${APP}/, within the constraints in the brief at ${BRIEF}. Run the check: ${f.check}. Append to ${DIR}/progress.md what you changed and what the check returned. Do not edit features.json and do not commit.${feedback ? `\nThe last attempt failed verification:\n${feedback}` : ''}`,
      { label: `${f.id} build (try ${attempt})` })
    verdict = await agent(`Independently verify feature ${f.id} (${f.title}) in ${APP}/. Run ${APP}/init.sh, then: ${f.check}. Use the feature the way a user would, including one bad input. Then prove the check can fail: copy aside each file the mutation touches, apply the mutation from ${DIR}/features.json, run the check and confirm it exits non-zero, then restore each file and confirm with cmp that it matches the copy. Answer passes: false if the mutated check still passes or anything is uncertain. Leave no file changed.`,
      { label: `${f.id} verify (try ${attempt})`, schema: VERDICT })
    if (verdict && verdict.passes) break
    feedback = verdict ? verdict.evidence : 'the verifier returned nothing'
  }
  const passes = !!(verdict && verdict.passes)
  results.push({ id: f.id, passes, evidence: verdict ? verdict.evidence : null })
  log(`${f.id}: ${passes ? 'passes' : 'failed twice'}`)
  if (!passes) { log(`Two strikes on ${f.id}: stopping so a person can look before any third try`); break }
}

phase('Record')
const passed = results.filter(r => r.passes).map(r => r.id)
if (passed.length) await agent(`In ${DIR}/features.json set passes: true for exactly these ids and no others: ${passed.join(', ')}. Change nothing else.`, { label: 'mark passing features', effort: 'low' })
return { results, next: 'try the running app; run /staged-build-4-build again for the next features, or /staged-build-5-review when all pass' }
