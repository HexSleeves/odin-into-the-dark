package gen

import "core:math/rand"
import "core:slice"


MIN_ROOM_W :: 4
MAX_ROOM_W :: 10
MIN_ROOM_H :: 3
MAX_ROOM_H :: 8
MAX_ROOMS :: 12
ROOM_PADDING :: 1
BSP_MAX_LEAVES :: 32
BSP_MIN_LEAF_W :: 12
BSP_MIN_LEAF_H :: 9

// ─── Room helpers ─────────────────────────────────────────────────────────────

room_center :: proc(r: Room) -> Vec2 {
	return Vec2{(r.x1 + r.x2) / 2, (r.y1 + r.y2) / 2}
}

rooms_overlap :: proc(a, b: Room, padding: int) -> bool {
	if a.x1 - padding >= b.x2 + padding {return false}
	if b.x1 - padding >= a.x2 + padding {return false}
	if a.y1 - padding >= b.y2 + padding {return false}
	if b.y1 - padding >= a.y2 + padding {return false}
	return true
}

// ─── Carving helpers ──────────────────────────────────────────────────────────

carve_rect :: proc(game: ^Game, x1, y1, x2, y2: int) {
	for y in y1 ..< y2 {
		for x in x1 ..< x2 {
			if x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT {
				game.tiles[pos_to_idx(x, y)].type = .Floor
			}
		}
	}
}

carve_h_tunnel :: proc(game: ^Game, x1, x2, y: int) {
	lo := min(x1, x2)
	hi := max(x1, x2)
	for x in lo ..= hi {
		if x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT {
			game.tiles[pos_to_idx(x, y)].type = .Floor
		}
	}
}

carve_v_tunnel :: proc(game: ^Game, y1, y2, x: int) {
	lo := min(y1, y2)
	hi := max(y1, y2)
	for y in lo ..= hi {
		if x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT {
			game.tiles[pos_to_idx(x, y)].type = .Floor
		}
	}
}

carve_room_connection :: proc(game: ^Game, a, b: Vec2) {
	if rand.int_max(2) == 0 {
		carve_h_tunnel(game, a.x, b.x, a.y)
		carve_v_tunnel(game, a.y, b.y, b.x)
	} else {
		carve_v_tunnel(game, a.y, b.y, a.x)
		carve_h_tunnel(game, a.x, b.x, b.y)
	}
}

bsp_split_leaf :: proc(leaves: ^[BSP_MAX_LEAVES]Room, index: int, leaf_count: ^int) -> bool {
	leaf := leaves[index]
	w := leaf.x2 - leaf.x1
	h := leaf.y2 - leaf.y1
	if leaf_count^ >= BSP_MAX_LEAVES {return false}
	if w < BSP_MIN_LEAF_W * 2 && h < BSP_MIN_LEAF_H * 2 {return false}

	split_vertical := w > h
	if w >= BSP_MIN_LEAF_W * 2 && h >= BSP_MIN_LEAF_H * 2 {
		split_vertical = rand.int_max(2) == 0
	}

	if split_vertical {
		if w < BSP_MIN_LEAF_W * 2 {return false}
		split := mapgen_rand_range(leaf.x1 + BSP_MIN_LEAF_W, leaf.x2 - BSP_MIN_LEAF_W + 1)
		leaves[index] = Room{leaf.x1, leaf.y1, split, leaf.y2}
		leaves[leaf_count^] = Room{split, leaf.y1, leaf.x2, leaf.y2}
		leaf_count^ += 1
		return true
	}

	if h < BSP_MIN_LEAF_H * 2 {return false}
	split := mapgen_rand_range(leaf.y1 + BSP_MIN_LEAF_H, leaf.y2 - BSP_MIN_LEAF_H + 1)
	leaves[index] = Room{leaf.x1, leaf.y1, leaf.x2, split}
	leaves[leaf_count^] = Room{leaf.x1, split, leaf.x2, leaf.y2}
	leaf_count^ += 1
	return true
}

bsp_room_from_leaf :: proc(leaf: Room, depth: int) -> (room: Room, ok: bool) {
	leaf_w := leaf.x2 - leaf.x1
	leaf_h := leaf.y2 - leaf.y1
	max_w := min(MAX_ROOM_W + depth / 2, leaf_w - 2)
	max_h := min(MAX_ROOM_H + depth / 3, leaf_h - 2)
	if max_w < MIN_ROOM_W || max_h < MIN_ROOM_H {return {}, false}

	w := mapgen_rand_range(MIN_ROOM_W, max_w + 1)
	h := mapgen_rand_range(MIN_ROOM_H, max_h + 1)
	x := mapgen_rand_range(leaf.x1 + 1, leaf.x2 - w)
	y := mapgen_rand_range(leaf.y1 + 1, leaf.y2 - h)
	return Room{x, y, x + w, y + h}, true
}

