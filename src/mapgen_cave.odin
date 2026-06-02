package main

import "core:math/rand"

// ─── Cellular automata helpers ────────────────────────────────────────────────

@(private = "file")
count_wall_neighbors :: proc(game: ^Game, cx, cy: int) -> int {
	count := 0
	for dy in -1 ..= 1 {
		for dx in -1 ..= 1 {
			if dx == 0 && dy == 0 {continue}
			nx := cx + dx
			ny := cy + dy
			if nx < 0 || nx >= MAP_WIDTH || ny < 0 || ny >= MAP_HEIGHT {
				count += 1 // out-of-bounds counts as wall
				continue
			}
			if game.tiles[pos_to_idx(nx, ny)].type == .Wall {
				count += 1
			}
		}
	}
	return count
}

@(private = "file")
smooth_pass :: proc(game: ^Game) {
	temp: [MAP_WIDTH * MAP_HEIGHT]Tile_Type
	for y in 1 ..< MAP_HEIGHT - 1 {
		for x in 1 ..< MAP_WIDTH - 1 {
			walls := count_wall_neighbors(game, x, y)
			if walls >= 5 {
				temp[pos_to_idx(x, y)] = .Wall
			} else {
				temp[pos_to_idx(x, y)] = .Floor
			}
		}
	}
	// Copy back interior
	for y in 1 ..< MAP_HEIGHT - 1 {
		for x in 1 ..< MAP_WIDTH - 1 {
			game.tiles[pos_to_idx(x, y)].type = temp[pos_to_idx(x, y)]
		}
	}
}

// ─── Flood fill: count reachable floor tiles from (sx,sy) ────────────────────

flood_fill_count :: proc(game: ^Game, sx, sy: int, visited: ^[MAP_WIDTH * MAP_HEIGHT]bool) -> int {
	if sx < 0 || sx >= MAP_WIDTH || sy < 0 || sy >= MAP_HEIGHT {return 0}

	start_idx := pos_to_idx(sx, sy)
	if visited[start_idx] {return 0}
	if game.tiles[start_idx].type == .Wall {return 0}

	// BFS
	Queue_Entry :: struct {
		x, y: int,
	}
	queue: [MAP_WIDTH * MAP_HEIGHT]Queue_Entry
	head := 0
	tail := 0

	visited[start_idx] = true
	queue[tail] = {sx, sy}
	tail += 1
	count := 0

	DX :: [4]int{0, 0, -1, 1}
	DY :: [4]int{-1, 1, 0, 0}

	for head != tail {
		cur := queue[head]
		head += 1
		count += 1

		dx := DX
		dy := DY
		for dir in 0 ..< 4 {
			nx := cur.x + dx[dir]
			ny := cur.y + dy[dir]
			if nx < 0 || nx >= MAP_WIDTH || ny < 0 || ny >= MAP_HEIGHT {continue}
			idx := pos_to_idx(nx, ny)
			if visited[idx] {continue}
			if game.tiles[idx].type == .Wall {continue}
			visited[idx] = true
			queue[tail] = {nx, ny}
			tail += 1
		}
	}

	return count
}

// ─── Flood fill mark helper ──────────────────────────────────────────────────

@(private = "file")
flood_fill_mark :: proc(game: ^Game, sx, sy: int, marked: ^[MAP_WIDTH * MAP_HEIGHT]bool) {
	if sx < 0 || sx >= MAP_WIDTH || sy < 0 || sy >= MAP_HEIGHT {return}

	start_idx := pos_to_idx(sx, sy)
	if game.tiles[start_idx].type == .Wall {return}

	Queue_Entry :: struct {
		x, y: int,
	}
	queue: [MAP_WIDTH * MAP_HEIGHT]Queue_Entry
	head := 0
	tail := 0

	marked[start_idx] = true
	queue[tail] = {sx, sy}
	tail += 1

	DX :: [4]int{0, 0, -1, 1}
	DY :: [4]int{-1, 1, 0, 0}

	for head != tail {
		cur := queue[head]
		head += 1

		dx := DX
		dy := DY
		for dir in 0 ..< 4 {
			nx := cur.x + dx[dir]
			ny := cur.y + dy[dir]
			if nx < 0 || nx >= MAP_WIDTH || ny < 0 || ny >= MAP_HEIGHT {continue}
			idx := pos_to_idx(nx, ny)
			if marked[idx] {continue}
			if game.tiles[idx].type == .Wall {continue}
			marked[idx] = true
			queue[tail] = {nx, ny}
			tail += 1
		}
	}
}

// ─── Find the farthest floor tile from (sx,sy) using BFS ─────────────────────

