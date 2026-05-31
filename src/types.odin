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

Enemy_Type :: enum {
	Rat,
	Miner_Husk,
	Cave_Crawler,
	Deep_Watcher,
}

Enemy :: struct {
	pos:        Vec2,
	hp:         int,
	max_hp:     int,
	attack:     int,
	enemy_type: Enemy_Type,
	glyph:      rune,
	color:      rl.Color,
	alive:      bool,
}

// ─── Items ────────────────────────────────────────────────────────────────────

MAX_INVENTORY :: 9

Item_Type :: enum {
	Health_Potion,
	Torch,
}

Item :: struct {
	pos:       Vec2,
	item_type: Item_Type,
	glyph:     rune,
	color:     rl.Color,
	picked_up: bool,
	quantity:  int,
}

Inventory_Slot :: struct {
	occupied: bool,
	item:     Item,
}

// ─── Lighting (hook for S03) ──────────────────────────────────────────────────

Light_Source :: struct {
	pos:             Vec2,
	radius:          f32,
	remaining_turns: int,
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
}
