package main


generate_map :: proc(content: ^Content_Manager, game: ^Game) {
	// Clear tiles
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		game.tiles[i] = Tile{}
	}
	web_tiles_clear(game)

	// Clear rooms and state
	clear(&game.rooms)
	game.skip_next_turn = false

	// Dispatch by depth
	if game.depth <= 2 {
		generate_rooms(game)
	} else if game.depth <= 4 {
		generate_mixed(game)
	} else {
		generate_cave(game)
	}

	// Spawn enemies and items (works for all gen types)
	spawn_enemies(content, game)
	spawn_items(content, game)
	spawn_hazards(game)
	spawn_ore_veins(game)

	// Spawn 1 anvil per floor
	spawn_anvil(game)

	// Spawn boss on milestone depths
	spawn_boss(content, game)

	// Spawn optional fountain (depth 2+)
	spawn_fountain(game)
	spawn_monster_den(content, game)
	spawn_treasure_vault(content, game)

	// Clear hazard state
	game.minimap_reveal_enemies = false
	game.water_slow_active = false

	// Set depth-based floor palette
	game.palette = palette_for_depth(game.depth)
}

// ─── Room-and-corridor generator ──────────────────────────────────────────────
