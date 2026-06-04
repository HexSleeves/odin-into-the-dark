#+build !js
package main

import "core:testing"

fov_test_fill_tiles :: proc(game: ^Game, tile_type: Tile_Type = .Floor) {
	game_init_world(game)
	for &tile in game.tiles {
		tile.type = tile_type
	}
}

@(test)
fov_radius_zero_only_reveals_player_tile :: proc(t: ^testing.T) {
	game: Game
	fov_test_fill_tiles(&game)
	game.player.pos = Vec2{5, 5}
	game.player.light_radius = 0

	compute_fov(&game)

	testing.expect(t, tile_visible_at(&game, 5, 5))
	testing.expect(t, !tile_visible_at(&game, 6, 5))
	testing.expect(t, !tile_visible_at(&game, 5, 6))
}

@(test)
fov_wall_is_visible_but_blocks_tile_behind_it :: proc(t: ^testing.T) {
	game: Game
	fov_test_fill_tiles(&game)
	game.player.pos = Vec2{2, 2}
	game.player.light_radius = 5
	game.tiles[pos_to_idx(3, 2)].type = .Wall

	compute_fov(&game)

	testing.expect(t, tile_visible_at(&game, 3, 2))
	testing.expect(t, !tile_visible_at(&game, 4, 2))
}

@(test)
fov_locked_door_is_visible_but_blocks_tile_behind_it :: proc(t: ^testing.T) {
	game: Game
	fov_test_fill_tiles(&game)
	game.player.pos = Vec2{2, 2}
	game.player.light_radius = 5
	game.tiles[pos_to_idx(3, 2)].type = .Locked_Door

	compute_fov(&game)

	testing.expect(t, tile_visible_at(&game, 3, 2))
	testing.expect(t, !tile_visible_at(&game, 4, 2))
}

@(test)
fov_clear_visibility_preserves_explored_memory :: proc(t: ^testing.T) {
	game: Game
	fov_test_fill_tiles(&game)
	game.player.pos = Vec2{5, 5}
	game.player.light_radius = 1
	_ = tile_state_set(&game, 10, 10, true, true, 0.75)

	compute_fov(&game)

	testing.expect(t, !tile_visible_at(&game, 10, 10))
	testing.expect(t, tile_explored_at(&game, 10, 10))
	testing.expect(t, tile_visible_at(&game, 5, 5))
}

@(test)
fov_origin_at_map_edge_keeps_valid_in_bounds_visibility :: proc(t: ^testing.T) {
	game: Game
	fov_test_fill_tiles(&game)
	game.player.pos = Vec2{0, 0}
	game.player.light_radius = 3

	compute_fov(&game)

	testing.expect(t, tile_visible_at(&game, 0, 0))
	testing.expect(t, tile_visible_at(&game, 1, 0) || tile_visible_at(&game, 0, 1))
}
