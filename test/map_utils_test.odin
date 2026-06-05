#+build !js
package main

import "core:testing"

@(test)
fire_vent_tiles_are_walkable :: proc(t: ^testing.T) {
	game: Game
	game_init_world(&game)
	game.tiles[pos_to_idx(2, 1)].type = .Fire_Vent

	testing.expect(t, is_walkable(&game, 2, 1))
}
