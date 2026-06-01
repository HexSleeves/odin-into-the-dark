package main

import "core:mem"
import "core:os"

import rl "vendor:raylib"

// ─── Save Constants ───────────────────────────────────────────────────────────

SAVE_FILE :: "savegame.dat"
SAVE_VERSION :: u32(1)
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
	color:            rl.Color,
	alive:            bool,
	ability_type:     Save_String,
	ability_cooldown: int,
	ability_max_cd:   int,
	ability_range:    int,
}

Save_Item :: struct {
	pos:            Vec2,
	item_type:      Save_String,
	name:           Save_String,
	glyph:          rune,
	color:          rl.Color,
	picked_up:      bool,
	quantity:       int,
	equipment_slot: Save_String,
	stat_bonus:     int,
	durability:     int,
	max_durability: int,
}

Save_Ore_Vein :: struct {
	ore_type: Save_String,
	color:    rl.Color,
}

Save_Inventory_Slot :: struct {
	occupied: bool,
	item:     Save_Item,
}

Save_Equipment :: struct {
	occupied: bool,
	item:     Save_Item,
}

// ─── File layout ──────────────────────────────────────────────────────────────

Save_Header :: struct {
	magic:   u32,
	version: u32,
}

Save_Data :: struct {
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
	pickaxe_durability: int,
	pickaxe_max_dur:    int,
}

// ─── String conversion helpers ────────────────────────────────────────────────

string_to_save :: proc(s: string) -> Save_String {
	result: Save_String
	copy_len := min(len(s), MAX_NAME_LEN)
	for i in 0 ..< copy_len {
		result.data[i] = s[i]
	}
	result.len = copy_len
	return result
}

// Resolve a Save_String back to a stable string pointer from g_data.
// All game strings originate from data definitions (lifetime = program),
// so we look them up instead of allocating.
save_to_string :: proc(s: ^Save_String) -> string {
	if s.len == 0 {
		return ""
	}
	temp := string(s.data[:s.len])

	// Look up in enemy definitions
	for &def in g_data.enemies.enemies {
		if def.id == temp {return def.id}
		if def.name == temp {return def.name}
		if def.ability.type == temp {return def.ability.type}
	}

	// Look up in item definitions
	for &def in g_data.items.items {
		if def.id == temp {return def.id}
		if def.name == temp {return def.name}
		if def.equipment_slot == temp {return def.equipment_slot}
	}

	// Known constant strings (string literals — always valid)
	known := [?]string{"web", "pull", "weapon", "armor", "helmet", "material"}
	for k in known {
		if k == temp {return k}
	}

	return ""
}

// ─── Item conversion helpers ──────────────────────────────────────────────────

item_to_save :: proc(item: ^Item) -> Save_Item {
	return Save_Item {
		pos = item.pos,
		item_type = string_to_save(item.item_type),
		name = string_to_save(item.name),
		glyph = item.glyph,
		color = item.color,
		picked_up = item.picked_up,
		quantity = item.quantity,
		equipment_slot = string_to_save(item.equipment_slot),
		stat_bonus = item.stat_bonus,
		durability = item.durability,
		max_durability = item.max_durability,
	}
}

save_to_item :: proc(si: ^Save_Item) -> Item {
	return Item {
		pos = si.pos,
		item_type = save_to_string(&si.item_type),
		name = save_to_string(&si.name),
		glyph = si.glyph,
		color = si.color,
		picked_up = si.picked_up,
		quantity = si.quantity,
		equipment_slot = save_to_string(&si.equipment_slot),
		stat_bonus = si.stat_bonus,
		durability = si.durability,
		max_durability = si.max_durability,
	}
}

// ─── Save ─────────────────────────────────────────────────────────────────────

save_game :: proc(game: ^Game) -> bool {
	// Heap-allocate — Save_Data is large (~600KB+)
	data := new(Save_Data)
	if data == nil {return false}
	defer free(data)

	// ── Copy fixed arrays and scalars ──
	data.tiles = game.tiles
	data.web_tiles = game.web_tiles
	data.player = game.player
	data.depth = game.depth
	data.turn_count = game.turn_count
	data.kills = game.kills
	data.seed = game.seed
	data.light_boost_bonus = game.light_boost_bonus
	data.light_boost_turns = game.light_boost_turns
	data.skip_next_turn = game.skip_next_turn
	data.water_slow_active = game.water_slow_active
	data.pickaxe_durability = game.pickaxe_durability
	data.pickaxe_max_dur = game.pickaxe_max_dur

	// ── Convert ore veins (string → Save_String) ──
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		data.ore_veins[i] = Save_Ore_Vein {
			ore_type = string_to_save(game.ore_veins[i].ore_type),
			color    = game.ore_veins[i].color,
		}
	}

	// ── Convert enemies ──
	data.enemy_count = min(len(game.enemies), MAX_SAVE_ENEMIES)
	for i in 0 ..< data.enemy_count {
		e := &game.enemies[i]
		data.enemies[i] = Save_Enemy {
			pos              = e.pos,
			hp               = e.hp,
			max_hp           = e.max_hp,
			attack           = e.attack,
			enemy_type       = string_to_save(e.enemy_type),
			name             = string_to_save(e.name),
			glyph            = e.glyph,
			color            = e.color,
			alive            = e.alive,
			ability_type     = string_to_save(e.ability_type),
			ability_cooldown = e.ability_cooldown,
			ability_max_cd   = e.ability_max_cd,
			ability_range    = e.ability_range,
		}
	}

	// ── Convert items ──
	data.item_count = min(len(game.items), MAX_SAVE_ITEMS)
	for i in 0 ..< data.item_count {
		data.items[i] = item_to_save(&game.items[i])
	}

	// ── Convert rooms ──
	data.room_count = min(len(game.rooms), MAX_SAVE_ROOMS)
	for i in 0 ..< data.room_count {
		data.rooms[i] = game.rooms[i]
	}

	// ── Convert inventory ──
	for i in 0 ..< MAX_INVENTORY {
		data.inventory[i] = Save_Inventory_Slot {
			occupied = game.inventory[i].occupied,
			item     = item_to_save(&game.inventory[i].item),
		}
	}

	// ── Convert equipment ──
	data.equipped_weapon = Save_Equipment {
		occupied = game.equipped_weapon.occupied,
		item     = item_to_save(&game.equipped_weapon.item),
	}
	data.equipped_armor = Save_Equipment {
		occupied = game.equipped_armor.occupied,
		item     = item_to_save(&game.equipped_armor.item),
	}
	data.equipped_helmet = Save_Equipment {
		occupied = game.equipped_helmet.occupied,
		item     = item_to_save(&game.equipped_helmet.item),
	}

	// ── Serialize header + data as raw bytes ──
	total_size := size_of(Save_Header) + size_of(Save_Data)
	buf := make([]u8, total_size)
	defer delete(buf)

	header := Save_Header {
		magic   = SAVE_MAGIC,
		version = SAVE_VERSION,
	}
	mem.copy(&buf[0], &header, size_of(Save_Header))
	mem.copy(&buf[size_of(Save_Header)], data, size_of(Save_Data))

	write_err := os.write_entire_file(SAVE_FILE, buf)
	return write_err == nil
}

