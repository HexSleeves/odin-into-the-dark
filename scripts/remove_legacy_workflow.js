export const meta = {
  name: 'into-the-dark-remove-legacy',
  description: 'Discover genuine legacy/dead code (excluding defensive fallbacks) and remove it sequentially, verify-gated, stop-on-red',
  phases: [
    { title: 'Discover', detail: 'read-only scan: classify legacy vs defensive-fallback vs needs-decision' },
    { title: 'Remove', detail: 'sequential per-cluster removal, just verify, commit, stop-on-red' },
    { title: 'Final-verify', detail: 'full just verify after all removals' },
  ],
}

const ROOT = '/Users/lecoqjacob/Developer/games/odin-into-the-dark'

const DISCOVER_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['clusters'],
  properties: {
    clusters: { type: 'array', items: {
      type: 'object', additionalProperties: false,
      required: ['id','title','classification','files_touched','evidence','rationale','removal_note','risk'],
      properties: {
        id: { type: 'string' },
        title: { type: 'string' },
        classification: { type: 'string', enum: ['remove','keep_defensive','needs_decision'] },
        files_touched: { type: 'array', items: { type: 'string' } },
        evidence: { type: 'string', description: 'file:line cites proving it is dead/legacy or defensive' },
        rationale: { type: 'string' },
        removal_note: { type: 'string', description: 'exactly what to delete + what to leave; how to confirm no live callers' },
        risk: { type: 'string', enum: ['low','med','high'] },
      },
    } },
  },
}

const REMOVE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['cluster_id','status','commits','files_changed','summary','verify_passed','blockers'],
  properties: {
    cluster_id: { type: 'string' },
    status: { type: 'string', enum: ['green','red','stopped','skipped'] },
    commits: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['sha','subject'], properties: { sha: { type: 'string' }, subject: { type: 'string' } } } },
    files_changed: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
    verify_passed: { type: 'boolean' },
    blockers: { type: 'array', items: { type: 'string' } },
  },
}

phase('Discover')
const disc = await agent(
`Read-only legacy-code audit of the Odin roguelike at ${ROOT}. Find GENUINE legacy/dead code and DISTINGUISH it from legitimate defensive fallbacks (which must be KEPT).

Use \`graphify query "..."\` and grep. Read actual code to confirm deadness (no live callers, unreachable branch, superseded path).

DEFINITELY LEGACY (classify "remove") — examples to look for:
- LIGHT_AFFECTS_DETECTION #config flag in src/core/gameplay_tuning.odin (now defaults TRUE): the \`when !LIGHT_AFFECTS_DETECTION\` / else "plain Manhattan" branch in src/ai/enemy_turns.odin (~85-93) is now dead weight. The whole flag + its alias in src/ai/common.odin + the test alias in test/test_imports_test.odin + the flag-off test + the \`when LIGHT_AFFECTS_DETECTION\` guards in test/light_detection_test.odin should collapse to UNCONDITIONAL light-gated detection.
- Post-v11 save remnants: src/io/save_write.odin:51 "Legacy mirrors — kept so the v8 prefix region stays meaningful" and src/io/save_format.odin:116 "legacy scalar status fields (poison_turns/burning_turns/...)". Since M1-P5 dropped all v2-v10 read support and the v8 prefix no longer needs to stay meaningful, confirm whether these mirror/scalar fields still feed anything live; if dead, mark remove.
- Any unreferenced procs/structs/consts, dead enum variants, commented-out blocks, or superseded code paths.

DO NOT REMOVE (classify "keep_defensive") — legitimate runtime fallbacks, NOT legacy:
- sprite fallback_sprite/sprite_manager_fallback, enemy_factory unknown-enemy fallback, item_make unknown-id fallback.
- save_write.odin:169 direct-write fallback when rename is unavailable (web/WASM has no rename — REAL).
- logger_parse_bool/level fallback params (default values).
- Active build flags: CHEATS, PUBLIC_BUILD, NO_AUDIO, NO_SPRITES, SPRITES, SKIP_TITLE, FIXED_SEED (build matrix uses them), LEVELUP_ENABLED (live feature toggle).
- detection_radius<=0 "always aware (legacy/hand-built enemies)" — this supports hand-built/test enemies; classify needs_decision, not remove, unless proven unused.
- Old_Miner (a character role), audio raylib backend (kept per platform split).

For anything ambiguous (a contract, or unsure if dead) use "needs_decision".

Return clusters with file:line evidence, exact removal_note, and risk. Be precise — a later agent removes "remove"-classified clusters verbatim.`,
  { label: 'discover-legacy', phase: 'Discover', schema: DISCOVER_SCHEMA }
)

