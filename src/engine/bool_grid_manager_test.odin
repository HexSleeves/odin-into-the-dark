#+build !js
package engine

import "core:testing"

@(test)
bool_grid_manager_starts_empty_and_respects_bounds :: proc(t: ^testing.T) {
	grid := bool_grid_manager_make(engine_grid_2d_make(4, 3))

	testing.expect(t, bool_grid_manager_is_valid(grid))
	testing.expect_value(t, bool_grid_manager_cell_count(grid), 12)
	testing.expect(t, !bool_grid_manager_get(grid, 2, 1))
	testing.expect(t, !bool_grid_manager_get(grid, -1, 0))
	testing.expect(t, !bool_grid_manager_get(grid, 4, 0))
}

@(test)
bool_grid_manager_sets_clears_and_counts_true_cells :: proc(t: ^testing.T) {
	grid := bool_grid_manager_make(engine_grid_2d_make(4, 3))

	testing.expect(t, bool_grid_manager_set(&grid, 2, 1, true))
	testing.expect(t, bool_grid_manager_get(grid, 2, 1))
	testing.expect_value(t, bool_grid_manager_true_count(grid), 1)
	testing.expect(t, !bool_grid_manager_set(&grid, 4, 0, true))

	bool_grid_manager_clear(&grid)
	testing.expect(t, !bool_grid_manager_get(grid, 2, 1))
	testing.expect_value(t, bool_grid_manager_true_count(grid), 0)
}

@(test)
bool_grid_manager_imports_and_exports_linear_storage :: proc(t: ^testing.T) {
	grid := bool_grid_manager_make(engine_grid_2d_make(4, 3))
	values: [12]bool
	values[5] = true
	values[11] = true
	out: [12]bool

	bool_grid_manager_import(&grid, values[:])
	testing.expect(t, bool_grid_manager_get(grid, 1, 1))
	testing.expect(t, bool_grid_manager_get(grid, 3, 2))

	bool_grid_manager_export(grid, out[:])
	testing.expect(t, out[5])
	testing.expect(t, out[11])
}