package main

import rl "vendor:raylib"

// ─── Message Log ──────────────────────────────────────────────────────────────

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
	Anvil,
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
	ability_cooldown: int, // current cooldown (decrements each turn)
	ability_max_cd:   int, // max cooldown for reset
	ability_range:    int, // range of the ability
	is_boss:          bool,
}

// ─── Items ────────────────────────────────────────────────────────────────────

Item :: struct {
	pos:            Vec2,
	item_type:      string, // data-driven ID (e.g. "health_potion", "torch")
	name:           string, // display name from data
	glyph:          rune,
	color:          rl.Color,
	picked_up:      bool,
	quantity:       int,
	equipment_slot: string, // "", "weapon", "armor", "helmet"
	stat_bonus:     int, // bonus value when equipped
	durability:     int, // current durability (0 = broken, -1 = no durability)
	max_durability: int, // max durability (0 = item has no durability)
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

// ─── Mining ───────────────────────────────────────────────────────────────────

Ore_Vein :: struct {
	ore_type: string, // "iron_ore", "copper_ore", "crystal_shard", "gold_nugget", or ""
	color:    rl.Color, // visual tint for the wall
}

// ─── UI State ─────────────────────────────────────────────────────────────────

UI_State :: struct {
	show_minimap:  bool,
	dropping:      bool, // inventory drop mode
	equipping:     bool, // inventory equip mode
	inspect_slot:  int, // highlighted slot in inventory (-1 = none)
	mining_mode:   bool, // true when player pressed X and awaits direction
	use_sprites:   bool, // true = tileset sprites, false = ASCII mode
	title_choice:  int, // selected title menu option
	return_to_title: bool, // modal overlays should return to title instead of gameplay
}

// ─── Game State ───────────────────────────────────────────────────────────────

Game_State :: enum {
	Title_Screen,
	Playing,
	Game_Over,
	Victory,
	Viewing_Inventory,
	Viewing_Crafting,
	Viewing_Help,
	Viewing_Scores,
}

Game :: struct {
	tiles:             [MAP_WIDTH * MAP_HEIGHT]Tile,
	dijkstra_map:      [MAP_WIDTH * MAP_HEIGHT]int,
	map_width:         int,
	map_height:        int,
	player:            Player,
	rooms:             [dynamic]Room,
	enemies:           [dynamic]Enemy,
	items:             [dynamic]Item,
	inventory:         [MAX_INVENTORY]Inventory_Slot,
	light_sources:     [dynamic]Light_Source,
	depth:             int,
	kills:             int,
	seed:              u64,
	state:             Game_State,
	// Timed light boost (from lantern oil)
	light_boost_bonus: int,
	light_boost_turns: int,
	// Web tiles (Cave Crawler ability)
	web_tiles:         [MAP_WIDTH * MAP_HEIGHT]bool,
	skip_next_turn:    bool, // player stuck in web
	// Equipment slots
	equipped_weapon:   Equipment,
	equipped_armor:    Equipment,
	equipped_helmet:   Equipment,
	// Depth-based floor palette
	palette:           Floor_Palette,
	// Hazard state
	water_slow_active: bool, // player in water, costs next turn
	prev_player_pos:   Vec2, // track previous position for unstable collapse
	// Mining system
	ore_veins:         [MAP_WIDTH * MAP_HEIGHT]Ore_Vein,
	// Death tracking
	death_cause:       string,
	score_saved:       bool,
	last_score_rank:   int,
}