find_farthest_floor :: proc(game: ^Game, sx, sy: int) -> Vec2 {
	visited: [MAP_WIDTH * MAP_HEIGHT]bool
	Queue_Entry :: struct {
		x, y: int,
	}
	queue: [MAP_WIDTH * MAP_HEIGHT]Queue_Entry
	head := 0
	tail := 0

	start_idx := pos_to_idx(sx, sy)
	visited[start_idx] = true
	queue[tail] = {sx, sy}
	tail += 1

	farthest := Vec2{sx, sy}

	DX :: [4]int{0, 0, -1, 1}
	DY :: [4]int{-1, 1, 0, 0}

	for head != tail {
		cur := queue[head]
		head += 1
		farthest = Vec2{cur.x, cur.y}

		dx := DX
		dy := DY
		for dir in 0 ..< 4 {
			nx := cur.x + dx[dir]
			ny := cur.y + dy[dir]
			if nx < 0 || nx >= MAP_WIDTH || ny < 0 || ny >= MAP_HEIGHT {continue}
			idx := pos_to_idx(nx, ny)
			if visited[idx] {continue}
			if game.tiles[idx].type == .Wall {continue}
			visited[idx] = true
			queue[tail] = {nx, ny}
			tail += 1
		}
	}

	return farthest
}

// ─── Find nearest floor tile to a position (BFS) ─────────────────────────────

@(private = "file")
find_nearest_floor :: proc(game: ^Game, sx, sy: int) -> Vec2 {
	// If already on floor, return it
	if sx >= 0 && sx < MAP_WIDTH && sy >= 0 && sy < MAP_HEIGHT {
		if game.tiles[pos_to_idx(sx, sy)].type == .Floor {
			return Vec2{sx, sy}
		}
	}

	visited: [MAP_WIDTH * MAP_HEIGHT]bool
	Queue_Entry :: struct {
		x, y: int,
	}
	queue: [MAP_WIDTH * MAP_HEIGHT]Queue_Entry
	head := 0
	tail := 0

	csx := clamp(sx, 0, MAP_WIDTH - 1)
	csy := clamp(sy, 0, MAP_HEIGHT - 1)

	start_idx := pos_to_idx(csx, csy)
	visited[start_idx] = true
	queue[tail] = {csx, csy}
	tail += 1

	DX :: [4]int{0, 0, -1, 1}
	DY :: [4]int{-1, 1, 0, 0}

	for head != tail {
		cur := queue[head]
		head += 1

		if game.tiles[pos_to_idx(cur.x, cur.y)].type == .Floor {
			return Vec2{cur.x, cur.y}
		}

		dx := DX
		dy := DY
		for dir in 0 ..< 4 {
			nx := cur.x + dx[dir]
			ny := cur.y + dy[dir]
			if nx < 0 || nx >= MAP_WIDTH || ny < 0 || ny >= MAP_HEIGHT {continue}
			idx := pos_to_idx(nx, ny)
			if visited[idx] {continue}
			visited[idx] = true
			queue[tail] = {nx, ny}
			tail += 1
		}
	}

	// Fallback — shouldn't happen
	return Vec2{sx, sy}
}

// ─── Cave generator (cellular automata) ───────────────────────────────────────

