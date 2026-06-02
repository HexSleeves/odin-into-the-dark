package engine

import "core:testing"

@(test)
engine_distance_map_resets_and_reads_distances_by_grid_position :: proc(t: ^testing.T) {
	values: [12]int
	grid := engine_grid_2d_make(4, 3)
	dmap := engine_distance_map_make(values[:], grid, 9999)

	engine_distance_map_reset(&dmap)
	testing.expect_value(t, values[0], 9999)
	testing.expect_value(t, values[11], 9999)

	testing.expect(t, engine_distance_map_set(&dmap, 2, 1, 7))
	testing.expect_value(t, engine_distance_map_get(&dmap, 2, 1), 7)
	testing.expect_value(t, values[engine_grid_2d_index(grid, 2, 1)], 7)
}

@(test)
engine_distance_map_rejects_out_of_bounds_and_invalid_storage :: proc(t: ^testing.T) {
	values: [4]int
	grid := engine_grid_2d_make(2, 2)
	dmap := engine_distance_map_make(values[:], grid, 123)
	short_map := engine_distance_map_make(values[:3], grid, 123)

	testing.expect(t, engine_distance_map_is_valid(&dmap))
	testing.expect(t, !engine_distance_map_is_valid(&short_map))
	testing.expect(t, !engine_distance_map_set(&dmap, -1, 0, 5))
	testing.expect(t, !engine_distance_map_set(&dmap, 2, 0, 5))
	testing.expect_value(t, engine_distance_map_get(&dmap, -1, 0), 123)
	testing.expect_value(t, engine_distance_map_get(&dmap, 2, 0), 123)
}

