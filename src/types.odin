package main

import rl "vendor:raylib"

// ─── Constants ────────────────────────────────────────────────────────────────

TILE_SIZE      :: 16
SCREEN_WIDTH   :: 1280
SCREEN_HEIGHT  :: 800
MAP_WIDTH      :: 80
MAP_HEIGHT     :: 50

// ─── Vector ───────────────────────────────────────────────────────────────────

Vec2 :: struct {
	x, y: int,
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
}

Game :: struct {
	tiles:         [MAP_WIDTH * MAP_HEIGHT]Tile,
	map_width:     int,
	map_height:    int,
	player:        Player,
	enemies:       [dynamic]Enemy,
	light_sources: [dynamic]Light_Source,
	depth:         int,
	turn_count:    int,
	seed:          u64,
	state:         Game_State,
}
