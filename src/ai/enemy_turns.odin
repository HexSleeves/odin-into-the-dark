package ai

import "core:math/rand"

import eng "../engine"


process_enemy_turns :: proc(messages: ^Message_Manager, game: ^Game) {
	if game.state == .Game_Over {return}

	// Recompute dijkstra map so enemies have fresh pathfinding
	compute_dijkstra_map(game)

	for &enemy in game.enemies {
		if game.state == .Game_Over {return}
		if !enemy.alive {continue}

		// Grant this round's AP (accumulates on any debt from previous rounds)
		enemy.energy += enemy.quickness * 10

		// Let the enemy act until it runs out of AP
		for enemy.energy > 0 {
			if game.state == .Game_Over {return}
			enemy_update_awareness(game, &enemy)
			if !enemy_act_once(messages, game, &enemy) {break}
			if game.state == .Game_Over {return}
			if !enemy.alive {break}
		}
	}
}

// ─── Single-action dispatcher ─────────────────────────────────────────────────

// enemy_act_once performs exactly one action and deducts its AP cost.
// Returns true if an action was taken, false if the enemy should stop acting.
@(private = "file")
enemy_act_once :: proc(
	messages: ^Message_Manager,
	game: ^Game,
	enemy: ^Enemy,
) -> bool {
	move_cost := max(1, BASE_MOVE_COST * enemy.move_speed / 100)

	switch enemy.behavior {
	case ENEMY_BEHAVIOR_LURKER:
		if enemy.aware {
			return lurker_act_once(messages, game, enemy)
		}
		enemy.energy = 0
		return false
	case:
		if enemy.aware {
			return chase_act_once(messages, game, enemy, move_cost)
		}
		return wander_act_once(game, enemy, move_cost)
	}
}

// enemy_update_awareness checks if the enemy can detect the player
// based on Manhattan distance to its detection_radius.
// Once aware, an enemy stays aware (it heard/saw you).
@(private = "file")
enemy_update_awareness :: proc(game: ^Game, enemy: ^Enemy) {
	if enemy.aware {return}
	// detection_radius 0 means "always detect" (legacy / hand-built enemies)
	if enemy.detection_radius <= 0 {
		enemy.aware = true
		return
	}
	dx := abs(enemy.pos.x - game.player.pos.x)
	dy := abs(enemy.pos.y - game.player.pos.y)
	if dx + dy <= enemy.detection_radius {
		enemy.aware = true
	}
}

// ─── Chase behavior (dijkstra downhill) ──────────────────────────────────────

@(private = "file")
chase_act_once :: proc(
	messages: ^Message_Manager,
	game: ^Game,
	enemy: ^Enemy,
	move_cost: int,
) -> bool {
	dx := CARDINAL_DX
	dy := CARDINAL_DY

	// Attack if adjacent
	for dir in 0 ..< 4 {
		nx := enemy.pos.x + dx[dir]
		ny := enemy.pos.y + dy[dir]
		if nx == game.player.pos.x && ny == game.player.pos.y {
			resolve_attack_enemy_on_player(messages, game, enemy)
			enemy.energy -= BASE_ACTION_COST
			return true
		}
	}

	// Move toward player via Dijkstra map
	dmap := eng.engine_distance_map_make(game.dijkstra_map[:], game_grid(game), DMAP_UNREACHABLE)
	current_dist := eng.engine_distance_map_get(&dmap, enemy.pos.x, enemy.pos.y)
	if current_dist >= DMAP_UNREACHABLE {
		enemy.energy = 0
		return false
	}

	best_pos := enemy.pos
	best_dist := current_dist
	for dir in 0 ..< 4 {
		nx := enemy.pos.x + dx[dir]
		ny := enemy.pos.y + dy[dir]
		if nx < 0 || nx >= MAP_WIDTH || ny < 0 || ny >= MAP_HEIGHT {continue}
		if !is_walkable(game, nx, ny) {continue}
		if enemy_at(game, nx, ny) != nil {continue}
		if nx == game.player.pos.x && ny == game.player.pos.y {continue}

		n_dist := eng.engine_distance_map_get(&dmap, nx, ny)
		if n_dist < best_dist {
			best_dist = n_dist
			best_pos = Vec2{nx, ny}
		}
	}

	if best_pos != enemy.pos {
		enemy.pos = best_pos
		enemy.energy -= move_cost
		return true
	}

	// Stuck — drain AP to prevent spin
	enemy.energy = 0
	return false
}

// ─── Wander behavior (random movement) ──────────────────────────────────────

@(private = "file")
wander_act_once :: proc(game: ^Game, enemy: ^Enemy, move_cost: int) -> bool {
	// 50% chance to stay put each time (preserves existing wandering feel)
	if rand.int_max(2) == 0 {
		enemy.energy = 0
		return false
	}

	dx := CARDINAL_DX
	dy := CARDINAL_DY

	dir := rand.int_max(4)
	nx := enemy.pos.x + dx[dir]
	ny := enemy.pos.y + dy[dir]

	if nx < 0 || nx >= MAP_WIDTH || ny < 0 || ny >= MAP_HEIGHT {
		enemy.energy = 0
		return false
	}
	if !is_walkable(game, nx, ny) {
		enemy.energy = 0
		return false
	}
	if enemy_at(game, nx, ny) != nil {
		enemy.energy = 0
		return false
	}
	if nx == game.player.pos.x && ny == game.player.pos.y {
		enemy.energy = 0
		return false
	}

	enemy.pos = Vec2{nx, ny}
	enemy.energy -= move_cost
	return true
}

// ─── Lurker behavior (stays still until adjacent, then attacks) ──────────────

@(private = "file")
lurker_act_once :: proc(messages: ^Message_Manager, game: ^Game, enemy: ^Enemy) -> bool {
	dx := CARDINAL_DX
	dy := CARDINAL_DY

	// Attack if adjacent
	for dir in 0 ..< 4 {
		nx := enemy.pos.x + dx[dir]
		ny := enemy.pos.y + dy[dir]
		if nx == game.player.pos.x && ny == game.player.pos.y {
			resolve_attack_enemy_on_player(messages, game, enemy)
			enemy.energy -= BASE_ACTION_COST
			return true
		}
	}

	// Not adjacent: lurker stays completely still
	enemy.energy = 0
	return false
}


// ─── Process special abilities ───────────────────────────────────────────────
