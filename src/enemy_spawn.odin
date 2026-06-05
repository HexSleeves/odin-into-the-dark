package main

import "core:math/rand"



spawn_enemies :: proc(content: ^Content_Manager, game: ^Game) {
	clear(&game.enemies)

	if len(game.rooms) >= 2 {
		// Room-based spawning: skip room 0 (player's room), 1-2 enemies per room
		total := 0
		for i in 1 ..< len(game.rooms) {
			room := game.rooms[i]
			count := rand.int_max(2) + 1 // 1 or 2

			for _ in 0 ..< count {
				for _ in 0 ..< 20 {
					ex := rand.int_max(room.x2 - room.x1 - 2) + room.x1 + 1
					ey := rand.int_max(room.y2 - room.y1 - 2) + room.y1 + 1
					pos := Vec2{ex, ey}

					if !can_place_enemy(game, ex, ey) {continue}
					def := content_manager_enemy_def_for_depth(content, game.depth)
					if def != nil {
						append(&game.enemies, enemy_make_from_def(def, pos))
						total += 1
					}
					break
				}
			}
		}
		logger_debugf(
			.Enemy,
			"spawned %v enemies across %v rooms (depth=%v)",
			total,
			len(game.rooms) - 1,
			game.depth,
		)
	} else {
		// Cave layout: scatter enemies on random floor tiles
		target := 3 + game.depth + game.depth / 2 // slower scaling
		if target > 15 {target = 15}

		spawned := 0
		for _ in 0 ..< target * 10 {
			if spawned >= target {break}
			x := rand.int_max(MAP_WIDTH - 2) + 1
			y := rand.int_max(MAP_HEIGHT - 2) + 1
			pos := Vec2{x, y}
			if !can_place_enemy(game, x, y) {continue}

			def := content_manager_enemy_def_for_depth(content, game.depth)
			if def != nil {
				append(&game.enemies, enemy_make_from_def(def, pos))
				spawned += 1
			}
		}
		logger_debugf(.Enemy, "spawned %v enemies (cave, depth=%v)", spawned, game.depth)
	}
}

// ─── Find enemy at position ──────────────────────────────────────────────────

enemy_at :: proc(game: ^Game, x, y: int) -> ^Enemy {
	for &e in game.enemies {
		if e.alive && e.pos.x == x && e.pos.y == y {
			return &e
		}
	}
	return nil
}

// ─── Dijkstra map (BFS flood-fill from player) ──────────────────────────────
