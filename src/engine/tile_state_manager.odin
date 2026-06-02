package engine

ENGINE_TILE_STATE_MAX_CELLS :: 4096

Tile_State :: struct {
	visible:     bool,
	explored:    bool,
	light_level: f32,
}

Tile_State_Manager :: struct {
	grid:   Engine_Grid_2D,
	states: [ENGINE_TILE_STATE_MAX_CELLS]Tile_State,
}

tile_state_manager_make :: proc(grid: Engine_Grid_2D) -> Tile_State_Manager {
	return Tile_State_Manager{grid = grid}
}

tile_state_manager_is_valid :: proc(manager: Tile_State_Manager) -> bool {
	return engine_grid_2d_is_valid(manager.grid) &&
	       engine_grid_2d_cell_count(manager.grid) <= ENGINE_TILE_STATE_MAX_CELLS
}

tile_state_manager_cell_count :: proc(manager: Tile_State_Manager) -> int {
	if !tile_state_manager_is_valid(manager) {
		return 0
	}
	return engine_grid_2d_cell_count(manager.grid)
}

tile_state_at :: proc(manager: Tile_State_Manager, x, y: int) -> Tile_State {
	if !tile_state_manager_is_valid(manager) || !engine_grid_2d_contains(manager.grid, x, y) {
		return Tile_State{}
	}
	return manager.states[engine_grid_2d_index(manager.grid, x, y)]
}

tile_state_at_idx :: proc(manager: Tile_State_Manager, index: int) -> Tile_State {
	if !tile_state_manager_is_valid(manager) || index < 0 || index >= tile_state_manager_cell_count(manager) {
		return Tile_State{}
	}
	return manager.states[index]
}

tile_state_visible :: proc(manager: Tile_State_Manager, x, y: int) -> bool {
	return tile_state_at(manager, x, y).visible
}

tile_state_visible_idx :: proc(manager: Tile_State_Manager, index: int) -> bool {
	return tile_state_at_idx(manager, index).visible
}

tile_state_explored :: proc(manager: Tile_State_Manager, x, y: int) -> bool {
	return tile_state_at(manager, x, y).explored
}

tile_state_explored_idx :: proc(manager: Tile_State_Manager, index: int) -> bool {
	return tile_state_at_idx(manager, index).explored
}

tile_state_light_level :: proc(manager: Tile_State_Manager, x, y: int) -> f32 {
	return tile_state_at(manager, x, y).light_level
}

tile_state_light_level_idx :: proc(manager: Tile_State_Manager, index: int) -> f32 {
	return tile_state_at_idx(manager, index).light_level
}

tile_state_set :: proc(manager: ^Tile_State_Manager, x, y: int, visible, explored: bool, light_level: f32) -> bool {
	if manager == nil || !tile_state_manager_is_valid(manager^) || !engine_grid_2d_contains(manager.grid, x, y) {
		return false
	}
	manager.states[engine_grid_2d_index(manager.grid, x, y)] = Tile_State {
		visible     = visible,
		explored    = explored,
		light_level = light_level,
	}
	return true
}

tile_state_set_idx :: proc(manager: ^Tile_State_Manager, index: int, visible, explored: bool, light_level: f32) -> bool {
	if manager == nil || !tile_state_manager_is_valid(manager^) || index < 0 || index >= tile_state_manager_cell_count(manager^) {
		return false
	}
	manager.states[index] = Tile_State {
		visible     = visible,
		explored    = explored,
		light_level = light_level,
	}
	return true
}

tile_state_set_visible :: proc(manager: ^Tile_State_Manager, x, y: int, visible: bool) -> bool {
	if manager == nil || !tile_state_manager_is_valid(manager^) || !engine_grid_2d_contains(manager.grid, x, y) {
		return false
	}
	manager.states[engine_grid_2d_index(manager.grid, x, y)].visible = visible
	return true
}

tile_state_set_explored :: proc(manager: ^Tile_State_Manager, x, y: int, explored: bool) -> bool {
	if manager == nil || !tile_state_manager_is_valid(manager^) || !engine_grid_2d_contains(manager.grid, x, y) {
		return false
	}
	manager.states[engine_grid_2d_index(manager.grid, x, y)].explored = explored
	return true
}

tile_state_set_light_level :: proc(manager: ^Tile_State_Manager, x, y: int, light_level: f32) -> bool {
	if manager == nil || !tile_state_manager_is_valid(manager^) || !engine_grid_2d_contains(manager.grid, x, y) {
		return false
	}
	manager.states[engine_grid_2d_index(manager.grid, x, y)].light_level = light_level
	return true
}

tile_state_clear_visibility :: proc(manager: ^Tile_State_Manager) {
	if manager == nil || !tile_state_manager_is_valid(manager^) {
		return
	}
	for i in 0 ..< tile_state_manager_cell_count(manager^) {
		manager.states[i].visible = false
		manager.states[i].light_level = 0
	}
}

tile_state_manager_import :: proc(manager: ^Tile_State_Manager, states: []Tile_State) {
	if manager == nil || !tile_state_manager_is_valid(manager^) {
		return
	}
	cell_count := min(tile_state_manager_cell_count(manager^), len(states))
	for i in 0 ..< cell_count {
		manager.states[i] = states[i]
	}
	for i in cell_count ..< tile_state_manager_cell_count(manager^) {
		manager.states[i] = Tile_State{}
	}
}

tile_state_manager_export :: proc(manager: Tile_State_Manager, states: []Tile_State) {
	if !tile_state_manager_is_valid(manager) {
		return
	}
	cell_count := min(tile_state_manager_cell_count(manager), len(states))
	for i in 0 ..< cell_count {
		states[i] = manager.states[i]
	}
}
