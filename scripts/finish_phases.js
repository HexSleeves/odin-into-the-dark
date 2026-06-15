export const meta = {
  name: 'into-the-dark-finish-phases',
  description: 'Finish remaining audit action-plan items as sequential verify-gated batches, stop-on-red, commit per phase',
  phases: [
    { title: 'P8-overlay' }, { title: 'P9-occupancy' }, { title: 'AI-fidelity' },
    { title: 'M1-diet' }, { title: 'D5-recipes' }, { title: 'present-floors' },
    { title: 'web-fs' }, { title: 'final-verify' },
  ],
}

const ROOT = '/Users/lecoqjacob/Developer/games/odin-into-the-dark'

const RESULT_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['phase_id','status','commits','files_changed','summary','verify_passed','blockers'],
  properties: {
    phase_id: { type: 'string' },
    status: { type: 'string', enum: ['green','red','stopped','skipped'] },
    commits: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['sha','subject'], properties: { sha: { type: 'string' }, subject: { type: 'string' } } } },
    files_changed: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
    verify_passed: { type: 'boolean' },
    blockers: { type: 'array', items: { type: 'string' } },
  },
}

const COMMON = `You implement ONE phase of remaining audit work on the Odin roguelike at ${ROOT}. Tree is clean + single-owner at phase start.
Refs: docs/audit-2026-06-13.md (action plan) + docs/legacy-removal-plan-2026-06-14.md. Source is ground truth — re-read/grep before editing. Use \`graphify query\`.
HARD RULES:
- Implement ONLY this phase. Respect project layout: tests in test/ (package main); src/engine raylib-free; src/io=gameio, src/core=gcore; Game heap-alloc in prod.
- Iterate with \`just check\`; run FULL \`just verify\` before committing — it MUST print the success line + exit 0. (The test runner occasionally crashes flaky on signal exit 245/251 — if verify fails ONLY with that and no compile/test error, re-run once; a second failure is real.)
- \`just fmt\` before commit (ODINFMT=~/Developer/games/ols/odinfmt if not on PATH).
- Commit Conventional Commits (feat/perf/refactor), body lists changes, trailer:
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  Stage explicit paths. DO NOT push. DO NOT amend.
- Add/extend tests for new behavior. For SAVE-FORMAT changes: legacy save support was already dropped (pre-release, no save contract) — bump SAVE_VERSION, keep ONLY the new version load path (reject others cleanly), update save convert/restore/write AND the round-trip + layout-invariant tests in test/io/.
- STOP-ON-RED: if verify won't go green or the phase proves larger/riskier than scoped or hits a real design ambiguity, restore ONLY your edited files to leave a clean tree and report status=red/stopped + blockers. Never commit broken code. A clean stop is acceptable.
Return structured result. THIS PHASE:\n`

