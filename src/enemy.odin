package main

import "core:fmt"
import "core:math/rand"

import rl "vendor:raylib"

// ─── Enemy definitions by type ───────────────────────────────────────────────

enemy_make :: proc(etype: Enemy_Type, pos: Vec2) -> Enemy {
	switch etype {
	case .Rat:
		return Enemy{
			pos        = pos,
			hp         = 3,
			max_hp     = 3,
			attack     = 1,
			enemy_type = .Rat,
			glyph      = 'r',
			color      = rl.Color{150, 120, 80, 255},
			alive      = true,
		}
	case .Miner_Husk:
		return Enemy{
			pos        = pos,
			hp         = 6,
			max_hp     = 6,
			attack     = 3,
			enemy_type = .Miner_Husk,
			glyph      = 'H',
			color      = rl.Color{180, 180, 160, 255},
			alive      = true,
		}
	case .Cave_Crawler:
		return Enemy{
			pos        = pos,
			hp         = 10,
			max_hp     = 10,
			attack     = 4,
			enemy_type = .Cave_Crawler,
			glyph      = 'C',
			color      = rl.Color{100, 200, 100, 255},
			alive      = true,
		}
	case .Deep_Watcher:
		return Enemy{
			pos        = pos,
			hp         = 15,
			max_hp     = 15,
			attack     = 6,
			enemy_type = .Deep_Watcher,
			glyph      = 'W',
			color      = rl.Color{180, 50, 220, 255},
			alive      = true,
		}
	}
	// Unreachable but satisfies compiler
	return Enemy{}
}

// ─── Enemy type selection by depth ───────────────────────────────────────────

@(private = "file")
pick_enemy_type :: proc(depth: int) -> Enemy_Type {
	roll := rand.int_max(100)
	switch {
	case depth <= 1:
		// Floor 1: mostly rats
		if roll < 80 { return .Rat }
		return .Miner_Husk
	case depth == 2:
		if roll < 40 { return .Rat }
		if roll < 80 { return .Miner_Husk }
		return .Cave_Crawler
	case depth == 3:
		if roll < 20 { return .Rat }
		if roll < 50 { return .Miner_Husk }
		if roll < 85 { return .Cave_Crawler }
		return .Deep_Watcher
	case:
		// Deep floors: harder enemies
		if roll < 10 { return .Miner_Husk }
		if roll < 50 { return .Cave_Crawler }
		return .Deep_Watcher
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
			for attempt in 0 ..< 20 {
				ex := rand.int_max(room.x2 - room.x1 - 2) + room.x1 + 1
				ey := rand.int_max(room.y2 - room.y1 - 2) + room.y1 + 1
				pos := Vec2{ex, ey}

				// Don't spawn on non-walkable, player, or other enemies
				if !is_walkable(game, ex, ey) { continue }
				if pos == game.player.pos { continue }
				if enemy_at(game, ex, ey) != nil { continue }

				etype := pick_enemy_type(game.depth)
				append(&game.enemies, enemy_make(etype, pos))
				total += 1
				break
			}
		}
	}

	fmt.printfln("[enemy] spawned %v enemies across %v rooms (depth=%v)", total, len(game.rooms) - 1, game.depth)
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
	Queue_Entry :: struct { x, y: int }
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
			// Chase: move toward player using dijkstra map (downhill)
			chase_player(game, &enemy)
		} else {
			// Wander: move randomly
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

		// Check if player is at target — allow bump (combat will handle it)
		if nx == game.player.pos.x && ny == game.player.pos.y {
			// Attack the player
			resolve_attack_enemy_on_player(game, enemy)
			return
		}

		if !is_walkable(game, nx, ny) { continue }
		if enemy_at(game, nx, ny) != nil { continue } // don't stack on other enemies

		dist := game.dijkstra_map[pos_to_idx(nx, ny)]
		if dist < best_dist {
			best_dist = dist
			best_x = nx
			best_y = ny
		}
	}

	// Move to best neighbor
	enemy.pos.x = best_x
	enemy.pos.y = best_y
}

// ─── Wander behavior (random movement) ──────────────────────────────────────

@(private = "file")
wander :: proc(game: ^Game, enemy: ^Enemy) {
	// 50% chance to stay still (enemies don't wander aggressively)
	if rand.int_max(2) == 0 { return }

	DX :: [4]int{0, 0, -1, 1}
	DY :: [4]int{-1, 1, 0, 0}

	dx := DX
	dy := DY

	// Try a random direction
	dir := rand.int_max(4)
	nx := enemy.pos.x + dx[dir]
	ny := enemy.pos.y + dy[dir]

	if nx < 0 || nx >= MAP_WIDTH || ny < 0 || ny >= MAP_HEIGHT { return }
	if !is_walkable(game, nx, ny) { return }
	if enemy_at(game, nx, ny) != nil { return }
	if nx == game.player.pos.x && ny == game.player.pos.y { return } // don't bump player while wandering

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
