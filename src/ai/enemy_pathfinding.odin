package ai

import eng "../engine"


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

	dx := CARDINAL_DX
	dy := CARDINAL_DY
	for head != tail {
		cur := queue[head]
		head += 1
		cur_dist := eng.engine_distance_map_get(&dmap, cur.x, cur.y)
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
