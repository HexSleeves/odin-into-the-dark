package main

import "core:fmt"
import "core:math/rand"

import eng "./engine"

// ─── Enemy factory (data-driven) ─────────────────────────────────────────────

enemy_make :: proc(content: ^Content_Manager, id: string, pos: Vec2) -> Enemy {
	def := content_manager_enemy_def(content, id)
	if def != nil {
		return enemy_make_from_def(def, pos)
	}
	// Fallback: unknown enemy
	logger_warnf(.Enemy, "unknown enemy id '%s'", id)
	return Enemy {
		pos = pos,
		hp = 1,
		max_hp = 1,
		attack = 1,
		enemy_type = id,
		name = id,
		glyph = '?',
		color = eng.Engine_Color{230, 41, 55, 255},
		alive = true,
	}
}

// ─── Spawn enemies into rooms ────────────────────────────────────────────────

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

					if !is_walkable(game, ex, ey) {continue}
					if pos == game.player.pos {continue}
					if enemy_at(game, ex, ey) != nil {continue}

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
			if !is_walkable(game, x, y) {continue}
			pos := Vec2{x, y}
			if pos == game.player.pos {continue}
			if enemy_at(game, x, y) != nil {continue}
			// Don't spawn on descent
			t := tile_at(game, x, y)
			if t != nil && t.type == .Descent {continue}

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

compute_dijkstra_map :: proc(game: ^Game) {
	dmap := eng.engine_distance_map_make(game.dijkstra_map[:], game_grid(game), DMAP_UNREACHABLE)
	eng.engine_distance_map_reset(&dmap)

	// BFS queue using a simple ring buffer
	Queue_Entry :: struct {
		x, y: int,
	}
	queue: [MAP_WIDTH * MAP_HEIGHT]Queue_Entry
	head := 0
	tail := 0

	// Seed with player position
	px := game.player.pos.x
	py := game.player.pos.y
	eng.engine_distance_map_set(&dmap, px, py, 0)
	queue[tail] = {px, py}
	tail += 1

	// 4-directional offsets
	DX :: [4]int{0, 0, -1, 1}
	DY :: [4]int{-1, 1, 0, 0}

	for head != tail {
		cur := queue[head]
		head += 1
		cur_dist := eng.engine_distance_map_get(&dmap, cur.x, cur.y)

		dx := DX
		dy := DY
		for dir in 0 ..< 4 {
			nx := cur.x + dx[dir]
			ny := cur.y + dy[dir]

			if nx < 0 || nx >= MAP_WIDTH || ny < 0 || ny >= MAP_HEIGHT {continue}
			if !is_walkable(game, nx, ny) {continue}

			if eng.engine_distance_map_get(&dmap, nx, ny) <= cur_dist + 1 {continue}

			eng.engine_distance_map_set(&dmap, nx, ny, cur_dist + 1)
			queue[tail] = {nx, ny}
			tail += 1
		}
	}
}


// ─── Process enemy turns (energy-based) ──────────────────────────────────────