carve_bsp_rooms :: proc(game: ^Game, bounds: Generation_Bounds) {
	leaves: [BSP_MAX_LEAVES]Room
	leaves[0] = Room{bounds.x1 + 1, bounds.y1 + 1, bounds.x2 - 1, bounds.y2 - 1}
	leaf_count := 1
	target := min(8 + game.depth, BSP_MAX_LEAVES)

	for attempts := 0; attempts < BSP_MAX_LEAVES * 4 && leaf_count < target; attempts += 1 {
		index := rand.int_max(leaf_count)
		_ = bsp_split_leaf(&leaves, index, &leaf_count)
	}

	for i in 0 ..< leaf_count {
		room, ok := bsp_room_from_leaf(leaves[i], game.depth)
		if !ok {continue}
		carve_rect(game, room.x1, room.y1, room.x2, room.y2)
		append(&game.rooms, room)
	}

	slice.sort_by(game.rooms[:], proc(a, b: Room) -> bool {
		return room_center(a).x < room_center(b).x
	})

	for i in 1 ..< len(game.rooms) {
		carve_room_connection(game, room_center(game.rooms[i - 1]), room_center(game.rooms[i]))
	}

	cycle_count := min(max(game.depth / 3, 1), 4)
	for _ in 0 ..< cycle_count {
		if len(game.rooms) < 4 {break}
		a := rand.int_max(len(game.rooms))
		b := rand.int_max(len(game.rooms))
		if a == b {continue}
		carve_room_connection(game, room_center(game.rooms[a]), room_center(game.rooms[b]))
	}
}

carve_maze_spurs :: proc(game: ^Game, bounds: Generation_Bounds, spur_count, max_cells: int) {
	DX :: CARDINAL_DX
	DY :: CARDINAL_DY
	dx := DX
	dy := DY

	for _ in 0 ..< spur_count {
		start := game.player.pos
		if len(game.rooms) > 0 {
			start = room_center(game.rooms[rand.int_max(len(game.rooms))])
		}
		stack: [MAP_WIDTH * MAP_HEIGHT]Vec2
		head := 0
		stack[head] = start
		head += 1
		carved := 0

		for head > 0 && carved < max_cells {
			cur := stack[head - 1]
			dir_start := rand.int_max(4)
			moved := false
			for step in 0 ..< 4 {
				dir := (dir_start + step) % 4
				nx := cur.x + dx[dir] * 2
				ny := cur.y + dy[dir] * 2
				mx := cur.x + dx[dir]
				my := cur.y + dy[dir]
				if !mapgen_bounds_interior_contains(bounds, nx, ny) {continue}
				if game.tiles[pos_to_idx(nx, ny)].type != .Wall {continue}
				game.tiles[pos_to_idx(mx, my)].type = .Floor
				game.tiles[pos_to_idx(nx, ny)].type = .Floor
				stack[head] = Vec2{nx, ny}
				head += 1
				carved += 1
				moved = true
				break
			}
			if !moved {head -= 1}
		}
	}
}

// ─── Map generator (depth dispatch) ───────────────────────────────────────────

generate_rooms :: proc(game: ^Game) {
	bounds := mapgen_bounds_for_depth(game.depth)
	mapgen_clear_to_walls(game)
	clear(&game.rooms)
	carve_bsp_rooms(game, bounds)

	if game.depth >= 3 {
		carve_maze_spurs(game, bounds, 1 + game.depth / 2, 14 + game.depth * 2)
	}

	if len(game.rooms) > 0 {
		game.player.pos = room_center(game.rooms[0])
	}

	descent_pos := find_farthest_floor(game, game.player.pos.x, game.player.pos.y)
	game.tiles[pos_to_idx(descent_pos.x, descent_pos.y)].type = .Descent

	for &room in game.rooms {
		rubble_count := rand.int_max(2) + 1
		for _ in 0 ..< rubble_count {
			for _ in 0 ..< 10 {
				rx, ry := rand_room_any(room)
				idx := pos_to_idx(rx, ry)
				if game.tiles[idx].type == .Floor &&
				   !(rx == game.player.pos.x && ry == game.player.pos.y) &&
				   !(rx == descent_pos.x && ry == descent_pos.y) {
					game.tiles[idx].type = .Rubble
					break
				}
			}
		}
	}

	logger_debugf(
		.Gen,
		"bsp_rooms: seed=%v bounds=%vx%v rooms=%v player=(%v,%v) descent=(%v,%v)",
		game.seed,
		mapgen_bounds_width(bounds),
		mapgen_bounds_height(bounds),
		len(game.rooms),
		game.player.pos.x,
		game.player.pos.y,
		descent_pos.x,
		descent_pos.y,
	)
}

// ─── Hazard tile spawning (depth-gated) ───────────────────────────────────────
