export const meta = {
  name: 'staged-build',
  description: 'Brief-driven build in five stages, one per run: understand, prd, plan, build, review',
  whenToUse: 'A new build that needs a mapped starting point, a reviewed PRD, testable features and an independent check. Run the stages in order and sign off between them. args: {brief, stage}',
  phases: [
    { title: 'Understand', detail: 'one reader per area in the brief, then a completeness critic' },
    { title: 'PRD', detail: 'draft, three-lens review, revise' },
    { title: 'Plan', detail: 'feature list with a check per feature, then an audit' },
    { title: 'Build', detail: 'one feature at a time: implement, independent verify, two strikes' },
    { title: 'Review', detail: 'code, security and PRD criteria, in parallel' },
  ],
}

// The brief is a markdown file in the project. Everything project-specific lives there, never here.
// It needs these sections:
//   ## Goal          what is being built, for whom
//   ## Why now       the reason, in the owner's words
//   ## Areas to map  one bullet per area: a name, then the paths to read (one reader each)
//   ## Constraints   rules the PRD and the build must carry
//   ## Paths         "docs: <dir>" for stage outputs, "app: <dir>" for the code
// The PRD and planning steps use whichever build-pipeline skills this repo's CLAUDE.md routes to.

if (!args || !args.brief) return { error: 'pass args.brief: the path to the brief markdown file' }
const BRIEF = args.brief
const stage = args.stage || 'understand'
const STAGES = ['understand', 'prd', 'plan', 'build', 'review']
if (!STAGES.includes(stage)) return { error: `unknown stage "${stage}"; use ${STAGES.join(', ')}` }

const READ_ONLY = 'Read-only: change no file. Quote paths exactly, list only files you opened, and mark anything you did not verify UNVERIFIED.'
const CHANGELOG = "If this repo's CLAUDE.md requires a change log entry, add one."
const SCOPE = 'Report only issues that affect correctness or the stated requirements: at most 8, most severe first.'