const toRemove = (disc?.clusters || []).filter(c => c.classification === 'remove')
const decide = (disc?.clusters || []).filter(c => c.classification === 'needs_decision')
const keep = (disc?.clusters || []).filter(c => c.classification === 'keep_defensive')
log(`Discovery: ${toRemove.length} remove, ${decide.length} needs-decision, ${keep.length} keep-defensive`)

const COMMON_REMOVE = `You are removing ONE cluster of genuine legacy/dead code from the Odin roguelike at ${ROOT}. The working tree is clean and single-owner at batch start.
HARD RULES:
- Remove ONLY this cluster. Do NOT touch defensive fallbacks or unrelated code.
- Before deleting a symbol, grep for live callers; if a non-test caller exists, do NOT delete it — set status=stopped with the blocker.
- Tests live in test/ (package main); engine/ stays raylib-free; src/io=gameio, src/core=gcore.
- Iterate with \`just check\`; run full \`just verify\` before committing — it MUST pass (success line + exit 0).
- \`just fmt\` before commit (odinfmt at ~/Developer/games/ols/odinfmt if not on PATH: ODINFMT=... just fmt).
- Commit Conventional Commits (refactor/chore), body lists what was removed, trailer:
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  Stage only your files (git add -p / explicit paths). DO NOT push. DO NOT amend.
- STOP-ON-RED: if verify won't go green or a live caller blocks removal, leave the tree clean (revert your partial edits via git restore of ONLY your files) and report status=red/stopped + blockers. Never commit broken code.
Return structured result. THE CLUSTER TO REMOVE:\n`

phase('Remove')
const results = []
let stopped = null
for (const c of toRemove) {
  const res = await agent(
    COMMON_REMOVE + `id=${c.id}\ntitle=${c.title}\nfiles=${(c.files_touched||[]).join(', ')}\nevidence=${c.evidence}\nrationale=${c.rationale}\nremoval_note=${c.removal_note}\nrisk=${c.risk}`,
    { label: `remove:${c.id}`, phase: 'Remove', schema: REMOVE_SCHEMA }
  )
  if (!res) { results.push({ cluster_id: c.id, status: 'red', summary: 'agent died', blockers: ['agent died'] }); stopped = c.id; break }
  results.push(res)
  log(`Remove ${c.id} [${res.status}] ${(res.commits||[]).length} commit(s)`)
  if (res.status === 'red' || res.status === 'stopped') { stopped = c.id; log(`STOP-ON-RED at ${c.id}`); break }
}

let finalVerify = 'skipped (stopped early)'
if (!stopped) {
  phase('Final-verify')
  finalVerify = await agent(
    `Run a final \`just verify\` at ${ROOT}. Report pass/fail (exit 0 + success line) and the last ~15 lines. List session commits via \`git log --oneline origin/main..HEAD\`. Do NOT push.`,
    { label: 'final-verify', phase: 'Final-verify' }
  ) || 'final-verify returned null'
}

return JSON.stringify({
  stopped,
  discovery: { remove: toRemove.map(c=>c.id), needs_decision: decide, keep_defensive: keep.map(c=>({id:c.id,title:c.title})) },
  removals: results,
  finalVerify,
}, null, 2)