const PHASES = [
  { id:'P8', phase:'P8-overlay', subject:'feat(debug): toggleable perf/debug overlay + tracking allocator',
    task:`Audit #11 (P8) gap: src/io/perf_timer.odin + scoped timers exist, but there is NO visual overlay and NO tracking allocator. Add: (a) a toggle-key debug overlay (renderer) showing FPS/frame-ms, entity counts, dijkstra recompute count, and the perf_timer channel timings; (b) a tracking_allocator wrapper around the game loop in a DEBUG build to count allocs/leaks per frame, surfaced in the overlay. Gate behind a debug/cheat flag so release is unaffected. Additive only — no gameplay change. Add a test for the perf-overlay state toggle where feasible.` },
  { id:'P9', phase:'P9-occupancy', subject:'perf: O(1) enemy_at via enemy_occupancy grid',
    task:`Audit #18 (P9): enemy_at is a linear scan (src/core/game_utils.odin ~155) called per-cell across ai/gen/gameplay. Add an enemy_occupancy:[MAP_WIDTH*MAP_HEIGHT]i32 grid on Game (index = enemy slot+1, 0 = empty); maintain it on spawn/move/death/cleanup; make enemy_at O(1) reading the grid (keep behavior identical incl. first-match + dead/off-grid handling). BEHAVIOR-NEUTRAL. Add an equivalence test (grid lookup == old linear scan for every cell) and tests for the maintenance points. dijkstra_dirty/flow cache (P7) already done — don't redo.` },
  { id:'AI', phase:'AI-fidelity', subject:'feat(ai): occupancy-aware flow field + Frozen affects combat',
    task:`Audit #23 (depends on P9 grid from the previous phase): (a) make the Dijkstra flow field / enemy pathfinding occupancy-aware so packs route around occupied tiles instead of funneling (use the enemy_occupancy grid); (b) extend the Frozen status so it affects COMBAT (e.g. reduced attack / skipped attack turns), not just movement/ability cost. Small intended AI behavior change, low blast radius. Add tests: frozen enemy's combat is penalized; flow field steers a second enemy around an occupied tile. Keep verify green.` },
  { id:'M1', phase:'M1-diet', subject:'refactor: data-model diet — Ore_Kind enum, i32 dijkstra, right-size caps',
    task:`Audit #15 (M1/P5 remainder): replace Ore_Vein.ore_type:string (src/core/types.odin ~188) with an Ore_Kind enum (drop per-cell color string buffers; derive color from kind); change dijkstra_map [..]int -> i32 (types.odin ~277); drop any remaining dead Tile fields; right-size the fixed grid caps if they over-allocate vs MAP_CELLS. This touches save convert/restore (Save_Ore_Vein) -> bump SAVE_VERSION (drop legacy), update round-trip + layout tests. Verify Game struct shrinks (size assertion). Medium risk — keep round-trip tests green.` },
  { id:'D5', phase:'D5-recipes', subject:'feat(gameplay): data-driven recipes + score-weight tuning',
    task:`Audit #21 remainder: (a) D5 — move the hardcoded RECIPES :: [4]Recipe (src/core/recipes.odin) into data-driven content (data/recipes.json5 loaded via the content manager, like enemies/items), and deepen the materials economy a little (more recipes / material uses) so crafting isn't vestigial; (b) D7 — replace the "placeholder" score weights in compute_run_score (src/render/scores.odin ~35) with sensible tuned values (depth/kills/victory balance). Add tests: recipes load from data; compute_run_score weighting sanity. No save-format change required for recipes (keep recipe defs as content). Keep verify green.` },
  { id:'PF', phase:'present-floors', subject:'refactor(save)!: serialize only present floors (length-prefixed)',
    task:`Audit #16 (HIGH risk — do carefully): replace visited_floors:[MAX_DEPTH+1]Save_Floor (src/io/save_format.odin) with a length-prefixed list of only PRESENT floors (count + index tag per floor) to cut the ~3.9MB blob. Bump SAVE_VERSION (drop legacy). Update save_write (write only present), save_restore (reconstruct sparse), save_convert. EXTEND tests heavily: round-trip with sparse present floors, restore places floors at correct depths, corruption/truncation/oversize still rejected, clamp counts. This is the highest-corruption-risk change on a permadeath save — if you cannot make it provably correct + green, STOP and report. Verify Save_Data shrinks dramatically.` },
  { id:'R5', phase:'web-fs', subject:'feat(engine): web localStorage save backend',
    task:`Audit #22 (R5, large, secondary platform): implement a #+build js Engine_File_System backend in src/engine/file_system_web.odin backed by localStorage (or IndexedDB) via JS interop, replacing the empty stub. Wire read/write/exists/remove/rename to localStorage keys (base64 the ~MB blob). game_engine_config must set config.file_system on the web build. If WASM/JS interop is not feasible in this toolchain within reason, STOP and report what's missing rather than half-wiring. Don't break the desktop path or the engine's raylib-free invariant. Add a headless test for the backend logic where possible.` },
]

const results = []
let stopped = null
for (const p of PHASES) {
  phase(p.phase)
  const res = await agent(COMMON + `phase_id=${p.id}\nconventional_subject="${p.subject}"\n${p.task}`,
    { label: `phase:${p.id}`, phase: p.phase, schema: RESULT_SCHEMA })
  if (!res) { results.push({ phase_id:p.id, status:'red', summary:'agent died', blockers:['agent died'] }); stopped=p.id; break }
  results.push(res)
  log(`${p.id} [${res.status}] ${(res.commits||[]).length} commit(s) — ${(res.summary||'').slice(0,70)}`)
  if (res.status === 'red' || res.status === 'stopped') { stopped=p.id; log(`STOP-ON-RED at ${p.id}`); break }
}

let finalVerify = 'skipped (stopped early)'
if (!stopped) {
  phase('final-verify')
  finalVerify = await agent(
    `Run final \`just verify\` at ${ROOT}; report pass/fail + last ~15 lines. List session commits via \`git log --oneline origin/main..HEAD\`. Run \`graphify update . --force\` best-effort. Do NOT push.`,
    { label:'final-verify', phase:'final-verify' }) || 'final-verify returned null'
}

return JSON.stringify({ stopped, phases: results, finalVerify }, null, 2)
