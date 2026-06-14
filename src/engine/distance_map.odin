package engine

Engine_Distance_Map :: struct {
	values:      []int,
	grid:        Engine_Grid_2D,
	unreachable: int,
}

engine_distance_map_make :: proc(
	values: []int,
	grid: Engine_Grid_2D,
	unreachable: int,
) -> Engine_Distance_Map {
	return Engine_Distance_Map{values = values, grid = grid, unreachable = unreachable}
}

engine_distance_map_is_valid :: proc(dmap: ^Engine_Distance_Map) -> bool {
	return(
		dmap != nil &&
		engine_grid_2d_is_valid(dmap.grid) &&
		len(dmap.values) >= engine_grid_2d_cell_count(dmap.grid) \
	)
}

engine_distance_map_reset :: proc(dmap: ^Engine_Distance_Map) {
	if !engine_distance_map_is_valid(dmap) {
		return
	}
	for i in 0 ..< engine_grid_2d_cell_count(dmap.grid) {
		dmap.values[i] = dmap.unreachable
	}
}

engine_distance_map_get :: proc(dmap: ^Engine_Distance_Map, x, y: int) -> int {
	if !engine_distance_map_is_valid(dmap) || !engine_grid_2d_contains(dmap.grid, x, y) {
		return dmap.unreachable if dmap != nil else 0
	}
	return dmap.values[engine_grid_2d_index(dmap.grid, x, y)]
}

engine_distance_map_set :: proc(dmap: ^Engine_Distance_Map, x, y, distance: int) -> bool {
	if !engine_distance_map_is_valid(dmap) || !engine_grid_2d_contains(dmap.grid, x, y) {
		return false
	}
	dmap.values[engine_grid_2d_index(dmap.grid, x, y)] = distance
	return true
}

// ─── Unchecked accessors for hot inner loops ──────────────────────────────────
//
// These skip the per-call engine_distance_map_is_valid / engine_grid_2d_cell_count
// recomputation. Callers MUST validate the map once with engine_distance_map_is_valid
// and bounds-check (x,y) independently before calling these.

@(private = "file")
_distance_map_get_unchecked :: proc(dmap: ^Engine_Distance_Map, x, y: int) -> int {
	return dmap.values[engine_grid_2d_index(dmap.grid, x, y)]
}

@(private = "file")
_distance_map_set_unchecked :: proc(dmap: ^Engine_Distance_Map, x, y, distance: int) {
	dmap.values[engine_grid_2d_index(dmap.grid, x, y)] = distance
}
