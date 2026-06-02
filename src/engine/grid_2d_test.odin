package engine

import "core:testing"

@(test)
engine_grid_2d_converts_positions_and_indexes :: proc(t: ^testing.T) {
	grid := engine_grid_2d_make(80, 50)

	testing.expect_value(t, engine_grid_2d_cell_count(grid), 4000)
	testing.expect_value(t, engine_grid_2d_index(grid, 3, 2), 163)

	pos := engine_grid_2d_position(grid, 163)
	testing.expect_value(t, pos.x, 3)
	testing.expect_value(t, pos.y, 2)
}

@(test)
engine_grid_2d_reports_bounds_and_rejects_invalid_dimensions :: proc(t: ^testing.T) {
	grid := engine_grid_2d_make(4, 3)
	invalid := engine_grid_2d_make(0, 3)

	testing.expect(t, engine_grid_2d_is_valid(grid))
	testing.expect(t, !engine_grid_2d_is_valid(invalid))
	testing.expect(t, engine_grid_2d_contains(grid, 0, 0))
	testing.expect(t, engine_grid_2d_contains(grid, 3, 2))
	testing.expect(t, !engine_grid_2d_contains(grid, -1, 0))
	testing.expect(t, !engine_grid_2d_contains(grid, 4, 2))
	testing.expect(t, !engine_grid_2d_contains(grid, 3, 3))
}

