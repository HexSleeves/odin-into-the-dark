export const meta = {
  name: 'into-the-dark-apply',
  description: 'Apply audit findings batch-by-batch (sequential, stop-on-red, commit per batch, no push) for the Odin roguelike',
  phases: [
    { title: 'Baseline', detail: 'commit current green WIP as clean conventional commits' },
    { title: 'Finish-criticals', detail: 'C1 .bak load fallback + regression tests for landed fixes' },
    { title: 'Optimize', detail: 'P3 scores cache, P2 minimap scratch, P4 dedup, P6-P7 dijkstra cache' },
    { title: 'Pause-menu', detail: 'R11 Escape -> pause/confirm scene' },
    { title: 'Save-diet', detail: 'M1-P5 Tile diet + DROP legacy v2-v10 migrations' },
    { title: 'Gameplay', detail: 'D7 scoring, D1 light-detection (flagged), D8 combat feedback, D3 levelup (flagged)' },
    { title: 'Onboarding', detail: 'D4 first-encounter hints (appends to v11)' },
    { title: 'CI-docs', detail: 'T1 ci flag fix, README cleanup' },
    { title: 'Final-verify', detail: 'full just verify + graphify update' },
  ],
}

const ROOT = '/Users/lecoqjacob/Developer/games/odin-into-the-dark'

const RESULT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['batch_id','title','status','commits','files_changed','summary','verify_passed','verify_tail','blockers','follow_ups'],
  properties: {
    batch_id: { type: 'string' },
    title: { type: 'string' },
    status: { type: 'string', enum: ['green','red','stopped','skipped'] },
    commits: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['sha','subject'], properties: { sha: { type: 'string' }, subject: { type: 'string' } } } },
    files_changed: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
    verify_passed: { type: 'boolean' },
    verify_tail: { type: 'string', description: 'last ~15 lines of just verify output' },
    blockers: { type: 'array', items: { type: 'string' } },
    follow_ups: { type: 'array', items: { type: 'string' } },
  },
}

const COMMON = `You are applying ONE batch of an audited implementation plan to the Odin roguelike at ${ROOT}.
Authoritative refs (READ them): docs/impl-plan-2026-06-13.md (find your batch section + the per-item detail blocks for your items) and docs/audit-2026-06-13.md. Actual source is ground truth over any line numbers.
Use \`graphify query "..."\` / \`graphify explain "..."\` for fast scoped context.

HARD RULES:
- Apply ONLY this batch's items. Do not touch other batches' scope.
- Tests live in test/ (mirrors src/, package main, full-sentence proc names); NEVER put *_test.odin in src/.
- src/engine/ MUST stay raylib-free (headless). src/io is package gameio; src/core is package gcore.
- Game struct heap-alloc invariant in production.
- Iterate fast with \`just check\`; run FULL \`just verify\` before committing — it MUST print the success line and exit 0.
- Run \`just fmt\` before committing.
- Commit with Conventional Commits: the given subject, a body listing the items + key changes, and a trailing line exactly:
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  Use: git add -A (tree is clean at batch start, so all changes are yours), then git commit. You MAY split into multiple conventional commits if the batch spans distinct concerns. DO NOT push. DO NOT amend or rebase existing commits.
- STOP-ON-RED: if you cannot reach green \`just verify\` after a genuine effort, OR you hit a design ambiguity not resolved by the plan, DO NOT commit broken code and DO NOT guess wildly. Leave the tree as-is, set status="red" (verify fails) or status="stopped" (blocked), and report blockers + the verify tail. A clean stop is better than a broken commit.
- If the item is already fully done in-tree and green, set status="green" with an empty commits list and explain in summary.

Return the structured result. THIS BATCH:\n`

