package gameio

import gcore "../core"
import eng "../engine"

// ─── Save Constants ───────────────────────────────────────────────────────────

SAVE_FILE :: gcore.SAVE_FILE
SAVE_VERSION :: u32(9)
SAVE_VERSION_V8 :: u32(8)
SAVE_VERSION_V7 :: u32(7)
SAVE_VERSION_V6 :: u32(6)
SAVE_VERSION_V4 :: u32(4)
SAVE_VERSION_V3 :: u32(3)
SAVE_VERSION_V2 :: u32(2)
SAVE_MAGIC :: u32(0x44455054) // "DEPT"

MAX_SAVE_ENEMIES :: 64
MAX_SAVE_ITEMS :: 64
MAX_SAVE_ROOMS :: 16
MAX_SAVE_LIGHTS :: 16
MAX_NAME_LEN :: 32

// ─── Save-safe string (fixed buffer, no heap pointer) ─────────────────────────

Save_String :: struct {
	data: [MAX_NAME_LEN]u8,
	len:  int,
}

// ─── Save-safe versions of types that contain strings ─────────────────────────

Save_Enemy :: struct {
	pos:              Vec2,
	hp:               int,
	max_hp:           int,
	attack:           int,
	enemy_type:       Save_String,
	name:             Save_String,
	glyph:            rune,
	color:            eng.Engine_Color,
	alive:            bool,
	ability_type:     Save_String,
	ability_cooldown: int,
	ability_max_cd:   int,
	ability_range:    int,
	is_boss:          bool,
	detection_radius: int,
	aware:            bool,
	memory_turns:     int,
	aware_turns_left: int,
}

Save_Item :: struct {
	pos:            Vec2,
	item_type:      Save_String,
	name:           Save_String,
	glyph:          rune,
	color:          eng.Engine_Color,
	picked_up:      bool,
	quantity:       int,
	equipment_slot: Save_String,
	stat_bonus:     int,
	durability:     int,
	max_durability: int,
}

Save_Ore_Vein :: struct {
	ore_type: Save_String,
	color:    eng.Engine_Color,
}

Save_Inventory_Slot :: struct {
	occupied: bool,
	item:     Save_Item,
}

Save_Equipment :: struct {
	occupied: bool,
	item:     Save_Item,
}


Save_Floor :: struct {
	tiles:              [MAP_WIDTH * MAP_HEIGHT]Tile,
	web_tiles:          [MAP_WIDTH * MAP_HEIGHT]bool,
	ore_veins:          [MAP_WIDTH * MAP_HEIGHT]Save_Ore_Vein,
	player_pos:         Vec2,
	enemy_count:        int,
	enemies:            [MAX_SAVE_ENEMIES]Save_Enemy,
	item_count:         int,
	items:              [MAX_SAVE_ITEMS]Save_Item,
	room_count:         int,
	rooms:              [MAX_SAVE_ROOMS]Room,
	light_source_count: int,
	light_sources:      [MAX_SAVE_LIGHTS]Light_Source,
	palette:            gcore.Floor_Palette,
	event_used:         bool,
	npcs:               [gcore.MAX_NPCS]gcore.NPC,
	npc_count:          int,
}
// ─── File layout ──────────────────────────────────────────────────────────────

Save_Header :: struct {
	magic:   u32,
	version: u32,
}

// Current save format (v9) — v8 is a strict prefix of this struct.
// The legacy scalar status fields (poison_turns/burning_turns/frozen_turns/
// web_stuck_turns) are retained mid-struct for layout compatibility and
// mirrored into player_status on write; restore reads only player_status.
Save_Data :: struct {
	// Fixed-size tile arrays (Tile has no strings — safe)
	tiles:                 [MAP_WIDTH * MAP_HEIGHT]Tile,
	web_tiles:             [MAP_WIDTH * MAP_HEIGHT]bool,
	ore_veins:             [MAP_WIDTH * MAP_HEIGHT]Save_Ore_Vein,
	// Player (no strings — safe)
	player:                Player,
	// Dynamic arrays flattened to fixed-size + count
	enemy_count:           int,
	enemies:               [MAX_SAVE_ENEMIES]Save_Enemy,
	item_count:            int,
	items:                 [MAX_SAVE_ITEMS]Save_Item,
	room_count:            int,
	rooms:                 [MAX_SAVE_ROOMS]Room,
	// Inventory and equipment
	inventory:             [MAX_INVENTORY]Save_Inventory_Slot,
	equipped_weapon:       Save_Equipment,
	equipped_armor:        Save_Equipment,
	equipped_helmet:       Save_Equipment,
	// Scalar game state
	depth:                 int,
	turn_count:            int,
	kills:                 int,
	seed:                  u64,
	light_boost_bonus:     int,
	light_boost_turns:     int,
	web_stuck_turns:       int,
	water_slow_active:     bool,
	// v4 additions
	items_found:           int,
	// v5 additions
	poison_turns:          int,
	burning_turns:         int,
	frozen_turns:          int,
	// v6 additions
	quest:                 Quest_State,
	// v7 additions
	floor_entry_pos:       Vec2,
	visited_floor_present: [gcore.MAX_DEPTH + 1]bool,
	visited_floors:        [gcore.MAX_DEPTH + 1]Save_Floor,
	// v8 additions — dialogue persistent state
	seen_conv_count:       int,
	seen_convs:            [gcore.MAX_SEEN_CONVS][gcore.MAX_CONV_ID_LEN]u8,
	seen_lens:             [gcore.MAX_SEEN_CONVS]int,
	dlg_flag_count:        int,
	dlg_flags:             [gcore.MAX_DLG_FLAGS][gcore.MAX_FLAG_LEN]u8,
	dlg_flag_lens:         [gcore.MAX_DLG_FLAGS]int,
	// v9 additions — per-entity status effects
	player_status:         gcore.Status_Turns,
	enemy_status:          [MAX_SAVE_ENEMIES]gcore.Status_Turns,
	floor_enemy_status:    [gcore.MAX_DEPTH + 1][MAX_SAVE_ENEMIES]gcore.Status_Turns,
}

