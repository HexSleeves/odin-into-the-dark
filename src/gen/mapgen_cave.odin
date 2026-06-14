package gen

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
	smooth_pass_in_bounds(game, Generation_Bounds{0, 0, MAP_WIDTH, MAP_HEIGHT})
}

@(private = "file")
smooth_pass_in_bounds :: proc(game: ^Game, bounds: Generation_Bounds) {
	temp: [MAP_WIDTH * MAP_HEIGHT]Tile_Type
	for y in bounds.y1 + 1 ..< bounds.y2 - 1 {
		for x in bounds.x1 + 1 ..< bounds.x2 - 1 {
			walls := count_wall_neighbors(game, x, y)
			if walls >= 5 {
				temp[pos_to_idx(x, y)] = .Wall
			} else {
				temp[pos_to_idx(x, y)] = .Floor
			}
		}
	}
	for y in bounds.y1 + 1 ..< bounds.y2 - 1 {
		for x in bounds.x1 + 1 ..< bounds.x2 - 1 {
			game.tiles[pos_to_idx(x, y)].type = temp[pos_to_idx(x, y)]
		}
	}
}

@(private = "file")
hash_noise :: proc(x, y: int, seed: u64) -> int {
	h := seed
	h ~= u64(x + 4096) * 0x9E3779B185EBCA87
	h ~= u64(y + 4096) * 0xC2B2AE3D27D4EB4F
	h ~= h >> 33
	h *= 0xFF51AFD7ED558CCD
	h ~= h >> 33
	return int(h % 100)
}

@(private = "file")
fractal_noise :: proc(x, y: int, seed: u64) -> int {
	v := hash_noise(x / 16, y / 16, seed) * 4
	v += hash_noise(x / 8, y / 8, seed + 17) * 2
	v += hash_noise(x / 4, y / 4, seed + 31)
	return v / 7
}

@(private = "file")
fractal_seed_cave :: proc(game: ^Game, bounds: Generation_Bounds, floor_threshold: int) {
	seed := u64(rand.int_max(1_000_000_000))
	for y in bounds.y1 + 1 ..< bounds.y2 - 1 {
		for x in bounds.x1 + 1 ..< bounds.x2 - 1 {
			noise := fractal_noise(x, y, seed)
			if noise < floor_threshold {
				game.tiles[pos_to_idx(x, y)].type = .Floor
			} else {
				game.tiles[pos_to_idx(x, y)].type = .Wall
			}
		}
	}
}

