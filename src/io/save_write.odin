package gameio
import "core:mem"


import eng "../engine"


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
	data.web_stuck_turns = game.web_stuck_turns
	data.water_slow_active = game.water_slow_active
	data.items_found = game.items_found
	data.poison_turns = game.poison_turns
	data.burning_turns = game.burning_turns
	data.frozen_turns = game.frozen_turns
	data.quest = game.quest
	data.floor_entry_pos = game.floor_entry_pos

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
		data.enemies[i] = enemy_to_save(e)
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

	// ── Convert visited floor stack ──
	for depth in 0 ..< len(game.visited_floors) {
		if game.visited_floors[depth] == nil {continue}
		data.visited_floor_present[depth] = true
		floor_to_save(game.visited_floors[depth], &data.visited_floors[depth])
	}

	// ── Write dialogue persistent state ──
	data.seen_conv_count = game.seen_count
	for i in 0 ..< game.seen_count {
		data.seen_convs[i] = game.seen_convs[i]
		data.seen_lens[i] = game.seen_lens[i]
	}
	data.dlg_flag_count = game.dlg_flag_count
	for i in 0 ..< game.dlg_flag_count {
		data.dlg_flags[i] = game.dlg_flags[i]
		data.dlg_flag_lens[i] = game.dlg_flag_lens[i]
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
