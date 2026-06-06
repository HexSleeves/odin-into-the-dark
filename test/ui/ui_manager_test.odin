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
