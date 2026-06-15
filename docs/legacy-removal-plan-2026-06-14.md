# Legacy Removal Plan — 2026-06-14

Integration plan for the legacy-code removal pass. Source: 34 audit findings across 7 domain audits (`docs/audit-2026-06-13.md`). Each confirmed `remove` proof was re-verified by grep against the live tree on 2026-06-14.

Completion gate for every batch: `just fmt` then `just verify` (type-check + flag matrix + build + tests) must stay green.

---

## 1. CALLOUTS (read first)

### 1a. Conflict resolution — `*_import_anchor` procs (two audits disagree)

Two findings touch the per-file `import_anchor` keepalives and **directly contradict each other**:

- `ER-importanchor-1` classifies the 10 clay anchors as **keep_defensive**.
- `L-anchor-1` classifies 12 anchors (the 10 clay ones **plus** `cheat_import_anchor` and `_lifecycle_import_anchor`) as **remove**, claiming "every import has other live references".

Re-verification on 2026-06-14 shows **L-anchor-1's proof is wrong for two of the twelve**:

- **`cheat_import_anchor` (src/input/cheats.odin)** — every real `fmt.`/`gcore.` use (lines 49, 85, 157) is inside `when CHEATS_ENABLED {` (line 13). Under `PUBLIC_BUILD` (CHEATS=false) those imports become unused and the anchor is the only thing keeping the file compiling. **KEEP** (agrees with `L-input-2`). Removing it breaks the CHEATS=false flag-matrix leg.
- **`_lifecycle_import_anchor` (src/game_app_lifecycle.odin)** — the only real `gameaudio.` use is `gameaudio.music_update(game)` at line 127, inside `when !NO_AUDIO {` (line 126). Under `NO_AUDIO=true` the `gameaudio` import is unused and the anchor is load-bearing. **KEEP**. Removing it breaks the NO_AUDIO=true flag-matrix leg.

For the **10 clay anchors**, grep confirms zero `when` flag-guards in 9 of 10 files (clay_overlays has 1, around its own scope), so their imports are unconditionally used and the anchors are *currently* redundant. **However**, because (a) a domain audit explicitly flagged them keep_defensive, (b) they are a deliberate Odin idiom, and (c) removal is pure churn that silently breaks if any future `when` guard is added to those files, they are routed to **needs_decision** rather than a clean batch. Default recommendation: **keep**. Do not remove without maintainer sign-off.

Net effect: `L-anchor-1` is **not** scheduled as a remove batch. It is fully superseded by this callout.

### 1b. needs_decision items (not scheduled for removal)

| id | title | why deferred | risk |
|----|-------|--------------|------|
| L-flags-1 | SPRITES_REQUESTED vestigial | matrix line + justfile SPRITES knob are externally visible build surface; confirm whether the knob stays as a future placeholder | low |
| L-flags-2 | LEVELUP_ENABLED off-path dead in default build | genuine feature toggle (off=auto milestone buffs, on=level-up menu); apply_kill_milestone_buff still has live test coverage; product decision, do not remove blindly | med |
| L-save-2 | stale `// v10` comment in v11 save writer | comment-only; skip if removal agent is code-only | low |
| L-core-5 | never-populated Light_Source subsystem | **cross-domain**: fields are part of the on-disk save_format binary layout; needs save-format version bump + migration; coordinate with io owner | med |
| ER-distmap-set-1 | engine_distance_map_set | **DEMOTED from remove** — dead in src but has 3 live test callers asserting bounds behavior; removing it deletes real test coverage of the checked path. Decide: drop symmetric get/set API or keep | low |
| ER-event-subsystem-1 | half-wired Event_Manager | designed-but-unwired input-event abstraction; confirm not reserved for an in-progress input refactor before deleting | med |
| ER-texture-wrappers-1 | unused engine texture convenience wrappers | part of texture abstraction surface; keep-minimal-API decision | low |
| ER-audio-wrappers-1 | unused engine audio accessors | part of audio abstraction surface; keep-minimal-API decision | low |
| ER-testonly-accessors-1 | ~24 test-only manager getters/counters | live managers, tested public API; per-symbol judgment, not a bulk delete | low |
| ER-ctor-helpers-1 | engine_vec2_make / engine_rect_make | API-symmetry judgment vs heavily-used engine_color_make | low |
| L-ai-1 | detection_radius<=0 "always aware" branch | **NOT dead** — live handler for the keep_defensive unknown-id fallback enemy; removal is a behavior decision | med |
| L-gen-2 | unreachable BSP_Rooms/BSP_Maze arms | self-contained pure fn documenting depth→method intent; low value, judgment call | low |
| L-alias-gameplay-2 | gameplay mapgen_bounds_* re-exports | **DEMOTED from clean remove** — test-only caller chain via `gp.mapgen_bounds_*` in test_imports; removing requires repointing tests to `genpkg.*` first | med |

