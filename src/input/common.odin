package gameinput

import gameaudio "../audio"
import gcore "../core"
import eng "../engine"
import gp "../gameplay"
import gameio "../io"
import renderer "../render"
import gameui "../ui"

// ─── Build flags (needed for `when` guards in this package) ───────────────────
CHEATS_ENABLED :: #config(CHEATS, false)
NO_AUDIO :: #config(NO_AUDIO, false)
NO_SPRITES :: #config(NO_SPRITES, false)

// ─── Core types ───────────────────────────────────────────────────────────────
Game :: gcore.Game
Player :: gcore.Player
Enemy :: gcore.Enemy
Item :: gcore.Item
Vec2 :: gcore.Vec2
Tile :: gcore.Tile
Tile_Type :: gcore.Tile_Type
Content_Manager :: gcore.Content_Manager
Message_Manager :: eng.Message_Manager
Engine :: eng.Engine
UI_Manager :: gameui.UI_Manager
UI_State :: gcore.UI_State
Score_Manager :: renderer.Score_Manager
Audio_Manager :: gameaudio.Audio_Manager
Sound_Type :: gameaudio.Sound_Type
when CHEATS_ENABLED {
	Cheat_Command :: gcore.Cheat_Command
}

// ─── Core constants ───────────────────────────────────────────────────────────
MAP_WIDTH :: gcore.MAP_WIDTH
MAP_HEIGHT :: gcore.MAP_HEIGHT
MAX_INVENTORY :: gcore.MAX_INVENTORY
MAX_DEPTH :: gcore.MAX_DEPTH
SURFACE_DEPTH :: gcore.SURFACE_DEPTH
BASE_ACTION_COST :: gcore.BASE_ACTION_COST
BASE_MOVE_COST :: gcore.BASE_MOVE_COST
TILE_SIZE :: gcore.TILE_SIZE
ITEM_ID_VAULT_KEY :: gcore.ITEM_ID_VAULT_KEY
TITLE_OPTION_COUNT :: gcore.TITLE_OPTION_COUNT
TITLE_NEW_GAME :: gcore.TITLE_NEW_GAME
TITLE_CONTINUE :: gcore.TITLE_CONTINUE
TITLE_HIGH_SCORES :: gcore.TITLE_HIGH_SCORES
TITLE_HELP :: gcore.TITLE_HELP
TITLE_QUIT :: gcore.TITLE_QUIT
when CHEATS_ENABLED {
	CHEAT_COMMAND_COUNT :: gcore.CHEAT_COMMAND_COUNT
}

// ─── Core helpers ─────────────────────────────────────────────────────────────
pos_to_idx :: gcore.pos_to_idx
tile_at :: gcore.tile_at
tile_state_at_idx :: gcore.tile_state_at_idx
tile_state_set_idx :: gcore.tile_state_set_idx
is_walkable :: gcore.is_walkable
enemy_at :: gcore.enemy_at
item_at :: gcore.item_at
npc_at :: gcore.npc_at
item_display_name :: gcore.item_display_name
effective_attack_cost :: gcore.effective_attack_cost
remove_item_from_inventory :: gcore.remove_item_from_inventory
game_camera_update :: gcore.game_camera_update
inventory_first_empty_slot :: gcore.inventory_first_empty_slot
inventory_put_slot :: gcore.inventory_put_slot
when CHEATS_ENABLED {
	cheat_command_label :: gcore.cheat_command_label
	cheat_command_for_index :: gcore.cheat_command_for_index
}

// ─── Service accessors ────────────────────────────────────────────────────────
game_engine_content_manager :: renderer.game_engine_content_manager
game_engine_message_manager :: renderer.game_engine_message_manager
game_engine_camera_manager :: renderer.game_engine_camera_manager
game_engine_turn_manager :: renderer.game_engine_turn_manager
game_engine_vfx_manager :: renderer.game_engine_vfx_manager
game_engine_particle_manager :: renderer.game_engine_particle_manager
game_engine_ui_manager :: renderer.game_engine_ui_manager
game_camera_x :: renderer.game_camera_x
game_camera_y :: renderer.game_camera_y

game_engine_audio_manager :: proc(engine: ^Engine) -> ^Audio_Manager {
	return eng.engine_audio_manager(engine)
}
ascend :: gp.ascend

game_engine_save_manager :: renderer.game_engine_save_manager
game_engine_score_manager :: renderer.game_engine_score_manager

@(private = "file")
GAME_ENGINE_SERVICE_INPUT :: eng.Engine_Service_Id(7)

game_engine_input_manager :: proc(engine: ^Engine) -> ^Input_Manager {
	if engine == nil || engine.services == nil {return nil}
	return cast(^Input_Manager)eng.engine_services_get(engine.services, GAME_ENGINE_SERVICE_INPUT)
}

// ─── UI helpers ───────────────────────────────────────────────────────────────
add_message :: gameui.add_message
clear_messages :: gameui.clear_messages
ui_manager_state :: gameui.ui_manager_state

// ─── Audio helpers ────────────────────────────────────────────────────────────
play_sfx :: gameaudio.play_sfx
audio_manager_play_sfx :: gameaudio.audio_manager_play_sfx
audio_manager_toggle :: gameaudio.audio_manager_toggle
audio_set_master_volume :: gameaudio.audio_set_master_volume

// ─── Render helpers ───────────────────────────────────────────────────────────
spawn_hit_particles :: renderer.spawn_hit_particles
spawn_mine_particles :: renderer.spawn_mine_particles
spawn_pickup_particles :: renderer.spawn_pickup_particles
spawn_death_particles :: renderer.spawn_death_particles

// ─── IO helpers ───────────────────────────────────────────────────────────────
save_manager_load_game :: gameio.save_manager_load_game
save_manager_save_game :: gameio.save_manager_save_game
save_manager_save_exists :: gameio.save_manager_save_exists
logger_debugf :: gameio.logger_debugf

// ─── Gameplay helpers ─────────────────────────────────────────────────────────
start_conversation :: gp.start_conversation
advance_dialogue :: gp.advance_dialogue
confirm_dialogue_choice :: gp.confirm_dialogue_choice
close_dialogue :: gp.close_dialogue
descend :: gp.descend
descend_allowed :: gp.descend_allowed
add_descent_locked_message :: gp.add_descent_locked_message
trigger_enemy_rounds :: gp.trigger_enemy_rounds
handle_player_moved :: gp.handle_player_moved
handle_player_descended :: gp.handle_player_descended
handle_player_ascended :: gp.handle_player_ascended
announce_item_under_player :: gp.announce_item_under_player
start_mining_mode :: gp.start_mining_mode
mine_wall :: gp.mine_wall
pickup_item :: gp.pickup_item
use_item :: gp.use_item
drop_item :: gp.drop_item
equip_item :: gp.equip_item
try_craft :: gp.try_craft
save_run_score :: gp.save_run_score
compute_fov :: gp.compute_fov
item_make :: gp.item_make
apply_item_effect :: gp.apply_item_effect
generate_map :: gp.generate_map
restart_game :: gp.restart_game
