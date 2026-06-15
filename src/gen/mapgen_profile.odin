package gen

import "core:math/rand"

Generation_Bounds :: struct {
	x1, y1, x2, y2: int,
}

Mapgen_Method :: enum {
	BSP_Rooms,
	BSP_Maze,
	Fractal_Caves,
	Drunkard_Caves,
	Hybrid_Deep,
}

mapgen_bounds_width :: proc(bounds: Generation_Bounds) -> int {
	return bounds.x2 - bounds.x1
}

mapgen_bounds_height :: proc(bounds: Generation_Bounds) -> int {
	return bounds.y2 - bounds.y1
}

mapgen_bounds_for_depth :: proc(depth: int) -> Generation_Bounds {
	if depth <= 0 {
		return Generation_Bounds{0, 0, MAP_WIDTH, MAP_HEIGHT}
	}

	d := clamp(depth, 1, MAX_DEPTH)
	steps := max(MAX_DEPTH - 1, 1)
	min_w := 52
	min_h := 34
	w := min_w + (MAP_WIDTH - min_w) * (d - 1) / steps
	h := min_h + (MAP_HEIGHT - min_h) * (d - 1) / steps

	if d >= MAX_DEPTH {
		w = MAP_WIDTH
		h = MAP_HEIGHT
	}

	x1 := (MAP_WIDTH - w) / 2
	y1 := (MAP_HEIGHT - h) / 2
	return Generation_Bounds{x1, y1, x1 + w, y1 + h}
}

mapgen_method_for_depth :: proc(depth: int) -> Mapgen_Method {
	if depth <= 2 {
		return .BSP_Rooms
	}
	if depth <= 4 {
		return .BSP_Maze
	}
	if depth <= 7 {
		if rand.int_max(2) == 0 {return .Fractal_Caves}
		return .Drunkard_Caves
	}
	return .Hybrid_Deep
}

mapgen_bounds_contains :: proc(bounds: Generation_Bounds, x, y: int) -> bool {
	return x >= bounds.x1 && x < bounds.x2 && y >= bounds.y1 && y < bounds.y2
}

mapgen_bounds_interior_contains :: proc(bounds: Generation_Bounds, x, y: int) -> bool {
	return x > bounds.x1 && x < bounds.x2 - 1 && y > bounds.y1 && y < bounds.y2 - 1
}

mapgen_rand_range :: proc(lo, hi_exclusive: int) -> int {
	span := hi_exclusive - lo
	if span <= 1 {return lo}
	return rand.int_max(span) + lo
}

mapgen_rand_interior :: proc(bounds: Generation_Bounds) -> Vec2 {
	return Vec2 {
		mapgen_rand_range(bounds.x1 + 1, bounds.x2 - 1),
		mapgen_rand_range(bounds.y1 + 1, bounds.y2 - 1),
	}
}

mapgen_clear_to_walls :: proc(game: ^Game) {
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		game.tiles[i] = Tile{}
	}
}
