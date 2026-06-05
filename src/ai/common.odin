package ai

import gameaudio "../audio"
import gcore "../core"
import eng "../engine"
import gameio "../io"
import renderer "../render"
import gameui "../ui"

Game :: gcore.Game
Enemy :: gcore.Enemy
Vec2 :: gcore.Vec2
Content_Manager :: gcore.Content_Manager
Message_Manager :: gameui.Message_Manager
Engine :: eng.Engine

MAP_WIDTH :: gcore.MAP_WIDTH
MAP_HEIGHT :: gcore.MAP_HEIGHT
TILE_SIZE :: gcore.TILE_SIZE
BASE_ACTION_COST :: gcore.BASE_ACTION_COST
BASE_MOVE_COST :: gcore.BASE_MOVE_COST
BASE_AP_PER_ROUND :: gcore.BASE_AP_PER_ROUND
DMAP_UNREACHABLE :: gcore.DMAP_UNREACHABLE
DEATH_CAUSE_MAX_LEN :: gcore.DEATH_CAUSE_MAX_LEN
CARDINAL_DX :: gcore.CARDINAL_DX
CARDINAL_DY :: gcore.CARDINAL_DY

ENEMY_BEHAVIOR_LURKER :: "lurker"
ENEMY_ABILITY_WEB :: "web"
ENEMY_ABILITY_PULL :: "pull"
ENEMY_ABILITY_POISON_CLOUD :: "poison_cloud"
ENEMY_ABILITY_TELEPORT :: "teleport"
ENEMY_ABILITY_SLAM :: "slam"
ENEMY_ABILITY_DARKNESS :: "darkness"
ENEMY_ABILITY_RANGED_SHOOT :: "ranged_shoot"
ENEMY_ABILITY_FREEZE :: "freeze"

enemy_make_from_def :: gcore.enemy_make_from_def
content_manager_enemy_def :: gcore.content_manager_enemy_def
content_manager_enemy_def_for_depth :: gcore.content_manager_enemy_def_for_depth
is_walkable :: gcore.is_walkable
tile_at :: gcore.tile_at
logger_warnf :: gameio.logger_warnf
spawn_death_particles :: renderer.spawn_death_particles
tile_visible_at :: gcore.tile_visible_at
web_tile_at :: gcore.web_tile_at
web_tile_set :: gcore.web_tile_set
pos_to_idx :: gcore.pos_to_idx
enemy_display_name :: gcore.enemy_display_name
item_display_name :: gcore.item_display_name
game_grid :: gcore.game_grid
add_message :: gameui.add_message
clear_messages :: gameui.clear_messages
play_sfx :: gameaudio.play_sfx
game_engine_vfx_manager :: renderer.game_engine_vfx_manager
logger_debugf :: gameio.logger_debugf
Game_Log_Channel :: gameio.Game_Log_Channel

effective_attack :: proc(game: ^Game) -> int {
	bonus := 0
	if game.equipped_weapon.occupied {bonus = game.equipped_weapon.item.stat_bonus}
	return game.player.attack + bonus
}

effective_defense :: proc(game: ^Game) -> int {
	if game.equipped_armor.occupied {return game.equipped_armor.item.stat_bonus}
	return 0
}

enemy_at :: proc(game: ^Game, x, y: int) -> ^Enemy {
	return gcore.enemy_at(game, x, y)
}

can_place_enemy :: proc(game: ^Game, x, y: int) -> bool {
	if !is_walkable(game, x, y) {return false}
	if x == game.player.pos.x && y == game.player.pos.y {return false}
	if enemy_at(game, x, y) != nil {return false}
	if t := tile_at(game, x, y); t != nil && t.type == .Descent {return false}
	return true
}