Canonical ids (source JSON): SPRITES=`L-flags-1`, LEVELUP=`L-flags-2`, stale-comment=`L-save-2`. This table is the authoritative needs_decision set (13 items).

### 1c. Demotions applied (remove → needs_decision)

- **ER-distmap-set-1**: proof says "dead in src" but it has live test assertions for bounds behavior. Deleting it removes test coverage, not just a dead symbol. Demoted.
- **L-alias-gameplay-2**: has a real (test-only) `gp.`-qualified caller chain. Not a clean per-line alias delete. Demoted.

### 1d. Risk note on save-format

`L-core-5` is the **only** finding that touches on-disk save binary layout. It must NOT be bundled with the low-risk batches. It is deferred (needs_decision) pending an io/save-format owner agreeing to a version bump + migration. If it is later approved, it gets its own dedicated, last batch.

---

## 2. Summary table

| id | title | symbol | classification | risk | files | proof (verified 2026-06-14) |
|----|-------|--------|----------------|------|-------|------|
| L-save-1 | dead save_exists trio | save_exists / _at / _in_storage | **remove** | low | src/io/save_query.odin | grep: only 5 self-refs inside the file; live path is gcore.save_manager_save_exists |
| L-core-1 | unused ITEM_ID_WEB_TILE | ITEM_ID_WEB_TILE | **remove** | low | src/core/content_ids.odin | grep: def-only (content_ids.odin:8) |
| L-core-2 | unused CARDINAL_DIRS | CARDINAL_DIRS | **remove** | low | src/core/directions.odin | grep: def-only; CARDINAL_DX/DY are the live tables |
| L-core-3 | unused tile_light_level_idx | tile_light_level_idx | **remove** | low | src/core/game_utils.odin | grep: def-only; tile_light_level_at is live |
| L-core-4 | unused Equipment_Slot enum | Equipment_Slot | **remove** | low | src/core/types.odin | grep: token `Equipment_Slot` def-only; string consts EQUIPMENT_SLOT_* drive equipment |
| L-gameplay-1 | unused shrine_buff_label | shrine_buff_label | **remove** | low | src/gameplay/events.odin | grep: def-only; render uses SHRINE_BUFF_LABELS array |
| L-input-1 | unused action_binding_ptr | action_binding_ptr | **remove** | low | src/input/manager.odin | grep: def-only; action_binding (value) is live |
| L-gen-1 | orphaned mapgen_floor_count | mapgen_floor_count | **remove** | low | src/gen/mapgen_profile.odin | grep: def-only; generate_cave inlines the loop |
| ER-titlefx-1 | render_title_fx.odin superseded | draw_centered_text, draw_title_embers | **remove** | low | src/render/render_title_fx.odin | grep: zero callers; live path is Clay clay_render_title_* |
| ER-rendercolor-1 | orphaned render_color wrappers | render_draw_rectangle_lines, render_draw_texture_region | **remove** | low | src/render/render_color.odin | grep: zero callers of the renderer-layer wrappers; engine vtable variants are distinct & live |
| ER-stubs-1 | 3 empty render stub files | (none) | **remove** | low | src/render/render_hud.odin, render_minimap.odin, render_ui.odin | 17-byte package-only files; nothing references them |
| ER-tilestate-accessors-1 | bypassed Tile_State single-field accessors | 6 getters + 3 setters | **remove** | low | src/engine/tile_state_manager.odin | grep: no `eng.` callers in src; prod uses tile_state_at(...).field + full-record setters; test-only refs |
| L-alias-ai-1 | dead ai re-export aliases | 8 aliases | **remove** | low | src/ai/common.odin | grep: zero non-common uses; no aipkg. refs |
| L-alias-gameplay-1 | dead gameplay re-export aliases | 28 aliases | **remove** | low | src/gameplay/common.odin | grep: zero non-common uses; no gp. refs |
| L-alias-gen-1 | dead gen re-export aliases | 5 aliases | **remove** | low | src/gen/common.odin | grep: zero non-common uses; no genpkg. refs |
| L-alias-input-1 | dead gameinput re-export aliases | 18 aliases | **remove** | low | src/input/common.odin | grep: zero non-common uses; no gameinput. refs |
| L-alias-input-2 | dead NO_AUDIO redeclaration in input | NO_AUDIO | **remove** | low | src/input/common.odin | grep: only the def line in src/input; no `when NO_AUDIO` in input |
| L-alias-io-1 | dead gameio re-export aliases | 5 aliases | **remove** | low | src/io/save_common.odin | grep: 4 fully dead; clear_visited_floors used in-file → inline first |
| — | — | — | — | — | — | — |
| L-flags-1 | SPRITES_REQUESTED vestigial | SPRITES_REQUESTED | needs_decision | low | build_config.odin, test, ci.yml, justfile | externally visible build knob |
| L-flags-2 | LEVELUP off-path dead in default | LEVELUP_ENABLED, apply_kill_milestone_buff | needs_decision | med | gameplay_tuning.odin + 3 | genuine toggle; live test coverage |
| L-save-2 | stale v10 comment | (comment) | needs_decision | low | src/io/save_write.odin | comment-only |
| L-core-5 | never-populated Light_Source | Light_Source + fields | needs_decision | med | core/io (9 files) | save-format binary layout; needs version bump |
| ER-distmap-set-1 | engine_distance_map_set | engine_distance_map_set | needs_decision | low | src/engine/distance_map.odin | DEMOTED: 3 live test assertions |
| ER-event-subsystem-1 | half-wired Event_Manager | Event_Manager + 20 syms | needs_decision | med | engine/event_manager.odin, engine.odin | possible in-progress refactor |
| ER-texture-wrappers-1 | unused texture wrappers | 3 procs | needs_decision | low | engine/texture_*.odin | abstraction surface |
| ER-audio-wrappers-1 | unused audio accessors | 3 procs | needs_decision | low | engine/audio_*.odin | abstraction surface |
| ER-testonly-accessors-1 | test-only manager getters | ~24 syms | needs_decision | low | 12 engine/render files | tested public API |
| ER-ctor-helpers-1 | engine_vec2_make/rect_make | 2 procs | needs_decision | low | engine/render_backend.odin | API symmetry |
| L-ai-1 | detection_radius<=0 branch | awareness branches | needs_decision | med | ai + factory + io (5) | NOT dead — fallback handler |
| L-gen-2 | unreachable BSP arms | BSP_Rooms/BSP_Maze | needs_decision | low | gen (3) | documents depth intent |
| L-alias-gameplay-2 | gameplay mapgen_bounds_* | 4 aliases | needs_decision | med | gameplay/common.odin, tests | DEMOTED: test-only caller chain |
| — | — | — | — | — | — | — |
| L-anchor-1 | per-file import_anchor (12) | 12 anchors | KEEP/needs_decision | low/med | 12 files | SUPERSEDED by callout 1a — 2 are load-bearing build keepalives, 10 deferred |
| ER-importanchor-keep-1 | clay import_anchor keepalives | 10 anchors | keep_defensive | low | 10 clay files | intentional Odin idiom |
| L-input-2 | cheat_import_anchor keepalive | cheat_import_anchor | keep_defensive | med | src/input/cheats.odin | breaks PUBLIC_BUILD if removed |

