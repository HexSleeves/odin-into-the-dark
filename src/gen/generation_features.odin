package gen

import "core:math/rand"


spawn_anvil :: proc(game: ^Game) {
	for _ in 0 ..< 200 {
		x := rand.int_max(MAP_WIDTH - 2) + 1
		y := rand.int_max(MAP_HEIGHT - 2) + 1
		idx := pos_to_idx(x, y)
		if game.tiles[idx].type != .Floor {continue}
		pos := Vec2{x, y}
		if pos == game.player.pos {continue}
		if enemy_at(game, x, y) != nil {continue}
		if item_at(game, x, y) != nil {continue}
		game.tiles[idx].type = .Anvil
		logger_debugf(.Gen, "anvil at (%v,%v)", x, y)
		return
	}
}

// ─── Boss spawning (depth-gated) ─────────────────────────────────────────────

spawn_boss :: proc(content: ^Content_Manager, game: ^Game) {
	boss_id: string
	if game.depth == 5 {
		boss_id = "mine_guardian"
	} else if game.depth == 10 {
		boss_id = "abyssal_lord"
	} else {
		return
	}

	for y in 0 ..< MAP_HEIGHT {
		for x in 0 ..< MAP_WIDTH {
			if game.tiles[pos_to_idx(x, y)].type == .Descent {
				DX :: CARDINAL_DX
				DY :: CARDINAL_DY
				dx := DX
				dy := DY
				for dir in 0 ..< 4 {
					bx := x + dx[dir]
					by := y + dy[dir]
					if is_walkable(game, bx, by) && enemy_at(game, bx, by) == nil {
						def := content_manager_enemy_def(content, boss_id)
						if def != nil {
							boss := enemy_make_from_def(def, Vec2{bx, by})
							boss.is_boss = true
							append(&game.enemies, boss)
							logger_debugf(.Gen, "boss '%s' spawned at (%v,%v)", boss_id, bx, by)
						}
						return
					}
				}
				return
			}
		}
	}
}

// ─── Fountain spawning (depth-gated) ─────────────────────────────────────────

spawn_fountain :: proc(game: ^Game) {
	if game.depth < 2 || len(game.rooms) < 3 {return}
	if rand.int_max(2) != 0 {return}
	for _ in 0 ..< 50 {
		room_idx := rand.int_max(len(game.rooms) - 1) + 1
		room := game.rooms[room_idx]
		x := rand.int_max(room.x2 - room.x1 - 2) + room.x1 + 1
		y := rand.int_max(room.y2 - room.y1 - 2) + room.y1 + 1
		idx := pos_to_idx(x, y)
		if game.tiles[idx].type != .Floor {continue}
		pos := Vec2{x, y}
		if pos == game.player.pos {continue}
		game.tiles[idx].type = .Fountain
		logger_debugf(.Gen, "fountain at (%v,%v) depth=%v", x, y, game.depth)
		return
	}
}
// ─── Monster den spawning (depth-gated) ──────────────────────────────────────

spawn_monster_den :: proc(content: ^Content_Manager, game: ^Game) {
	if game.depth < 3 || len(game.rooms) < 4 {return}
	if rand.int_max(4) != 0 {return} 	// 25% chance

	// Pick a room that isn't the first (player start) or last (descent)
	room_idx := rand.int_max(len(game.rooms) - 2) + 1
	room := game.rooms[room_idx]

	// Spawn 3-5 extra enemies in the room
	extra := rand.int_max(3) + 3
	for _ in 0 ..< extra {
		for _ in 0 ..< 20 {
			x := rand.int_max(room.x2 - room.x1) + room.x1
			y := rand.int_max(room.y2 - room.y1) + room.y1
			if !is_walkable(game, x, y) {continue}
			if enemy_at(game, x, y) != nil {continue}
			if x == game.player.pos.x && y == game.player.pos.y {continue}
			def := content_manager_enemy_def_for_depth(content, game.depth)
			if def == nil {break}
			append(&game.enemies, enemy_make_from_def(def, Vec2{x, y}))
			break
		}
	}

	// Place 1 guaranteed item in the den
	for _ in 0 ..< 50 {
		x := rand.int_max(room.x2 - room.x1) + room.x1
		y := rand.int_max(room.y2 - room.y1) + room.y1
		if !is_walkable(game, x, y) {continue}
		if item_at(game, x, y) != nil {continue}
		def := content_manager_pick_item_def_for_depth(content, game.depth)
		if def == nil {break}
		append(&game.items, item_make_from_def(def, Vec2{x, y}))
		break
	}

	logger_debugf(.Gen, "monster den in room %v at depth %v", room_idx, game.depth)
}
