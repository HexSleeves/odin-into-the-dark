package gameio
import "core:hash"
import "core:mem"
import "core:strings"


import gcore "../core"
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
	_pt := perf_begin("save_game")
	defer perf_end(_pt)

	// Heap-allocate — Save_Data is large (~600KB+)
	data := new(Save_Data)
	if data == nil {return false}
	defer free(data)

	// ── Copy fixed arrays and scalars ──
	data.tiles = game.tiles
	tile_state_manager_export(game, data.tile_states[:])
	eng.bool_grid_manager_export(game.web_tiles, data.web_tiles[:])
	data.player = game.player
	data.depth = game.depth
	data.turn_count = eng.turn_manager_current(turns)
	data.kills = game.kills
	data.seed = game.seed
	data.light_boost_bonus = game.light_boost_bonus
	data.light_boost_turns = game.light_boost_turns
	data.water_slow_active = game.water_slow_active
	data.items_found = game.items_found
	data.quest = game.quest
	data.floor_entry_pos = game.floor_entry_pos
	data.player_status = game.player_status
	data.tutorial_flags = game.tutorial_flags

	// ── Convert ore veins (kind enum, item ID + tint derived on load) ──
	for i in 0 ..< MAP_WIDTH * MAP_HEIGHT {
		data.ore_veins[i] = Save_Ore_Vein {
			kind = game.ore_veins[i].kind,
		}
	}

	// ── Convert enemies ──
	data.enemy_count = min(len(game.enemies), MAX_SAVE_ENEMIES)
	for i in 0 ..< data.enemy_count {
		e := &game.enemies[i]
		data.enemies[i] = enemy_to_save(e)
		data.enemy_status[i] = e.status
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

	// ── Convert visited floor stack into a length-prefixed list of PRESENT floors ──
	// Only depths with a populated runtime floor are serialized (v14); absent depths
	// cost nothing on disk. Each record is depth-tagged so restore can reconstruct
	// the sparse visited_floors stack at the correct slots.
	floor_records: [dynamic]Save_Floor_Record
	defer delete(floor_records)
	for depth in 0 ..< len(game.visited_floors) {
		if game.visited_floors[depth] == nil {continue}
		rec: Save_Floor_Record
		rec.depth = i32(depth)
		floor_to_save(game.visited_floors[depth], &rec.floor)
		floor_enemy_count := min(len(game.visited_floors[depth].enemies), MAX_SAVE_ENEMIES)
		for i in 0 ..< floor_enemy_count {
			rec.enemy_status[i] = game.visited_floors[depth].enemies[i].status
		}
		append(&floor_records, rec)
	}

	// ── Write dialogue persistent state ──
	data.seen_conv_count = min(game.seen_count, gcore.MAX_SEEN_CONVS)
	for i in 0 ..< data.seen_conv_count {
		data.seen_convs[i] = game.seen_convs[i]
		data.seen_lens[i] = game.seen_lens[i]
	}
	data.dlg_flag_count = min(game.dlg_flag_count, gcore.MAX_DLG_FLAGS)
	for i in 0 ..< data.dlg_flag_count {
		data.dlg_flags[i] = game.dlg_flags[i]
		data.dlg_flag_lens[i] = game.dlg_flag_lens[i]
	}

	// ── Serialize header + data + floor list as raw bytes ──
	// header (12 bytes) | Save_Data | floor_count:u32 | floor_count × Save_Floor_Record
	floor_count := u32(len(floor_records))
	data_offset := size_of(Save_Header)
	count_offset := data_offset + size_of(Save_Data)
	floors_offset := count_offset + size_of(u32)
	total_size := floors_offset + int(floor_count) * size_of(Save_Floor_Record)
	buf := make([]u8, total_size)
	defer delete(buf)

	// Copy payload first so we can checksum it.
	mem.copy(&buf[data_offset], data, size_of(Save_Data))
	mem.copy(&buf[count_offset], &floor_count, size_of(u32))
	if floor_count > 0 {
		mem.copy(
			&buf[floors_offset],
			raw_data(floor_records),
			int(floor_count) * size_of(Save_Floor_Record),
		)
	}
	payload_bytes := buf[data_offset:]
	checksum := hash.crc32(payload_bytes)

	header := Save_Header {
		magic   = SAVE_MAGIC,
		version = SAVE_VERSION,
		crc32   = checksum,
	}
	mem.copy(&buf[0], &header, size_of(Save_Header))

	// ── Atomic write: write to .tmp, backup existing, rename into place ──
	// If rename is unavailable (e.g. WASM), fall back to a direct write.
	fs := eng.storage_manager_file_system(storage)
	if fs.rename != nil {
		tmp_path := strings.concatenate([]string{path, ".tmp"})
		defer delete(tmp_path)

		// Write to .tmp
		if !eng.storage_manager_write(storage, tmp_path, buf) {
			return false
		}
		// Best-effort backup of existing save to .bak
		if eng.storage_manager_exists(storage, path) {
			bak_path := strings.concatenate([]string{path, ".bak"})
			defer delete(bak_path)
			_ = eng.storage_manager_rename(storage, path, bak_path) // ignore failure
		}
		// Atomic rename .tmp → final path
		return eng.storage_manager_rename(storage, tmp_path, path)
	}

	// Fallback: direct write (web/WASM or any platform without rename)
	return eng.storage_manager_write(storage, path, buf)
}
