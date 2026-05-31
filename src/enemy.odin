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
	return Enemy{
		pos        = pos,
		hp         = 1,
		max_hp     = 1,
		attack     = 1,
		enemy_type = id,
		name       = id,
		glyph      = '?',
		color      = rl.RED,
		alive      = true,
	}
}

// ─── Spawn enemies into rooms ────────────────────────────────────────────────

spawn_enemies :: proc(game: ^Game) {
	clear(&game.enemies)

	if len(game.rooms) < 2 {
		return
	}

	total := 0

	// Skip room 0 (player's room), spawn 1-2 enemies per room
	for i in 1 ..< len(game.rooms) {
		room := game.rooms[i]
		count := rand.int_max(2) + 1 // 1 or 2

		for _ in 0 ..< count {
			// Pick random floor position inside room
			for _ in 0 ..< 20 {
				ex := rand.int_max(room.x2 - room.x1 - 2) + room.x1 + 1
				ey := rand.int_max(room.y2 - room.y1 - 2) + room.y1 + 1
				pos := Vec2{ex, ey}

				// Don't spawn on non-walkable, player, or other enemies
				if !is_walkable(game, ex, ey) { continue }
				if pos == game.player.pos { continue }
				if enemy_at(game, ex, ey) != nil { continue }

				def := pick_enemy_def_for_depth(game.depth)
				if def != nil {
					append(&game.enemies, enemy_make_from_def(def, pos))
					total += 1
				}
				break
			}
		}
	}

	fmt.printfln(
		"[enemy] spawned %v enemies across %v rooms (depth=%v)",
		total,
		len(game.rooms) - 1,
		game.depth,
	)
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

			if nx < 0 || nx >= MAP_WIDTH || ny < 0 || ny >= MAP_HEIGHT { continue }
			if !is_walkable(game, nx, ny) { continue }

			idx := pos_to_idx(nx, ny)
			if game.dijkstra_map[idx] <= cur_dist + 1 { continue }

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
		if !enemy.alive { continue }

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
	best_x := enemy.pos.x
	best_y := enemy.pos.y
	best_dist := game.dijkstra_map[pos_to_idx(enemy.pos.x, enemy.pos.y)]

	DX :: [4]int{0, 0, -1, 1}
	DY :: [4]int{-1, 1, 0, 0}

	dx := DX
	dy := DY
	for dir in 0 ..< 4 {
		nx := enemy.pos.x + dx[dir]
		ny := enemy.pos.y + dy[dir]

		if nx < 0 || nx >= MAP_WIDTH || ny < 0 || ny >= MAP_HEIGHT { continue }

		if nx == game.player.pos.x && ny == game.player.pos.y {
			resolve_attack_enemy_on_player(game, enemy)
			return
		}

		if !is_walkable(game, nx, ny) { continue }
		if enemy_at(game, nx, ny) != nil { continue }

		dist := game.dijkstra_map[pos_to_idx(nx, ny)]
		if dist < best_dist {
			best_dist = dist
			best_x = nx
			best_y = ny
		}
	}

	enemy.pos.x = best_x
	enemy.pos.y = best_y
}

// ─── Wander behavior (random movement) ──────────────────────────────────────

@(private = "file")
wander :: proc(game: ^Game, enemy: ^Enemy) {
	if rand.int_max(2) == 0 { return }

	DX :: [4]int{0, 0, -1, 1}
	DY :: [4]int{-1, 1, 0, 0}

	dx := DX
	dy := DY

	dir := rand.int_max(4)
	nx := enemy.pos.x + dx[dir]
	ny := enemy.pos.y + dy[dir]

	if nx < 0 || nx >= MAP_WIDTH || ny < 0 || ny >= MAP_HEIGHT { return }
	if !is_walkable(game, nx, ny) { return }
	if enemy_at(game, nx, ny) != nil { return }
	if nx == game.player.pos.x && ny == game.player.pos.y { return }

	enemy.pos.x = nx
	enemy.pos.y = ny
}

// ─── Remove dead enemies ────────────────────────────────────────────────────

remove_dead_enemies :: proc(game: ^Game) {
	i := 0
	for i < len(game.enemies) {
		if !game.enemies[i].alive {
			unordered_remove(&game.enemies, i)
		} else {
			i += 1
		}
	}
}
