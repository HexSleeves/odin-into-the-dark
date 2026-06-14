package gameio
import "base:runtime"
import "core:mem"
import "core:strings"


import gcore "../core"
import eng "../engine"

// read_and_decode_save reads one candidate path, validates its header, and
// migrates/deserializes the payload into a freshly allocated Save_Data.
// Returns nil on any failure so the caller can fall back to the next candidate.
@(private = "file")
read_and_decode_save :: proc(storage: ^eng.Storage_Manager, path: string) -> ^Save_Data {
	read_allocator := context.allocator
	buf, read_ok := eng.storage_manager_read(storage, path, read_allocator)
	if !read_ok {return nil}
	defer delete(buf, read_allocator)

	if len(buf) < size_of(Save_Header) {return nil}

	// ── Validate header ──
	// v11 is the only supported format: a full 12-byte header (magic + version + crc32).
	header: Save_Header
	mem.copy(&header, &buf[0], size_of(Save_Header))

	// ── Deserialize current (v11) save data ──
	data, data_ok := load_save_data(header, buf)
	if !data_ok {return nil}
	return data
}

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
	// ── Read + validate + migrate, recovering from the rolling backup ──
	// The atomic writer leaves a one-deep `.bak` of the previous save. If the
	// primary save is missing or corrupt (truncated/CRC mismatch/torn write),
	// fall back to the backup so a half-completed write cannot brick a run.
	bak_path := strings.concatenate([]string{path, ".bak"})
	defer delete(bak_path)
	tmp_path := strings.concatenate([]string{path, ".tmp"})
	defer delete(tmp_path)

	data: ^Save_Data
	for candidate in ([]string{path, bak_path}) {
		data = read_and_decode_save(storage, candidate)
		if data != nil {break}
	}
	if data == nil {return false}
	defer free(data)
	old_context := context
	context.allocator = runtime.default_allocator()
	defer {
		context = old_context
	}

	// ── Clean up existing dynamic arrays ──
	game_cleanup(game)

	// ── Restore fixed fields ──
	game.tiles = data.tiles
	game_init_world(game)
	tile_state_manager_import(game, data.tile_states[:])
	eng.bool_grid_manager_import(&game.web_tiles, data.web_tiles[:])
	game.player = data.player
	// Reconstruct energy system fields from content (not persisted — derived from player_def)
	{
		p_def := content_manager_player_def(content)
		qn := 100 if p_def.quickness == 0 else p_def.quickness
		ms := 100 if p_def.move_speed == 0 else p_def.move_speed
		game.player.quickness = qn
		game.player.move_speed = ms
		game.player.energy = qn * 10 // restore to full AP — mid-round state is not saved
	}
	game.depth = data.depth
	eng.turn_manager_set(turns, data.turn_count)
	game.kills = data.kills
	game.seed = data.seed
	game.light_boost_bonus = data.light_boost_bonus
	game.light_boost_turns = data.light_boost_turns
	game.water_slow_active = data.water_slow_active
	game.items_found = data.items_found
	game.player_status = data.player_status
	game.quest = data.quest
	game.floor_entry_pos = data.floor_entry_pos
	game.active_npc = -1
	game.active_conv_idx = -1
	game.active_node_idx = -1
	game.dialogue_choice = -1
	game.state = .Playing

	// NPCs are deterministic — repopulate them when loading onto the surface.
	game.npc_count = 0
	if game.depth == gcore.SURFACE_DEPTH {
		gcore.place_town_npcs(game)
	}
	for depth in 0 ..< len(data.visited_floor_present) {
		if !data.visited_floor_present[depth] {continue}
		game.visited_floors[depth] = new(Saved_Floor, runtime.default_allocator())
		if game.visited_floors[depth] != nil {
			save_to_floor(content, &data.visited_floors[depth], game.visited_floors[depth])
			floor_enemy_count := min(len(game.visited_floors[depth].enemies), MAX_SAVE_ENEMIES)
			for i in 0 ..< floor_enemy_count {
				game.visited_floors[depth].enemies[i].status = data.floor_enemy_status[depth][i]
			}
		}
	}

	// ── Restore dialogue persistent state ──
	game.seen_count = min(data.seen_conv_count, gcore.MAX_SEEN_CONVS)
	for i in 0 ..< game.seen_count {
		game.seen_convs[i] = data.seen_convs[i]
		game.seen_lens[i] = data.seen_lens[i]
	}
	game.dlg_flag_count = min(data.dlg_flag_count, gcore.MAX_DLG_FLAGS)
	for i in 0 ..< game.dlg_flag_count {
		game.dlg_flags[i] = data.dlg_flags[i]
		game.dlg_flag_lens[i] = data.dlg_flag_lens[i]
	}

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
		restored := save_to_enemy(content, &data.enemies[i])
		restored.status = data.enemy_status[i]
		append(&game.enemies, restored)
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
	// action_cost, crit_chance, and description are not persisted — recover from item defs
	for &it in game.items {
		def := content_manager_item_def(content, it.item_type)
		if def != nil {
			it.action_cost = def.action_cost
			it.crit_chance = def.crit_chance
			it.description = def.description
		}
	}
	for i in 0 ..< MAX_INVENTORY {
		if game.inventory[i].occupied {
			def := content_manager_item_def(content, game.inventory[i].item.item_type)
			if def != nil {
				game.inventory[i].item.action_cost = def.action_cost
				game.inventory[i].item.crit_chance = def.crit_chance
				game.inventory[i].item.description = def.description
			}
		}
	}
	// Reconstruct transient fields on equipped items
	if game.equipped_weapon.occupied {
		def := content_manager_item_def(content, game.equipped_weapon.item.item_type)
		if def != nil {
			game.equipped_weapon.item.action_cost = def.action_cost
			game.equipped_weapon.item.crit_chance = def.crit_chance
			game.equipped_weapon.item.description = def.description
		}
	}
	if game.equipped_armor.occupied {
		def := content_manager_item_def(content, game.equipped_armor.item.item_type)
		if def != nil {
			game.equipped_armor.item.action_cost = def.action_cost
			game.equipped_armor.item.crit_chance = def.crit_chance
			game.equipped_armor.item.description = def.description
		}
	}
	if game.equipped_helmet.occupied {
		def := content_manager_item_def(content, game.equipped_helmet.item.item_type)
		if def != nil {
			game.equipped_helmet.item.action_cost = def.action_cost
			game.equipped_helmet.item.crit_chance = def.crit_chance
			game.equipped_helmet.item.description = def.description
		}
	}
	game.palette = palette_for_depth(game.depth)
	compute_fov(game)
	game_camera_update(camera, game, true)
	clear_messages(messages)
	add_message(messages, game, "Game loaded.", eng.Engine_Color{100, 255, 100, 255})

	// Reset transient UI modes on load.
	ui_manager_reset_transient(ui)
	// use_sprites intentionally NOT reset — player render preference is sticky

	// Reset transient VFX.
	eng.vfx_manager_reset(vfx)

	// ── Delete save artifacts (roguelike: one load per save) ──
	// Remove the primary plus any rolling backup / leftover temp so a recovered
	// run cannot be reloaded from a stale backup on the next launch.
	eng.storage_manager_remove(storage, path)
	eng.storage_manager_remove(storage, bak_path)
	eng.storage_manager_remove(storage, tmp_path)

	return true
}

// ─── Check if a save file exists ──────────────────────────────────────────────
