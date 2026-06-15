export const meta = {
  name: 'into-the-dark-remove-legacy-full',
  description: 'Remove all confirmed legacy/dead code (18 items) + 4 approved needs-decision clusters, sequential verify-gated stop-on-red',
  phases: [
    { title: 'core' }, { title: 'io-save_query' }, { title: 'render' },
    { title: 'gameplay-gen-input' }, { title: 'engine-tilestate' }, { title: 'aliases' },
    { title: 'engine-surface' }, { title: 'levelup-hardwire' }, { title: 'event-manager' },
    { title: 'light-source-save' }, { title: 'final-verify' },
  ],
}

const ROOT = '/Users/lecoqjacob/Developer/games/odin-into-the-dark'
const PLAN = 'docs/legacy-removal-plan-2026-06-14.md'

const RESULT_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['batch_id','status','commits','files_changed','summary','verify_passed','blockers'],
  properties: {
    batch_id: { type: 'string' },
    status: { type: 'string', enum: ['green','red','stopped','skipped'] },
    commits: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['sha','subject'], properties: { sha: { type: 'string' }, subject: { type: 'string' } } } },
    files_changed: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
    verify_passed: { type: 'boolean' },
    blockers: { type: 'array', items: { type: 'string' } },
  },
}

const COMMON = `You are removing ONE batch of legacy/dead code from the Odin roguelike at ${ROOT}. The working tree is clean + single-owner at batch start.
Authoritative spec: read ${PLAN} and find the per-item detail (removal_note + proof) for THIS batch's item ids. Source is ground truth — re-grep to confirm no live (non-test) caller before deleting each symbol.
HARD RULES:
- Remove ONLY this batch's items. Leave defensive fallbacks, active build flags, and anything not in this batch untouched.
- Before deleting a symbol: grep src/ AND test/ for callers. If a live non-test caller exists that the plan didn't account for, do NOT delete it — set status=stopped with the blocker.
- Tests live in test/ (package main); src/engine stays raylib-free; src/io=gameio, src/core=gcore. Update/delete coupled tests as the removal_note specifies.
- Iterate with \`just check\`; run FULL \`just verify\` before committing — it MUST print the success line + exit 0.
- \`just fmt\` before commit (odinfmt not on PATH: prefix \`ODINFMT=~/Developer/games/ols/odinfmt\`).
- Commit Conventional Commits with the given subject, body listing removed symbols, trailer:
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  Stage ONLY your files (explicit paths). DO NOT push. DO NOT amend.
- STOP-ON-RED: if verify won't go green or a live caller blocks you, restore ONLY your edited files (git restore <your paths>) to leave a clean tree, and report status=red/stopped + blockers. Never commit broken code.
Return structured result. THIS BATCH:\n`

