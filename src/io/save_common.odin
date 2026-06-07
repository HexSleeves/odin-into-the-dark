package gameio
import "base:runtime"


import gcore "../core"
import eng "../engine"
import gameui "../ui"

Vec2 :: gcore.Vec2
Room :: gcore.Room
Tile :: gcore.Tile
Enemy :: gcore.Enemy
Quest_State :: gcore.Quest_State
Enemy_Def :: gcore.Enemy_Def
Item :: gcore.Item
Item_Def :: gcore.Item_Def
Inventory_Slot :: gcore.Inventory_Slot
Equipment :: gcore.Equipment
Light_Source :: gcore.Light_Source
Ore_Vein :: gcore.Ore_Vein
Player :: gcore.Player
Saved_Floor :: gcore.Saved_Floor
Game :: gcore.Game
Content_Manager :: gcore.Content_Manager
UI_Manager :: gameui.UI_Manager
Message_Manager :: eng.Message_Manager

MAP_WIDTH :: gcore.MAP_WIDTH
MAP_HEIGHT :: gcore.MAP_HEIGHT
MAX_INVENTORY :: gcore.MAX_INVENTORY
MAX_DEPTH :: gcore.MAX_DEPTH
DEATH_CAUSE_MAX_LEN :: gcore.DEATH_CAUSE_MAX_LEN
BASE_ACTION_COST :: gcore.BASE_ACTION_COST
DEFAULT_ENEMY_DETECTION_RADIUS :: gcore.DEFAULT_ENEMY_DETECTION_RADIUS
DEFAULT_ENEMY_MEMORY_TURNS :: gcore.DEFAULT_ENEMY_MEMORY_TURNS

ENEMY_ABILITY_WEB :: "web"
ENEMY_ABILITY_PULL :: "pull"
ENEMY_ABILITY_POISON_CLOUD :: "poison_cloud"
ENEMY_ABILITY_TELEPORT :: "teleport"
ENEMY_ABILITY_SLAM :: "slam"
ENEMY_ABILITY_DARKNESS :: "darkness"
EQUIPMENT_SLOT_WEAPON :: "weapon"
EQUIPMENT_SLOT_ARMOR :: "armor"
EQUIPMENT_SLOT_HELMET :: "helmet"
ITEM_EFFECT_MATERIAL :: "material"

content_manager_item_def :: gcore.content_manager_item_def
content_manager_player_def :: gcore.content_manager_player_def
content_manager_enemy_def :: gcore.content_manager_enemy_def
item_display_name :: gcore.item_display_name
tile_states_import_from_tiles :: gcore.tile_states_import_from_tiles
tile_states_export_to_tiles :: gcore.tile_states_export_to_tiles
game_init_world :: gcore.game_init_world
game_camera_update :: gcore.game_camera_update
palette_for_depth :: gcore.palette_for_depth
ui_manager_reset_transient :: gameui.ui_manager_reset_transient

effective_light_bonus :: proc(game: ^Game) -> int {
	if game != nil && game.equipped_helmet.occupied {return game.equipped_helmet.item.stat_bonus}
	return 0
}

add_message :: proc(
	messages: ^Message_Manager,
	game: ^Game,
	text: string,
	color: eng.Engine_Color,
) {
	if messages == nil || game == nil {return}
	eng.message_manager_add(messages, text, color)
}

clear_messages :: proc(messages: ^Message_Manager) {
	eng.message_manager_clear(messages)
}

saved_floor_destroy :: proc(floor: ^Saved_Floor) {
	if floor == nil {return}
	if floor.rooms != nil {delete(floor.rooms)}
	if floor.enemies != nil {delete(floor.enemies)}
	if floor.items != nil {delete(floor.items)}
	if floor.light_sources != nil {delete(floor.light_sources)}
	floor^ = {}
}

clear_visited_floors :: proc(game: ^Game) {
	if game == nil {return}
	for i in 0 ..< len(game.visited_floors) {
		if game.visited_floors[i] == nil {continue}
		saved_floor_destroy(game.visited_floors[i])
		free(game.visited_floors[i], runtime.default_allocator())
		game.visited_floors[i] = nil
	}
}

game_cleanup :: proc(game: ^Game) {
	if game == nil {return}
	clear_visited_floors(game)
	if game.rooms != nil {delete(game.rooms)}
	if game.enemies != nil {delete(game.enemies)}
	if game.items != nil {delete(game.items)}
	if game.light_sources != nil {delete(game.light_sources)}
	game.rooms = nil
	game.enemies = nil
	game.items = nil
	game.light_sources = nil
}

@(private = "file")
SAVE_OCTANT_MULTIPLIERS :: [8][4]int {
	{1, 0, 0, 1},
	{0, 1, 1, 0},
	{0, -1, 1, 0},
	{-1, 0, 0, 1},
	{-1, 0, 0, -1},
	{0, -1, -1, 0},
	{0, 1, -1, 0},
	{1, 0, 0, -1},
}

compute_fov :: proc(game: ^Game) {
	if game == nil {return}
	gcore.tile_states_clear_visibility(game)
	px := game.player.pos.x
	py := game.player.pos.y
	radius := game.player.light_radius + game.light_boost_bonus + effective_light_bonus(game)
	_ = gcore.tile_state_set(game, px, py, true, true, 1.0)
	mults := SAVE_OCTANT_MULTIPLIERS
	for oct in 0 ..< 8 {
		save_cast_light(game, px, py, radius, 1, 1.0, 0.0, mults[oct])
	}
}

@(private = "file")
save_cast_light :: proc(
	game: ^Game,
	origin_x, origin_y: int,
	radius: int,
	row: int,
	start_slope: f64,
	end_slope: f64,
	mult: [4]int,
) {
	start := start_slope
	if start < end_slope {return}
	radius_sq := f64(radius * radius)
	for j := row; j <= radius; j += 1 {
		dx := -j - 1
		dy := -j
		blocked := false
		next_start := start
		for dx <= 0 {
			dx += 1
			map_x := origin_x + dx * mult[0] + dy * mult[1]
			map_y := origin_y + dx * mult[2] + dy * mult[3]
			l_slope := (f64(dx) - 0.5) / (f64(dy) + 0.5)
			r_slope := (f64(dx) + 0.5) / (f64(dy) - 0.5)
			if start < r_slope {continue}
			if end_slope > l_slope {break}
			dist_sq := f64(dx * dx + dy * dy)
			if dist_sq <= radius_sq && gcore.tile_at(game, map_x, map_y) != nil {
				_ = gcore.tile_state_set(
					game,
					map_x,
					map_y,
					true,
					true,
					f32(1.0 - dist_sq / radius_sq),
				)
			}
			if blocked {
				if save_is_opaque(game, map_x, map_y) {
					next_start = r_slope
					continue
				} else {
					blocked = false
					start = next_start
				}
			} else if save_is_opaque(game, map_x, map_y) && j < radius {
				blocked = true
				save_cast_light(game, origin_x, origin_y, radius, j + 1, start, l_slope, mult)
				next_start = r_slope
			}
		}
		if blocked {break}
	}
}

@(private = "file")
save_is_opaque :: proc(game: ^Game, x, y: int) -> bool {
	t := gcore.tile_at(game, x, y)
	if t == nil {return true}
	#partial switch t.type {
	case .Wall, .Locked_Door:
		return true
	}
	return false
}
