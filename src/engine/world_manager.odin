package engine

World_Manager :: struct {
	grid:      Engine_Grid_2D,
	tile_size: int,
}

world_manager_make :: proc(width, height, tile_size: int) -> World_Manager {
	return World_Manager{grid = engine_grid_2d_make(width, height), tile_size = tile_size}
}

world_manager_is_valid :: proc(world: World_Manager) -> bool {
	return engine_grid_2d_is_valid(world.grid) && world.tile_size > 0
}

world_manager_grid :: proc(world: World_Manager) -> Engine_Grid_2D {
	return world.grid
}

world_manager_width :: proc(world: World_Manager) -> int {
	return world.grid.width
}

world_manager_height :: proc(world: World_Manager) -> int {
	return world.grid.height
}

world_manager_tile_size :: proc(world: World_Manager) -> int {
	return world.tile_size
}

world_manager_cell_count :: proc(world: World_Manager) -> int {
	return engine_grid_2d_cell_count(world.grid)
}

world_manager_pixel_width :: proc(world: World_Manager) -> int {
	if !world_manager_is_valid(world) {
		return 0
	}
	return world.grid.width * world.tile_size
}

world_manager_pixel_height :: proc(world: World_Manager) -> int {
	if !world_manager_is_valid(world) {
		return 0
	}
	return world.grid.height * world.tile_size
}

world_manager_contains :: proc(world: World_Manager, x, y: int) -> bool {
	return engine_grid_2d_contains(world.grid, x, y)
}

world_manager_index :: proc(world: World_Manager, x, y: int) -> int {
	return engine_grid_2d_index(world.grid, x, y)
}

world_manager_position :: proc(world: World_Manager, index: int) -> Engine_Grid_Pos {
	return engine_grid_2d_position(world.grid, index)
}
