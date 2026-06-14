---
name: input-patterns
description: input package layout, quit-armed double-press pattern, reset_repeats call sites, cardinal enforcement locations
metadata:
  type: project
---

Package `gameinput` lives in `src/input/`. Key files:

- `manager.odin` — Game_Action enum, Input_Manager typedef, bindings, reset_repeats, check_repeat
- `common.odin` — all cross-package aliases; CHEATS_ENABLED defined here as `#config(CHEATS, false)`
- `state_shared.odin` — package-level globals: `death_sound_played`, `quit_armed`
- `playing_action.odin` — handle_input (movement + quit), read_cardinal_press
- `playing_state.odin` — update_playing, handle_playing_hotkeys (state transitions to Inventory/Crafting/Help)
- `state_updates.odin` — update_viewing_inventory, update_viewing_crafting, update_viewing_help, update_viewing_scores
- `cheats.odin` — entire cheat block inside `when CHEATS_ENABLED`

Patterns established:

**Cardinal enforcement:** `if dx != 0 && dy != 0 { dy = 0 }` applied in both `read_cardinal_press` and the `check_repeat` block in `handle_input`. Prefer horizontal axis.

**Quit-armed double-press:** `quit_armed bool` in `state_shared.odin`. First Escape in `handle_input` sets flag + posts warning message; second Escape within same state quits; any non-Escape keypress clears it. State transitions also clear it via `quit_armed = false`.

**reset_repeats call sites:** Called whenever `game.state` transitions between Playing and a sub-state, to prevent held-key bleed. Sites: `handle_playing_hotkeys` (entering Inventory, Crafting, Help), `update_viewing_inventory` and `update_viewing_crafting` (returning to Playing).

**Cheat key gating:** `.Cheat_Menu` binding in `input_default_bindings` wrapped in `when CHEATS_ENABLED`. The action enum value still exists unconditionally (needed for the non-cheat stub proc signature).

**input_tick deleted:** Was dead (0 callers). Removed from manager.odin.

**Why:** reset_repeats and cardinal enforcement were pre-existing dead/incomplete code that needed wiring. quit_armed avoids adding a new Game_State enum value (would require editing core/types.odin outside the input-only constraint).
