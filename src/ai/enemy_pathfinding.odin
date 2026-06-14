package ai

import eng "../engine"


compute_dijkstra_map :: proc(game: ^Game) {
	dmap := eng.engine_distance_map_make(game.dijkstra_map[:], game_grid(game), DMAP_UNREACHABLE)

	// Validate the map ONCE here; the BFS below already bounds-checks every
	// neighbour against MAP_WIDTH/MAP_HEIGHT, so the per-cell unchecked
	// accessors are safe and skip the per-call validity recompute.
	if !eng.engine_distance_map_is_valid(&dmap) {
		game.dijkstra_dirty = false
		return
	}
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
	eng.engine_distance_map_set_unchecked(&dmap, px, py, 0)
	queue[tail] = {px, py}
	tail += 1

	dx := CARDINAL_DX
	dy := CARDINAL_DY
	for head != tail {
		cur := queue[head]
		head += 1
		cur_dist := eng.engine_distance_map_get_unchecked(&dmap, cur.x, cur.y)
		for dir in 0 ..< 4 {
			nx := cur.x + dx[dir]
			ny := cur.y + dy[dir]
			if nx < 0 || nx >= MAP_WIDTH || ny < 0 || ny >= MAP_HEIGHT {continue}
			if !is_walkable(game, nx, ny) {continue}
			if eng.engine_distance_map_get_unchecked(&dmap, nx, ny) <= cur_dist + 1 {continue}
			eng.engine_distance_map_set_unchecked(&dmap, nx, ny, cur_dist + 1)
			queue[tail] = {nx, ny}
			tail += 1
		}
	}

	// Flow field is now fresh for this player input; clear the dirty flag so
	// subsequent enemy rounds in the same input reuse it.
	game.dijkstra_dirty = false
}


// ─── Process enemy turns (energy-based) ──────────────────────────────────────