const BATCHES = [
  { id:'B1', phase:'core', subject:'refactor(core): remove dead constants, enum, and accessor',
    task:`Items L-core-1, L-core-2, L-core-3, L-core-4 (files: core/content_ids.odin, core/directions.odin, core/game_utils.odin, core/types.odin). Delete the dead consts/enum/accessor per their removal_notes; grep-confirm zero live callers first.` },
  { id:'B2', phase:'io-save_query', subject:'refactor(io): delete orphaned save_exists query module',
    task:`Item L-save-1: delete the orphaned src/io/save_query.odin (whole file) per removal_note. Confirm nothing imports/calls its procs. Remove any now-dead test referencing it.` },
  { id:'B3', phase:'render', subject:'refactor(render): drop superseded title-fx, color wrappers, and empty stubs',
    task:`Items ER-titlefx-1, ER-rendercolor-1, ER-stubs-1 (files: render/render_title_fx.odin, render/render_color.odin, render/render_hud.odin, render/render_minimap.odin, render/render_ui.odin). Delete superseded/empty-stub code per removal_notes; grep-confirm no live callers.` },
  { id:'B4', phase:'gameplay-gen-input', subject:'refactor(gameplay,gen,input): remove orphaned helpers',
    task:`Items L-gameplay-1, L-gen-1, L-input-1 (files: gameplay/events.odin, gen/mapgen_profile.odin, input/manager.odin). Delete the orphaned helpers per removal_notes; grep-confirm dead.` },
  { id:'B5', phase:'engine-tilestate', subject:'refactor(engine): remove bypassed Tile_State single-field accessors',
    task:`Item ER-tilestate-accessors-1 (engine/tile_state_manager.odin + test/engine/tile_state_manager_test.odin). Remove the bypassed single-field accessors and their coupled test assertions per removal_note. Keep the live accessors.` },
  { id:'B6', phase:'aliases', subject:'refactor: prune dead per-package re-export aliases',
    task:`Items L-alias-ai-1, L-alias-gameplay-1, L-alias-gen-1, L-alias-input-1, L-alias-input-2, L-alias-io-1 (files: ai/common.odin, gameplay/common.odin, gen/common.odin, input/common.odin, io/save_common.odin). Delete ONLY aliases proven unused in their consuming package. For L-alias-io-1: inline the in-file clear_visited_floors call before deleting that alias (per removal_note). Re-grep each alias name (used even once = keep).` },
  { id:'B7', phase:'engine-surface', subject:'refactor(engine): trim unused texture/audio wrappers, ctor helpers, test-only getters',
    task:`APPROVED needs_decision cluster "Engine abstraction surface": items ER-texture-wrappers-1, ER-audio-wrappers-1, ER-ctor-helpers-1 (engine_vec2_make/rect_make), ER-testonly-accessors-1 (~24 test-only manager getters). Remove those proven to have no live non-test caller; for test-only getters, also remove/adjust the tests that only exist to exercise them (or the getter if the test is the sole caller). Re-grep each symbol. If any is actually used in production, KEEP it and note it. Keep raylib-free engine invariant.` },
  { id:'B8', phase:'levelup-hardwire', subject:'refactor(gameplay): hardwire level-ups on; remove LEVELUP_ENABLED flag',
    task:`APPROVED: hardwire LEVELUP_ENABLED on (item L-flags-2). Delete the LEVELUP_ENABLED #config in core/gameplay_tuning.odin + any alias (ai/common, test_imports), remove the runtime \`if LEVELUP_ENABLED\` / \`when\` guards so milestone level-ups are always enabled, and delete the flag-off test. Same treatment as the earlier LIGHT_AFFECTS_DETECTION removal. Grep-confirm zero LEVELUP_ENABLED refs remain. just verify green.` },
  { id:'B9', phase:'event-manager', subject:'refactor(engine): remove half-wired Event_Manager subsystem',
    task:`APPROVED (riskier) needs_decision item ER-event-subsystem-1: remove the half-wired Event_Manager subsystem per removal_note. Grep ALL of src/ + test/ for every Event_Manager symbol/field/registration; remove the struct, its engine field, init/registration, and any dead emit/consume procs. If ANY live production path uses it, STOP (status=stopped) and report — do not rip out something load-bearing. just verify green.` },
  { id:'B10', phase:'light-source-save', subject:'refactor(save)!: drop never-populated Light_Source field; bump save format v11->v12',
    task:`APPROVED save-format change (item L-core-5), MUST BE LAST. Remove the never-populated Light_Source field/array per removal_note. This shifts the save binary layout, so: bump SAVE_VERSION 11->12 in io/save_format.odin, make load_save_data accept only v12 (reject others cleanly as the v11-only path already does), update save_write/restore/convert to stop writing/reading the field, and update the v11/v12 layout-invariant + round-trip tests (rename to v12, fix size relationships). Pre-release: no save contract, dropping old saves is fine. Grep-confirm the field has no live populator. just verify green. Use \`!\` in the conventional subject (breaking save format).` },
]

const results = []
let stopped = null
for (const b of BATCHES) {
  phase(b.phase)
  const res = await agent(COMMON + `id=${b.id}\nconventional_subject="${b.subject}"\n${b.task}`,
    { label: `remove:${b.id}`, phase: b.phase, schema: RESULT_SCHEMA })
  if (!res) { results.push({ batch_id:b.id, status:'red', summary:'agent died', blockers:['agent died'] }); stopped=b.id; break }
  results.push(res)
  log(`${b.id} [${res.status}] ${(res.commits||[]).length} commit(s) — ${(res.summary||'').slice(0,70)}`)
  if (res.status === 'red' || res.status === 'stopped') { stopped=b.id; log(`STOP-ON-RED at ${b.id}`); break }
}

let finalVerify = 'skipped (stopped early)'
if (!stopped) {
  phase('final-verify')
  finalVerify = await agent(
    `Run final \`just verify\` at ${ROOT}; report pass/fail (exit 0 + success line) + last ~15 lines. List session commits via \`git log --oneline origin/main..HEAD\`. Run \`graphify update . --force\` best-effort (ignore failure). Do NOT push.`,
    { label:'final-verify', phase:'final-verify' }) || 'final-verify returned null'
}

return JSON.stringify({ stopped, removals: results, finalVerify }, null, 2)