generate_cave :: proc(game: ^Game) {
	// (a) Fill all tiles to Wall
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		game.tiles[i] = Tile{}
	}

	// (b) Randomly set ~45% of interior tiles to Floor
	for y in 1 ..< MAP_HEIGHT - 1 {
		for x in 1 ..< MAP_WIDTH - 1 {
			if rand.int_max(100) < 45 {
				game.tiles[pos_to_idx(x, y)].type = .Floor
			}
		}
	}

	// (c) Run 4 smoothing passes
	for _ in 0 ..< 4 {
		smooth_pass(game)
	}

	// (d) Border is already Wall (never touched interior to border)

	// (e) Find the largest connected floor region
	visited: [MAP_WIDTH * MAP_HEIGHT]bool
	best_start := Vec2{0, 0}
	best_count := 0

	// First pass: find all connected floor regions, track the largest
	for y in 1 ..< MAP_HEIGHT - 1 {
		for x in 1 ..< MAP_WIDTH - 1 {
			idx := pos_to_idx(x, y)
			if visited[idx] {continue}
			if game.tiles[idx].type == .Wall {continue}

			count := flood_fill_count(game, x, y, &visited)
			if count > best_count {
				best_count = count
				best_start = Vec2{x, y}
			}
		}
	}

	// Second pass: mark only the largest component, fill everything else with Wall
	// Re-flood from best_start to find which tiles belong to the largest component
	largest: [MAP_WIDTH * MAP_HEIGHT]bool
	flood_fill_mark(game, best_start.x, best_start.y, &largest)

	for y in 1 ..< MAP_HEIGHT - 1 {
		for x in 1 ..< MAP_WIDTH - 1 {
			idx := pos_to_idx(x, y)
			if game.tiles[idx].type != .Wall && !largest[idx] {
				game.tiles[idx].type = .Wall
			}
		}
	}

	// (f) Place player at a random floor tile in the largest region
	player_placed := false
	for _ in 0 ..< 1000 {
		px := rand.int_max(MAP_WIDTH - 2) + 1
		py := rand.int_max(MAP_HEIGHT - 2) + 1
		if game.tiles[pos_to_idx(px, py)].type == .Floor {
			game.player.pos = Vec2{px, py}
			player_placed = true
			break
		}
	}
	if !player_placed {
		// Fallback: use best_start
		game.player.pos = best_start
	}

	// (g) Place descent at the floor tile farthest from player using BFS
	descent_pos := find_farthest_floor(game, game.player.pos.x, game.player.pos.y)
	game.tiles[pos_to_idx(descent_pos.x, descent_pos.y)].type = .Descent

	// (h) Scatter 2-4 rubble tiles on random floor tiles
	rubble_count := rand.int_max(3) + 2 // 2..4
	for _ in 0 ..< rubble_count {
		for _ in 0 ..< 50 {
			rx := rand.int_max(MAP_WIDTH - 2) + 1
			ry := rand.int_max(MAP_HEIGHT - 2) + 1
			idx := pos_to_idx(rx, ry)
			if game.tiles[idx].type == .Floor &&
			   !(rx == game.player.pos.x && ry == game.player.pos.y) &&
			   !(rx == descent_pos.x && ry == descent_pos.y) {
				game.tiles[idx].type = .Rubble
				break
			}
		}
	}

	// (i) Clear rooms since caves don't have rooms
	clear(&game.rooms)

	// (j) Count floor tiles for diagnostics
	floor_count := 0
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		if game.tiles[i].type != .Wall {
			floor_count += 1
		}
	}

	logger_debugf(
		.Gen,
		"cave: seed=%v floor_tiles=%v player=(%v,%v) descent=(%v,%v)",
		game.seed,
		floor_count,
		game.player.pos.x,
		game.player.pos.y,
		descent_pos.x,
		descent_pos.y,
	)
}

// ─── Mixed generator (rooms + organic erosion) ────────────────────────────────

generate_mixed :: proc(game: ^Game) {
	// (a) Start with room-and-corridor generation
	generate_rooms(game)

	// (b) Run 2 cellular automata smoothing passes to erode edges
	for _ in 0 ..< 2 {
		smooth_pass(game)
	}

	// (c) Flood-fill to ensure connectivity — fill disconnected regions
	visited: [MAP_WIDTH * MAP_HEIGHT]bool
	best_start := Vec2{0, 0}
	best_count := 0

	for y in 1 ..< MAP_HEIGHT - 1 {
		for x in 1 ..< MAP_WIDTH - 1 {
			idx := pos_to_idx(x, y)
			if visited[idx] {continue}
			if game.tiles[idx].type == .Wall {continue}

			count := flood_fill_count(game, x, y, &visited)
			if count > best_count {
				best_count = count
				best_start = Vec2{x, y}
			}
		}
	}

	// Keep only the largest component
	largest: [MAP_WIDTH * MAP_HEIGHT]bool
	flood_fill_mark(game, best_start.x, best_start.y, &largest)

	for y in 1 ..< MAP_HEIGHT - 1 {
		for x in 1 ..< MAP_WIDTH - 1 {
			idx := pos_to_idx(x, y)
			if game.tiles[idx].type != .Wall && !largest[idx] {
				game.tiles[idx].type = .Wall
			}
		}
	}

	// (d) Make sure player is on a floor tile (erosion may have moved the center)
	if !is_walkable(game, game.player.pos.x, game.player.pos.y) {
		// Find nearest floor tile to original player position
		game.player.pos = find_nearest_floor(game, game.player.pos.x, game.player.pos.y)
	}

	// (e) Re-place descent — center of last room may have eroded, find nearest floor
	if len(game.rooms) > 0 {
		last_center := room_center(game.rooms[len(game.rooms) - 1])
		descent_pos := find_nearest_floor(game, last_center.x, last_center.y)
		// Clear any old descent tile
		for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
			if game.tiles[i].type == .Descent {
				game.tiles[i].type = .Floor
			}
		}
		game.tiles[pos_to_idx(descent_pos.x, descent_pos.y)].type = .Descent

		logger_debugf(
			.Gen,
			"mixed: seed=%v rooms=%v player=(%v,%v) descent=(%v,%v)",
			game.seed,
			len(game.rooms),
			game.player.pos.x,
			game.player.pos.y,
			descent_pos.x,
			descent_pos.y,
		)
	}
}
