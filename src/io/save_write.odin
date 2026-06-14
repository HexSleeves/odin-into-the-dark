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
	// Legacy mirrors — kept so the v8 prefix region stays meaningful.
	data.poison_turns = game.player_status[gcore.Status_Kind.Poison]
	data.burning_turns = game.player_status[gcore.Status_Kind.Burning]
	data.frozen_turns = game.player_status[gcore.Status_Kind.Frozen]
	data.web_stuck_turns = game.player_status[gcore.Status_Kind.Webbed]

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

	// ── Convert visited floor stack ──
	for depth in 0 ..< len(game.visited_floors) {
		if game.visited_floors[depth] == nil {continue}
		data.visited_floor_present[depth] = true
		floor_to_save(game.visited_floors[depth], &data.visited_floors[depth])
		floor_enemy_count := min(len(game.visited_floors[depth].enemies), MAX_SAVE_ENEMIES)
		for i in 0 ..< floor_enemy_count {
			data.floor_enemy_status[depth][i] = game.visited_floors[depth].enemies[i].status
		}
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

	// ── Serialize header + data as raw bytes ──
	// v10: header is Save_Header (12 bytes: magic + version + crc32).
	total_size := size_of(Save_Header) + size_of(Save_Data)
	buf := make([]u8, total_size)
	defer delete(buf)

	// Copy payload first so we can checksum it.
	mem.copy(&buf[size_of(Save_Header)], data, size_of(Save_Data))
	payload_bytes := buf[size_of(Save_Header):]
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
