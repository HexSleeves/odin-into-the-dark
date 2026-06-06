package gameio
import "core:mem"


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
		etype := save_to_string(content, &se.enemy_type)
		def := content_manager_enemy_def(content, etype)
		qn := 100
		ms := 100
		beh := ""
		if def != nil {
			qn = 100 if def.quickness == 0 else def.quickness
			ms = 100 if def.move_speed == 0 else def.move_speed
			beh = def.behavior
		}
		append(
			&game.enemies,
			Enemy {
				pos              = se.pos,
				hp               = se.hp,
				max_hp           = se.max_hp,
				attack           = se.attack,
				enemy_type       = etype,
				name             = save_to_string(content, &se.name),
				glyph            = se.glyph,
				color            = se.color,
				alive            = se.alive,
				ability_type     = save_to_string(content, &se.ability_type),
				ability_cooldown = se.ability_cooldown,
				ability_max_cd   = se.ability_max_cd,
				ability_range    = se.ability_range,
				is_boss          = se.is_boss,
				behavior         = beh,
				quickness        = qn,
				move_speed       = ms,
				energy           = 0, // granted at start of next enemy round
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