// v8 save format — byte-for-byte identical to Save_Data minus per-entity status.
Save_Data_V8 :: struct {
	tiles:                 [MAP_WIDTH * MAP_HEIGHT]Tile,
	web_tiles:             [MAP_WIDTH * MAP_HEIGHT]bool,
	ore_veins:             [MAP_WIDTH * MAP_HEIGHT]Save_Ore_Vein,
	player:                Player,
	enemy_count:           int,
	enemies:               [MAX_SAVE_ENEMIES]Save_Enemy,
	item_count:            int,
	items:                 [MAX_SAVE_ITEMS]Save_Item,
	room_count:            int,
	rooms:                 [MAX_SAVE_ROOMS]Room,
	inventory:             [MAX_INVENTORY]Save_Inventory_Slot,
	equipped_weapon:       Save_Equipment,
	equipped_armor:        Save_Equipment,
	equipped_helmet:       Save_Equipment,
	depth:                 int,
	turn_count:            int,
	kills:                 int,
	seed:                  u64,
	light_boost_bonus:     int,
	light_boost_turns:     int,
	web_stuck_turns:       int,
	water_slow_active:     bool,
	items_found:           int,
	poison_turns:          int,
	burning_turns:         int,
	frozen_turns:          int,
	quest:                 Quest_State,
	floor_entry_pos:       Vec2,
	visited_floor_present: [gcore.MAX_DEPTH + 1]bool,
	visited_floors:        [gcore.MAX_DEPTH + 1]Save_Floor,
	seen_conv_count:       int,
	seen_convs:            [gcore.MAX_SEEN_CONVS][gcore.MAX_CONV_ID_LEN]u8,
	seen_lens:             [gcore.MAX_SEEN_CONVS]int,
	dlg_flag_count:        int,
	dlg_flags:             [gcore.MAX_DLG_FLAGS][gcore.MAX_FLAG_LEN]u8,
	dlg_flag_lens:         [gcore.MAX_DLG_FLAGS]int,
}

// v7 save format — byte-for-byte identical to Save_Data minus dialogue state.
Save_Data_V7 :: struct {
	tiles:                 [MAP_WIDTH * MAP_HEIGHT]Tile,
	web_tiles:             [MAP_WIDTH * MAP_HEIGHT]bool,
	ore_veins:             [MAP_WIDTH * MAP_HEIGHT]Save_Ore_Vein,
	player:                Player,
	enemy_count:           int,
	enemies:               [MAX_SAVE_ENEMIES]Save_Enemy,
	item_count:            int,
	items:                 [MAX_SAVE_ITEMS]Save_Item,
	room_count:            int,
	rooms:                 [MAX_SAVE_ROOMS]Room,
	inventory:             [MAX_INVENTORY]Save_Inventory_Slot,
	equipped_weapon:       Save_Equipment,
	equipped_armor:        Save_Equipment,
	equipped_helmet:       Save_Equipment,
	depth:                 int,
	turn_count:            int,
	kills:                 int,
	seed:                  u64,
	light_boost_bonus:     int,
	light_boost_turns:     int,
	web_stuck_turns:       int,
	water_slow_active:     bool,
	items_found:           int,
	poison_turns:          int,
	burning_turns:         int,
	frozen_turns:          int,
	quest:                 Quest_State,
	floor_entry_pos:       Vec2,
	visited_floor_present: [gcore.MAX_DEPTH + 1]bool,
	visited_floors:        [gcore.MAX_DEPTH + 1]Save_Floor,
}

