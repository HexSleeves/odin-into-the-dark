package core

import eng "../engine"


// ─── Message Log ──────────────────────────────────────────────────────────────

Message :: eng.Message
MessageLog :: eng.Message_Log

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
	Ascent,
	Water,
	Gas_Vent,
	Unstable,
	Chasm,
	Anvil,
	Fountain,
	Fire_Vent,
	Locked_Door,
	Shrine,
	Chest,
	Merchant,
}

// Visibility/exploration/light live in the engine Tile_State_Manager (the live
// source of truth) and are serialized via a dedicated [N]eng.Tile_State array on
// the save structs — NOT mirrored back onto Tile. Tile carries only terrain type.
Tile :: struct {
	type: Tile_Type,
}

// ─── Player ───────────────────────────────────────────────────────────────────

Player :: struct {
	pos:          Vec2,
	hp:           int,
	max_hp:       int,
	attack:       int,
	light_radius: int,
	glyph:        rune,
	color:        eng.Engine_Color,
	// Energy system (Qud-style AP scheduling)
	energy:       int, // current action points (may be negative = debt)
	quickness:    int, // AP generated per round = quickness * 10. Default 100.
	move_speed:   int, // movement cost modifier (100 = normal). Default 100.
}

// ─── Status Effects ───────────────────────────────────────────────────────────

Status_Kind :: enum {
	Poison,
	Burning,
	Frozen,
	Webbed,
}

// Turns remaining per status. 0 = inactive.
Status_Turns :: [Status_Kind]int

status_apply :: proc(s: ^Status_Turns, kind: Status_Kind, turns: int) {
	s[kind] = max(s[kind], turns)
}

status_active :: proc(s: ^Status_Turns, kind: Status_Kind) -> bool {
	return s[kind] > 0
}

// ─── Onboarding hints ─────────────────────────────────────────────────────────

// One-time first-encounter tutorial hints. Each variant fires its message at
// most once per run; the set is persisted in the save and survives descent, but
// is cleared on game reinit/restart. Append new variants at the END (the bit_set
// is serialized as a trailing u8 in the save format).
Tutorial_Hint :: enum u8 {
	First_Enemy,
	First_Ore,
	First_Torch,
	First_Status,
	First_Shrine,
}

Tutorial_Flags :: bit_set[Tutorial_Hint;u8]

// ─── Enemies ──────────────────────────────────────────────────────────────────

Enemy :: struct {
	pos:              Vec2,
	hp:               int,
	max_hp:           int,
	attack:           int,
	crit_chance:      int,
	enemy_type:       string, // data-driven ID (e.g. "rat", "cave_crawler")
	name:             string, // display name from data
	glyph:            rune,
	color:            eng.Engine_Color,
	alive:            bool,
	// Special ability fields (data-driven)
	ability_type:     string, // "web", "pull", "ranged_shoot", or "" for none
	ability_cooldown: int, // current cooldown (decrements each turn)
	ability_max_cd:   int, // max cooldown for reset
	ability_range:    int, // range of the ability
	ability_damage:   int, // base damage for damage-dealing abilities (0 = use fallback)
	is_boss:          bool,
	behavior:         string, // "lurker" or "" for standard
	// Detection / awareness
	detection_radius: int, // how far this enemy can "see" the player
	aware:            bool, // currently chasing the player
	memory_turns:     int, // max turns to remember player after losing detection
	aware_turns_left: int, // countdown — 0 = forget and wander
	// Energy system (Qud-style AP scheduling)
	energy:           int, // current action points (may be negative = debt)
	quickness:        int, // AP generated per round = quickness * 10. Default 100.
	move_speed:       int, // movement cost modifier (100 = normal). Default 100.
	// Per-entity status effects (poison/burning tick damage, frozen/webbed impair)
	status:           Status_Turns,
}

// ─── Items ────────────────────────────────────────────────────────────────────

Item :: struct {
	pos:            Vec2,
	item_type:      string, // data-driven ID (e.g. "health_potion", "torch")
	name:           string, // display name from data
	description:    string, // flavour/stat description
	glyph:          rune,
	color:          eng.Engine_Color,
	picked_up:      bool,
	quantity:       int,
	equipment_slot: string, // "", "weapon", "armor", "helmet"
	stat_bonus:     int, // bonus value when equipped
	durability:     int, // current durability (0 = broken, -1 = no durability)
	max_durability: int, // max durability (0 = item has no durability)
	action_cost:    int, // AP to attack with this weapon (0 = use BASE_ACTION_COST)
	crit_chance:    int, // weapon crit % added to BASE_CRIT_CHANCE_PCT (0 = no bonus)
}

Inventory_Slot :: struct {
	occupied: bool,
	item:     Item,
}