---

## 3. Removal batch plan

Ordering rules applied: low-risk dead-symbol/alias deletions first; group by file-locality (same-file edits in one batch); save-format layout changes isolated to a later batch (none scheduled — only candidate L-core-5 is deferred); respect depends_on.

All scheduled batches are **low risk** (no save-format layout change among confirmed removes).

### Batch 1 — `refactor(core): remove dead constants, enum, and accessor`
- Items: **L-core-1, L-core-2, L-core-3, L-core-4**
- Files: src/core/content_ids.odin, src/core/directions.odin, src/core/game_utils.odin, src/core/types.odin
- Rationale: four independent single-symbol deletions all in `src/core`, no test edits.

### Batch 2 — `refactor(io): delete orphaned save_exists query module`
- Items: **L-save-1**
- Files: src/io/save_query.odin (whole-file delete)
- Rationale: whole-file orphan; superseded by Save_Manager facade.

### Batch 3 — `refactor(render): drop superseded title-fx, color wrappers, and empty stubs`
- Items: **ER-titlefx-1, ER-rendercolor-1, ER-stubs-1**
- Files: src/render/render_title_fx.odin (delete), src/render/render_color.odin (drop 2 procs, keep the 3 live ones), src/render/render_hud.odin + render_minimap.odin + render_ui.odin (delete)
- Rationale: all dead render-layer surface; live render goes through Clay / engine vtable.

