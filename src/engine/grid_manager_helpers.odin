package engine

// Shared helpers for fixed-array grid managers (Bool_Grid_Manager, Tile_State_Manager).
// All procs are package-private; public APIs live in the individual manager files.

@(private)
_grid_manager_is_valid :: proc(grid: Engine_Grid_2D, max_cells: int) -> bool {
	return engine_grid_2d_is_valid(grid) && engine_grid_2d_cell_count(grid) <= max_cells
}

@(private)
_grid_manager_cell_count :: proc(grid: Engine_Grid_2D, max_cells: int) -> int {
	if !_grid_manager_is_valid(grid, max_cells) {
		return 0
	}
	return engine_grid_2d_cell_count(grid)
}

// Copies up to min(cell_count, len(src)) elements from src into dst, then
// zero-fills the remainder of dst up to cell_count.
@(private)
_grid_manager_import :: proc(dst: []$T, src: []T, cell_count: int) {
	n := min(cell_count, len(src))
	for i in 0 ..< n {
		dst[i] = src[i]
	}
	zero: T
	for i in n ..< cell_count {
		dst[i] = zero
	}
}
