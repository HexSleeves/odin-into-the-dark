package gameio
import "core:mem"


import gcore "../core"
import eng "../engine"

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
	game.web_stuck_turns = data.web_stuck_turns
	game.water_slow_active = data.water_slow_active
	game.items_found = data.items_found
	game.poison_turns = data.poison_turns
	game.burning_turns = data.burning_turns
	game.frozen_turns = data.frozen_turns
	game.quest = data.quest
	game.floor_entry_pos = data.floor_entry_pos
	game.active_npc = -1
	game.dialogue_line = 0
	game.state = .Playing

	// NPCs are deterministic — repopulate them when loading onto the surface.
	game.npc_count = 0
	if game.depth == gcore.SURFACE_DEPTH {
		gcore.place_town_npcs(game)
	}
	for depth in 0 ..< len(data.visited_floor_present) {
		if !data.visited_floor_present[depth] {continue}
		game.visited_floors[depth] = new(Saved_Floor)
		if game.visited_floors[depth] != nil {
			save_to_floor(content, &data.visited_floors[depth], game.visited_floors[depth])
		}
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
		append(&game.enemies, save_to_enemy(content, &data.enemies[i]))
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
	// action_cost on items is not persisted — recover it from item defs
	for &it in game.items {
		def := content_manager_item_def(content, it.item_type)
		if def != nil {it.action_cost = def.action_cost}
	}
	for i in 0 ..< MAX_INVENTORY {
		if game.inventory[i].occupied {
			def := content_manager_item_def(content, game.inventory[i].item.item_type)
			if def != nil {game.inventory[i].item.action_cost = def.action_cost}
		}
	}
	// Reconstruct action_cost on equipped items
	if game.equipped_weapon.occupied {
		def := content_manager_item_def(content, game.equipped_weapon.item.item_type)
		if def != nil {game.equipped_weapon.item.action_cost = def.action_cost}
	}
	if game.equipped_armor.occupied {
		def := content_manager_item_def(content, game.equipped_armor.item.item_type)
		if def != nil {game.equipped_armor.item.action_cost = def.action_cost}
	}
	if game.equipped_helmet.occupied {
		def := content_manager_item_def(content, game.equipped_helmet.item.item_type)
		if def != nil {game.equipped_helmet.item.action_cost = def.action_cost}
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

	// ── Delete save file (roguelike: one load per save) ──
	eng.storage_manager_remove(storage, path)

	return true
}

// ─── Check if a save file exists ──────────────────────────────────────────────
