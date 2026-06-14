package gameio

import gcore "../core"
import "core:hash"
import "core:mem"


// Pre-v9 saves stored player statuses as flat scalar fields. Fold them into
// the v9 player_status array; enemy statuses did not exist and stay zeroed.
@(private = "file")
migrate_legacy_status_fields :: proc(data: ^Save_Data) {
	data.player_status[gcore.Status_Kind.Poison] = data.poison_turns
	data.player_status[gcore.Status_Kind.Burning] = data.burning_turns
	data.player_status[gcore.Status_Kind.Frozen] = data.frozen_turns
	data.player_status[gcore.Status_Kind.Webbed] = data.web_stuck_turns
}

// clamp_save_counts clamps all file-controlled count fields to their fixed-array
// capacities. Called after every mem.copy to prevent out-of-bounds iteration on
// release builds that skip bounds checks (-no-bounds-check).
@(private = "file")
clamp_save_counts :: proc(data: ^Save_Data) {
	data.enemy_count = clamp(data.enemy_count, 0, MAX_SAVE_ENEMIES)
	data.item_count = clamp(data.item_count, 0, MAX_SAVE_ITEMS)
	data.room_count = clamp(data.room_count, 0, MAX_SAVE_ROOMS)
	for d in 0 ..< len(data.visited_floors) {
		data.visited_floors[d].enemy_count = clamp(
			data.visited_floors[d].enemy_count,
			0,
			MAX_SAVE_ENEMIES,
		)
		data.visited_floors[d].item_count = clamp(
			data.visited_floors[d].item_count,
			0,
			MAX_SAVE_ITEMS,
		)
		data.visited_floors[d].room_count = clamp(
			data.visited_floors[d].room_count,
			0,
			MAX_SAVE_ROOMS,
		)
		data.visited_floors[d].light_source_count = clamp(
			data.visited_floors[d].light_source_count,
			0,
			MAX_SAVE_LIGHTS,
		)
	}
}

