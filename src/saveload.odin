package main

import "core:mem"

import eng "./engine"
import rl "vendor:raylib"

// ─── Save Constants ───────────────────────────────────────────────────────────

SAVE_FILE :: "savegame.dat"
SAVE_VERSION    :: u32(4)
SAVE_VERSION_V3 :: u32(3)
SAVE_VERSION_V2 :: u32(2)
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
	is_boss:          bool,
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

// Current save format (v4) — v3 is a strict prefix of this struct.
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
	skip_next_turn:    bool,
	water_slow_active: bool,
	// v4 additions
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

string_to_save :: proc(s: string) -> Save_String {
	result: Save_String
	copy_len := min(len(s), MAX_NAME_LEN)
	for i in 0 ..< copy_len {
		result.data[i] = s[i]
	}
	result.len = copy_len
	return result
}

// Resolve a Save_String back to a stable string pointer from loaded content.
// All game strings originate from data definitions (lifetime = program),
// so we look them up instead of allocating.
save_to_string :: proc(content: ^Content_Manager, s: ^Save_String) -> string {
	if s.len == 0 {
		return ""
	}
	temp := string(s.data[:s.len])

	// Look up in enemy definitions
	enemies: []Enemy_Def
	if content != nil {
		enemies = content.registry.enemies.enemies
	}
	for &def in enemies {
		if def.id == temp {return def.id}
		if def.name == temp {return def.name}
		if def.ability.type == temp {return def.ability.type}
	}

	// Look up in item definitions
	items: []Item_Def
	if content != nil {
		items = content.registry.items.items
	}
	for &def in items {
		if def.id == temp {return def.id}
		if def.name == temp {return def.name}
		if def.equipment_slot == temp {return def.equipment_slot}
	}

	// Known constant strings (string literals — always valid)
	known := [?]string {
		"web",
		"pull",
		"poison_cloud",
		"teleport",
		"slam",
		"darkness",
		"weapon",
		"armor",
		"helmet",
		"material",
	}
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

save_to_item :: proc(content: ^Content_Manager, si: ^Save_Item) -> Item {
	return Item {
		pos = si.pos,
		item_type = save_to_string(content, &si.item_type),
		name = save_to_string(content, &si.name),
		glyph = si.glyph,
		color = si.color,
		picked_up = si.picked_up,
		quantity = si.quantity,
		equipment_slot = save_to_string(content, &si.equipment_slot),
		stat_bonus = si.stat_bonus,
		durability = si.durability,
		max_durability = si.max_durability,
	}
}

// ─── Save ─────────────────────────────────────────────────────────────────────

save_game :: proc(turns: ^eng.Turn_Manager, game: ^Game) -> bool {
	return save_game_to_path(turns, game, SAVE_FILE)
}

save_game_to_path :: proc(turns: ^eng.Turn_Manager, game: ^Game, path: string) -> bool {
	storage := eng.storage_manager_make()
	return save_game_to_storage(turns, game, &storage, path)
}

save_game_to_storage :: proc(
	turns: ^eng.Turn_Manager,
	game: ^Game,
	storage: ^eng.Storage_Manager,
	path: string,
) -> bool {
	// Heap-allocate — Save_Data is large (~600KB+)
	data := new(Save_Data)
	if data == nil {return false}
	defer free(data)

	// ── Copy fixed arrays and scalars ──
	data.tiles = game.tiles
	tile_states_export_to_tiles(game, data.tiles[:])
	eng.bool_grid_manager_export(game.web_tiles, data.web_tiles[:])
	data.player = game.player
	data.depth = game.depth
	data.turn_count = eng.turn_manager_current(turns)
	data.kills = game.kills
	data.seed = game.seed
	data.light_boost_bonus = game.light_boost_bonus
	data.light_boost_turns = game.light_boost_turns
	data.skip_next_turn = game.skip_next_turn
	data.water_slow_active = game.water_slow_active
	data.items_found = game.items_found

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
			is_boss          = e.is_boss,
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

	return eng.storage_manager_write(storage, path, buf)
}

load_save_data :: proc(header: Save_Header, buf: []u8) -> (data: ^Save_Data, ok: bool) {
	if header.magic != SAVE_MAGIC {return nil, false}

	data_offset :: size_of(Save_Header)

	if header.version == SAVE_VERSION {
		expected_size := size_of(Save_Header) + size_of(Save_Data)
		if len(buf) != expected_size {return nil, false}

		data = new(Save_Data)
		if data == nil {return nil, false}
		mem.copy(data, &buf[data_offset], size_of(Save_Data))
		return data, true
	}

	if header.version == SAVE_VERSION_V3 {
		expected_size := size_of(Save_Header) + size_of(Save_Data_V3)
		if len(buf) != expected_size {return nil, false}
		old := new(Save_Data_V3)
		if old == nil {return nil, false}
		defer free(old)
		mem.copy(old, &buf[data_offset], size_of(Save_Data_V3))
		data = new(Save_Data)
		if data == nil {return nil, false}
		// V4 is V3 + items_found(int). Copy V3 prefix; items_found zero-inits.
		mem.copy(data, old, size_of(Save_Data_V3))
		return data, true
	}

	if header.version == SAVE_VERSION_V2 {
		expected_size := size_of(Save_Header) + size_of(Save_Data_V2)
		if len(buf) != expected_size {return nil, false}
		old := new(Save_Data_V2)
		if old == nil {return nil, false}
		defer free(old)
		mem.copy(old, &buf[data_offset], size_of(Save_Data_V2))
		data = new(Save_Data)
		if data == nil {return nil, false}
		// V4 is a superset of V3 which is a prefix of V2. Copy V3-sized prefix.
		mem.copy(data, old, size_of(Save_Data_V3))
		return data, true
	}

	return nil, false
}

// ─── Load ─────────────────────────────────────────────────────────────────────

load_game :: proc(
	content: ^Content_Manager,
	turns: ^eng.Turn_Manager,
	camera: ^eng.Camera_Manager,
	vfx: ^eng.Vfx_Manager,
	ui: ^UI_Manager,
	messages: ^Message_Manager,
	game: ^Game,
) -> bool {
	return load_game_from_path(content, turns, camera, vfx, ui, messages, game, SAVE_FILE)
}

load_game_from_path :: proc(
	content: ^Content_Manager,
	turns: ^eng.Turn_Manager,
	camera: ^eng.Camera_Manager,
	vfx: ^eng.Vfx_Manager,
	ui: ^UI_Manager,
	messages: ^Message_Manager,
	game: ^Game,
	path: string,
) -> bool {
	storage := eng.storage_manager_make()
	return load_game_from_storage(content, turns, camera, vfx, ui, messages, game, &storage, path)
}

load_game_from_storage :: proc(
	content: ^Content_Manager,
	turns: ^eng.Turn_Manager,
	camera: ^eng.Camera_Manager,
	vfx: ^eng.Vfx_Manager,
	ui: ^UI_Manager,
	messages: ^Message_Manager,
	game: ^Game,
	storage: ^eng.Storage_Manager,
	path: string,
) -> bool {
	buf, read_ok := eng.storage_manager_read(storage, path, context.allocator)
	if !read_ok {return false}
	defer delete(buf, context.allocator)

	if len(buf) < size_of(Save_Header) {return false}

	// ── Validate header ──
	header: Save_Header
	mem.copy(&header, &buf[0], size_of(Save_Header))

	// ── Deserialize current save data, or migrate supported legacy layouts ──
	data, data_ok := load_save_data(header, buf)
	if !data_ok {return false}
	defer free(data)

	// ── Clean up existing dynamic arrays ──
	game_cleanup(game)

	// ── Restore fixed fields ──
	game.tiles = data.tiles
	game_init_world(game)
	tile_states_import_from_tiles(game, data.tiles[:])
	eng.bool_grid_manager_import(&game.web_tiles, data.web_tiles[:])
	game.player = data.player
	game.depth = data.depth
	eng.turn_manager_set(turns, data.turn_count)
	game.kills = data.kills
	game.seed = data.seed
	game.light_boost_bonus = data.light_boost_bonus
	game.light_boost_turns = data.light_boost_turns
	game.skip_next_turn = data.skip_next_turn
	game.water_slow_active = data.water_slow_active
	game.items_found = data.items_found
	game.state = .Playing

	// ── Restore ore veins ──
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		game.ore_veins[i] = Ore_Vein {
			ore_type = save_to_string(content, &data.ore_veins[i].ore_type),
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
				enemy_type = save_to_string(content, &se.enemy_type),
				name = save_to_string(content, &se.name),
				glyph = se.glyph,
				color = se.color,
				alive = se.alive,
				ability_type = save_to_string(content, &se.ability_type),
				ability_cooldown = se.ability_cooldown,
				ability_max_cd = se.ability_max_cd,
				ability_range = se.ability_range,
				is_boss = se.is_boss,
			},
		)
	}

	game.items = make([dynamic]Item)
	for i in 0 ..< data.item_count {
		append(&game.items, save_to_item(content, &data.items[i]))
	}

	game.light_sources = make([dynamic]Light_Source)

	// ── Restore inventory ──
	for i in 0 ..< MAX_INVENTORY {
		game.inventory[i] = Inventory_Slot {
			occupied = data.inventory[i].occupied,
			item     = save_to_item(content, &data.inventory[i].item),
		}
	}

	// ── Restore equipment ──
	game.equipped_weapon = Equipment {
		occupied = data.equipped_weapon.occupied,
		item     = save_to_item(content, &data.equipped_weapon.item),
	}
	game.equipped_armor = Equipment {
		occupied = data.equipped_armor.occupied,
		item     = save_to_item(content, &data.equipped_armor.item),
	}
	game.equipped_helmet = Equipment {
		occupied = data.equipped_helmet.occupied,
		item     = save_to_item(content, &data.equipped_helmet.item),
	}

	// ── Reconstruct transient state ──
	game.palette = palette_for_depth(game.depth)
	compute_fov(game)
	game_camera_update(camera, game, true)
	clear_messages(messages)
	add_message(messages, game, "Game loaded.", rl.Color{100, 255, 100, 255})

	// Reset transient UI modes on load.
	ui_manager_reset_transient(ui)
	// use_sprites intentionally NOT reset — player render preference is sticky

	// Reset transient VFX.
	eng.vfx_manager_reset(vfx)

	// ── Delete save file (roguelike: one load per save) ──
	eng.storage_manager_remove(storage, path)

	return true
}

// ─── Check if a save file exists ──────────────────────────────────────────────

save_exists :: proc() -> bool {
	return save_exists_at(SAVE_FILE)
}

save_exists_at :: proc(path: string) -> bool {
	storage := eng.storage_manager_make()
	return save_exists_in_storage(&storage, path)
}

save_exists_in_storage :: proc(storage: ^eng.Storage_Manager, path: string) -> bool {
	return eng.storage_manager_exists(storage, path)
}
