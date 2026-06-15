export const meta = {
  name: 'into-the-dark-legacy-audit',
  description: 'Fan-out audit for ALL genuine legacy/dead code, with proof-of-deadness, then synthesize a removal plan',
  phases: [
    { title: 'Audit', detail: '7 parallel read-only domain audits with proof-of-deadness' },
    { title: 'Synthesize', detail: 'dedupe, classify, order into removal batches, write plan doc' },
  ],
}

const ROOT = '/Users/lecoqjacob/Developer/games/odin-into-the-dark'

const FINDINGS_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['domain','findings'],
  properties: {
    domain: { type: 'string' },
    findings: { type: 'array', items: {
      type: 'object', additionalProperties: false,
      required: ['id','title','symbol','files','evidence','proof_of_deadness','classification','risk','removal_note','depends_on'],
      properties: {
        id: { type: 'string', description: 'short stable id e.g. L-flags-1' },
        title: { type: 'string' },
        symbol: { type: 'string', description: 'the proc/struct/const/field/alias name(s)' },
        files: { type: 'array', items: { type: 'string' } },
        evidence: { type: 'string', description: 'file:line cites of the legacy/dead code' },
        proof_of_deadness: { type: 'string', description: 'grep/graphify result proving no live (non-test) caller, OR why it is superseded/unreachable. If a live caller exists, say so.' },
        classification: { type: 'string', enum: ['remove','keep_defensive','needs_decision'] },
        risk: { type: 'string', enum: ['low','med','high'] },
        removal_note: { type: 'string', description: 'exact deletion steps + what to leave + how to confirm green' },
        depends_on: { type: 'array', items: { type: 'string' } },
      },
    } },
  },
}

const PREAMBLE = `Read-only legacy/dead-code audit of the Odin roguelike at ${ROOT}. Goal: find GENUINE legacy/dead/superseded code to DELETE, rigorously PROVING deadness, and clearly separating it from legitimate defensive fallbacks and active build flags (which are NOT legacy).
Method: grep across BOTH src/ and test/, and use \`graphify query "..."\`. For any symbol you propose removing, PROVE no live (non-test) caller exists, or explain why the path is unreachable/superseded. If a non-test caller exists, classify keep_defensive or needs_decision, NOT remove.
Context already done this session (do NOT re-list as findings): removed LIGHT_AFFECTS_DETECTION flag, dead save status mirrors, dead Save_Floor.tutorial_flags, dead Energy_Actor/scene_update/g_data, FOV/floor dedup, v2-v10 save migrations.
NOT legacy — classify keep_defensive: runtime fallbacks (sprite/enemy-factory/item unknown-id, save direct-write when rename unavailable for web, logger param defaults), active build flags (CHEATS/PUBLIC_BUILD/NO_AUDIO/NO_SPRITES/SPRITES/SKIP_TITLE/FIXED_SEED), the audio raylib backend (platform split), Old_Miner (a character).
Return structured findings with file:line evidence, proof_of_deadness, classification, risk, exact removal_note, and depends_on. Be precise and conservative — false positives waste a removal agent's time. YOUR DOMAIN:\n`

