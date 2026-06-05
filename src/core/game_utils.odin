package core

import eng "../engine"

pos_to_idx :: proc(x, y: int) -> int {
	return y * MAP_WIDTH + x
}

idx_to_pos_xy :: proc(idx: int) -> (int, int) {
	return idx % MAP_WIDTH, idx / MAP_WIDTH
}

idx_to_pos :: proc(idx: int) -> Vec2 {
	x, y := idx_to_pos_xy(idx)
	return Vec2{x, y}
}

game_world :: proc(game: ^Game = nil) -> eng.World_Manager {
	if game == nil {return {}}
	return game.world
}

game_grid :: proc(game: ^Game = nil) -> eng.Engine_Grid_2D {
	return eng.world_manager_grid(game_world(game))
}

tile_at :: proc(game: ^Game, x, y: int) -> ^Tile {
	if game == nil {return nil}
	if x < 0 || x >= MAP_WIDTH || y < 0 || y >= MAP_HEIGHT {return nil}
	return &game.tiles[pos_to_idx(x, y)]
}

tile_state_at :: proc(game: ^Game, x, y: int) -> eng.Tile_State {
	if game == nil {return {}}
	return tile_state_at_idx(game, pos_to_idx(x, y))
}

tile_state_at_idx :: proc(game: ^Game, idx: int) -> eng.Tile_State {
	if game == nil || idx < 0 || idx >= MAP_WIDTH * MAP_HEIGHT {return {}}
	return eng.tile_state_at_idx(game.tile_states, idx)
}

tile_visible_at :: proc(game: ^Game, x, y: int) -> bool {
	if game == nil || x < 0 || x >= MAP_WIDTH || y < 0 || y >= MAP_HEIGHT {return false}
	return tile_state_at_idx(game, pos_to_idx(x, y)).visible
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
	if game == nil {return false}
	return eng.tile_state_set(&game.tile_states, x, y, visible, explored, light_level)
}

tile_state_set_idx :: proc(
	game: ^Game,
	idx: int,
	visible, explored: bool,
	light_level: f32,
) -> bool {
	if game == nil {return false}
	return eng.tile_state_set_idx(&game.tile_states, idx, visible, explored, light_level)
}

tile_states_clear_visibility :: proc(game: ^Game) {
	if game == nil {return}
	game.render_map_dirty = true
	eng.tile_state_clear_visibility(&game.tile_states)
}

tile_states_import_from_tiles :: proc(game: ^Game, tiles: []Tile) {
	if game == nil {return}
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
	if game == nil {return}
	for i in 0 ..< min(len(tiles), eng.tile_state_manager_cell_count(game.tile_states)) {
		state := eng.tile_state_at_idx(game.tile_states, i)
		tiles[i].visible = state.visible
		tiles[i].explored = state.explored
		tiles[i].light_level = state.light_level
	}
}

is_walkable :: proc(game: ^Game, x, y: int) -> bool {
	t := tile_at(game, x, y)
	if t == nil {return false}
	#partial switch t.type {
	case .Floor, .Rubble, .Descent, .Water, .Gas_Vent, .Unstable, .Anvil, .Fountain, .Fire_Vent:
		return true
	}
	return false
}

web_tile_at :: proc(game: ^Game, x, y: int) -> bool {
	if game == nil {return false}
	return eng.bool_grid_manager_get(game.web_tiles, x, y)
}

web_tile_at_idx :: proc(game: ^Game, idx: int) -> bool {
	x, y := idx_to_pos_xy(idx)
	return web_tile_at(game, x, y)
}

web_tile_set :: proc(game: ^Game, x, y: int, value: bool) -> bool {
	if game == nil {return false}
	return eng.bool_grid_manager_set(&game.web_tiles, x, y, value)
}

web_tile_set_idx :: proc(game: ^Game, idx: int, value: bool) -> bool {
	x, y := idx_to_pos_xy(idx)
	return web_tile_set(game, x, y, value)
}

web_tiles_clear :: proc(game: ^Game) {
	if game == nil {return}
	eng.bool_grid_manager_clear(&game.web_tiles)
}

game_init_world :: proc(game: ^Game) {
	if game == nil {return}
	game.world = eng.world_manager_make(MAP_WIDTH, MAP_HEIGHT, TILE_SIZE)
	game.web_tiles = eng.bool_grid_manager_make(eng.world_manager_grid(game.world))
	game.tile_states = eng.tile_state_manager_make(eng.world_manager_grid(game.world))
	game.map_width = eng.world_manager_width(game.world)
	game.map_height = eng.world_manager_height(game.world)
}

enemy_at :: proc(game: ^Game, x, y: int) -> ^Enemy {
	for &enemy in game.enemies {
		if enemy.alive && enemy.pos.x == x && enemy.pos.y == y {
			return &enemy
		}
	}
	return nil
}

item_at :: proc(game: ^Game, x, y: int) -> ^Item {
	for &it in game.items {
		if !it.picked_up && it.pos.x == x && it.pos.y == y {
			return &it
		}
	}
	return nil
}

effective_attack_cost :: proc(game: ^Game) -> int {
	if game.equipped_weapon.occupied && game.equipped_weapon.item.action_cost > 0 {
		return game.equipped_weapon.item.action_cost
	}
	return BASE_ACTION_COST
}

effective_light_bonus :: proc(game: ^Game) -> int {
	if game.equipped_helmet.occupied {return game.equipped_helmet.item.stat_bonus}
	return 0
}

item_display_name :: proc(item: ^Item) -> string {
	if len(item.name) > 0 {return item.name}
	if len(item.item_type) > 0 {return item.item_type}
	return "Unknown"
}

enemy_display_name :: proc(enemy: ^Enemy) -> string {
	if enemy == nil {return "unknown"}
	if len(enemy.name) > 0 {return enemy.name}
	if len(enemy.enemy_type) > 0 {return enemy.enemy_type}
	return "creature"
}

count_material :: proc(game: ^Game, material_id: string) -> int {
	return inventory_count_item_type(game, material_id)
}

game_has_live_boss :: proc(game: ^Game) -> bool {
	if game == nil {return false}
	for &enemy in game.enemies {
		if enemy.alive && enemy.is_boss {return true}
	}
	return false
}

game_camera_update :: proc(camera: ^eng.Camera_Manager, game: ^Game, snap: bool = false) {
	if camera == nil || game == nil {return}
	zoom := f32(1.12) if game_has_live_boss(game) else f32(1)
	eng.camera_manager_set_zoom(camera, zoom)
	eng.camera_manager_update(
		camera,
		game.player.pos.x * TILE_SIZE + TILE_SIZE / 2,
		game.player.pos.y * TILE_SIZE + TILE_SIZE / 2,
		MAP_VIEW_WIDTH,
		MAP_VIEW_HEIGHT,
		eng.world_manager_pixel_width(game.world),
		eng.world_manager_pixel_height(game.world),
		snap,
	)
}
