export const meta = {
  name: "odin-prod-audit",
  description:
    "Audit Odin roguelike for optimization, cleanup, refactoring toward production readiness",
  phases: [
    { title: "Audit", detail: "parallel auditors across code groups" },
    {
      title: "Verify",
      detail: "adversarial verification of high/med findings",
    },
    { title: "Synthesize", detail: "dedup + prioritized report" },
  ],
};

const FINDINGS_SCHEMA = {
  type: "object",
  required: ["group", "findings"],
  properties: {
    group: { type: "string" },
    findings: {
      type: "array",
      items: {
        type: "object",
        required: [
          "file",
          "category",
          "severity",
          "title",
          "detail",
          "recommendation",
        ],
        properties: {
          file: { type: "string", description: "path:line or path" },
          category: {
            type: "string",
            enum: [
              "memory",
              "performance",
              "correctness",
              "cleanup",
              "refactor",
              "architecture",
              "deadcode",
              "idiom",
              "testgap",
            ],
          },
          severity: { type: "string", enum: ["high", "medium", "low"] },
          title: { type: "string", description: "one line" },
          detail: {
            type: "string",
            description: "what and why it matters for production",
          },
          recommendation: { type: "string", description: "concrete fix" },
        },
      },
    },
  },
};

const VERDICT_SCHEMA = {
  type: "object",
  required: ["verdict", "adjusted_severity", "reason"],
  properties: {
    verdict: {
      type: "string",
      enum: ["confirmed", "rejected", "needs-context"],
    },
    adjusted_severity: { type: "string", enum: ["high", "medium", "low"] },
    reason: { type: "string" },
    effort: { type: "string", enum: ["trivial", "small", "medium", "large"] },
  },
};

const ODIN_CTX = `Project: Into the Depths — turn-based 2D roguelike in Odin (dev-2026-05) + Raylib.
Repo root: /Users/lecoqjacob/Developer/games/odin-into-the-dark
Two packages: src/ (package main, game) and src/engine/ (package engine, backend-agnostic, MUST NOT import raylib or Clay).
Conventions: types PascalCase, procs snake_case with type_verb prefix, constructors type_make, destructors type_destroy.
Memory: Game struct heap-allocated; [dynamic]T collections freed in cleanup; pass allocator explicitly to file reads.
Odin specifics to respect: defer for cleanup, no exceptions (bool returns), explicit allocators, context.allocator/temp_allocator, slices vs dynamic arrays, no hidden allocations.
Build is currently clean (odin check passes).`;

const GROUPS = [
  {
    key: "game-core",
    label: "game core/state/scenes",
    files:
      "src/game.odin src/game_app.odin src/scene.odin src/actions.odin src/types.odin src/constants.odin src/game_app_services_test.odin",
  },
  {
    key: "generation",
    label: "mapgen/fov",
    files:
      "src/generation.odin src/mapgen_cave.odin src/map_utils.odin src/fov.odin",
  },
  {
    key: "combat-enemy",
    label: "combat/enemy/mining",
    files:
      "src/combat.odin src/enemy.odin src/enemy_abilities.odin src/enemy_turns.odin src/enemy_spawn.odin src/mining.odin",
  },
  {
    key: "items-data",
    label: "items/equipment/data/content",
    files:
      "src/items.odin src/equipment.odin src/data.odin src/content_manager.odin src/content_ids.odin",
  },
  {
    key: "saveload",
    label: "save/load/scores",
    files: "src/saveload.odin src/save_manager.odin src/scores.odin",
  },
  {
    key: "input",
    label: "input routing",
    files: "src/input.odin src/input_manager.odin",
  },
  {
    key: "clay-ui",
    label: "Clay UI declarations",
    files:
      "src/clay_ui.odin src/clay_renderer.odin src/clay_hud.odin src/clay_overlays.odin src/clay_messages.odin src/clay_minimap.odin src/clay_screen_ui.odin src/clay_theme.odin src/clay_tooltip.odin src/ui_theme.odin",
  },
  {
    key: "render",
    label: "rendering/sprites",
    files:
      "src/render_map.odin src/render_hud.odin src/render_ui.odin src/render_minimap.odin src/render_title_fx.odin src/sprites.odin src/sprite_manager.odin src/outcome_text.odin",
  },
  {
    key: "audio",
    label: "audio/music",
    files: "src/audio.odin src/audio_raylib.odin src/music.odin",
  },
  {
    key: "logger-misc",
    label: "logger/particles/cheats",
    files:
      "src/logger.odin src/logger_desktop.odin src/particles.odin src/cheat_menu.odin src/karl2d_backend.odin",
  },
  {
    key: "engine-core",
    label: "engine core/services/scene",
    files:
      "src/engine/engine.odin src/engine/engine_services.odin src/engine/scene_manager.odin src/engine/turn_manager.odin src/engine/frame_manager.odin src/engine/world_manager.odin src/engine/event_manager.odin src/engine/config_manager.odin",
  },
  {
    key: "engine-backends",
    label: "engine backend abstractions",
    files:
      "src/engine/audio_backend.odin src/engine/input_backend.odin src/engine/input_backend_raylib.odin src/engine/render_backend.odin src/engine/render_backend_raylib.odin src/engine/texture_backend.odin src/engine/texture_backend_raylib.odin src/engine/platform_backend.odin src/engine/platform_backend_raylib.odin src/engine/action_input_manager.odin",
  },
  {
    key: "engine-managers",
    label: "engine managers/grids",
    files:
      "src/engine/texture_manager.odin src/engine/audio_manager.odin src/engine/message_manager.odin src/engine/particle_manager.odin src/engine/vfx_manager.odin src/engine/camera_manager.odin src/engine/storage_manager.odin src/engine/tile_state_manager.odin src/engine/bool_grid_manager.odin src/engine/distance_map.odin src/engine/grid_2d.odin src/engine/file_system.odin src/engine/file_system_desktop.odin",
  },
];

