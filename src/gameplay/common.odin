package gameplay

import aipkg "../ai"
import gameaudio "../audio"
import gcore "../core"
import eng "../engine"
import genpkg "../gen"
import gameio "../io"
import renderer "../render"
import gameui "../ui"

// ─── Core types ───────────────────────────────────────────────────────────────
Game :: gcore.Game
Player :: gcore.Player
Enemy :: gcore.Enemy
Item :: gcore.Item
Equipment :: gcore.Equipment
Vec2 :: gcore.Vec2
Tile :: gcore.Tile
Tile_Type :: gcore.Tile_Type
Room :: gcore.Room
Light_Source :: gcore.Light_Source
Ore_Vein :: gcore.Ore_Vein
Saved_Floor :: gcore.Saved_Floor
Content_Manager :: gcore.Content_Manager
Message_Manager :: eng.Message_Manager
Engine :: eng.Engine
UI_Manager :: gameui.UI_Manager
Input_Manager :: eng.Action_Input_Manager
Score_Manager :: renderer.Score_Manager
Score_Entry :: renderer.Score_Entry
Score_Table :: renderer.Score_Table
Audio_Manager :: gameaudio.Audio_Manager
Sound_Type :: gameaudio.Sound_Type
Particle_Manager :: eng.Particle_Manager
Item_Def :: gcore.Item_Def
Status_Kind :: gcore.Status_Kind
Status_Turns :: gcore.Status_Turns
status_apply :: gcore.status_apply
status_active :: gcore.status_active

// ─── Core constants ───────────────────────────────────────────────────────────
MAP_WIDTH :: gcore.MAP_WIDTH
MAP_HEIGHT :: gcore.MAP_HEIGHT
MAX_INVENTORY :: gcore.MAX_INVENTORY
MAX_DEPTH :: gcore.MAX_DEPTH
SURFACE_DEPTH :: gcore.SURFACE_DEPTH
SURFACE_LIGHT_RADIUS :: gcore.SURFACE_LIGHT_RADIUS
BASE_ACTION_COST :: gcore.BASE_ACTION_COST
BASE_MOVE_COST :: gcore.BASE_MOVE_COST
BASE_AP_PER_ROUND :: gcore.BASE_AP_PER_ROUND
TILE_SIZE :: gcore.TILE_SIZE
EQUIPMENT_SLOT_WEAPON :: gcore.EQUIPMENT_SLOT_WEAPON
EQUIPMENT_SLOT_ARMOR :: gcore.EQUIPMENT_SLOT_ARMOR
EQUIPMENT_SLOT_HELMET :: gcore.EQUIPMENT_SLOT_HELMET
ITEM_ID_RUSTY_PICKAXE :: gcore.ITEM_ID_RUSTY_PICKAXE
ITEM_ID_TORCH :: gcore.ITEM_ID_TORCH
ITEM_ID_BANDAGE :: gcore.ITEM_ID_BANDAGE
ITEM_ID_LEATHER_VEST :: gcore.ITEM_ID_LEATHER_VEST
ITEM_ID_VAULT_KEY :: gcore.ITEM_ID_VAULT_KEY
ITEM_ID_ANCIENT_TREASURE :: gcore.ITEM_ID_ANCIENT_TREASURE
ITEM_EFFECT_HEAL :: gcore.ITEM_EFFECT_HEAL
ITEM_EFFECT_LIGHT_BOOST :: gcore.ITEM_EFFECT_LIGHT_BOOST
ITEM_EFFECT_TIMED_LIGHT_BOOST :: gcore.ITEM_EFFECT_TIMED_LIGHT_BOOST
ITEM_EFFECT_EQUIP :: gcore.ITEM_EFFECT_EQUIP
ITEM_EFFECT_MATERIAL :: gcore.ITEM_EFFECT_MATERIAL
ITEM_EFFECT_CURE_POISON :: gcore.ITEM_EFFECT_CURE_POISON