// ─── Equipment ────────────────────────────────────────────────────────────────

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
	wall:    eng.Engine_Color,
	floor:   eng.Engine_Color,
	rubble:  eng.Engine_Color,
	descent: eng.Engine_Color,
}

// ─── Mining ───────────────────────────────────────────────────────────────────

// Ore variant for a wall cell. None = plain wall (no vein). The content item ID
// and visual tint are derived from the kind (see ore_kind_item_id / ore_kind_color)
// rather than stored per cell, so Ore_Vein is a single byte.
Ore_Kind :: enum u8 {
	None,
	Iron,
	Copper,
	Crystal,
	Gold,
}

Ore_Vein :: struct {
	kind: Ore_Kind,
}

// Content item ID dropped when mining this ore kind. "" for None.
ore_kind_item_id :: proc(kind: Ore_Kind) -> string {
	switch kind {
	case .Iron:
		return "iron_ore"
	case .Copper:
		return "copper_ore"
	case .Crystal:
		return "crystal_shard"
	case .Gold:
		return "gold_nugget"
	case .None:
		return ""
	}
	return ""
}

// Wall tint for this ore kind. None returns transparent (no tint).
ore_kind_color :: proc(kind: Ore_Kind) -> eng.Engine_Color {
	switch kind {
	case .Iron:
		return eng.Engine_Color{200, 120, 50, 255}
	case .Copper:
		return eng.Engine_Color{80, 180, 80, 255}
	case .Crystal:
		return eng.Engine_Color{100, 150, 255, 255}
	case .Gold:
		return eng.Engine_Color{255, 215, 0, 255}
	case .None:
		return eng.Engine_Color{0, 0, 0, 0}
	}
	return eng.Engine_Color{0, 0, 0, 0}
}

// ─── UI State ─────────────────────────────────────────────────────────────────

UI_State :: struct {
	show_minimap:    bool,
	dropping:        bool, // inventory drop mode
	equipping:       bool, // inventory equip mode
	inspect_slot:    int, // highlighted slot in inventory (-1 = none)
	mining_mode:     bool, // true when player pressed X and awaits direction
	use_sprites:     bool, // true = tileset sprites, false = ASCII mode
	title_choice:    int, // selected title menu option
	return_to_title: bool, // modal overlays should return to title instead of gameplay
	cheat_choice:    int, // highlighted cheat menu row; only used in CHEATS builds
	pause_choice:    int, // highlighted pause menu row (Resume / Quit to Title)
	debug_overlay:   bool, // perf/debug overlay visible; only used in DEBUG_OVERLAY builds
}

// ─── Game State ───────────────────────────────────────────────────────────────

Merchant_Offer :: struct {
	item_id:  string, // content ID of item being sold
	cost_id:  string, // material required
	cost_qty: int, // amount of material needed
	sold:     bool, // already purchased
}

MAX_NPCS :: 8

NPC_Role :: enum {
	Old_Miner, // quest-giver
	Shopkeeper,
	Guard,
	Elder,
}

NPC :: struct {
	pos:   Vec2,
	name:  string, // static literal
	glyph: rune,
	color: eng.Engine_Color,
	role:  NPC_Role,
}

Quest_State :: enum {
	Not_Started,
	Active, // miner has given the quest; go fetch the treasure
	Treasure_Found, // player has the treasure
	Complete, // returned/rewarded
}

Saved_Floor :: struct {
	tiles:         [MAP_WIDTH * MAP_HEIGHT]Tile,
	web_tiles:     [MAP_WIDTH * MAP_HEIGHT]bool,
	ore_veins:     [MAP_WIDTH * MAP_HEIGHT]Ore_Vein,
	player_pos:    Vec2,
	rooms:         [dynamic]Room,
	enemies:       [dynamic]Enemy,
	items:         [dynamic]Item,
	light_sources: [dynamic]Light_Source,
	palette:       Floor_Palette,
	event_used:    bool,
	npcs:          [MAX_NPCS]NPC,
	npc_count:     int,
	// Engine tile-state layer (visibility/exploration/light). LAST field.
	tile_states:   [MAP_WIDTH * MAP_HEIGHT]eng.Tile_State,
}

Game_State :: enum {
	Title_Screen,
	Playing,
	Game_Over,
	Victory,
	Viewing_Inventory,
	Viewing_Crafting,
	Viewing_Help,
	Viewing_Scores,
	Viewing_Cheats,
	Viewing_Shrine,
	Viewing_Chest,
	Viewing_Merchant,
	Viewing_Dialogue,
	Pause,
	Viewing_Level_Up,
}

