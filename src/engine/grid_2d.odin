package engine

Engine_Grid_2D :: struct {
	width:  int,
	height: int,
}

Engine_Grid_Pos :: struct {
	x, y: int,
}

engine_grid_2d_make :: proc(width, height: int) -> Engine_Grid_2D {
	return Engine_Grid_2D{width = width, height = height}
}

engine_grid_2d_is_valid :: proc(grid: Engine_Grid_2D) -> bool {
	return grid.width > 0 && grid.height > 0
}

engine_grid_2d_cell_count :: proc(grid: Engine_Grid_2D) -> int {
	if !engine_grid_2d_is_valid(grid) {
		return 0
	}
	return grid.width * grid.height
}

engine_grid_2d_contains :: proc(grid: Engine_Grid_2D, x, y: int) -> bool {
	return engine_grid_2d_is_valid(grid) && x >= 0 && y >= 0 && x < grid.width && y < grid.height
}

engine_grid_2d_index :: proc(grid: Engine_Grid_2D, x, y: int) -> int {
	return y * grid.width + x
}

engine_grid_2d_position :: proc(grid: Engine_Grid_2D, index: int) -> Engine_Grid_Pos {
	if grid.width <= 0 {
		return Engine_Grid_Pos{}
	}
	return Engine_Grid_Pos{x = index % grid.width, y = index / grid.width}
}
