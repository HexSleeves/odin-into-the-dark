package main

import "core:fmt"
import "core:math/rand"

import rl "vendor:raylib"

// ─── Enemy factory (data-driven) ─────────────────────────────────────────────

enemy_make :: proc(id: string, pos: Vec2) -> Enemy {
	def := find_enemy_def(id)
	if def != nil {
		return enemy_make_from_def(def, pos)
	}
	// Fallback: unknown enemy
	fmt.eprintfln("[enemy] WARNING: unknown enemy id '%s'", id)
	return Enemy {
		pos = pos,
		hp = 1,
		max_hp = 1,
		attack = 1,
		enemy_type = id,
		name = id,
		glyph = '?',
		color = rl.RED,
		alive = true,
	}
}

// ─── Spawn enemies into rooms ────────────────────────────────────────────────

spawn_enemies :: proc(game: ^Game) {
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

					def := pick_enemy_def_for_depth(game.depth)
					if def != nil {
						append(&game.enemies, enemy_make_from_def(def, pos))
						total += 1
					}
					break
				}
			}
		}
		if DEBUG_LOGS {
			fmt.printfln(
				"[enemy] spawned %v enemies across %v rooms (depth=%v)",
				total,
				len(game.rooms) - 1,
				game.depth,
			)
		}
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

			def := pick_enemy_def_for_depth(game.depth)
			if def != nil {
				append(&game.enemies, enemy_make_from_def(def, pos))
				spawned += 1
			}
		}
		if DEBUG_LOGS {
			fmt.printfln("[enemy] spawned %v enemies (cave, depth=%v)", spawned, game.depth)
		}
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
	// Fill with unreachable
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		game.dijkstra_map[i] = DMAP_UNREACHABLE
	}

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
	game.dijkstra_map[pos_to_idx(px, py)] = 0
	queue[tail] = {px, py}
	tail += 1

	// 4-directional offsets
	DX :: [4]int{0, 0, -1, 1}
	DY :: [4]int{-1, 1, 0, 0}

	for head != tail {
		cur := queue[head]
		head += 1
		cur_dist := game.dijkstra_map[pos_to_idx(cur.x, cur.y)]

		dx := DX
		dy := DY
		for dir in 0 ..< 4 {
			nx := cur.x + dx[dir]
			ny := cur.y + dy[dir]

			if nx < 0 || nx >= MAP_WIDTH || ny < 0 || ny >= MAP_HEIGHT {continue}
			if !is_walkable(game, nx, ny) {continue}

			idx := pos_to_idx(nx, ny)
			if game.dijkstra_map[idx] <= cur_dist + 1 {continue}

			game.dijkstra_map[idx] = cur_dist + 1
			queue[tail] = {nx, ny}
			tail += 1
		}
	}
}

// ─── Process enemy turns ─────────────────────────────────────────────────────

process_enemy_turns :: proc(game: ^Game) {
	// Recompute dijkstra map so enemies have fresh pathfinding
	compute_dijkstra_map(game)

	for &enemy in game.enemies {
		if !enemy.alive {continue}

		// Check if this enemy's tile is currently visible to the player
		tile := tile_at(game, enemy.pos.x, enemy.pos.y)
		is_visible := tile != nil && tile.visible

		if is_visible {
			chase_player(game, &enemy)
		} else {
			wander(game, &enemy)
		}
	}
}

// ─── Chase behavior (dijkstra downhill) ──────────────────────────────────────

@(private = "file")
chase_player :: proc(game: ^Game, enemy: ^Enemy) {
	// 1. Check if adjacent to player -> attack
	DX :: [4]int{0, 0, -1, 1}
	DY :: [4]int{-1, 1, 0, 0}
	dx := DX
	dy := DY
	for dir in 0 ..< 4 {
		nx := enemy.pos.x + dx[dir]
		ny := enemy.pos.y + dy[dir]
		if nx == game.player.pos.x && ny == game.player.pos.y {
			resolve_attack_enemy_on_player(game, enemy)
			return
		}
	}

	// 2. Follow the precomputed Dijkstra map downhill toward the player.
	current_dist := game.dijkstra_map[pos_to_idx(enemy.pos.x, enemy.pos.y)]
	if current_dist >= DMAP_UNREACHABLE {
		wander(game, enemy)
		return
	}

	best_pos := enemy.pos
	best_dist := current_dist
	for dir in 0 ..< 4 {
		nx := enemy.pos.x + dx[dir]
		ny := enemy.pos.y + dy[dir]
		if nx < 0 || nx >= MAP_WIDTH || ny < 0 || ny >= MAP_HEIGHT {continue}
		if !is_walkable(game, nx, ny) {continue}
		if enemy_at(game, nx, ny) != nil {continue}

		n_dist := game.dijkstra_map[pos_to_idx(nx, ny)]
		if n_dist < best_dist {
			best_dist = n_dist
			best_pos = Vec2{nx, ny}
		}
	}

	if best_pos != enemy.pos {
		enemy.pos = best_pos
		return
	}

	wander(game, enemy)
}

