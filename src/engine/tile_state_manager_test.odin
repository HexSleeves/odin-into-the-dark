package engine

import "core:testing"

@(test)
tile_state_manager_starts_empty_and_respects_bounds :: proc(t: ^testing.T) {
	states := tile_state_manager_make(engine_grid_2d_make(4, 3))

	testing.expect(t, tile_state_manager_is_valid(states))
	testing.expect_value(t, tile_state_manager_cell_count(states), 12)
	testing.expect(t, !tile_state_visible(states, 2, 1))
	testing.expect(t, !tile_state_explored(states, -1, 0))
	testing.expect_value(t, tile_state_light_level(states, 4, 0), f32(0))
}

@(test)
tile_state_manager_sets_visibility_exploration_and_light :: proc(t: ^testing.T) {
	states := tile_state_manager_make(engine_grid_2d_make(4, 3))

	tile_state_set(&states, 2, 1, true, true, 0.75)

	testing.expect(t, tile_state_visible(states, 2, 1))
	testing.expect(t, tile_state_explored(states, 2, 1))
	testing.expect_value(t, tile_state_light_level(states, 2, 1), f32(0.75))
}

@(test)
tile_state_manager_clears_visibility_without_losing_exploration :: proc(t: ^testing.T) {
	states := tile_state_manager_make(engine_grid_2d_make(4, 3))
	tile_state_set(&states, 2, 1, true, true, 0.5)

	tile_state_clear_visibility(&states)

	testing.expect(t, !tile_state_visible(states, 2, 1))
	testing.expect(t, tile_state_explored(states, 2, 1))
	testing.expect_value(t, tile_state_light_level(states, 2, 1), f32(0))
}

@(test)
tile_state_manager_imports_and_exports_linear_storage :: proc(t: ^testing.T) {
	states := tile_state_manager_make(engine_grid_2d_make(4, 3))
	input: [12]Tile_State
	input[5] = Tile_State {
		visible     = true,
		explored    = true,
		light_level = 0.4,
	}
	output: [12]Tile_State

	tile_state_manager_import(&states, input[:])
	testing.expect(t, tile_state_visible(states, 1, 1))
	testing.expect(t, tile_state_explored(states, 1, 1))
	testing.expect_value(t, tile_state_light_level(states, 1, 1), f32(0.4))

	tile_state_manager_export(states, output[:])
	testing.expect(t, output[5].visible)
	testing.expect(t, output[5].explored)
	testing.expect_value(t, output[5].light_level, f32(0.4))
}
