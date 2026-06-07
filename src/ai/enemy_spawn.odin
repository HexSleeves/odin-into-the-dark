package ai

import "core:math/rand"

import eng "../engine"


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
					ex, ey := rand_room_interior(room)
					pos := Vec2{ex, ey}

					if !can_place_enemy(game, ex, ey) {continue}
					def := content_manager_enemy_def_for_depth(content, game.depth)
					if def != nil {
						append(&game.enemies, enemy_make_from_def(def, pos))
						logger_debugf(.Enemy, "spawned '%s' at (%v,%v) room=%v", def.id, ex, ey, i)
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
		// Cave/mixed layouts: split between route-biased and free scatter.
		target := 3 + game.depth + game.depth / 2
		if target > 15 {target = 15}

		// Route-biased: ~60% of enemies near the path to descent.
		route_target := target * 3 / 5
		free_target := target - route_target

		route: [MAP_WIDTH * MAP_HEIGHT]bool
		route_ok := enemy_spawn_mark_route_to_descent(game, &route)
		path_radius := 4 + game.depth / 3 // widen at deeper depths
		min_player_distance := max(game.player.light_radius + 2, 6)

		spawned := 0
		for _ in 0 ..< route_target * 30 {
			if spawned >= route_target {break}
			x := rand.int_max(MAP_WIDTH - 2) + 1
			y := rand.int_max(MAP_HEIGHT - 2) + 1
			if !can_place_enemy(game, x, y) {continue}

			dist := abs(x - game.player.pos.x) + abs(y - game.player.pos.y)
			if dist < min_player_distance {continue}
			if route_ok && !enemy_spawn_near_route(&route, x, y, path_radius) {continue}

			def := content_manager_enemy_def_for_depth(content, game.depth)
			if def != nil {
				append(&game.enemies, enemy_make_from_def(def, Vec2{x, y}))
				logger_debugf(.Enemy, "spawned '%s' at (%v,%v) cave route", def.id, x, y)
				spawned += 1
			}
		}

		// Free scatter: remaining enemies anywhere on walkable floor.
		for _ in 0 ..< free_target * 30 {
			if spawned >= target {break}
			x := rand.int_max(MAP_WIDTH - 2) + 1
			y := rand.int_max(MAP_HEIGHT - 2) + 1
			if !can_place_enemy(game, x, y) {continue}

			dist := abs(x - game.player.pos.x) + abs(y - game.player.pos.y)
			if dist < min_player_distance {continue}

			def := content_manager_enemy_def_for_depth(content, game.depth)
			if def != nil {
				append(&game.enemies, enemy_make_from_def(def, Vec2{x, y}))
				logger_debugf(.Enemy, "spawned '%s' at (%v,%v) cave free", def.id, x, y)
				spawned += 1
			}
		}

		for _ in 0 ..< target * 20 {
			if spawned >= target {break}
			x := rand.int_max(MAP_WIDTH - 2) + 1
			y := rand.int_max(MAP_HEIGHT - 2) + 1
			pos := Vec2{x, y}
			if !can_place_enemy(game, x, y) {continue}

			def := content_manager_enemy_def_for_depth(content, game.depth)
			if def != nil {
				append(&game.enemies, enemy_make_from_def(def, pos))
				logger_debugf(.Enemy, "spawned '%s' at (%v,%v) cave fallback", def.id, x, y)
				spawned += 1
			}
		}
		logger_debugf(.Enemy, "spawned %v enemies (cave, depth=%v)", spawned, game.depth)
	}
}

@(private = "file")
enemy_spawn_find_descent :: proc(game: ^Game) -> (pos: Vec2, ok: bool) {
	for y in 0 ..< MAP_HEIGHT {
		for x in 0 ..< MAP_WIDTH {
			if t := tile_at(game, x, y); t != nil && t.type == .Descent {
				return Vec2{x, y}, true
			}
		}
	}
	return {}, false
}

@(private = "file")
enemy_spawn_mark_route_to_descent :: proc(
	game: ^Game,
	route: ^[MAP_WIDTH * MAP_HEIGHT]bool,
) -> bool {
	descent, found := enemy_spawn_find_descent(game)
	if !found {return false}

	compute_dijkstra_map(game)
	dmap := eng.engine_distance_map_make(game.dijkstra_map[:], game_grid(game), DMAP_UNREACHABLE)
	current := descent
	current_dist := eng.engine_distance_map_get(&dmap, current.x, current.y)
	if current_dist >= DMAP_UNREACHABLE {return false}

	for current_dist > 0 {
		route[pos_to_idx(current.x, current.y)] = true
		best := current
		best_dist := current_dist
		dx := CARDINAL_DX
		dy := CARDINAL_DY
		for dir in 0 ..< 4 {
			nx := current.x + dx[dir]
			ny := current.y + dy[dir]
			next_dist := eng.engine_distance_map_get(&dmap, nx, ny)
			if next_dist < best_dist {
				best_dist = next_dist
				best = Vec2{nx, ny}
			}
		}
		if best == current {return false}
		current = best
		current_dist = best_dist
	}

	route[pos_to_idx(game.player.pos.x, game.player.pos.y)] = true
	return true
}

@(private = "file")
enemy_spawn_near_route :: proc(route: ^[MAP_WIDTH * MAP_HEIGHT]bool, x, y, radius: int) -> bool {
	for oy in -radius ..= radius {
		for ox in -radius ..= radius {
			if abs(ox) + abs(oy) > radius {continue}
			nx := x + ox
			ny := y + oy
			if nx < 0 || nx >= MAP_WIDTH || ny < 0 || ny >= MAP_HEIGHT {continue}
			if route[pos_to_idx(nx, ny)] {return true}
		}
	}
	return false
}

// ─── Dijkstra map (BFS flood-fill from player) ──────────────────────────────
