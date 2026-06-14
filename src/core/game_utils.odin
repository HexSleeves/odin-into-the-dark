package core

import eng "../engine"
import "core:fmt"
import "core:math/rand"

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

// Serialize the live engine tile-state layer into a flat array (save/snapshot).
tile_state_manager_export :: proc(game: ^Game, states: []eng.Tile_State) {
	if game == nil {return}
	eng.tile_state_manager_export(game.tile_states, states)
}

// Restore the engine tile-state layer from a flat array (load/snapshot restore).
tile_state_manager_import :: proc(game: ^Game, states: []eng.Tile_State) {
	if game == nil {return}
	eng.tile_state_manager_import(&game.tile_states, states)
}

is_walkable :: proc(game: ^Game, x, y: int) -> bool {
	t := tile_at(game, x, y)
	if t == nil {return false}
	#partial switch t.type {
	case .Floor,
	     .Rubble,
	     .Descent,
	     .Ascent,
	     .Water,
	     .Gas_Vent,
	     .Unstable,
	     .Anvil,
	     .Fountain,
	     .Fire_Vent,
	     .Shrine,
	     .Chest,
	     .Merchant:
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

npc_at :: proc(game: ^Game, x, y: int) -> int {
	for i in 0 ..< game.npc_count {
		if game.npcs[i].pos.x == x && game.npcs[i].pos.y == y {
			return i
		}
	}
	return -1
}

effective_attack_cost :: proc(game: ^Game) -> int {
	if game.equipped_weapon.occupied && game.equipped_weapon.item.action_cost > 0 {
		return game.equipped_weapon.item.action_cost
	}
	return BASE_ACTION_COST
}

// effective_light_bonus returns the combined non-base light modifier:
// helmet equipment bonus plus any active debuff (light_debuff_bonus is negative).
// All FOV radius computations go through here so callers need not know the breakdown.
effective_light_bonus :: proc(game: ^Game) -> int {
	helmet_bonus := 0
	if game.equipped_helmet.occupied {helmet_bonus = game.equipped_helmet.item.stat_bonus}
	return helmet_bonus + game.light_debuff_bonus
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
	zoom := BOSS_CAMERA_ZOOM if game_has_live_boss(game) else f32(1)
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

// rand_room_interior picks a random interior point in a room (1 tile inset).
// Returns (room center x, room center y) if the room is too small for an interior.
rand_room_interior :: proc(room: Room) -> (x, y: int) {
	w := room.x2 - room.x1 - 2
	h := room.y2 - room.y1 - 2
	if w <= 0 || h <= 0 {
		return (room.x1 + room.x2) / 2, (room.y1 + room.y2) / 2
	}
	return rand.int_max(w) + room.x1 + 1, rand.int_max(h) + room.y1 + 1
}

// rand_room_any picks a random point anywhere within a room's bounds.
// Returns (room center x, room center y) if the room has zero area.
rand_room_any :: proc(room: Room) -> (x, y: int) {
	w := room.x2 - room.x1
	h := room.y2 - room.y1
	if w <= 0 || h <= 0 {
		return (room.x1 + room.x2) / 2, (room.y1 + room.y2) / 2
	}
	return rand.int_max(w) + room.x1, rand.int_max(h) + room.y1
}

victory_boss_status_text :: proc(game: ^Game) -> cstring {
	if game != nil && game.boss_killed_this_turn {
		return "Defeated"
	}
	return "Not defeated"
}

// ─── Kill-progression milestones ──────────────────────────────────────────────

// apply_kill_milestone_buff checks whether game.kills has crossed the next
// milestone threshold. If so, it increments kills_milestone, applies a small
// permanent buff to the player, and returns a non-empty message string for the
// caller to display. Returns "" when no milestone was reached.
// Buff type cycles: Max_HP → Attack → Light (repeating).
apply_kill_milestone_buff :: proc(game: ^Game) -> string {
	if game == nil {return ""}
	next_threshold := (game.kills_milestone + 1) * KILLS_PER_MILESTONE
	if game.kills < next_threshold {return ""}

	// Cycle buff type by milestone index (0=HP, 1=Attack, 2=Light, repeat)
	buff_index := game.kills_milestone % 3
	game.kills_milestone += 1

	switch buff_index {
	case 0:
		// Max HP
		game.player.max_hp += SHRINE_BUFF_MAX_HP
		game.player.hp += SHRINE_BUFF_MAX_HP
		return fmt.tprintf("You grow stronger! (+%d Max HP)", SHRINE_BUFF_MAX_HP)
	case 1:
		// Attack
		game.player.attack += SHRINE_BUFF_ATTACK
		return fmt.tprintf("Your strikes sharpen! (+%d Attack)", SHRINE_BUFF_ATTACK)
	case 2:
		// Light
		game.player.light_radius += SHRINE_BUFF_LIGHT
		return fmt.tprintf("Your vision expands! (+%d Light Radius)", SHRINE_BUFF_LIGHT)
	}
	return ""
}
