export const meta = {
  name: 'staged-build-1-understand',
  description: 'Staged build 1/5: map every area the brief names, then find gaps and write the inventory',
  whenToUse: 'Start of a brief-driven build. Read-only except the inventory. Next: staged-build-2-prd. args: {brief}',
  phases: [
    { title: 'Read brief', detail: 'paths and areas to map' },
    { title: 'Map areas', detail: 'one reader per area, in parallel' },
    { title: 'Write inventory', detail: 'search for gaps, check files exist, write inventory.md' },
  ],
}

// One stage per workflow, as the docs advise for sign-off between stages. Every agent runs inside a
// phase listed in meta.phases, so the progress view shows exactly this stage's steps.
//
// The brief is a markdown file in the project. Everything project-specific lives there, never here.
// It needs these sections:
//   ## Goal          what is being built, for whom
//   ## Why now       the reason, in the owner's words
//   ## Areas to map  one bullet per area: a name, then the paths to read (one reader each)
//   ## Constraints   rules the PRD and the build must carry
//   ## Paths         "docs: <dir>" for stage outputs, "app: <dir>" for the code
// The PRD and planning stages use whichever build-pipeline skills this repo's CLAUDE.md routes to.

if (!args || !args.brief) return { error: 'pass args.brief: the path to the brief markdown file' }
const BRIEF = args.brief
const READ_ONLY = 'Read-only: change no file. Quote paths exactly, list only files you opened, and mark anything you did not verify UNVERIFIED.'
const CHANGELOG = "If this repo's CLAUDE.md requires a change log entry, add one."

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

phase('Map areas')
const HEADER = '| Area | Component | Purpose | Inputs | Output | Gate (what stops it, what enforces that) | Files | State (current/draft/superseded, with evidence) |'
const maps = (await parallel(brief.areas.map(a => () =>
  agent(`Read the brief at ${BRIEF} for context. Then map the area "${a.name}": ${a.paths}. Return markdown table rows only, one per component, under exactly this header:\n${HEADER}\nEnd with one line "Open questions:" if you have any. ${READ_ONLY}`,
    { label: a.name, phase: 'Map areas' })))).filter(Boolean)
if (maps.length < brief.areas.length) log(`${brief.areas.length - maps.length} reader(s) returned nothing; the inventory is partial`)

phase('Write inventory')
await agent(`These maps cover the areas in the brief at ${BRIEF}:\n${maps.join('\n\n')}\nFirst find what is missing: search the repo for components, prompts or gates the brief's goal needs that are not listed, and check that every listed file exists. Then write ${DIR}/inventory.md: the merged table, a "Gaps" section with what you found, and the open questions. ${CHANGELOG}`,
  { label: 'find gaps, write inventory' })
return { areas: maps.length, next: `read ${DIR}/inventory.md, then run /staged-build-2-prd` }