const brief = await agent(`Read the brief at ${BRIEF}. Return its docs and app paths and its "Areas to map" bullets exactly as written. List any required section that is missing in "missing". ${READ_ONLY}`, {
  label: 'read-brief', effort: 'low',
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

if (stage === 'understand') {
  phase('Understand')
  const HEADER = '| Area | Component | Purpose | Inputs | Output | Gate (what stops it, what enforces that) | Files | State (current/draft/superseded, with evidence) |'
  const maps = (await parallel(brief.areas.map(a => () =>
    agent(`Read the brief at ${BRIEF} for context. Then map the area "${a.name}": ${a.paths}. Return markdown table rows only, one per component, under exactly this header:\n${HEADER}\nEnd with one line "Open questions:" if you have any. ${READ_ONLY}`,
      { label: `read:${a.name}` })))).filter(Boolean)
  if (maps.length < brief.areas.length) log(`${brief.areas.length - maps.length} reader(s) returned nothing; the inventory is partial`)
  await agent(`These maps cover the areas in the brief at ${BRIEF}:\n${maps.join('\n\n')}\nFirst find what is missing: search the repo for components, prompts or gates the brief's goal needs that are not listed, and check that every listed file exists. Then write ${DIR}/inventory.md: the merged table, a "Gaps" section with what you found, and the open questions. ${CHANGELOG}`,
    { label: 'critic-and-write' })
  return { stage, areas: maps.length, next: `read ${DIR}/inventory.md, then run stage "prd"` }
}

if (stage === 'prd') {
  phase('PRD')
  await agent(`Write ${DIR}/PRD.md using this repo's PRD skill. Inputs: the brief at ${BRIEF} (goal, why now, constraints) and ${DIR}/inventory.md. Every constraint in the brief appears in the PRD. Success criteria must be binary, so that a script or a single command can check each one.`,
    { label: 'draft-prd' })
  const LENSES = [
    { type: 'simplifier', ask: 'Find over-engineering: anything the goal does not need.' },
    { type: 'adversarial-reviewer', ask: 'Find claims without a source, success criteria that are not binary, and constraints from the brief that the PRD dropped.' },
    { type: 'chaos-engineer', ask: 'Find failure modes the PRD does not handle: slow or failed calls, bad input, missing sources, stale data shown as current.' },
  ]
  const reviews = (await parallel(LENSES.map(l => () =>
    agent(`Review ${DIR}/PRD.md against the brief at ${BRIEF}. ${l.ask} ${SCOPE} ${READ_ONLY}`,
      { label: `review:${l.type}`, agentType: l.type })))).filter(Boolean)
  await agent(`Revise ${DIR}/PRD.md using these reviews. Fix what affects correctness or requirements. List the rest under "Review notes not taken", with a one-line reason each. ${CHANGELOG}\n${reviews.join('\n---\n')}`,
    { label: 'revise-prd' })
  return { stage, reviews: reviews.length, next: `approve ${DIR}/PRD.md, then run stage "plan"` }
}

if (stage === 'plan') {
  phase('Plan')
  await agent(`Use this repo's planning skill on ${DIR}/PRD.md. Write ${DIR}/features.json as an array of {id, title, prd_criteria: [...], check: "<one shell command that exits 0 only when the feature works>", passes: false}, in build order, each small enough for one focused pass. Write ${DIR}/progress.md (a header, then nothing). Write ${APP}/init.sh, which starts the app and exits non-zero if it does not come up.`,
    { label: 'plan' })
  const audit = await agent(`Check ${DIR}/features.json against ${DIR}/PRD.md. Every success criterion needs at least one feature whose check could actually fail. Name each criterion left uncovered and each check that cannot fail (for example, a file-exists test on a file the plan creates first). ${READ_ONLY}`,
    { label: 'plan-audit' })
  return { stage, audit, next: 'review the audit, then run stage "build"' }
}

if (stage === 'build') {
  phase('Build')
  const MAX = 4
  const todo = await agent(`Read ${DIR}/features.json and return the features with passes: false, in order. ${READ_ONLY}`, {
    label: 'list-features', effort: 'low',
    schema: { type: 'object', required: ['features'], properties: { features: { type: 'array', items: { type: 'object', required: ['id', 'title', 'check'], properties: { id: { type: 'string' }, title: { type: 'string' }, check: { type: 'string' } } } } } },
  })
  if (!todo) return { stage, error: 'could not read features.json' }
  const queue = todo.features.slice(0, MAX)
  if (todo.features.length > MAX) log(`Building ${MAX} of ${todo.features.length} open features this run; the rest wait for the next run`)
  const VERDICT = { type: 'object', required: ['passes', 'evidence'], properties: { passes: { type: 'boolean' }, evidence: { type: 'string', description: 'the commands run, what they returned, and every failure found' } } }
  const results = []
  // One feature at a time: features share files, and a fresh agent per feature keeps context small.
  for (const f of queue) {
    let feedback = ''
    let verdict = null
    for (let attempt = 1; attempt <= 2; attempt++) {
      await agent(`Start by reading ${DIR}/progress.md, the last 10 git log lines and ${DIR}/PRD.md, then run ${APP}/init.sh. Implement ONLY feature ${f.id} (${f.title}) in ${APP}/, within the constraints in the brief at ${BRIEF}. Run the check: ${f.check}. Append to ${DIR}/progress.md what you changed and what the check returned. Do not edit features.json and do not commit.${feedback ? `\nThe last attempt failed verification:\n${feedback}` : ''}`,
        { label: `implement:${f.id}#${attempt}` })
      verdict = await agent(`Independently verify feature ${f.id} (${f.title}) in ${APP}/. Run ${APP}/init.sh, then: ${f.check}. Use the feature the way a user would, including one bad input. Answer passes: false if anything is uncertain. Change no files.`,
        { label: `verify:${f.id}#${attempt}`, schema: VERDICT })
      if (verdict && verdict.passes) break
      feedback = verdict ? verdict.evidence : 'the verifier returned nothing'
    }
    const passes = !!(verdict && verdict.passes)
    results.push({ id: f.id, passes, evidence: verdict ? verdict.evidence : null })
    if (!passes) { log(`Two strikes on ${f.id}: stopping so a person can look before any third try`); break }
  }
  const passed = results.filter(r => r.passes).map(r => r.id)
  if (passed.length) await agent(`In ${DIR}/features.json set passes: true for exactly these ids and no others: ${passed.join(', ')}. Change nothing else.`, { label: 'mark-passing', effort: 'low' })
  return { stage, results, next: 'try the running app; run "build" again for the next features, or "review" when all pass' }
}

phase('Review')
const CHECKS = [
  { type: 'code-reviewer', ask: `Review ${APP}/ for correctness bugs.` },
  { type: 'security-auditor', ask: `Audit ${APP}/ for injection, path traversal and data written where the brief's constraints forbid it.` },
  { type: 'general-purpose', ask: `Check every success criterion in ${DIR}/PRD.md against ${APP}/ and report green or red for each, with the command output.` },
]
const reports = (await parallel(CHECKS.map(c => () =>
  agent(`${c.ask} The brief is at ${BRIEF}. Flag only issues that affect correctness, security or the PRD's criteria: at most 8, most severe first, each with its file and line. ${READ_ONLY}`,
    { label: `review:${c.type}`, agentType: c.type })))).filter(Boolean)
return { stage, reports }