// v6 save format — byte-for-byte identical to Save_Data minus floor stack.
Save_Data_V6 :: struct {
	tiles:             [MAP_WIDTH * MAP_HEIGHT]Tile,
	web_tiles:         [MAP_WIDTH * MAP_HEIGHT]bool,
	ore_veins:         [MAP_WIDTH * MAP_HEIGHT]Save_Ore_Vein,
	player:            Player,
	enemy_count:       int,
	enemies:           [MAX_SAVE_ENEMIES]Save_Enemy,
	item_count:        int,
	items:             [MAX_SAVE_ITEMS]Save_Item,
	room_count:        int,
	rooms:             [MAX_SAVE_ROOMS]Room,
	inventory:         [MAX_INVENTORY]Save_Inventory_Slot,
	equipped_weapon:   Save_Equipment,
	equipped_armor:    Save_Equipment,
	equipped_helmet:   Save_Equipment,
	depth:             int,
	turn_count:        int,
	kills:             int,
	seed:              u64,
	light_boost_bonus: int,
	light_boost_turns: int,
	web_stuck_turns:   int,
	water_slow_active: bool,
	items_found:       int,
	poison_turns:      int,
	burning_turns:     int,
	frozen_turns:      int,
	quest:             Quest_State,
}

// v4 save format — byte-for-byte identical to Save_Data minus status timers.
Save_Data_V4 :: struct {
	tiles:             [MAP_WIDTH * MAP_HEIGHT]Tile,
	web_tiles:         [MAP_WIDTH * MAP_HEIGHT]bool,
	ore_veins:         [MAP_WIDTH * MAP_HEIGHT]Save_Ore_Vein,
	player:            Player,
	enemy_count:       int,
	enemies:           [MAX_SAVE_ENEMIES]Save_Enemy,
	item_count:        int,
	items:             [MAX_SAVE_ITEMS]Save_Item,
	room_count:        int,
	rooms:             [MAX_SAVE_ROOMS]Room,
	inventory:         [MAX_INVENTORY]Save_Inventory_Slot,
	equipped_weapon:   Save_Equipment,
	equipped_armor:    Save_Equipment,
	equipped_helmet:   Save_Equipment,
	depth:             int,
	turn_count:        int,
	kills:             int,
	seed:              u64,
	light_boost_bonus: int,
	light_boost_turns: int,
	skip_next_turn:    bool,
	water_slow_active: bool,
	items_found:       int,
}

// v3 save format — byte-for-byte identical to Save_Data minus items_found.
Save_Data_V3 :: struct {
	tiles:             [MAP_WIDTH * MAP_HEIGHT]Tile,
	web_tiles:         [MAP_WIDTH * MAP_HEIGHT]bool,
	ore_veins:         [MAP_WIDTH * MAP_HEIGHT]Save_Ore_Vein,
	player:            Player,
	enemy_count:       int,
	enemies:           [MAX_SAVE_ENEMIES]Save_Enemy,
	item_count:        int,
	items:             [MAX_SAVE_ITEMS]Save_Item,
	room_count:        int,
	rooms:             [MAX_SAVE_ROOMS]Room,
	inventory:         [MAX_INVENTORY]Save_Inventory_Slot,
	equipped_weapon:   Save_Equipment,
	equipped_armor:    Save_Equipment,
	equipped_helmet:   Save_Equipment,
	depth:             int,
	turn_count:        int,
	kills:             int,
	seed:              u64,
	light_boost_bonus: int,
	light_boost_turns: int,
	skip_next_turn:    bool,
	water_slow_active: bool,
}

// v2 save files used the same prefix as v3, followed by two legacy pickaxe
// durability fields that are now stored on the equipped pickaxe item instead.
Save_Data_V2 :: struct {
	// Fixed-size tile arrays (Tile has no strings — safe)
	tiles:              [MAP_WIDTH * MAP_HEIGHT]Tile,
	web_tiles:          [MAP_WIDTH * MAP_HEIGHT]bool,
	ore_veins:          [MAP_WIDTH * MAP_HEIGHT]Save_Ore_Vein,

	// Player (no strings — safe)
	player:             Player,

	// Dynamic arrays flattened to fixed-size + count
	enemy_count:        int,
	enemies:            [MAX_SAVE_ENEMIES]Save_Enemy,
	item_count:         int,
	items:              [MAX_SAVE_ITEMS]Save_Item,
	room_count:         int,
	rooms:              [MAX_SAVE_ROOMS]Room,

	// Inventory and equipment
	inventory:          [MAX_INVENTORY]Save_Inventory_Slot,
	equipped_weapon:    Save_Equipment,
	equipped_armor:     Save_Equipment,
	equipped_helmet:    Save_Equipment,

	// Scalar game state
	depth:              int,
	turn_count:         int,
	kills:              int,
	seed:               u64,
	light_boost_bonus:  int,
	light_boost_turns:  int,
	skip_next_turn:     bool,
	water_slow_active:  bool,
	pickaxe_durability: int, // ignored during v2 -> v3 migration
	pickaxe_max_dur:    int, // ignored during v2 -> v3 migration
}

// ─── String conversion helpers ────────────────────────────────────────────────