const BATCHES = [
  { id:'B0', title:'Commit green baseline', phase:'Baseline', task:
`Baseline commit of the CURRENT uncommitted working tree (it is already green: just verify passes). Do NOT write new code — only commit what exists, grouped into clean Conventional Commits.
Inspect \`git status\` + \`git diff\`/\`git diff --cached\`. The uncommitted set is the FOV/floor-snapshot consolidation (G4: src/core/fov.odin + gameplay/fov.odin wrapper + save_common alias; G5: src/core/floor.odin + removed dupes in save_common.odin/generation.odin; aliases in gameplay/common.odin), dead-code cleanup (G6: src/data.odin/content_manager.odin/test; E4: turn_manager.odin), plus the plan doc and any small staged prior-session tweaks.
Group sensibly, e.g.:
  1) refactor: consolidate FOV + floor-snapshot helpers into gcore   (G4, G5: core/fov.odin, core/floor.odin, gameplay/fov.odin, gameplay/common.odin, gameplay/generation.odin, io/save_common.odin, related tests)
  2) refactor: delete dead engine + content code   (E4, G6: turn_manager.odin, data.odin, content_manager.odin, content_manager_test.odin, etc.)
  3) docs: add audit implementation plan   (docs/impl-plan-2026-06-13.md)
Put any unrelated staged tweaks (justfile/audio/input/save_roundtrip_test) into the most fitting commit or a small chore/fix commit — do not drop them.
Run \`just fmt\` then \`just verify\` (must be green) BEFORE committing. After committing, \`git status\` must be clean. No push.` },

  { id:'B1', title:'Finish criticals + regression tests', phase:'Finish-criticals', task:
`Items C1 (finish), C2/T2 (tests), P1/R10/D6 (already-fixed -> add regression tests). See plan per-item detail for C1, C2-R1-save-deser-clamp, P1, R10, D6, T2.
- C1: production atomic-write/CRC is already in tree+committed. ADD the load-side .bak fallback in load_game_from_storage (src/io/save_restore.odin per plan) — wrap read/header-validate/migrate in a retry over {path, path+".bak"}; on success remove path+".bak" and path+".tmp". Add the 4 C1 tests.
- Add regression tests (current behavior already correct, lock it in): P1 temp_allocator-at-frame-arena test; R10 cardinal-movement collapse test; D6 depth-merchant currency test; C2 clamp + a save->load round-trip test.
- T2: the plan flags a wrong V4 assertion in test/io/save_roundtrip_test.odin (items_found should be 0 not 8). If that test currently passes (verify is green) it may already be correct — only change it if it is actually wrong; do not break green.
All new tests MUST pass. Commit e.g. "feat(io): recover save from backup when primary is corrupt" + "test: lock in clamp/temp-allocator/cardinal-move/merchant-currency behavior".` },

  { id:'B4', title:'Perf hot-path optimizations', phase:'Optimize', task:
`Items P3, P2, P4, P6-P7. See plan per-item detail.
- P3: cache parsed scores.json on Score_Manager with write-through invalidation; load returns an owned clone. Tests assert single disk read across loads.
- P2: minimap scratch index buffers ([N]i32 enemy/npc) built once per render, O(1) per cell; first-match semantics; equivalence test vs linear scan.
- P4: DEDUP ONLY — replace render_map inline tint block with get_tile_color(...); delete dead render_last_cam_x/y (and render_map_dirty if truly dead per plan). DEFER the color cache. Dedup-lock test.
- P6-P7: expose unchecked distance_map accessors + validate-once in compute_dijkstra_map (P6); add dijkstra_dirty to Game, recompute only when dirty, mark dirty on player input, clear on recompute (P7). CRITICAL: update every direct process_enemy_turns test caller to set dijkstra_dirty=true or movement assertions break.
Commit "perf: grid + cache hot-path optimizations" (or split P2/P3/P4/P67).` },

  { id:'B5', title:'Pause/confirm menu', phase:'Pause-menu', task:
`Item R11. See plan per-item detail. Replace the in-tree double-Escape quit_armed (which kills the process) with a real Pause scene: new .Pause Game_State + Game_Scene + scene mapping + registration + update_pause (Resume / Quit-to-Title) + clay_render_pause_overlay. update_playing intercepts .Quit before handle_player_action; Quit-to-Title sets .Title_Screen (process stays alive). Remove quit_armed from state_shared.odin and the quit block in playing_action.odin. APPEND the new Game_State variant at the END of the enum (avoid reorder churn). Do NOT bool-wrap clay.UI (closes at calling scope — see project memory). Add the 5 pause tests. Commit "feat(input): route Escape to a pause/confirm menu".` },

  { id:'B6', title:'Save data-model diet (drop legacy)', phase:'Save-diet', task:
`Item M1-P5. See plan per-item detail. DECISION (locked): DROP legacy v2-v10 save read support entirely — delete those migration branches and DO NOT create the Tile_V10/Save_Data_V10 freeze. This collapses the item to LOW risk.
Do: drop dead Tile.visible/explored/light_level fields; add a dedicated [N]eng.Tile_State array as the LAST field of Saved_Floor + Save_Data + Save_Floor; route via tile_state_manager_export/import (new procs in game_utils.odin); delete the inline-Tile bridge procs; bump save version to v11 and KEEP ONLY the current/v11 load path (no ancient migrations). Update save_write/restore/convert/migrations and generation snapshot export/import accordingly. Delete now-dead migration code and any tests that asserted dropped legacy branches (or convert them to assert "unsupported old version rejected cleanly").
Add tests: save->load preserves engine tile-state layer; v11 layout byte-size relationship; a size assertion that Game/Tile shrank. MUST stay green. Commit "refactor: shrink save data model; drop legacy save migrations". This is the only HIGH-attention batch — be precise, keep verify green.` },

  { id:'B7', title:'Gameplay feedback + features', phase:'Gameplay', task:
`Items D7, D1, D8, D3 (D6 and D2 are already done — verify, do not re-do). See plan per-item detail.
- D7: add score:int + victory:bool to Score_Entry (json-tolerant, no migration); compute_run_score with VICTORY_MULTIPLIER/BONUS; insert_score ranks by score; show Final Score in victory overlay.
- D1: behind LIGHT_AFFECTS_DETECTION (default false) — player_effective_light_radius helper + DETECTION_HEARING_RADIUS; when on, sight reaches full detection_radius only inside emitted light, else clamp to hearing radius. Flag-off path byte-identical. Flag-on tests must be \`when\`-guarded so the flag matrix stays green.
- D8: new engine Floating_Text_Manager (zero raylib, pooled, world coords), service id 13, renderer-side draw, spawn at both combat resolution points; implement the missing poison_cloud AI branch + fix its data cooldown/range. Thread engine where needed.
- D3: behind LEVELUP_ENABLED (default true) — reuse Shrine_Buff as a no-HP-cost level-up; derive player_level from persisted kills (no save bump); new .Viewing_Level_Up Game_State (APPEND last); queue on milestone kill, apply buff. If using -define toggles, use runtime if not when. Recommend putting the two pure derivation procs in gcore.
Append new enum/struct fields at END. Commit per feature or as "feat(gameplay): combat feedback, light-detection, scoring, and milestone level-ups". Keep verify green; new flags: LIGHT_AFFECTS_DETECTION=false, LEVELUP_ENABLED=true.` },

  { id:'B8', title:'Onboarding hints', phase:'Onboarding', task:
`Item D4. See plan per-item detail. Add Tutorial_Flags :: bit_set[Tutorial_Hint; u8] to Game; tutorial_hint_once helper; five guarded trigger sites (first enemy seen, ore, torch, status, shrine). Persist by APPENDING tutorial_flags as the trailing field of the (now v11, from B6) Save_Data/Save_Floor — D4 is the LAST save-format mutator. Since legacy migrations were dropped in B6, just extend the v11 layout; no old-version migration needed. Flags survive descent; cleared on game reinit/restart. Surface hints via the message log. Add the onboarding + persistence tests. Commit "feat: first-encounter onboarding hints". Keep verify green.` },

  { id:'B9', title:'CI + docs cleanup', phase:'CI-docs', task:
`Items T1, docs-drift-readme-structure. See plan per-item detail.
- T1: in .github/workflows/ci.yml remove the redundant -collection:libs=vendor/ from the run_odin_tests.py invocations (the runner injects it; Odin aborts "collection 'libs' already exists"); KEEP it on the direct \`odin\` check/build lines. Simulate each CI test line locally to confirm "All tests were successful".
- docs: clean the corrupted/duplicated Backlog block in README.md (the "ta packs" orphan + duplicated heading) if present. Also fix the malformed Headroom "Formatting" duplication in CLAUDE.md if trivial.
Commit "ci: run the real test suite in CI" + "docs: fix README/CLAUDE.md drift". Keep verify green.` },
]