### Batch 4 — `refactor(gameplay,gen,input): remove orphaned helpers`
- Items: **L-gameplay-1, L-gen-1, L-input-1**
- Files: src/gameplay/events.odin, src/gen/mapgen_profile.odin, src/input/manager.odin
- Rationale: three independent dead procs across game-logic sub-packages, no test edits.

### Batch 5 — `refactor(engine): remove bypassed Tile_State single-field accessors`
- Items: **ER-tilestate-accessors-1**
- Files: src/engine/tile_state_manager.odin (+ test/engine/tile_state_manager_test.odin)
- Rationale: 9 procs in one file; **requires** rewriting/removing the matching test assertions (read via `tile_state_at(...).field`). Isolated because it carries a coupled test edit.

### Batch 6 — `refactor: prune dead per-package re-export aliases`
- Items: **L-alias-ai-1, L-alias-gameplay-1, L-alias-gen-1, L-alias-input-1, L-alias-input-2, L-alias-io-1**
- Files: src/ai/common.odin, src/gameplay/common.odin, src/gen/common.odin, src/input/common.odin (aliases + NO_AUDIO redecl), src/io/save_common.odin
- Rationale: pure alias-line deletions, one consuming `common.odin` per package, underlying symbols untouched. Saved last because they touch the most files and benefit from earlier batches already proving green. **Note (L-alias-io-1):** inline the in-file `clear_visited_floors(game)` call at save_common.odin:76 to `gcore.clear_visited_floors(game)` before deleting that alias; the other 4 aliases are fully dead. Keep `mapgen_bounds_*` (lines 172-175) — that is the deferred L-alias-gameplay-2.

> No save-format batch is scheduled. The only save-layout candidate (L-core-5) is deferred to needs_decision; if approved later it becomes a final standalone batch `refactor(save)!: drop Light_Source subsystem (save-format vNN bump + migration)` run after all of the above.

---

