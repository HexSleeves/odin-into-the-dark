#+build !js
package main

import "core:testing"

mining_test_fill_tiles :: proc(game: ^Game, tile_type: Tile_Type = .Floor) {
	game_init_world(game)
	for &tile in game.tiles {
		tile.type = tile_type
	}
}

mining_test_equip_pickaxe :: proc(game: ^Game) {
	game.equipped_weapon.occupied = true
	game.equipped_weapon.item = Item {
		name           = "Test Pickaxe",
		max_durability = 10,
		durability     = 10,
	}
}

@(test)
mine_wall_clears_fire_vent_to_rubble :: proc(t: ^testing.T) {
	game: Game
	mining_test_fill_tiles(&game)
	game.player.pos = Vec2{1, 1}
	game.tiles[pos_to_idx(2, 1)].type = .Fire_Vent
	mining_test_equip_pickaxe(&game)
	messages := message_manager_make()
	content := content_manager_make()

	mined := mine_wall(&content, &messages, &game, 1, 0)

	testing.expect(t, mined)
	testing.expect_value(t, game.tiles[pos_to_idx(2, 1)].type, Tile_Type.Rubble)
}

@(test)
mine_wall_clears_gas_vent_to_rubble :: proc(t: ^testing.T) {
	game: Game
	mining_test_fill_tiles(&game)
	game.player.pos = Vec2{1, 1}
	game.tiles[pos_to_idx(2, 1)].type = .Gas_Vent
	mining_test_equip_pickaxe(&game)
	messages := message_manager_make()
	content := content_manager_make()

	mined := mine_wall(&content, &messages, &game, 1, 0)

	testing.expect(t, mined)
	testing.expect_value(t, game.tiles[pos_to_idx(2, 1)].type, Tile_Type.Rubble)
}
