package core

import eng "../engine"

pos_to_idx :: proc(x, y: int) -> int {
	return y * MAP_WIDTH + x
}

idx_to_pos_xy :: proc(idx: int) -> (int, int) {
	return idx % MAP_WIDTH, idx / MAP_WIDTH
}

game_world :: proc(game: ^Game) -> eng.World_Manager {
	if game == nil {return {}}
	return game.world
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

tile_explored_at :: proc(game: ^Game, x, y: int) -> bool {
	return tile_state_at(game, x, y).explored
}

enemy_at :: proc(game: ^Game, x, y: int) -> ^Enemy {
	for &enemy in game.enemies {
		if enemy.alive && enemy.pos.x == x && enemy.pos.y == y {
			return &enemy
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

item_display_name :: proc(item: ^Item) -> string {
	if len(item.name) > 0 {return item.name}
	if len(item.item_type) > 0 {return item.item_type}
	return "Unknown"
}

tile_visible_idx :: proc(game: ^Game, idx: int) -> bool {
	return tile_state_at_idx(game, idx).visible
}

web_tile_at_idx :: proc(game: ^Game, idx: int) -> bool {
	if game == nil {return false}
	x, y := idx % MAP_WIDTH, idx / MAP_WIDTH
	return eng.bool_grid_manager_get(game.web_tiles, x, y)
}

enemy_display_name :: proc(enemy: ^Enemy) -> string {
	if enemy == nil {return "unknown"}
	if len(enemy.name) > 0 {return enemy.name}
	if len(enemy.enemy_type) > 0 {return enemy.enemy_type}
	return "creature"
}

ENEMY_ABILITY_WEB :: "web"

count_material :: proc(game: ^Game, material_id: string) -> int {
	if game == nil {return 0}
	total := 0
	for i in 0 ..< MAX_INVENTORY {
		if game.inventory[i].occupied && game.inventory[i].item.item_type == material_id {
			total += game.inventory[i].item.quantity
		}
	}
	return total
}