## 4. Per-item detail (confirmed removes)

### L-save-1 — dead save_exists trio
- removal_note: Delete entire src/io/save_query.odin (3 procs, package decl, one import). No external references; same package, no test refs.
- proof: grep for save_exists/_at/_in_storage (excl save_manager_save_exists) returns only 5 self-references inside the file. Live path: gcore.save_manager_save_exists (used by input/title_state.odin, render/clay_overlays.odin).

### L-core-1 — ITEM_ID_WEB_TILE
- removal_note: Delete line 8 of src/core/content_ids.odin.
- proof: grep returns only content_ids.odin:8. Web render uses bare "web" literal; web ability uses ENEMY_ABILITY_WEB.

### L-core-2 — CARDINAL_DIRS
- removal_note: Delete line 5 of src/core/directions.odin; keep CARDINAL_DX/DY.
- proof: grep def-only; CARDINAL_DX (18 refs) / CARDINAL_DY (18 refs) are the live tables.

### L-core-3 — tile_light_level_idx
- removal_note: Delete the proc (game_utils.odin:66-68); keep tile_light_level_at + tile_state_at_idx.
- proof: grep def-only; x,y sibling tile_light_level_at has 3 live refs.

### L-core-4 — Equipment_Slot enum
- removal_note: Delete enum (types.odin:163-168). Do NOT touch the Equipment struct or EQUIPMENT_SLOT_* string consts.
- proof: grep for token `Equipment_Slot` returns only types.odin:163. Equipment is string-ID driven.

### L-gameplay-1 — shrine_buff_label
- removal_note: Delete the proc (events.odin:57-67); keep Shrine_Buff enum, SHRINE_BUFF_COUNT, apply_shrine_buff.
- proof: grep def-only; labels rendered from SHRINE_BUFF_LABELS array in clay_events.odin.

### L-input-1 — action_binding_ptr
- removal_note: Delete proc (manager.odin:127-130); keep value-returning action_binding.
- proof: grep def-only in src+test; not re-exported.

### L-gen-1 — mapgen_floor_count
- removal_note: Delete proc (mapgen_profile.odin:88-94); keep other mapgen_* helpers.
- proof: grep def-only; generate_cave inlines an equivalent floor-count loop.

### ER-titlefx-1 — render_title_fx.odin
- removal_note: Delete the whole file. render_measure_text/draw_text/draw_rectangle stay (other callers).
- proof: grep zero callers for draw_centered_text/draw_title_embers; live backdrop is clay_render_title_overlay → clay_render_title_embers; clay_menu.odin:22 has commented-out reference confirming replacement.

### ER-rendercolor-1 — render_color wrappers
- removal_note: Delete only render_draw_rectangle_lines and render_draw_texture_region from src/render/render_color.odin; keep render_draw_rectangle/text/measure_text. Watch for unused-import fallout (eng/gcore still used by remaining procs).
- proof: grep shows zero callers of the renderer-layer wrappers. The numerous other hits are the engine vtable layer (engine_render_draw_*, nil_*, raylib_*) and test fakes — distinct symbols, all kept.

### ER-stubs-1 — empty render stubs
- removal_note: Delete render_hud.odin, render_minimap.odin, render_ui.odin (each 17 bytes, package-only).
- proof: zero symbols, nothing can reference them; real impls in clay_*.odin.

### ER-tilestate-accessors-1 — Tile_State single-field accessors
- removal_note: Delete 6 getters (lines 44-66) + 3 single-field setters (107-139) from tile_state_manager.odin. Keep tile_state_at/_idx, tile_state_set/_idx, clear_visibility, import/export, make/is_valid/cell_count. Remove or rewrite the matching assertions in test/engine/tile_state_manager_test.odin to read tile_state_at(...).field.
- proof: grep for eng.tile_state_visible/explored/light_level + set_ variants across src returns empty; prod reads via gcore wrappers + struct fields, writes via full-record setters; remaining refs test-only.

