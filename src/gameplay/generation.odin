package gameplay

import gcore "../core"
import eng "../engine"
import "base:runtime"
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

ensure_floor_snapshot :: proc(game: ^Game, depth: int) -> ^Saved_Floor {
	if game == nil || depth < SURFACE_DEPTH || depth > MAX_DEPTH {return nil}
	if game.visited_floors[depth] == nil {
		game.visited_floors[depth] = new(Saved_Floor, runtime.default_allocator())
	}
	return game.visited_floors[depth]
}

save_current_floor :: proc(game: ^Game) -> bool {
	old_context := context
	context.allocator = runtime.default_allocator()
	defer {
		context = old_context
	}

	floor := ensure_floor_snapshot(game, game.depth)
	if floor == nil {return false}
	saved_floor_destroy(floor)
	floor.tiles = game.tiles
	tile_state_manager_export(game, floor.tile_states[:])
	eng.bool_grid_manager_export(game.web_tiles, floor.web_tiles[:])
	floor.ore_veins = game.ore_veins
	floor.player_pos = game.player.pos
	floor.palette = game.palette
	floor.event_used = game.event_used
	floor.npcs = game.npcs
	floor.npc_count = game.npc_count
	floor.rooms = make([dynamic]Room)
	for room in game.rooms {append(&floor.rooms, room)}
	floor.enemies = make([dynamic]Enemy)
	for enemy in game.enemies {append(&floor.enemies, enemy)}
	floor.items = make([dynamic]Item)
	for item in game.items {append(&floor.items, item)}
	floor.light_sources = make([dynamic]Light_Source)
	for light in game.light_sources {append(&floor.light_sources, light)}
	return true
}

restore_dynamic_array :: proc($T: typeid, dst: ^[dynamic]T, src: [dynamic]T) {
	if dst^ == nil {
		dst^ = make([dynamic]T)
	} else {
		clear(dst)
	}
	for item in src {append(dst, item)}
}

restore_saved_floor :: proc(game: ^Game, depth: int) -> bool {
	old_context := context
	context.allocator = runtime.default_allocator()
	defer {
		context = old_context
	}
	if game == nil || depth < SURFACE_DEPTH || depth > MAX_DEPTH {return false}
	floor := game.visited_floors[depth]
	if floor == nil {return false}
	game.tiles = floor.tiles
	tile_state_manager_import(game, floor.tile_states[:])
	eng.bool_grid_manager_import(&game.web_tiles, floor.web_tiles[:])
	game.ore_veins = floor.ore_veins
	game.player.pos = floor.player_pos
	game.palette = floor.palette
	game.event_used = floor.event_used
	if depth == SURFACE_DEPTH {
		place_town_npcs(game)
	} else {
		game.npcs = floor.npcs
		game.npc_count = floor.npc_count
	}
	restore_dynamic_array(Room, &game.rooms, floor.rooms)
	restore_dynamic_array(Enemy, &game.enemies, floor.enemies)
	enemy_occupancy_mark_dirty(game)
	restore_dynamic_array(Item, &game.items, floor.items)
	restore_dynamic_array(Light_Source, &game.light_sources, floor.light_sources)
	saved_floor_destroy(floor)
	free(floor, runtime.default_allocator())
	game.visited_floors[depth] = nil
	return true
}

generate_map :: proc(content: ^Content_Manager, game: ^Game) {
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		game.tiles[i] = Tile{}
	}
	web_tiles_clear(game)
	clear(&game.rooms)
	game.player_status[.Webbed] = 0
	game.npc_count = 0

	// Depth 0 is the surface town — a safe hub, no combat or hazards.
	if game.depth == SURFACE_DEPTH {
		generate_town(game)
		game.minimap_reveal_enemies = false
		game.water_slow_active = false
		game.event_used = true // no floor events on the surface
		return
	}

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
	spawn_floor_event(game)

	// Final floor: the Ancient Treasure replaces the descent as the goal.
	if game.depth >= MAX_DEPTH {
		place_ancient_treasure(content, game)
	}

	game.minimap_reveal_enemies = false
	game.water_slow_active = false
	game.event_used = false
	game.palette = palette_for_depth(game.depth)
}

// place_ancient_treasure removes the descent exit and drops the quest treasure
// at the farthest reachable floor — the climax of the dive.
place_ancient_treasure :: proc(content: ^Content_Manager, game: ^Game) {
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		if game.tiles[i].type == .Descent {
			game.tiles[i].type = .Floor
		}
	}
	pos := find_farthest_floor(game, game.player.pos.x, game.player.pos.y)
	def := content_manager_item_def(content, ITEM_ID_ANCIENT_TREASURE)
	if def != nil {
		append(&game.items, item_make_from_def(def, pos))
	}
}
