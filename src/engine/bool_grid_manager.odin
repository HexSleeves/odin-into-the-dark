package engine

ENGINE_BOOL_GRID_MAX_CELLS :: 4096

Bool_Grid_Manager :: struct {
	grid:   Engine_Grid_2D,
	values: [ENGINE_BOOL_GRID_MAX_CELLS]bool,
}

bool_grid_manager_make :: proc(grid: Engine_Grid_2D) -> Bool_Grid_Manager {
	return Bool_Grid_Manager{grid = grid}
}

bool_grid_manager_is_valid :: proc(manager: Bool_Grid_Manager) -> bool {
	return(
		engine_grid_2d_is_valid(manager.grid) &&
		engine_grid_2d_cell_count(manager.grid) <= ENGINE_BOOL_GRID_MAX_CELLS \
	)
}

bool_grid_manager_cell_count :: proc(manager: Bool_Grid_Manager) -> int {
	if !bool_grid_manager_is_valid(manager) {
		return 0
	}
	return engine_grid_2d_cell_count(manager.grid)
}

bool_grid_manager_get :: proc(manager: Bool_Grid_Manager, x, y: int) -> bool {
	if !bool_grid_manager_is_valid(manager) || !engine_grid_2d_contains(manager.grid, x, y) {
		return false
	}
	return manager.values[engine_grid_2d_index(manager.grid, x, y)]
}

bool_grid_manager_set :: proc(manager: ^Bool_Grid_Manager, x, y: int, value: bool) -> bool {
	if manager == nil ||
	   !bool_grid_manager_is_valid(manager^) ||
	   !engine_grid_2d_contains(manager.grid, x, y) {
		return false
	}
	manager.values[engine_grid_2d_index(manager.grid, x, y)] = value
	return true
}

bool_grid_manager_clear :: proc(manager: ^Bool_Grid_Manager) {
	if manager == nil || !bool_grid_manager_is_valid(manager^) {
		return
	}
	for i in 0 ..< bool_grid_manager_cell_count(manager^) {
		manager.values[i] = false
	}
}

bool_grid_manager_true_count :: proc(manager: Bool_Grid_Manager) -> int {
	if !bool_grid_manager_is_valid(manager) {
		return 0
	}
	count := 0
	for i in 0 ..< bool_grid_manager_cell_count(manager) {
		if manager.values[i] {
			count += 1
		}
	}
	return count
}

bool_grid_manager_import :: proc(manager: ^Bool_Grid_Manager, values: []bool) {
	if manager == nil || !bool_grid_manager_is_valid(manager^) {
		return
	}
	cell_count := min(bool_grid_manager_cell_count(manager^), len(values))
	for i in 0 ..< cell_count {
		manager.values[i] = values[i]
	}
	for i in cell_count ..< bool_grid_manager_cell_count(manager^) {
		manager.values[i] = false
	}
}

bool_grid_manager_export :: proc(manager: Bool_Grid_Manager, values: []bool) {
	if !bool_grid_manager_is_valid(manager) {
		return
	}
	cell_count := min(bool_grid_manager_cell_count(manager), len(values))
	for i in 0 ..< cell_count {
		values[i] = manager.values[i]
	}
}