phase("Audit");
log(
  `Auditing ${GROUPS.length} code groups + data/build + test-coverage in parallel`,
);

const auditPrompt = (g) => `${ODIN_CTX}

You are a senior Odin/game-engine reviewer auditing the "${g.label}" group for PRODUCTION READINESS.
Read EVERY file in this group fully before reporting:
${g.files
  .split(" ")
  .map((f) => "  - " + f)
  .join("\n")}

Use Read on each file. Use Grep to check how symbols are used elsewhere when judging dead code or duplication. Use Bash (rg/wc) freely but do NOT modify files.

Hunt specifically for:
- MEMORY: leaks (missing destroy/free for [dynamic]/maps/allocations), allocations in hot/per-frame paths, missing defer, allocator passed implicitly where it should be explicit, temp_allocator misuse.
- PERFORMANCE: O(n^2) or worse in per-frame/per-turn paths, redundant recomputation, copying large structs by value, linear scans that should be maps, string allocations in loops.
- CORRECTNESS: off-by-one, unchecked bounds, ignored bool returns, nil deref risk, save/load version/round-trip hazards, integer overflow.
- CLEANUP/DEADCODE: unused procs/fields/vars/imports, commented-out code, unreachable branches, duplicated logic across files that should be a shared helper.
- REFACTOR: god-procs/files that should be split, deep nesting, copy-paste families, magic numbers that belong in constants.odin, leaky abstractions.
- ARCHITECTURE: engine layer importing game/raylib/Clay, service-registry misuse, coupling that blocks reuse.
- IDIOM: non-idiomatic Odin (manual loops over slices, missing or-else/or-return opportunities, switch vs if-chains, naming-convention violations per AGENTS.md).

Report ONLY real, actionable findings with concrete file:line and a concrete fix. No praise, no speculation, no "consider maybe". Prefer fewer high-confidence findings over noise. If the group is genuinely clean, return few or zero findings.
Return via the structured output tool with group="${g.key}".`;

const auditTasks = GROUPS.map(
  (g) => () =>
    agent(auditPrompt(g), {
      label: `audit:${g.key}`,
      phase: "Audit",
      schema: FINDINGS_SCHEMA,
      agentType: "Explore",
    }),
);

// data/build/tooling auditor
auditTasks.push(() =>
  agent(
    `${ODIN_CTX}

Audit the DATA + BUILD + TOOLING surface for production readiness. Read:
  - justfile
  - data/enemies.json5 data/items.json5 data/player.json5 data/sprites.json5
  - ols.json (if present)
  - .gitignore
  - any scripts/ files (ls scripts/ first)
Check for: schema inconsistencies between json5 and the Odin structs in src/data.odin (Read it to compare), missing release-build hygiene, debug defines leaking into release, asset/path fragility, missing CI/verify gaps, unsafe build flags. Report concrete findings with the structured tool, group="data-build".`,
    {
      label: "audit:data-build",
      phase: "Audit",
      schema: FINDINGS_SCHEMA,
      agentType: "Explore",
    },
  ),
);

// test-coverage auditor
auditTasks.push(() =>
  agent(
    `${ODIN_CTX}

Audit TEST COVERAGE for production readiness. The repo uses core:testing, files named *_test.odin.
Run: rg -l '@\\(test\\)' src/ ; and list all *_test.odin. Map which managers/subsystems have tests and which non-trivial logic has NONE.
Identify the highest-risk UNTESTED logic: save/load round-trips, generation determinism, combat math, fov, pathfinding, content loading edge cases, service registry.
Report gaps as findings (category="testgap") with the specific proc/file that needs a test and why it's risky. group="test-coverage".`,
    {
      label: "audit:test-coverage",
      phase: "Audit",
      schema: FINDINGS_SCHEMA,
      agentType: "Explore",
    },
  ),
);

