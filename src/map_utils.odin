package main

import eng "./engine"

// ─── Map helpers ──────────────────────────────────────────────────────────────

game_world :: proc(game: ^Game = nil) -> eng.World_Manager {
	if game != nil && eng.world_manager_is_valid(game.world) {
		return game.world
	}
	return eng.world_manager_make(MAP_WIDTH, MAP_HEIGHT, TILE_SIZE)
}

game_grid :: proc(game: ^Game = nil) -> eng.Engine_Grid_2D {
	return eng.world_manager_grid(game_world(game))
}

pos_to_idx :: proc(x, y: int) -> int {
	return eng.world_manager_index(game_world(), x, y)
}

idx_to_pos :: proc(idx: int) -> Vec2 {
	pos := eng.world_manager_position(game_world(), idx)
	return Vec2{pos.x, pos.y}
}

tile_at :: proc(game: ^Game, x, y: int) -> ^Tile {
	if game == nil || !eng.world_manager_contains(game_world(game), x, y) {
		return nil
	}
	return &game.tiles[pos_to_idx(x, y)]
}

is_walkable :: proc(game: ^Game, x, y: int) -> bool {
	t := tile_at(game, x, y)
	if t == nil {
		return false
	}
	#partial switch t.type {
	case .Floor, .Rubble, .Descent, .Water, .Gas_Vent, .Unstable, .Anvil:
		return true
	}
	return false
}

web_tile_at :: proc(game: ^Game, x, y: int) -> bool {
	if game == nil {
		return false
	}
	return eng.bool_grid_manager_get(game.web_tiles, x, y)
}

web_tile_at_idx :: proc(game: ^Game, idx: int) -> bool {
	pos := idx_to_pos(idx)
	return web_tile_at(game, pos.x, pos.y)
}

web_tile_set :: proc(game: ^Game, x, y: int, value: bool) -> bool {
	if game == nil {
		return false
	}
	return eng.bool_grid_manager_set(&game.web_tiles, x, y, value)
}

web_tile_set_idx :: proc(game: ^Game, idx: int, value: bool) -> bool {
	pos := idx_to_pos(idx)
	return web_tile_set(game, pos.x, pos.y, value)
}

web_tiles_clear :: proc(game: ^Game) {
	if game == nil {
		return
	}
	eng.bool_grid_manager_clear(&game.web_tiles)
}

tile_state_at :: proc(game: ^Game, x, y: int) -> eng.Tile_State {
	if game == nil {
		return eng.Tile_State{}
	}
	return eng.tile_state_at(game.tile_states, x, y)
}

tile_state_at_idx :: proc(game: ^Game, idx: int) -> eng.Tile_State {
	if game == nil {
		return eng.Tile_State{}
	}
	return eng.tile_state_at_idx(game.tile_states, idx)
}

tile_visible_at :: proc(game: ^Game, x, y: int) -> bool {
	return tile_state_at(game, x, y).visible
}

tile_visible_idx :: proc(game: ^Game, idx: int) -> bool {
	return tile_state_at_idx(game, idx).visible
}

tile_explored_at :: proc(game: ^Game, x, y: int) -> bool {
	return tile_state_at(game, x, y).explored
}

tile_explored_idx :: proc(game: ^Game, idx: int) -> bool {
	return tile_state_at_idx(game, idx).explored
}

tile_light_level_at :: proc(game: ^Game, x, y: int) -> f32 {
	return tile_state_at(game, x, y).light_level
}

tile_light_level_idx :: proc(game: ^Game, idx: int) -> f32 {
	return tile_state_at_idx(game, idx).light_level
}

tile_state_set :: proc(game: ^Game, x, y: int, visible, explored: bool, light_level: f32) -> bool {
	if game == nil {
		return false
	}
	return eng.tile_state_set(&game.tile_states, x, y, visible, explored, light_level)
}

tile_state_set_idx :: proc(
	game: ^Game,
	idx: int,
	visible, explored: bool,
	light_level: f32,
) -> bool {
	if game == nil {
		return false
	}
	return eng.tile_state_set_idx(&game.tile_states, idx, visible, explored, light_level)
}

tile_states_clear_visibility :: proc(game: ^Game) {
	if game == nil {
		return
	}
	eng.tile_state_clear_visibility(&game.tile_states)
}

tile_states_import_from_tiles :: proc(game: ^Game, tiles: []Tile) {
	if game == nil {
		return
	}
	for i in 0 ..< min(len(tiles), eng.tile_state_manager_cell_count(game.tile_states)) {
		_ = eng.tile_state_set_idx(
			&game.tile_states,
			i,
			tiles[i].visible,
			tiles[i].explored,
			tiles[i].light_level,
		)
	}
}

tile_states_export_to_tiles :: proc(game: ^Game, tiles: []Tile) {
	if game == nil {
		return
	}
	for i in 0 ..< min(len(tiles), eng.tile_state_manager_cell_count(game.tile_states)) {
		state := eng.tile_state_at_idx(game.tile_states, i)
		tiles[i].visible = state.visible
		tiles[i].explored = state.explored
		tiles[i].light_level = state.light_level
	}
}