// ─── Wander behavior (random movement) ──────────────────────────────────────

@(private = "file")
wander :: proc(game: ^Game, enemy: ^Enemy) {
	if rand.int_max(2) == 0 {return}

	DX :: [4]int{0, 0, -1, 1}
	DY :: [4]int{-1, 1, 0, 0}

	dx := DX
	dy := DY

	dir := rand.int_max(4)
	nx := enemy.pos.x + dx[dir]
	ny := enemy.pos.y + dy[dir]

	if nx < 0 || nx >= MAP_WIDTH || ny < 0 || ny >= MAP_HEIGHT {return}
	if !is_walkable(game, nx, ny) {return}
	if enemy_at(game, nx, ny) != nil {return}
	if nx == game.player.pos.x && ny == game.player.pos.y {return}

	enemy.pos.x = nx
	enemy.pos.y = ny
}

// ─── Process special abilities ───────────────────────────────────────────────

process_enemy_abilities :: proc(game: ^Game) {
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
					if is_walkable(game, wx, wy) && !game.web_tiles[pos_to_idx(wx, wy)] {
						game.web_tiles[pos_to_idx(wx, wy)] = true
						enemy.ability_cooldown = enemy.ability_max_cd
						add_message(
							game,
							fmt.tprintf("The %s spins a web!", enemy_display_name(&enemy)),
							rl.Color{100, 200, 100, 255},
						)
						break
					}
				}
			}
		} else if enemy.ability_type == "pull" {
			// Pull: if player is in LOS within range but not adjacent, pull 1 tile closer
			dist := abs(enemy.pos.x - game.player.pos.x) + abs(enemy.pos.y - game.player.pos.y)
			if dist >= 2 && dist <= enemy.ability_range {
				etile := tile_at(game, enemy.pos.x, enemy.pos.y)
				if etile != nil && etile.visible {
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
							game,
							"The Deep Watcher pulls you closer!",
							rl.Color{180, 50, 220, 255},
						)
					}
				}
			}
		} else if enemy.ability_type == "teleport" {
			dist := abs(enemy.pos.x - game.player.pos.x) + abs(enemy.pos.y - game.player.pos.y)
			if dist >= 3 && dist <= enemy.ability_range {
				tile := tile_at(game, enemy.pos.x, enemy.pos.y)
				if tile != nil && tile.visible {
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
								game,
								fmt.tprintf("The %s appears from the shadows!", enemy_display_name(&enemy)),
								rl.Color{80, 40, 120, 255},
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
					add_message(game, "The Mine Guardian slams the ground! (-4 HP)", rl.Color{220, 180, 60, 255})
					if game.player.hp <= 0 {
						game.death_cause = "Crushed by the Mine Guardian"
						game.state = .Game_Over
						add_message(game, "You have been slain...", rl.Color{255, 0, 0, 255})
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
				add_message(game, "The Abyssal Lord shrouds you in darkness!", rl.Color{150, 30, 200, 255})
			}
		}
	}
}

// ─── Remove dead enemies ────────────────────────────────────────────────────

remove_dead_enemies :: proc(game: ^Game) {
	i := 0
	for i < len(game.enemies) {
		if !game.enemies[i].alive {
			if game.enemies[i].ability_type == "poison_cloud" {
				t := tile_at(game, game.enemies[i].pos.x, game.enemies[i].pos.y)
				if t != nil && (t.type == .Floor || t.type == .Rubble) {
					t.type = .Gas_Vent
					add_message(game, fmt.tprintf("The %s releases toxic gas!", game.enemies[i].name), rl.Color{120, 200, 40, 255})
				}
			}
			unordered_remove(&game.enemies, i)
		} else {
			i += 1
		}
	}
}