// ─── Load ─────────────────────────────────────────────────────────────────────

load_game :: proc(game: ^Game) -> bool {
	buf, read_err := os.read_entire_file(SAVE_FILE, context.allocator)
	if read_err != nil {return false}
	defer delete(buf, context.allocator)

	expected_size := size_of(Save_Header) + size_of(Save_Data)
	if len(buf) != expected_size {return false}

	// ── Validate header ──
	header: Save_Header
	mem.copy(&header, &buf[0], size_of(Save_Header))
	if header.magic != SAVE_MAGIC || header.version != SAVE_VERSION {return false}

	// ── Deserialize into heap-allocated Save_Data ──
	data := new(Save_Data)
	if data == nil {return false}
	defer free(data)
	mem.copy(data, &buf[size_of(Save_Header)], size_of(Save_Data))

	// ── Clean up existing dynamic arrays ──
	game_cleanup(game)

	// ── Restore fixed fields ──
	game.tiles = data.tiles
	game.web_tiles = data.web_tiles
	game.player = data.player
	game.depth = data.depth
	game.turn_count = data.turn_count
	game.kills = data.kills
	game.seed = data.seed
	game.light_boost_bonus = data.light_boost_bonus
	game.light_boost_turns = data.light_boost_turns
	game.skip_next_turn = data.skip_next_turn
	game.water_slow_active = data.water_slow_active
	game.pickaxe_durability = data.pickaxe_durability
	game.pickaxe_max_dur = data.pickaxe_max_dur
	game.state = .Playing

	// ── Restore ore veins ──
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		game.ore_veins[i] = Ore_Vein {
			ore_type = save_to_string(&data.ore_veins[i].ore_type),
			color    = data.ore_veins[i].color,
		}
	}

	// ── Restore dynamic arrays ──
	game.rooms = make([dynamic]Room)
	for i in 0 ..< data.room_count {
		append(&game.rooms, data.rooms[i])
	}

	game.enemies = make([dynamic]Enemy)
	for i in 0 ..< data.enemy_count {
		se := &data.enemies[i]
		append(
			&game.enemies,
			Enemy {
				pos = se.pos,
				hp = se.hp,
				max_hp = se.max_hp,
				attack = se.attack,
				enemy_type = save_to_string(&se.enemy_type),
				name = save_to_string(&se.name),
				glyph = se.glyph,
				color = se.color,
				alive = se.alive,
				ability_type = save_to_string(&se.ability_type),
				ability_cooldown = se.ability_cooldown,
				ability_max_cd = se.ability_max_cd,
				ability_range = se.ability_range,
			},
		)
	}

	game.items = make([dynamic]Item)
	for i in 0 ..< data.item_count {
		append(&game.items, save_to_item(&data.items[i]))
	}

	game.light_sources = make([dynamic]Light_Source)

	// ── Restore inventory ──
	for i in 0 ..< MAX_INVENTORY {
		game.inventory[i] = Inventory_Slot {
			occupied = data.inventory[i].occupied,
			item     = save_to_item(&data.inventory[i].item),
		}
	}

	// ── Restore equipment ──
	game.equipped_weapon = Equipment {
		occupied = data.equipped_weapon.occupied,
		item     = save_to_item(&data.equipped_weapon.item),
	}
	game.equipped_armor = Equipment {
		occupied = data.equipped_armor.occupied,
		item     = save_to_item(&data.equipped_armor.item),
	}
	game.equipped_helmet = Equipment {
		occupied = data.equipped_helmet.occupied,
		item     = save_to_item(&data.equipped_helmet.item),
	}

	// ── Reconstruct transient state ──
	game.palette = palette_for_depth(game.depth)
	compute_fov(game)
	camera_update(game, snap = true)
	clear_messages(game)
	add_message(game, "Game loaded.", rl.Color{100, 255, 100, 255})

	// Reset UI modes
	game.mining_mode = false
	game.dropping = false
	game.equipping = false
	game.show_minimap = false
	game.inspect_slot = -1
	game.flash_alpha = 0
	game.anim_frame = 0

	// ── Delete save file (roguelike: one load per save) ──
	os.remove(SAVE_FILE)

	return true
}

// ─── Check if a save file exists ──────────────────────────────────────────────

save_exists :: proc() -> bool {
	return os.exists(SAVE_FILE)
}