Game :: struct {
	tiles:                  [MAP_WIDTH * MAP_HEIGHT]Tile,
	dijkstra_map:           [MAP_WIDTH * MAP_HEIGHT]i32,
	world:                  eng.World_Manager,
	map_width:              int,
	map_height:             int,
	player:                 Player,
	rooms:                  [dynamic]Room,
	enemies:                [dynamic]Enemy,
	items:                  [dynamic]Item,
	inventory:              [MAX_INVENTORY]Inventory_Slot,
	light_sources:          [dynamic]Light_Source,
	depth:                  int,
	kills:                  int,
	kills_milestone:        int, // count of kill-progression milestones already awarded
	seed:                   u64,
	state:                  Game_State,
	// Timed light boost (from lantern oil)
	light_boost_bonus:      int,
	light_boost_turns:      int,
	light_drain_timer:      int, // counts rounds until next light drain
	// Timed light debuff (from enemy darkness abilities). Negative bonus, independent of boost.
	light_debuff_bonus:     int, // negative value; net effect = light_boost_bonus + light_debuff_bonus
	light_debuff_turns:     int,
	// Web tiles (Cave Crawler ability)
	web_tiles:              eng.Bool_Grid_Manager,
	tile_states:            eng.Tile_State_Manager,
	// Equipment slots
	equipped_weapon:        Equipment,
	equipped_armor:         Equipment,
	equipped_helmet:        Equipment,
	// Depth-based floor palette
	palette:                Floor_Palette,
	// Hazard state
	water_slow_active:      bool, // player in water, costs next turn
	prev_player_pos:        Vec2, // track previous position for unstable collapse
	// Mining system
	ore_veins:              [MAP_WIDTH * MAP_HEIGHT]Ore_Vein,
	// Death tracking
	death_cause:            string,
	death_cause_storage:    [DEATH_CAUSE_MAX_LEN]u8,
	score_saved:            bool,
	last_score_rank:        int,
	render_map_dirty:       bool,
	// Dijkstra flow field is recomputed only when this is set (once per player
	// input); cleared by compute_dijkstra_map. Need not persist in saves.
	dijkstra_dirty:         bool,
	// Enemy occupancy grid (P9): index = pos_to_idx, value = enemy slot + 1
	// (0 = empty). Makes enemy_at O(1). Lazily (re)built by enemy_at whenever
	// enemy_occupancy_built is false, so it can never desync from a linear scan.
	// `built` is invalidated on every spawn/move/death/cleanup. Its zero value
	// (false) means "needs rebuild", so a freshly zero-valued Game behaves
	// exactly like the old linear scan with no setup required. Derived state —
	// need not persist in saves.
	enemy_occupancy:        [MAP_WIDTH * MAP_HEIGHT]i32,
	enemy_occupancy_built:  bool,
	// Player status effects (Poison/Burning/Frozen/Webbed turns remaining)
	player_status:          Status_Turns,
	boss_killed_this_turn:  bool,
	// Run statistics
	items_found:            int,
	minimap_reveal_enemies: bool, // cheat/debug: show enemy dots on explored tiles
	// Floor events
	event_used:             bool, // true if this floor's event has been consumed
	merchant_stock:         [3]Merchant_Offer, // current merchant offers (3 slots)
	shrine_choice:          int, // selected shrine buff index (UI state)
	// Surface town + story
	npcs:                   [MAX_NPCS]NPC,
	npc_count:              int,
	quest:                  Quest_State,
	active_npc:             int, // index into npcs during dialogue (-1 = none)
	active_conv_idx:        int, // index into content.dialogue.conversations (-1 = none)
	active_node_idx:        int, // index into conv.nodes (-1 = none)
	dialogue_choice:        int, // selected choice when on a choice node (-1 = not in choice)
	// Dialogue state persistence
	seen_count:             int,
	seen_convs:             [MAX_SEEN_CONVS][MAX_CONV_ID_LEN]u8,
	seen_lens:              [MAX_SEEN_CONVS]int,
	dlg_flag_count:         int,
	dlg_flags:              [MAX_DLG_FLAGS][MAX_FLAG_LEN]u8,
	dlg_flag_lens:          [MAX_DLG_FLAGS]int,
	visited_floors:         [MAX_DEPTH + 1]^Saved_Floor,
	floor_entry_pos:        Vec2,
	// Milestone level-ups (D3). player_level is derived from kills on load; it is
	// not persisted directly. pending_level_ups counts queued level-up menus the
	// player has yet to resolve; level_choice is the highlighted menu row.
	player_level:           int,
	pending_level_ups:      int,
	level_choice:           int,
	// First-encounter onboarding hints (D4). One bit per Tutorial_Hint; each hint
	// fires once per run. Persisted (survives descent), cleared on reinit/restart.
	tutorial_flags:         Tutorial_Flags,
}
