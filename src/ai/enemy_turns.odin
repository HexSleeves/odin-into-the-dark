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
enemy_act_once :: proc(messages: ^Message_Manager, game: ^Game, enemy: ^Enemy) -> bool {
	// Webbed enemies are stuck — they lose their whole round struggling.
	if status_active(&enemy.status, .Webbed) {
		enemy.energy = 0
		return false
	}

	move_cost := max(1, BASE_MOVE_COST * enemy.move_speed / 100)
	if status_active(&enemy.status, .Frozen) {move_cost *= 2}

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

// enemy_update_awareness manages detection and memory decay.
//
// Detection model:
//   Sight (LOS required): enemy detects player if it has LOS AND
//     dist <= max(player_light_radius, 2).
//     A brighter torch expands the sight-detection window (risk/reward).
//     The floor of 2 keeps melee-range detection even in pitch darkness.
//   Hearing (no LOS): dist <= max(1, detection_radius/3) — enemies are
//     never fully blind but cannot hunt from afar without light.
//   detection_radius <= 0: always aware (legacy enemies, unaffected).
@(private = "file")
enemy_update_awareness :: proc(game: ^Game, enemy: ^Enemy) {
	// detection_radius 0 = always aware (legacy / hand-built enemies)
	if enemy.detection_radius <= 0 {
		enemy.aware = true
		return
	}

	dist := abs(enemy.pos.x - game.player.pos.x) + abs(enemy.pos.y - game.player.pos.y)

	// Compute the player's effective emitted light radius (mirrors compute_fov formula).
	// Includes boost, debuff, and helmet bonus — all transient fields on Game/Player.
	helmet_bonus := 0
	if game.equipped_helmet.occupied {helmet_bonus = game.equipped_helmet.item.stat_bonus}
	player_light_radius :=
		game.player.light_radius + game.light_boost_bonus + game.light_debuff_bonus + helmet_bonus

	// Sight detection: LOS + within lit area (floor at 2 for close-range regardless).
	sight_range := max(player_light_radius, 2)
	hearing_radius := max(1, enemy.detection_radius / 3)
	has_los := enemy_has_los_to_player(game, enemy.pos)

	if (has_los && dist <= sight_range) || dist <= hearing_radius {
		enemy.aware = true
		enemy.aware_turns_left = enemy.memory_turns
		return
	}

	if !enemy.aware {return}

	// Out of detectable range — decay memory
	enemy.aware_turns_left -= 1
	if enemy.aware_turns_left <= 0 {
		enemy.aware = false
		enemy.aware_turns_left = 0
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
