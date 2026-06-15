#+build !js
package ui

import "core:testing"

@(test)
ui_manager_make_sets_defaults :: proc(t: ^testing.T) {
	ui := ui_manager_make(true)
	state := ui_manager_state(&ui)

	testing.expect(t, state != nil)
	testing.expect(t, state.use_sprites)
	testing.expect_value(t, state.inspect_slot, -1)
	testing.expect_value(t, state.title_choice, 0)
	testing.expect(t, !state.debug_overlay, "debug overlay should default to hidden")
}

@(test)
ui_manager_debug_overlay_flag_toggles :: proc(t: ^testing.T) {
	ui := ui_manager_make(true)
	state := ui_manager_state(&ui)

	testing.expect(t, !state.debug_overlay, "overlay starts hidden")
	state.debug_overlay = !state.debug_overlay
	testing.expect(t, state.debug_overlay, "overlay shows after first toggle")
	state.debug_overlay = !state.debug_overlay
	testing.expect(t, !state.debug_overlay, "overlay hides after second toggle")

	// New-game reset must clear the overlay back to hidden.
	state.debug_overlay = true
	ui_manager_reset_for_new_game(&ui, true)
	testing.expect(t, !state.debug_overlay, "new game reset should hide the overlay")
}

@(test)
ui_manager_resets_transient_modes_without_changing_sprite_preference :: proc(t: ^testing.T) {
	ui := ui_manager_make(true)
	state := ui_manager_state(&ui)
	state.mining_mode = true
	state.dropping = true
	state.equipping = true
	state.show_minimap = true
	state.inspect_slot = 5

	ui_manager_reset_transient(&ui)

	testing.expect(t, state.use_sprites)
	testing.expect(t, !state.mining_mode)
	testing.expect(t, !state.dropping)
	testing.expect(t, !state.equipping)
	testing.expect(t, state.show_minimap)
	testing.expect_value(t, state.inspect_slot, -1)
}
