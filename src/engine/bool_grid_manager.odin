package engine

ENGINE_BOOL_GRID_MAX_CELLS :: 8192

Bool_Grid_Manager :: struct {
	grid:   Engine_Grid_2D,
	values: [ENGINE_BOOL_GRID_MAX_CELLS]bool,
}

bool_grid_manager_make :: proc(grid: Engine_Grid_2D) -> Bool_Grid_Manager {
	return Bool_Grid_Manager{grid = grid}
}

bool_grid_manager_is_valid :: proc(manager: Bool_Grid_Manager) -> bool {
	return _grid_manager_is_valid(manager.grid, ENGINE_BOOL_GRID_MAX_CELLS)
}

bool_grid_manager_cell_count :: proc(manager: Bool_Grid_Manager) -> int {
	return _grid_manager_cell_count(manager.grid, ENGINE_BOOL_GRID_MAX_CELLS)
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
	_grid_manager_import(manager.values[:], values, bool_grid_manager_cell_count(manager^))
}

bool_grid_manager_export :: proc(manager: Bool_Grid_Manager, values: []bool) {
	if !bool_grid_manager_is_valid(manager) {
		return
	}
	n := min(bool_grid_manager_cell_count(manager), len(values))
	for i in 0 ..< n {
		values[i] = manager.values[i]
	}
}