### L-alias-ai-1 — dead ai aliases
- removal_note: Delete src/ai/common.odin lines 19,22,45,50,53,58,74,75 (TILE_SIZE, BASE_AP_PER_ROUND, tile_visible_at, item_display_name, clear_messages, Game_Log_Channel, Status_Kind, Status_Turns).
- proof: zero unqualified non-common uses in package ai; no aipkg. refs in src/test. ai combat uses `.Frozen` literal, not Status_Kind alias.

### L-alias-gameplay-1 — dead gameplay aliases (28)
- removal_note: Delete the 28 listed lines from src/gameplay/common.odin; keep section headers and interleaved live aliases; keep mapgen_bounds_* (deferred). Keep wrapper game_engine_audio_manager; only the game_engine_ui_manager alias is dead.
- proof: zero non-common unqualified uses + zero gp. qualified refs for all 28; test bare-name uses resolve to test_imports' own aliases.

### L-alias-gen-1 — dead gen aliases (5)
- removal_note: Delete src/gen/common.odin lines 14,27,31,38,42 (Item, idx_to_pos, web_tiles_clear, content_manager_room_item_chance, Game_Log_Channel); keep Item_Def, Ore_Vein, pos_to_idx.
- proof: zero non-common uses; no genpkg. refs; gen uses Item_Def/Ore_Vein not the bare Item alias.

### L-alias-input-1 — dead gameinput aliases (18)
- removal_note: Delete the 18 listed lines from src/input/common.odin; keep live type aliases (Game, Vec2, Content_Manager, Message_Manager, Engine, UI_Manager) and all CHEATS-guarded blocks.
- proof: zero non-common uses + zero gameinput. refs; status_active called with `.Frozen` literal.

### L-alias-input-2 — dead NO_AUDIO redeclaration in input
- removal_note: Delete src/input/common.odin line 13 (`NO_AUDIO :: #config(NO_AUDIO, false)`); keep CHEATS_ENABLED and NO_SPRITES (both used in `when` guards). Global build flag in audio layer unaffected.
- proof: grep shows only the def line in src/input; no `when NO_AUDIO` guard in the input package. Flag matrix covers NO_AUDIO=true.

### L-alias-io-1 — dead gameio aliases (5)
- removal_note: Delete src/io/save_common.odin lines 30,31,49,71,72. For clear_visited_floors (used by in-file game_cleanup at line 76): inline that one call to `gcore.clear_visited_floors(game)`, then delete the alias.
- proof: zero non-common uses + zero gameio. refs for all 5; only in-file caller is game_cleanup.

---

## 5. KEEP_DEFENSIVE — do NOT touch

- **ER-importanchor-keep-1 / the 10 clay `*_import_anchor` procs** (clay_hud, clay_menu, clay_messages, clay_minimap, clay_overlays, clay_renderer, clay_screen_ui, clay_theme, clay_tooltip, clay_ui). Intentional Odin unused-import idiom. Default: keep (see callout 1a; deferred, not scheduled).
- **L-input-2 / `cheat_import_anchor` (src/input/cheats.odin)** — load-bearing keepalive for the CHEATS=false (PUBLIC_BUILD) compile; all real fmt/gcore uses are inside `when CHEATS_ENABLED`. Removing it breaks the flag matrix.
- **`_lifecycle_import_anchor` (src/game_app_lifecycle.odin)** — load-bearing keepalive for the NO_AUDIO=true compile; the only real gameaudio use (music_update) is inside `when !NO_AUDIO`. Removing it breaks the flag matrix. (Corrects L-anchor-1, which wrongly listed it as remove.)
- **L-ai-1 / detection_radius<=0 "always aware" branch** — live handler for the unknown-id fallback enemy (which leaves detection_radius=0); not dead.
- **L-anchor-1 as a whole** — superseded by callout 1a; not scheduled.
