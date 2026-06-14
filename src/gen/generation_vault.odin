package gen

import "core:math/rand"

room_contains_point :: proc(room: Room, x, y: int) -> bool {
	return x >= room.x1 && x < room.x2 && y >= room.y1 && y < room.y2
}

room_perimeter_contains_point :: proc(room: Room, x, y: int) -> bool {
	if !room_contains_point(room, x, y) {return false}
	return x == room.x1 || x == room.x2 - 1 || y == room.y1 || y == room.y2 - 1
}

find_vault_door_position :: proc(game: ^Game, room: Room) -> (door: Vec2, ok: bool) {
	dx := [4]int{0, 1, 0, -1}
	dy := [4]int{-1, 0, 1, 0}
	for y in room.y1 ..< room.y2 {
		for x in room.x1 ..< room.x2 {
			if !room_perimeter_contains_point(room, x, y) {continue}
			if game.tiles[pos_to_idx(x, y)].type != .Floor {continue}
			for dir in 0 ..< 4 {
				out_x := x + dx[dir]
				out_y := y + dy[dir]
				in_x := x - dx[dir]
				in_y := y - dy[dir]
				if room_contains_point(room, out_x, out_y) {continue}
				if !room_contains_point(room, in_x, in_y) {continue}
				if out_x < 0 || out_x >= MAP_WIDTH || out_y < 0 || out_y >= MAP_HEIGHT {continue}
				if game.tiles[pos_to_idx(out_x, out_y)].type != .Floor {continue}
				if game.tiles[pos_to_idx(in_x, in_y)].type != .Floor {continue}
				return Vec2{x, y}, true
			}
		}
	}
	return {}, false
}

seal_room_perimeter_for_vault :: proc(game: ^Game, room: Room, door: Vec2) {
	for y in room.y1 ..< room.y2 {
		for x in room.x1 ..< room.x2 {
			if !room_perimeter_contains_point(room, x, y) {continue}
			if x == door.x && y == door.y {
				game.tiles[pos_to_idx(x, y)].type = .Locked_Door
			} else {
				game.tiles[pos_to_idx(x, y)].type = .Wall
			}
		}
	}
}

vault_loot_def :: proc(content: ^Content_Manager, depth: int) -> ^Item_Def {
	if depth >= 6 {
		if def := content_manager_item_def(content, "greatsword"); def != nil {return def}
	}
	if def := content_manager_item_def(content, "mine_dagger"); def != nil {return def}
	return content_manager_pick_item_def_for_depth(content, depth)
}

// room_interior_contains_tile returns true if any tile inside the room
// (excluding the perimeter) matches the given type.
@(private = "file")
room_interior_contains_tile :: proc(game: ^Game, room: Room, t: Tile_Type) -> bool {
	for y in room.y1 + 1 ..< room.y2 - 1 {
		for x in room.x1 + 1 ..< room.x2 - 1 {
			if game.tiles[pos_to_idx(x, y)].type == t {return true}
		}
	}
	return false
}

// room_contains_pos returns true if the given position lies inside the room
// boundary (inclusive of perimeter).
@(private = "file")
room_contains_pos :: proc(room: Room, pos: Vec2) -> bool {
	return pos.x >= room.x1 && pos.x < room.x2 && pos.y >= room.y1 && pos.y < room.y2
}

spawn_treasure_vault :: proc(content: ^Content_Manager, game: ^Game) {
	if game.depth < 4 || len(game.rooms) < 4 {return}
	if rand.int_max(5) != 0 {return}

	// Pick a mid room, skipping the first (player start) and last (descent area).
	// Also reject any room whose interior contains .Descent or the player spawn.
	room_idx := rand.int_max(len(game.rooms) - 2) + 1
	room := game.rooms[room_idx]

	// Guard 1: never seal a room that contains the .Descent tile.
	if room_interior_contains_tile(game, room, .Descent) {
		logger_debugf(
			.Gen,
			"vault skip: candidate room %v contains descent tile (depth=%v)",
			room_idx,
			game.depth,
		)
		return
	}

	// Guard 2: never seal a room that contains the player spawn position.
	if room_contains_pos(room, game.player.pos) {
		logger_debugf(
			.Gen,
			"vault skip: candidate room %v contains player spawn (depth=%v)",
			room_idx,
			game.depth,
		)
		return
	}

	door, door_ok := find_vault_door_position(game, room)
	if !door_ok {return}

	key_def := content_manager_item_def(content, ITEM_ID_VAULT_KEY)
	if key_def == nil {return}
	loot_def := vault_loot_def(content, game.depth)
	if loot_def == nil {return}

	seal_room_perimeter_for_vault(game, room, door)

	// Guard 3: flood-fill from player spawn to verify the key can be placed
	// on a reachable tile outside the vault.  If no reachable placement exists,
	// abort cleanly — unseal the door and return rather than leave an
	// unreachable key (or worse, strand the player).
	reachable: [MAP_WIDTH * MAP_HEIGHT]bool
	flood_fill_mark(game, game.player.pos.x, game.player.pos.y, &reachable)

	key_x, key_y := -1, -1
	for _ in 0 ..< 100 {
		key_room_idx := rand.int_max(len(game.rooms))
		if key_room_idx == room_idx {continue}
		key_room := game.rooms[key_room_idx]
		x := rand.int_max(key_room.x2 - key_room.x1) + key_room.x1
		y := rand.int_max(key_room.y2 - key_room.y1) + key_room.y1
		if !is_walkable(game, x, y) {continue}
		if !reachable[pos_to_idx(x, y)] {continue}
		if item_at(game, x, y) != nil {continue}
		if x == game.player.pos.x && y == game.player.pos.y {continue}
		key_x = x
		key_y = y
		break
	}

	if key_x < 0 {
		// No reachable tile found — undo the seal (restore full perimeter to Floor)
		// and skip the vault entirely.
		for y in room.y1 ..< room.y2 {
			for x in room.x1 ..< room.x2 {
				if !room_perimeter_contains_point(room, x, y) {continue}
				game.tiles[pos_to_idx(x, y)].type = .Floor
			}
		}
		logger_debugf(
			.Gen,
			"vault abort: no reachable key placement after seal (depth=%v)",
			game.depth,
		)
		return
	}

	// Place loot inside the vault.
	for _ in 0 ..< 50 {
		x, y := rand_room_interior(room)
		if item_at(game, x, y) != nil {continue}
		append(&game.items, item_make_from_def(loot_def, Vec2{x, y}))
		break
	}

	// Place the key on the confirmed reachable tile.
	append(&game.items, item_make_from_def(key_def, Vec2{key_x, key_y}))
	logger_debugf(
		.Gen,
		"vault key at (%v,%v), door at (%v,%v) depth=%v",
		key_x,
		key_y,
		door.x,
		door.y,
		game.depth,
	)
}