// ─── Gameplay tuning ──────────────────────────────────────────────────────────
DURABILITY_WARN_THRESHOLD :: gcore.DURABILITY_WARN_THRESHOLD
GAS_VENT_DAMAGE :: gcore.GAS_VENT_DAMAGE
GAS_VENT_POISON_TURNS :: gcore.GAS_VENT_POISON_TURNS
FOUNTAIN_HEAL :: gcore.FOUNTAIN_HEAL
FIRE_VENT_DAMAGE :: gcore.FIRE_VENT_DAMAGE
FIRE_VENT_BURNING_TURNS :: gcore.FIRE_VENT_BURNING_TURNS
MIN_LIGHT_RADIUS_DEFAULT :: gcore.MIN_LIGHT_RADIUS_DEFAULT
MIN_LIGHT_DEPTH :: gcore.MIN_LIGHT_DEPTH
MIN_LIGHT_RADIUS_DEEP :: gcore.MIN_LIGHT_RADIUS_DEEP
WEB_STUCK_TURNS :: gcore.WEB_STUCK_TURNS

// ─── Core helpers ─────────────────────────────────────────────────────────────
pos_to_idx :: gcore.pos_to_idx
tile_at :: gcore.tile_at
tile_state_at_idx :: gcore.tile_state_at_idx
tile_state_set_idx :: gcore.tile_state_set_idx
tile_state_manager_import :: gcore.tile_state_manager_import
tile_state_manager_export :: gcore.tile_state_manager_export
tile_visible_at :: gcore.tile_visible_at
is_walkable :: gcore.is_walkable
web_tile_at_idx :: gcore.web_tile_at_idx
web_tile_set_idx :: gcore.web_tile_set_idx
web_tiles_clear :: gcore.web_tiles_clear
enemy_at :: gcore.enemy_at
item_at :: gcore.item_at
item_display_name :: gcore.item_display_name
enemy_display_name :: gcore.enemy_display_name
item_make_from_def :: gcore.item_make_from_def
game_camera_update :: gcore.game_camera_update
game_equipment_slot :: gcore.game_equipment_slot
effective_attack :: gcore.effective_attack
apply_kill_milestone_buff :: gcore.apply_kill_milestone_buff
KILLS_PER_MILESTONE :: gcore.KILLS_PER_MILESTONE
SHRINE_BUFF_MAX_HP :: gcore.SHRINE_BUFF_MAX_HP
SHRINE_BUFF_ATTACK :: gcore.SHRINE_BUFF_ATTACK
SHRINE_BUFF_LIGHT :: gcore.SHRINE_BUFF_LIGHT
effective_defense :: gcore.effective_defense
effective_attack_cost :: gcore.effective_attack_cost
effective_light_bonus :: gcore.effective_light_bonus
count_material :: gcore.count_material
inventory_slot_in_bounds :: gcore.inventory_slot_in_bounds
inventory_first_empty_slot :: gcore.inventory_first_empty_slot
inventory_put_slot :: gcore.inventory_put_slot
inventory_decrement_slot :: gcore.inventory_decrement_slot
inventory_count_item_type :: gcore.inventory_count_item_type
inventory_consume_item_type :: gcore.inventory_consume_item_type
remove_item_from_inventory :: gcore.remove_item_from_inventory
item_stack_limit :: gcore.item_stack_limit
item_is_stackable :: gcore.item_is_stackable
content_manager_item_def :: gcore.content_manager_item_def
content_manager_player_def :: gcore.content_manager_player_def
palette_for_depth :: gcore.palette_for_depth

// ─── Service accessors ────────────────────────────────────────────────────────
game_engine_content_manager :: renderer.game_engine_content_manager
game_engine_message_manager :: renderer.game_engine_message_manager
game_engine_camera_manager :: renderer.game_engine_camera_manager
game_engine_turn_manager :: renderer.game_engine_turn_manager
game_engine_vfx_manager :: renderer.game_engine_vfx_manager
game_engine_particle_manager :: renderer.game_engine_particle_manager
game_engine_ui_manager :: renderer.game_engine_ui_manager
game_engine_audio_manager :: proc(engine: ^Engine) -> ^Audio_Manager {
	return eng.engine_audio_manager(engine)
}
game_camera_x :: renderer.game_camera_x
game_camera_y :: renderer.game_camera_y