load_save_data :: proc(header: Save_Header, buf: []u8) -> (data: ^Save_Data, ok: bool) {
	if header.magic != SAVE_MAGIC {return nil, false}

	// v10+: full 12-byte header; payload starts at size_of(Save_Header).
	// v2–v9: legacy 8-byte header; payload starts at size_of(Save_Header_Legacy).
	legacy_data_offset :: size_of(Save_Header_Legacy)
	current_data_offset :: size_of(Save_Header)

	if header.version == SAVE_VERSION {
		// v10: verify size, then CRC32 over payload bytes.
		expected_size := size_of(Save_Header) + size_of(Save_Data)
		if len(buf) != expected_size {return nil, false}

		payload := buf[current_data_offset:]
		if hash.crc32(payload) != header.crc32 {return nil, false}

		data = new(Save_Data)
		if data == nil {return nil, false}
		mem.copy(data, &buf[current_data_offset], size_of(Save_Data))
		clamp_save_counts(data)
		return data, true
	}

	if header.version == SAVE_VERSION_V9 {
		// v9: same Save_Data layout as v10 but uses legacy 8-byte header; no CRC.
		expected_size := size_of(Save_Header_Legacy) + size_of(Save_Data)
		if len(buf) != expected_size {return nil, false}

		data = new(Save_Data)
		if data == nil {return nil, false}
		mem.copy(data, &buf[legacy_data_offset], size_of(Save_Data))
		clamp_save_counts(data)
		return data, true
	}

	if header.version == SAVE_VERSION_V8 {
		expected_size := size_of(Save_Header_Legacy) + size_of(Save_Data_V8)
		if len(buf) != expected_size {return nil, false}
		old := new(Save_Data_V8)
		if old == nil {return nil, false}
		defer free(old)
		mem.copy(old, &buf[legacy_data_offset], size_of(Save_Data_V8))
		data = new(Save_Data)
		if data == nil {return nil, false}
		// V9 is V8 + per-entity status. Copy V8 prefix; fold legacy scalars.
		mem.copy(data, old, size_of(Save_Data_V8))
		migrate_legacy_status_fields(data)
		clamp_save_counts(data)
		return data, true
	}

	if header.version == SAVE_VERSION_V7 {
		expected_size := size_of(Save_Header_Legacy) + size_of(Save_Data_V7)
		if len(buf) != expected_size {return nil, false}
		old := new(Save_Data_V7)
		if old == nil {return nil, false}
		defer free(old)
		mem.copy(old, &buf[legacy_data_offset], size_of(Save_Data_V7))
		data = new(Save_Data)
		if data == nil {return nil, false}
		// V8 is V7 + dialogue state. Copy V7 prefix; dialogue fields zero-init.
		mem.copy(data, old, size_of(Save_Data_V7))
		migrate_legacy_status_fields(data)
		clamp_save_counts(data)
		return data, true
	}

	if header.version == SAVE_VERSION_V6 {
		expected_size := size_of(Save_Header_Legacy) + size_of(Save_Data_V6)
		if len(buf) != expected_size {return nil, false}
		old := new(Save_Data_V6)
		if old == nil {return nil, false}
		defer free(old)
		mem.copy(old, &buf[legacy_data_offset], size_of(Save_Data_V6))
		data = new(Save_Data)
		if data == nil {return nil, false}
		mem.copy(data, old, size_of(Save_Data_V6))
		migrate_legacy_status_fields(data)
		clamp_save_counts(data)
		return data, true
	}

	if header.version == SAVE_VERSION_V4 {
		expected_size := size_of(Save_Header_Legacy) + size_of(Save_Data_V4)
		if len(buf) != expected_size {return nil, false}
		old := new(Save_Data_V4)
		if old == nil {return nil, false}
		defer free(old)
		mem.copy(old, &buf[legacy_data_offset], size_of(Save_Data_V4))
		data = new(Save_Data)
		if data == nil {return nil, false}
		// V4 diverges from current after light_boost_turns: V4 stored
		// skip_next_turn:bool where current stores web_stuck_turns:int, so a raw
		// prefix copy past that point misaligns every later field. Copy only the
		// byte-identical prefix, then map the diverged tail fields explicitly.
		// web_stuck_turns and the status timers stay zero-initialized.
		prefix :: int(offset_of(Save_Data, web_stuck_turns))
		mem.copy(data, old, prefix)
		data.water_slow_active = old.water_slow_active
		data.items_found = old.items_found
		migrate_legacy_status_fields(data)
		clamp_save_counts(data)
		return data, true
	}

	if header.version == SAVE_VERSION_V3 {
		expected_size := size_of(Save_Header_Legacy) + size_of(Save_Data_V3)
		if len(buf) != expected_size {return nil, false}
		old := new(Save_Data_V3)
		if old == nil {return nil, false}
		defer free(old)
		mem.copy(old, &buf[legacy_data_offset], size_of(Save_Data_V3))
		data = new(Save_Data)
		if data == nil {return nil, false}
		// V3 has the same skip_next_turn divergence as V4 (and no items_found).
		// Copy only the byte-identical prefix, then map water_slow_active; web_stuck_turns,
		// items_found, and the status timers stay zero-initialized.
		prefix :: int(offset_of(Save_Data, web_stuck_turns))
		mem.copy(data, old, prefix)
		data.water_slow_active = old.water_slow_active
		migrate_legacy_status_fields(data)
		clamp_save_counts(data)
		return data, true
	}

	if header.version == SAVE_VERSION_V2 {
		expected_size := size_of(Save_Header_Legacy) + size_of(Save_Data_V2)
		if len(buf) != expected_size {return nil, false}
		old := new(Save_Data_V2)
		if old == nil {return nil, false}
		defer free(old)
		mem.copy(old, &buf[legacy_data_offset], size_of(Save_Data_V2))
		data = new(Save_Data)
		if data == nil {return nil, false}
		// V2 shares V3's prefix (plus trailing legacy pickaxe fields we drop) and
		// the same skip_next_turn divergence. Copy only the byte-identical prefix,
		// then map water_slow_active; everything past it stays zero-initialized.
		prefix :: int(offset_of(Save_Data, web_stuck_turns))
		mem.copy(data, old, prefix)
		data.water_slow_active = old.water_slow_active
		migrate_legacy_status_fields(data)
		clamp_save_counts(data)
		return data, true
	}

	return nil, false
}

// ─── Load ─────────────────────────────────────────────────────────────────────
