package main

generate_map :: proc(content: ^Content_Manager, game: ^Game) {
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		game.tiles[i] = Tile{}
	}
	web_tiles_clear(game)
	clear(&game.rooms)
	game.skip_next_turn = false

	if game.depth <= 2 {
		generate_rooms(game)
	} else if game.depth <= 4 {
		generate_mixed(game)
	} else {
		generate_cave(game)
	}

	spawn_enemies(content, game)
	spawn_items(content, game)
	spawn_hazards(game)
	spawn_ore_veins(game)
	spawn_anvil(game)
	spawn_boss(content, game)
	spawn_fountain(game)
	spawn_monster_den(content, game)
	spawn_treasure_vault(content, game)

	game.minimap_reveal_enemies = false
	game.water_slow_active = false
	game.palette = palette_for_depth(game.depth)
}