// ─── UI helpers ───────────────────────────────────────────────────────────────
add_message :: gameui.add_message
clear_messages :: gameui.clear_messages
ui_manager_state :: gameui.ui_manager_state
ui_manager_reset_for_new_game :: gameui.ui_manager_reset_for_new_game

// ─── Audio helpers ────────────────────────────────────────────────────────────
play_sfx :: gameaudio.play_sfx
audio_manager_play_sfx :: gameaudio.audio_manager_play_sfx
audio_manager_set_master_volume :: gameaudio.audio_manager_set_master_volume
music_set_tier_by_depth :: gameaudio.music_set_tier_by_depth

// ─── Render helpers ───────────────────────────────────────────────────────────
spawn_hit_particles :: renderer.spawn_hit_particles
spawn_mine_particles :: renderer.spawn_mine_particles
spawn_pickup_particles :: renderer.spawn_pickup_particles
spawn_death_particles :: renderer.spawn_death_particles
score_manager_load :: renderer.score_manager_load
score_manager_save :: renderer.score_manager_save
score_table_destroy :: renderer.score_table_destroy
insert_score :: renderer.insert_score
compute_run_score :: renderer.compute_run_score

// ─── IO helpers ───────────────────────────────────────────────────────────────
logger_debugf :: gameio.logger_debugf
logger_warnf :: gameio.logger_warnf
Game_Log_Channel :: gameio.Game_Log_Channel
rand_room_interior :: gcore.rand_room_interior
saved_floor_destroy :: gcore.saved_floor_destroy
clear_visited_floors :: gcore.clear_visited_floors

// ─── Gen package ──────────────────────────────────────────────────────────────
generate_rooms :: genpkg.generate_rooms
generate_mixed :: genpkg.generate_mixed
generate_cave :: genpkg.generate_cave
mapgen_bounds_for_depth :: genpkg.mapgen_bounds_for_depth
mapgen_bounds_width :: genpkg.mapgen_bounds_width
mapgen_bounds_height :: genpkg.mapgen_bounds_height
mapgen_bounds_contains :: genpkg.mapgen_bounds_contains
spawn_hazards :: genpkg.spawn_hazards
spawn_ore_veins :: genpkg.spawn_ore_veins
spawn_anvil :: genpkg.spawn_anvil
spawn_boss :: genpkg.spawn_boss
spawn_fountain :: genpkg.spawn_fountain
spawn_monster_den :: genpkg.spawn_monster_den
spawn_treasure_vault :: genpkg.spawn_treasure_vault
spawn_floor_event :: genpkg.spawn_floor_event
generate_town :: genpkg.generate_town
place_town_npcs :: gcore.place_town_npcs
dialogue_current_line :: gcore.dialogue_current_line
dialogue_current_node :: gcore.dialogue_current_node
dialogue_has_flag :: gcore.dialogue_has_flag
dialogue_set_flag :: gcore.dialogue_set_flag
dialogue_clear_flag :: gcore.dialogue_clear_flag
dialogue_has_seen :: gcore.dialogue_has_seen
dialogue_mark_seen :: gcore.dialogue_mark_seen
dialogue_check_requires :: gcore.dialogue_check_requires
dialogue_select_conv :: gcore.dialogue_select_conv
find_farthest_floor :: genpkg.find_farthest_floor

// ─── AI package ───────────────────────────────────────────────────────────────
player_die :: aipkg.player_die
process_enemy_turns :: aipkg.process_enemy_turns
process_enemy_abilities :: aipkg.process_enemy_abilities
remove_dead_enemies :: aipkg.remove_dead_enemies
spawn_enemies :: aipkg.spawn_enemies
