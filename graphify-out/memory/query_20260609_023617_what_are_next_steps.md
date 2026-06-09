---
type: "query"
date: "2026-06-09T02:36:17.211508+00:00"
question: "What are next steps"
contributor: "graphify"
source_nodes: ["player actions / turn flow (handle_player_action, tick_timed_effects, apply_current_tile_effects)", "web tile consumes action without moving player", "footstep_sound_selection_matches_tile_material"]
---

# Q: What are next steps

## Answer

Expanded from original query via vocab: next steps, remaining work, shipping validation, UI package. The current actionable sequence is: finish/resolution-check the UI package state because CONTEXT.md still marks src/ui in progress, but observed ui_manager/ui_text/ui_theme already import gcore and `odin check src/ui -no-entry-point -vet -strict-style -collection:libs=vendor/` passes; then follow NEXT_STEPS.md Priority 1 shipping validation: manual QA build flags, macOS bundle smoke test, WASM/web smoke test; then Priority 2 polish: boss camera zoom tuning and title screen polish; then Priority 3 engine maturity: texture-from-memory backend and frame allocator audit. Open roadmap issues remain for larger feature work.

## Source Nodes

- player actions / turn flow (handle_player_action, tick_timed_effects, apply_current_tile_effects)
- web tile consumes action without moving player
- footstep_sound_selection_matches_tile_material