const results = await parallel(auditTasks);
const allFindings = results
  .filter(Boolean)
  .flatMap((r) => (r.findings || []).map((f) => ({ ...f, group: r.group })));
log(`Collected ${allFindings.length} raw findings across all groups`);

// Verify high+medium; pass low through unverified
phase("Verify");
const toVerify = allFindings.filter(
  (f) => f.severity === "high" || f.severity === "medium",
);
const lowFindings = allFindings.filter((f) => f.severity === "low");
log(
  `Verifying ${toVerify.length} high/medium findings adversarially; ${lowFindings.length} low pass through`,
);

const verifyPrompt = (f) => `${ODIN_CTX}

Adversarially verify this audit finding. Your DEFAULT stance is skepticism — reject if the claim does not hold against the actual code or misunderstands Odin semantics.

FINDING:
  group: ${f.group}
  file: ${f.file}
  category: ${f.category}
  severity (claimed): ${f.severity}
  title: ${f.title}
  detail: ${f.detail}
  recommendation: ${f.recommendation}

Read the cited file/region with Read. Grep for real usage if it's a dead-code or duplication claim. Confirm the code actually does what the finding says.
- "confirmed" only if the problem is real AND the recommendation is sound.
- "rejected" if it misreads the code, the pattern is intentional/idiomatic, or the fix would break something.
- "needs-context" if it might be real but depends on runtime behavior you can't verify statically.
Set adjusted_severity to the TRUE severity (downgrade inflated ones). Set effort. Be terse. Return via structured tool.`;

const verified = await pipeline(toVerify, (f) =>
  agent(verifyPrompt(f), {
    label: `verify:${f.group}`,
    phase: "Verify",
    schema: VERDICT_SCHEMA,
  })
    .then((v) => ({ ...f, ...v }))
    .catch(() => ({
      ...f,
      verdict: "needs-context",
      adjusted_severity: f.severity,
      reason: "verification errored",
      effort: "unknown",
    })),
);

const confirmed = verified.filter((v) => v && v.verdict === "confirmed");
const needsContext = verified.filter((v) => v && v.verdict === "needs-context");
const rejected = verified.filter((v) => v && v.verdict === "rejected");
log(
  `Verified: ${confirmed.length} confirmed, ${needsContext.length} needs-context, ${rejected.length} rejected`,
);

phase("Synthesize");
const synthInput = {
  confirmed: confirmed.map((f) => ({
    group: f.group,
    file: f.file,
    category: f.category,
    severity: f.adjusted_severity,
    title: f.title,
    detail: f.detail,
    recommendation: f.recommendation,
    effort: f.effort,
  })),
  needsContext: needsContext.map((f) => ({
    group: f.group,
    file: f.file,
    category: f.category,
    severity: f.adjusted_severity,
    title: f.title,
    detail: f.detail,
    recommendation: f.recommendation,
  })),
  low: lowFindings.map((f) => ({
    group: f.group,
    file: f.file,
    category: f.category,
    title: f.title,
    recommendation: f.recommendation,
  })),
};

const report = await agent(
  `${ODIN_CTX}

You are the lead engineer synthesizing an audit into a single prioritized, de-duplicated action plan for taking this Odin roguelike toward production readiness.

Here are the verified findings as JSON:
${JSON.stringify(synthInput, null, 2)}

Produce a HTML report with these sections:
1. **Executive summary** — 4-6 sentences: overall health, biggest themes, what to do first.
2. **Cross-cutting themes** — patterns that recur across groups (e.g. a memory idiom, a duplication family). Merge duplicate findings here; cite all affected files.
3. **Prioritized action plan** — a TABLE ordered by (severity desc, effort asc) with columns: Priority | Category | File(s) | Issue | Fix | Severity | Effort. Include confirmed + needs-context (mark needs-context). Do NOT list the low-severity items individually here.
4. **Low-severity cleanup backlog** — terse bullet list grouped by category.
5. **Recommended sequencing** — 3 concrete batches (e.g. "Batch 1: memory-safety", "Batch 2: dedup/refactor", "Batch 3: test gaps") with which table rows belong to each, designed so each batch ends green on \`just verify\`.

Be concrete and terse. This is the deliverable the user reads. Return the HTML as your text output (no structured tool).`,
  { label: "synthesize", phase: "Synthesize" },
);

return {
  counts: {
    raw: allFindings.length,
    confirmed: confirmed.length,
    needsContext: needsContext.length,
    rejected: rejected.length,
    low: lowFindings.length,
  },
  report,
};