const results = []
let stoppedAt = null

for (const b of BATCHES) {
  phase(b.phase)
  const res = await agent(COMMON + b.task, { label: `apply:${b.id}`, phase: b.phase, schema: RESULT_SCHEMA })
  if (!res) {
    results.push({ batch_id: b.id, title: b.title, status: 'red', summary: 'agent returned null (died)', blockers: ['agent died / terminal error'] })
    stoppedAt = b.id
    log(`Batch ${b.id} DIED — stopping.`)
    break
  }
  results.push(res)
  log(`Batch ${b.id} [${res.status}] — ${(res.commits||[]).length} commit(s). ${res.summary?.slice(0,80) || ''}`)
  if (res.status === 'red' || res.status === 'stopped') {
    stoppedAt = b.id
    log(`Batch ${b.id} is ${res.status} — STOP-ON-RED engaged. Halting remaining batches.`)
    break
  }
}

// Final verification only if we didn't stop early
let finalVerify = 'skipped (stopped early)'
if (!stoppedAt) {
  phase('Final-verify')
  const fv = await agent(
    `Run a final \`just verify\` at ${ROOT} and confirm the whole repo is green after all batches. Then run \`graphify update .\` to refresh the knowledge graph (best-effort; ignore if it errors). Report: did just verify pass (exit 0 + success line)? Paste the last ~20 lines. List the commits made this session via \`git log --oneline origin/main..HEAD\`. Do NOT push.`,
    { label: 'final-verify', phase: 'Final-verify' }
  )
  finalVerify = fv || 'final-verify agent returned null'
}

return JSON.stringify({ stoppedAt, batches: results, finalVerify }, null, 2)