@(private = "file")
drunkard_walk_cave :: proc(
	game: ^Game,
	bounds: Generation_Bounds,
	walkers, steps_per_walker: int,
) {
	DX :: CARDINAL_DX
	DY :: CARDINAL_DY
	dx := DX
	dy := DY
	center := Vec2{(bounds.x1 + bounds.x2) / 2, (bounds.y1 + bounds.y2) / 2}
	game.tiles[pos_to_idx(center.x, center.y)].type = .Floor

	for _ in 0 ..< walkers {
		pos := center
		if rand.int_max(3) != 0 {
			pos = mapgen_rand_interior(bounds)
		}
		last_dir := rand.int_max(4)
		for _ in 0 ..< steps_per_walker {
			game.tiles[pos_to_idx(pos.x, pos.y)].type = .Floor
			dir := last_dir
			if rand.int_max(100) >= 68 {
				dir = rand.int_max(4)
			}
			nx := pos.x + dx[dir]
			ny := pos.y + dy[dir]
			if !mapgen_bounds_interior_contains(bounds, nx, ny) {
				dir = rand.int_max(4)
				nx = pos.x + dx[dir]
				ny = pos.y + dy[dir]
			}
			if mapgen_bounds_interior_contains(bounds, nx, ny) {
				pos = Vec2{nx, ny}
				last_dir = dir
			}
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

	DX :: CARDINAL_DX
	DY :: CARDINAL_DY

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

	DX :: CARDINAL_DX
	DY :: CARDINAL_DY

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

	DX :: CARDINAL_DX
	DY :: CARDINAL_DY

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

	DX :: CARDINAL_DX
	DY :: CARDINAL_DY

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
	bounds := mapgen_bounds_for_depth(game.depth)
	method := mapgen_method_for_depth(game.depth)
	mapgen_clear_to_walls(game)
	clear(&game.rooms)

	if method == .Hybrid_Deep {
		carve_bsp_rooms(game, bounds)
		carve_maze_spurs(game, bounds, 2 + game.depth / 3, 18 + game.depth * 2)
		drunkard_walk_cave(
			game,
			bounds,
			4 + game.depth / 2,
			mapgen_bounds_width(bounds) * mapgen_bounds_height(bounds) / 16,
		)
	} else if method == .Drunkard_Caves {
		drunkard_walk_cave(
			game,
			bounds,
			4 + game.depth,
			mapgen_bounds_width(bounds) * mapgen_bounds_height(bounds) / 18,
		)
	} else {
		fractal_seed_cave(game, bounds, 45 + min(game.depth, 10))
	}

	for _ in 0 ..< 4 {
		smooth_pass_in_bounds(game, bounds)
	}

	// (d) Border is already Wall (never touched interior to border)

	// (e) Find the largest connected floor region
	visited: [MAP_WIDTH * MAP_HEIGHT]bool
	best_start := Vec2{0, 0}
	best_count := 0

	// First pass: find all connected floor regions, track the largest
	for y in bounds.y1 + 1 ..< bounds.y2 - 1 {
		for x in bounds.x1 + 1 ..< bounds.x2 - 1 {
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

	for y in bounds.y1 + 1 ..< bounds.y2 - 1 {
		for x in bounds.x1 + 1 ..< bounds.x2 - 1 {
			idx := pos_to_idx(x, y)
			if game.tiles[idx].type != .Wall && !largest[idx] {
				game.tiles[idx].type = .Wall
			}
		}
	}

	// (f) Place player at a random floor tile in the largest region
	player_placed := false
	for _ in 0 ..< 1000 {
		pos := mapgen_rand_interior(bounds)
		px := pos.x
		py := pos.y
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
			pos := mapgen_rand_interior(bounds)
			rx := pos.x
			ry := pos.y
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
	if method != .Hybrid_Deep {clear(&game.rooms)}

	// (j) Count floor tiles for diagnostics
	floor_count := 0
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		if game.tiles[i].type != .Wall {
			floor_count += 1
		}
	}

	logger_debugf(
		.Gen,
		"cave: seed=%v method=%v bounds=%vx%v floor_tiles=%v player=(%v,%v) descent=(%v,%v)",
		game.seed,
		method,
		mapgen_bounds_width(bounds),
		mapgen_bounds_height(bounds),
		floor_count,
		game.player.pos.x,
		game.player.pos.y,
		descent_pos.x,
		descent_pos.y,
	)
}

// ─── Mixed generator (rooms + organic erosion) ────────────────────────────────

generate_mixed :: proc(game: ^Game) {
	bounds := mapgen_bounds_for_depth(game.depth)
	// (a) Start with BSP room-and-corridor generation plus maze/drunkard erosion
	generate_rooms(game)
	drunkard_walk_cave(
		game,
		bounds,
		2 + game.depth / 2,
		mapgen_bounds_width(bounds) * mapgen_bounds_height(bounds) / 30,
	)

	// (b) Run 2 cellular automata smoothing passes to erode edges
	for _ in 0 ..< 2 {
		smooth_pass_in_bounds(game, bounds)
	}

	// (c) Flood-fill to ensure connectivity — fill disconnected regions
	visited: [MAP_WIDTH * MAP_HEIGHT]bool
	best_start := Vec2{0, 0}
	best_count := 0

	for y in bounds.y1 + 1 ..< bounds.y2 - 1 {
		for x in bounds.x1 + 1 ..< bounds.x2 - 1 {
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

	for y in bounds.y1 + 1 ..< bounds.y2 - 1 {
		for x in bounds.x1 + 1 ..< bounds.x2 - 1 {
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

	// (e) Re-place descent at farthest reachable floor from player
	// Clear any old descent tile first
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		if game.tiles[i].type == .Descent {
			game.tiles[i].type = .Floor
		}
	}
	descent_pos := find_farthest_floor(game, game.player.pos.x, game.player.pos.y)
	game.tiles[pos_to_idx(descent_pos.x, descent_pos.y)].type = .Descent

	logger_debugf(
		.Gen,
		"mixed: seed=%v bounds=%vx%v rooms=%v player=(%v,%v) descent=(%v,%v)",
		game.seed,
		mapgen_bounds_width(bounds),
		mapgen_bounds_height(bounds),
		len(game.rooms),
		game.player.pos.x,
		game.player.pos.y,
		descent_pos.x,
		descent_pos.y,
	)

	// (f) Room bounds are no longer accurate after erosion — clear so
	//     spawn_enemies uses scatter placement instead of room-based.
	clear(&game.rooms)
}
