package gameplay

import gcore "../core"
import "core:math/rand"

// ─── Map generation dispatch ──────────────────────────────────────────────────

can_place_item :: proc(game: ^Game, x, y: int) -> bool {
	if !is_walkable(game, x, y) {return false}
	if x == game.player.pos.x && y == game.player.pos.y {return false}
	if enemy_at(game, x, y) != nil {return false}
	if t := tile_at(game, x, y); t != nil && t.type == .Descent {return false}
	if item_at(game, x, y) != nil {return false}
	return true
}

spawn_items :: proc(content: ^Content_Manager, game: ^Game) {
	clear(&game.items)

	if len(game.rooms) < 2 {
		target := 3 + game.depth
		if target > 10 {target = 10}

		spawned := 0
		for _ in 0 ..< target * 10 {
			if spawned >= target {break}
			x := rand.int_max(MAP_WIDTH - 2) + 1
			y := rand.int_max(MAP_HEIGHT - 2) + 1
			pos := Vec2{x, y}
			if !can_place_item(game, x, y) {continue}

			def := gcore.content_manager_pick_item_def_for_depth(content, game.depth)
			if def != nil {
				append(&game.items, item_make_from_def(def, pos))
				spawned += 1
			}
		}
		logger_debugf(.Items, "spawned %v items (cave, depth=%v)", spawned, game.depth)
		return
	}

	room_chance := gcore.content_manager_room_item_chance(content)
	if room_chance <= 0 {room_chance = 50}

	total := 0

	for i in 1 ..< len(game.rooms) {
		if rand.int_max(100) >= room_chance {
			continue
		}

		room := game.rooms[i]

		placed := false
		for _ in 0 ..< 20 {
			ix, iy := rand_room_interior(room)
			pos := Vec2{ix, iy}

			if !can_place_item(game, ix, iy) {continue}

			def := gcore.content_manager_pick_item_def_for_depth(content, game.depth)
			if def != nil {
				append(&game.items, item_make_from_def(def, pos))
				total += 1
			}
			placed = true
			break
		}

		_ = placed
	}

	logger_debugf(
		.Items,
		"spawned %v items across %v rooms (depth=%v)",
		total,
		len(game.rooms) - 1,
		game.depth,
	)
}

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