process_enemy_turns :: proc(messages: ^Message_Manager, game: ^Game) {
	// Recompute dijkstra map so enemies have fresh pathfinding
	compute_dijkstra_map(game)

	for &enemy in game.enemies {
		if !enemy.alive {continue}

		// Grant this round's AP (accumulates on any debt from previous rounds)
		enemy.energy += enemy.quickness * 10

		// Let the enemy act until it runs out of AP
		for enemy.energy > 0 {
			is_visible := tile_visible_at(game, enemy.pos.x, enemy.pos.y)
			if !enemy_act_once(messages, game, &enemy, is_visible) {break}
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
	is_visible: bool,
) -> bool {
	move_cost := max(1, BASE_MOVE_COST * enemy.move_speed / 100)

	switch enemy.behavior {
	case "lurker":
		if is_visible {
			return lurker_act_once(messages, game, enemy)
		}
		// Lurker stays completely still when the player can't see it
		enemy.energy = 0
		return false
	case:
		if is_visible {
			return chase_act_once(messages, game, enemy, move_cost)
		}
		return wander_act_once(game, enemy, move_cost)
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
	DX :: [4]int{0, 0, -1, 1}
	DY :: [4]int{-1, 1, 0, 0}
	dx := DX
	dy := DY

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
		// Unreachable — fall back to wander
		return wander_act_once(game, enemy, move_cost)
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

	DX :: [4]int{0, 0, -1, 1}
	DY :: [4]int{-1, 1, 0, 0}
	dx := DX
	dy := DY

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
	DX :: [4]int{0, 0, -1, 1}
	DY :: [4]int{-1, 1, 0, 0}
	dx := DX
	dy := DY

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

process_enemy_abilities :: proc(messages: ^Message_Manager, game: ^Game) {
	for &enemy in game.enemies {
		if !enemy.alive {continue}
		if enemy.ability_type == "" {continue}

		// Decrement cooldown
		if enemy.ability_cooldown > 0 {
			enemy.ability_cooldown -= 1
			continue
		}

		if enemy.ability_type == "web" {
			// Web: place web on a floor tile adjacent to enemy if player is nearby
			dist := abs(enemy.pos.x - game.player.pos.x) + abs(enemy.pos.y - game.player.pos.y)
			if dist <= 3 {
				DX :: [4]int{0, 0, -1, 1}
				DY :: [4]int{-1, 1, 0, 0}
				dx := DX
				dy := DY
				for dir in 0 ..< 4 {
					wx := enemy.pos.x + dx[dir]
					wy := enemy.pos.y + dy[dir]
					if is_walkable(game, wx, wy) && !web_tile_at(game, wx, wy) {
						web_tile_set(game, wx, wy, true)
						enemy.ability_cooldown = enemy.ability_max_cd
						add_message(
							messages,
							game,
							fmt.tprintf("The %s spins a web!", enemy_display_name(&enemy)),
							eng.Engine_Color{100, 200, 100, 255},
						)
						break
					}
				}
			}
		} else if enemy.ability_type == "pull" {
			// Pull: if player is in LOS within range but not adjacent, pull 1 tile closer
			dist := abs(enemy.pos.x - game.player.pos.x) + abs(enemy.pos.y - game.player.pos.y)
			if dist >= 2 && dist <= enemy.ability_range {
				if tile_visible_at(game, enemy.pos.x, enemy.pos.y) {
					// Pull player 1 tile toward enemy along the longer axis
					pull_dx := 0
					pull_dy := 0
					if enemy.pos.x > game.player.pos.x {
						pull_dx = 1
					} else if enemy.pos.x < game.player.pos.x {
						pull_dx = -1
					}
					if enemy.pos.y > game.player.pos.y {
						pull_dy = 1
					} else if enemy.pos.y < game.player.pos.y {
						pull_dy = -1
					}

					// Only pull along one axis (prefer the longer distance)
					if abs(enemy.pos.x - game.player.pos.x) >=
					   abs(enemy.pos.y - game.player.pos.y) {
						pull_dy = 0
					} else {
						pull_dx = 0
					}

					new_x := game.player.pos.x + pull_dx
					new_y := game.player.pos.y + pull_dy
					if is_walkable(game, new_x, new_y) && enemy_at(game, new_x, new_y) == nil {
						game.player.pos.x = new_x
						game.player.pos.y = new_y
						enemy.ability_cooldown = enemy.ability_max_cd
						add_message(
							messages,
							game,
							"The Deep Watcher pulls you closer!",
							eng.Engine_Color{180, 50, 220, 255},
						)
					}
				}
			}
		} else if enemy.ability_type == "teleport" {
			dist := abs(enemy.pos.x - game.player.pos.x) + abs(enemy.pos.y - game.player.pos.y)
			if dist >= 3 && dist <= enemy.ability_range {
				if tile_visible_at(game, enemy.pos.x, enemy.pos.y) {
					DX :: [4]int{0, 0, -1, 1}
					DY :: [4]int{-1, 1, 0, 0}
					dx := DX
					dy := DY
					for dir in 0 ..< 4 {
						tx := game.player.pos.x + dx[dir]
						ty := game.player.pos.y + dy[dir]
						if is_walkable(game, tx, ty) && enemy_at(game, tx, ty) == nil {
							enemy.pos = Vec2{tx, ty}
							enemy.ability_cooldown = enemy.ability_max_cd
							add_message(
								messages,
								game,
								fmt.tprintf(
									"The %s appears from the shadows!",
									enemy_display_name(&enemy),
								),
								eng.Engine_Color{80, 40, 120, 255},
							)
							break
						}
					}
				}
			}
		} else if enemy.ability_type == "slam" {
			dist := abs(enemy.pos.x - game.player.pos.x) + abs(enemy.pos.y - game.player.pos.y)
			if dist <= 2 {
				if dist == 1 {
					game.player.hp -= 4
					add_message(
						messages,
						game,
						"The Mine Guardian slams the ground! (-4 HP)",
						eng.Engine_Color{220, 180, 60, 255},
					)
					if game.player.hp <= 0 {
						game.death_cause = "Crushed by the Mine Guardian"
						game.state = .Game_Over
						add_message(
							messages,
							game,
							"You have been slain...",
							eng.Engine_Color{255, 0, 0, 255},
						)
					}
				}
				enemy.ability_cooldown = enemy.ability_max_cd
			}
		} else if enemy.ability_type == "darkness" {
			dist := abs(enemy.pos.x - game.player.pos.x) + abs(enemy.pos.y - game.player.pos.y)
			if dist <= enemy.ability_range {
				game.light_boost_bonus = max(game.light_boost_bonus - 2, -3)
				game.light_boost_turns = max(game.light_boost_turns, 5)
				enemy.ability_cooldown = enemy.ability_max_cd
				add_message(
					messages,
					game,
					"The Abyssal Lord shrouds you in darkness!",
					eng.Engine_Color{150, 30, 200, 255},
				)
			}
		} else if enemy.ability_type == "ranged_shoot" {
			dist := abs(enemy.pos.x - game.player.pos.x) + abs(enemy.pos.y - game.player.pos.y)
			if dist >= 2 && dist <= enemy.ability_range {
				if tile_visible_at(game, enemy.pos.x, enemy.pos.y) {
					dmg := enemy.attack
					game.player.hp -= dmg
					enemy.ability_cooldown = enemy.ability_max_cd
					add_message(
						messages,
						game,
						fmt.tprintf(
							"The %s throws a stone at you! (%d damage)",
							enemy_display_name(&enemy),
							dmg,
						),
						eng.Engine_Color{200, 160, 80, 255},
					)
					if game.player.hp <= 0 {
						game.death_cause = fmt.tprintf(
							"Pelted to death by a %s",
							enemy_display_name(&enemy),
						)
						game.state = .Game_Over
						add_message(
							messages,
							game,
							"You have been slain...",
							eng.Engine_Color{255, 0, 0, 255},
						)
					}
				}
			}
		} else if enemy.ability_type == "freeze" {
			dist := abs(enemy.pos.x - game.player.pos.x) + abs(enemy.pos.y - game.player.pos.y)
			if dist <= enemy.ability_range {
				if tile_visible_at(game, enemy.pos.x, enemy.pos.y) {
					game.frozen_turns = max(game.frozen_turns, 3)
					enemy.ability_cooldown = enemy.ability_max_cd
					add_message(
						messages,
						game,
						fmt.tprintf(
							"The %s freezes you with its gaze!",
							enemy_display_name(&enemy),
						),
						eng.Engine_Color{100, 180, 255, 255},
					)
				}
			}
		}
	}
}

// ─── Remove dead enemies ────────────────────────────────────────────────────

remove_dead_enemies :: proc(
	messages: ^Message_Manager,
	game: ^Game,
	particles: ^eng.Particle_Manager,
	cam_x, cam_y: int,
) {
	i := 0
	for i < len(game.enemies) {
		if !game.enemies[i].alive {
			if game.enemies[i].is_boss {
				game.boss_killed_this_turn = true
			}
			if game.enemies[i].ability_type == "poison_cloud" {
				t := tile_at(game, game.enemies[i].pos.x, game.enemies[i].pos.y)
				if t != nil && (t.type == .Floor || t.type == .Rubble) {
					t.type = .Gas_Vent
					add_message(
						messages,
						game,
						fmt.tprintf("The %s releases toxic gas!", game.enemies[i].name),
						eng.Engine_Color{120, 200, 40, 255},
					)
				}
			}
			spawn_death_particles(
				particles,
				game.enemies[i].pos.x,
				game.enemies[i].pos.y,
				cam_x,
				cam_y,
			)
			unordered_remove(&game.enemies, i)
		} else {
			i += 1
		}
	}
}