const DOMAINS = [
  { id:'flags', task:`COMPILE-FLAG / CONFIG legacy. Audit every #config flag (src/core/gameplay_tuning.odin, src/build_config.odin, src/core/cheat_defs.odin) and every \`when\`/\`when !\` branch. Find: flags that are now vestigial (only ever one value used; one branch dead), feature toggles that are effectively permanent (e.g. LEVELUP_ENABLED — is the off-path reachable/meaningful?), dead \`when\` arms. For each, prove which branch is dead. KEEP the active build/flag-matrix flags.` },
  { id:'save-io', task:`SAVE / IO legacy. Audit src/io/* (save_format, save_write, save_restore, save_convert, save_migrations, save_common, accessors, save_query). Post-v11: find dead version constants, leftover migration scaffolding, unused Save_Data/Save_Floor fields (never written or never read), dead header fields, "v5 additions"/"v8 prefix" style vestigial regions, unreferenced save procs. Prove no reader/writer for each candidate field.` },
  { id:'dead-symbols-core-gameplay', task:`DEAD SYMBOLS in src/core, src/gameplay, src/data.odin, src/content_manager.odin. Find unreferenced procs/structs/consts/enum variants (e.g. Game struct fields never read, tuning consts unused, helper procs with no callers, dead recipe/dialogue/equipment entries). Use grep across src/+test/ to prove zero live callers. Exclude anything only a test references but that is a real API (note those as needs_decision).` },
  { id:'dead-symbols-engine-render', task:`DEAD SYMBOLS in src/engine and src/render. Find unreferenced managers/procs/accessors (the audit flagged camera_manager_abs, input_tick, reset_repeats — verify current state), dead render helpers, unused vtable fields, unread struct fields, dead backend procs (beyond the kept raylib audio). Prove deadness via grep/graphify. KEEP backends that are platform-split even if currently unexercised — classify needs_decision with a note.` },
  { id:'dead-symbols-ai-input-gen', task:`DEAD SYMBOLS in src/ai, src/input, src/gen. Audit the detection_radius<=0 "always aware (legacy)" branches (src/ai/enemy_turns.odin ~76, src/ai/enemy_abilities.odin ~23): PROVE whether every enemy source sets detection_radius>0 — check data/enemies.json5, src/ai/enemy_factory.odin defaults, and EVERY test enemy constructor. Only classify remove if provably always >0; else needs_decision. Also find dead input handlers/procs, dead gen helpers, unreferenced map-gen profiles.` },
  { id:'aliases', task:`RE-EXPORT ALIASES legacy. The codebase re-exports ~hundreds of symbols via src/core_aliases.odin, src/render_aliases.odin, and per-package common.odin files. Find aliases that are DEAD (the bare re-exported name has no use in its consuming package). Use grep per consuming package. Removing a dead alias is low-risk. Report dead aliases grouped by file. Be careful: an alias used even once is live.` },
  { id:'markers', task:`VESTIGIAL MARKERS. Grep src/ for "for now","temporary","TODO.*remove","no longer","kept for","deprecated","stale","unused","commented-out" and review each. Find commented-out code blocks, fields/params kept "for layout"/"for compat" with no live use, and superseded helpers. Prove deadness. Also scan data/*.json5 for unreferenced content (enemies/items/recipes with no spawn/loot/recipe reference).` },
]

phase('Audit')
const audits = (await parallel(DOMAINS.map(d => () =>
  agent(PREAMBLE + d.task, { label: `audit:${d.id}`, phase: 'Audit', schema: FINDINGS_SCHEMA })
))).filter(Boolean)

const allFindings = audits.flatMap(a => (a.findings || []).map(f => ({ ...f, domain: a.domain })))
const counts = { remove:0, keep_defensive:0, needs_decision:0 }
for (const f of allFindings) counts[f.classification] = (counts[f.classification]||0)+1
log(`Audit: ${allFindings.length} findings — remove ${counts.remove}, keep ${counts.keep_defensive}, decide ${counts.needs_decision}`)

phase('Synthesize')
const SYNTH = `Integration planner for a legacy-code removal pass on the Odin roguelike at ${ROOT}.
Below is a JSON array of ${allFindings.length} audit findings from 7 domain audits. Do:
1) DEDUPE overlapping findings.
2) For each "remove" finding, sanity-check the proof_of_deadness is real (no live caller). Demote anything weak to needs_decision.
3) Order the confirmed "remove" findings into sequential REMOVAL BATCHES that: respect depends_on, group by file-locality (items editing the same file in one batch), put low-risk dead-symbol/alias deletions first and save-format-layout changes (which invalidate saves) in their own later batch, and give each batch a Conventional Commit subject.
4) Write docs/legacy-removal-plan-2026-06-14.md containing: a CALLOUTS section (needs_decision items + anything risky, listed first), a summary table (id | title | symbol | classification | risk | files | proof), the batch plan, and a per-item detail section (removal_note + proof). Clearly separate KEEP_DEFENSIVE (do-not-touch) at the bottom.
After writing, RETURN a compact markdown report: the needs_decision callouts, the batch table (batch | subject | item ids | files | risk), and counts by classification/risk. Do NOT include the whole file.

FINDINGS JSON:
${JSON.stringify(allFindings)}`

const report = await agent(SYNTH, { label: 'synthesize-legacy-plan', phase: 'Synthesize' })
return report
