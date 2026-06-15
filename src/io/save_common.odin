package gameio

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
DEFAULT_ENEMY_DETECTION_RADIUS :: gcore.DEFAULT_ENEMY_DETECTION_RADIUS
DEFAULT_ENEMY_MEMORY_TURNS :: gcore.DEFAULT_ENEMY_MEMORY_TURNS

ENEMY_ABILITY_WEB :: gcore.ENEMY_ABILITY_WEB
ENEMY_ABILITY_PULL :: gcore.ENEMY_ABILITY_PULL
ENEMY_ABILITY_POISON_CLOUD :: gcore.ENEMY_ABILITY_POISON_CLOUD
ENEMY_ABILITY_TELEPORT :: gcore.ENEMY_ABILITY_TELEPORT
ENEMY_ABILITY_SLAM :: gcore.ENEMY_ABILITY_SLAM
ENEMY_ABILITY_DARKNESS :: gcore.ENEMY_ABILITY_DARKNESS
EQUIPMENT_SLOT_WEAPON :: gcore.EQUIPMENT_SLOT_WEAPON
EQUIPMENT_SLOT_ARMOR :: gcore.EQUIPMENT_SLOT_ARMOR
EQUIPMENT_SLOT_HELMET :: gcore.EQUIPMENT_SLOT_HELMET
ITEM_EFFECT_MATERIAL :: gcore.ITEM_EFFECT_MATERIAL

content_manager_item_def :: gcore.content_manager_item_def
content_manager_player_def :: gcore.content_manager_player_def
content_manager_enemy_def :: gcore.content_manager_enemy_def
tile_state_manager_import :: gcore.tile_state_manager_import
tile_state_manager_export :: gcore.tile_state_manager_export
game_init_world :: gcore.game_init_world
game_camera_update :: gcore.game_camera_update
palette_for_depth :: gcore.palette_for_depth
ui_manager_reset_transient :: gameui.ui_manager_reset_transient

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

game_cleanup :: proc(game: ^Game) {
	if game == nil {return}
	gcore.clear_visited_floors(game)
	if game.rooms != nil {delete(game.rooms)}
	if game.enemies != nil {delete(game.enemies)}
	if game.items != nil {delete(game.items)}
	if game.light_sources != nil {delete(game.light_sources)}
	game.rooms = nil
	game.enemies = nil
	game.items = nil
	game.light_sources = nil
}

compute_fov :: gcore.compute_fov
