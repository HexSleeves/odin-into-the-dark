#+build !js
package main

import eng "./engine"
import "core:testing"

@(test)
game_init_world_configures_engine_world_manager :: proc(t: ^testing.T) {
	game: Game

	game_init_world(&game)

	testing.expect(t, eng.world_manager_is_valid(game.world))
	testing.expect_value(t, eng.world_manager_width(game.world), MAP_WIDTH)
	testing.expect_value(t, eng.world_manager_height(game.world), MAP_HEIGHT)
	testing.expect_value(t, eng.world_manager_tile_size(game.world), TILE_SIZE)
	testing.expect_value(t, eng.world_manager_pixel_width(game.world), MAP_WIDTH * TILE_SIZE)
	testing.expect_value(t, eng.world_manager_pixel_height(game.world), MAP_HEIGHT * TILE_SIZE)
	testing.expect_value(t, game.map_width, MAP_WIDTH)
	testing.expect_value(t, game.map_height, MAP_HEIGHT)
}

@(test)
map_helpers_use_engine_world_with_default_fallback :: proc(t: ^testing.T) {
	game: Game
	idx := pos_to_idx(3, 2)
	pos := idx_to_pos(idx)

	testing.expect_value(t, idx, 2 * MAP_WIDTH + 3)
	testing.expect_value(t, pos.x, 3)
	testing.expect_value(t, pos.y, 2)
	testing.expect(t, tile_at(&game, 0, 0) != nil)
	testing.expect(t, tile_at(&game, -1, 0) == nil)
}

@(test)
web_tile_layer_uses_engine_bool_grid_manager :: proc(t: ^testing.T) {
	game: Game
	game_init_world(&game)
	idx := pos_to_idx(2, 1)

	testing.expect(t, web_tile_set(&game, 2, 1, true))
	testing.expect(t, web_tile_at(&game, 2, 1))
	testing.expect(t, web_tile_at_idx(&game, idx))
	testing.expect_value(t, eng.bool_grid_manager_true_count(game.web_tiles), 1)

	web_tiles_clear(&game)
	testing.expect(t, !web_tile_at(&game, 2, 1))
	testing.expect_value(t, eng.bool_grid_manager_true_count(game.web_tiles), 0)
}

@(test)
tile_state_layer_uses_engine_tile_state_manager :: proc(t: ^testing.T) {
	game: Game
	game_init_world(&game)
	idx := pos_to_idx(2, 1)

	testing.expect(t, eng.tile_state_manager_is_valid(game.tile_states))
	testing.expect(t, tile_state_set(&game, 2, 1, true, true, 0.75))
	testing.expect(t, tile_visible_at(&game, 2, 1))
	testing.expect(t, tile_visible_idx(&game, idx))
	testing.expect(t, tile_explored_at(&game, 2, 1))
	testing.expect_value(t, tile_light_level_at(&game, 2, 1), f32(0.75))

	tile_states_clear_visibility(&game)
	testing.expect(t, !tile_visible_at(&game, 2, 1))
	testing.expect(t, tile_explored_at(&game, 2, 1))
	testing.expect_value(t, tile_light_level_at(&game, 2, 1), f32(0))
}
