package gameio

import gcore "../core"
import eng "../engine"

// ─── Save Constants ───────────────────────────────────────────────────────────

SAVE_FILE :: gcore.SAVE_FILE
// v14 is the only supported on-disk format. Legacy v2–v13 read support was
// intentionally dropped (pre-release; no shipped save contract to honor).
// v12 dropped the never-populated per-floor Light_Source array from the layout.
// v13 replaced per-cell Save_Ore_Vein{ore_type:Save_String, color} with a single
// Ore_Kind byte (item ID + tint are derived from the kind).
// v14 stopped embedding the dense [MAX_DEPTH+1]Save_Floor (+ parallel present-flag
// and per-floor enemy-status) arrays in Save_Data. Present floors are now written
// as a length-prefixed list of Save_Floor_Record (depth tag + floor + enemy
// status), cutting the on-disk blob from ~3.9 MB to roughly one floor's worth.
SAVE_VERSION :: u32(14)
SAVE_MAGIC :: u32(0x44455054) // "DEPT"

MAX_SAVE_ENEMIES :: 64
MAX_SAVE_ITEMS :: 64
MAX_SAVE_ROOMS :: 16
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
	kind: gcore.Ore_Kind,
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
	tiles:       [MAP_WIDTH * MAP_HEIGHT]Tile,
	web_tiles:   [MAP_WIDTH * MAP_HEIGHT]bool,
	ore_veins:   [MAP_WIDTH * MAP_HEIGHT]Save_Ore_Vein,
	player_pos:  Vec2,
	enemy_count: int,
	enemies:     [MAX_SAVE_ENEMIES]Save_Enemy,
	item_count:  int,
	items:       [MAX_SAVE_ITEMS]Save_Item,
	room_count:  int,
	rooms:       [MAX_SAVE_ROOMS]Room,
	palette:     gcore.Floor_Palette,
	event_used:  bool,
	npcs:        [gcore.MAX_NPCS]gcore.NPC,
	npc_count:   int,
	// Engine tile-state layer (visibility/exploration/light). LAST field.
	tile_states: [MAP_WIDTH * MAP_HEIGHT]eng.Tile_State,
}
// MAX_SAVE_FLOORS is the hard upper bound on serialized floor records: one per
// reachable depth (surface .. MAX_DEPTH inclusive). A file claiming more is
// rejected; counts are clamped before any allocation/iteration.
MAX_SAVE_FLOORS :: gcore.MAX_DEPTH + 1

// Save_Floor_Record is one present floor in the length-prefixed floor list. `depth`
// tags where the floor belongs in the runtime visited_floors stack (validated to
// 0..=MAX_DEPTH on load). enemy_status mirrors the per-floor enemy status effects
// that used to live in Save_Data.floor_enemy_status[depth].
Save_Floor_Record :: struct {
	depth:        i32,
	floor:        Save_Floor,
	enemy_status: [MAX_SAVE_ENEMIES]gcore.Status_Turns,
}

// ─── File layout ──────────────────────────────────────────────────────────────

// Save_Header is the on-disk header (12 bytes: magic + version + crc32).
// crc32 covers the Save_Data payload bytes only (not the header itself).
Save_Header :: struct {
	magic:   u32,
	version: u32,
	crc32:   u32,
}

// Current save format (v12). v12 drops the never-populated per-floor Light_Source
// array. (v11 dropped the dead Tile visibility/light fields and instead serializes
// the engine tile-state layer through a dedicated trailing tile_states array.)
// Per-entity status effects live in player_status/enemy_status.
Save_Data :: struct {
	// Fixed-size tile arrays (Tile has no strings — safe)
	tiles:             [MAP_WIDTH * MAP_HEIGHT]Tile,
	web_tiles:         [MAP_WIDTH * MAP_HEIGHT]bool,
	ore_veins:         [MAP_WIDTH * MAP_HEIGHT]Save_Ore_Vein,
	// Player (no strings — safe)
	player:            Player,
	// Dynamic arrays flattened to fixed-size + count
	enemy_count:       int,
	enemies:           [MAX_SAVE_ENEMIES]Save_Enemy,
	item_count:        int,
	items:             [MAX_SAVE_ITEMS]Save_Item,
	room_count:        int,
	rooms:             [MAX_SAVE_ROOMS]Room,
	// Inventory and equipment
	inventory:         [MAX_INVENTORY]Save_Inventory_Slot,
	equipped_weapon:   Save_Equipment,
	equipped_armor:    Save_Equipment,
	equipped_helmet:   Save_Equipment,
	// Scalar game state
	depth:             int,
	turn_count:        int,
	kills:             int,
	seed:              u64,
	light_boost_bonus: int,
	light_boost_turns: int,
	water_slow_active: bool,
	// v4 additions
	items_found:       int,
	// v6 additions
	quest:             Quest_State,
	// v7 additions
	floor_entry_pos:   Vec2,
	// v14: the dense [MAX_DEPTH+1] visited-floor arrays (present flags + floors)
	// no longer live here. Present floors are serialized as a length-prefixed list
	// of Save_Floor_Record appended after Save_Data on disk.
	// v8 additions — dialogue persistent state
	seen_conv_count:   int,
	seen_convs:        [gcore.MAX_SEEN_CONVS][gcore.MAX_CONV_ID_LEN]u8,
	seen_lens:         [gcore.MAX_SEEN_CONVS]int,
	dlg_flag_count:    int,
	dlg_flags:         [gcore.MAX_DLG_FLAGS][gcore.MAX_FLAG_LEN]u8,
	dlg_flag_lens:     [gcore.MAX_DLG_FLAGS]int,
	// v9 additions — per-entity status effects. v14 moved the per-floor enemy status
	// (previously floor_enemy_status[MAX_DEPTH+1]) into each Save_Floor_Record.
	player_status:     gcore.Status_Turns,
	enemy_status:      [MAX_SAVE_ENEMIES]gcore.Status_Turns,
	// v11 additions — engine tile-state layer (visibility/exploration/light).
	tile_states:       [MAP_WIDTH * MAP_HEIGHT]eng.Tile_State,
	// D4 additions — first-encounter onboarding hints (game-global). Appended as
	// the final field of the v11 layout; survives descent, cleared on reinit. LAST.
	tutorial_flags:    gcore.Tutorial_Flags,
}
// ─── String conversion helpers ────────────────────────────────────────────────
