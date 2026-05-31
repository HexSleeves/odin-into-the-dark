package main

import rl "vendor:raylib"

// ─── Constants ────────────────────────────────────────────────────────────────

TILE_SIZE :: 16
SCREEN_WIDTH :: 1080
SCREEN_HEIGHT :: 720
MAP_WIDTH :: 80
MAP_HEIGHT :: 50

// ─── UI Layout ────────────────────────────────────────────────────────────────
// Screen is split top-to-bottom: map viewport → HUD → message log.
HUD_REGION_HEIGHT :: 44
MSG_REGION_HEIGHT :: 120
MAP_VIEW_HEIGHT :: SCREEN_HEIGHT - HUD_REGION_HEIGHT - MSG_REGION_HEIGHT

// ─── Message Log ──────────────────────────────────────────────────────────────

MAX_MESSAGES :: 64
MAX_MSG_LEN :: 256

Message :: struct {
	text:     [MAX_MSG_LEN]u8,
	text_len: int,
	color:    rl.Color,
	turn:     int,
}

MessageLog :: struct {
	messages: [MAX_MESSAGES]Message,
	head:     int,
	count:    int,
}

// ─── Vector ───────────────────────────────────────────────────────────────────

Vec2 :: struct {
	x, y: int,
}

// ─── Room ─────────────────────────────────────────────────────────────────────

Room :: struct {
	x1, y1, x2, y2: int, // inclusive top-left, exclusive bottom-right
}

// ─── Tiles ────────────────────────────────────────────────────────────────────

Tile_Type :: enum {
	Wall,
	Floor,
	Rubble,
	Descent,
	Water,
	Gas_Vent,
	Unstable,
	Chasm,
}

Tile :: struct {
	type:        Tile_Type,
	visible:     bool,
	explored:    bool,
	light_level: f32,
}

// ─── Player ───────────────────────────────────────────────────────────────────

Player :: struct {
	pos:          Vec2,
	hp:           int,
	max_hp:       int,
	attack:       int,
	light_radius: int,
	glyph:        rune,
	color:        rl.Color,
}

// ─── Enemies ──────────────────────────────────────────────────────────────────

Enemy :: struct {
	pos:              Vec2,
	hp:               int,
	max_hp:           int,
	attack:           int,
	enemy_type:       string, // data-driven ID (e.g. "rat", "cave_crawler")
	name:             string, // display name from data
	glyph:            rune,
	color:            rl.Color,
	alive:            bool,
	// Special ability fields (data-driven)
	ability_type:     string, // "web", "pull", or "" for none
	ability_cooldown: int,    // current cooldown (decrements each turn)
	ability_max_cd:   int,    // max cooldown for reset
	ability_range:    int,    // range of the ability
}

// ─── Items ────────────────────────────────────────────────────────────────────

MAX_INVENTORY :: 9

Item :: struct {
	pos:       Vec2,
	item_type: string, // data-driven ID (e.g. "health_potion", "torch")
	name:      string, // display name from data
	glyph:     rune,
	color:     rl.Color,
	picked_up:      bool,
	quantity:       int,
	equipment_slot: string, // "", "weapon", "armor", "helmet"
	stat_bonus:     int,    // bonus value when equipped
}

Inventory_Slot :: struct {
	occupied: bool,
	item:     Item,
}

// ─── Equipment ────────────────────────────────────────────────────────────────

Equipment_Slot :: enum {
	None,
	Weapon,
	Armor,
	Helmet,
}

Equipment :: struct {
	occupied: bool,
	item:     Item,
}

// ─── Lighting (hook for S03) ──────────────────────────────────────────────────

Light_Source :: struct {
	pos:             Vec2,
	radius:          f32,
	remaining_turns: int,
}

// ─── Floor Palette (depth-themed tile colors) ────────────────────────────────

Floor_Palette :: struct {
	wall:    rl.Color,
	floor:   rl.Color,
	rubble:  rl.Color,
	descent: rl.Color,
}

// ─── Game State ───────────────────────────────────────────────────────────────

Game_State :: enum {
	Playing,
	Game_Over,
	Viewing_Inventory,
}

DMAP_UNREACHABLE :: 9999

Game :: struct {
	tiles:         [MAP_WIDTH * MAP_HEIGHT]Tile,
	dijkstra_map:  [MAP_WIDTH * MAP_HEIGHT]int,
	map_width:     int,
	map_height:    int,
	player:        Player,
	rooms:         [dynamic]Room,
	enemies:       [dynamic]Enemy,
	items:         [dynamic]Item,
	inventory:     [MAX_INVENTORY]Inventory_Slot,
	light_sources: [dynamic]Light_Source,
	depth:         int,
	turn_count:    int,
	kills:         int,
	seed:          u64,
	state:         Game_State,
	message_log:   MessageLog,
	// Camera offset: pixel position of top-left corner of the viewport in map-space
	camera_x:      int,
	camera_y:      int,
	// Timed light boost (from lantern oil)
	light_boost_bonus: int,
	light_boost_turns: int,
	// Inventory drop mode
	dropping: bool,
	// Web tiles (Cave Crawler ability)
	web_tiles:      [MAP_WIDTH * MAP_HEIGHT]bool,
	skip_next_turn: bool, // player stuck in web
	// Equipment slots
	equipped_weapon: Equipment,
	equipped_armor:  Equipment,
	equipped_helmet: Equipment,
	// Equipment mode in inventory
	equipping: bool,
	// Depth-based floor palette
	palette: Floor_Palette,
	// Minimap toggle
	show_minimap: bool,
	// Hazard state
	water_slow_active: bool, // player in water, costs next turn
	prev_player_pos:   Vec2, // track previous position for unstable collapse
}
