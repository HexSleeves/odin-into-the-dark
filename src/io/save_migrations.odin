package gameio

import "core:hash"
import "core:mem"


// clamp_save_counts clamps all file-controlled count fields to their fixed-array
// capacities. Called after the payload copy to prevent out-of-bounds iteration on
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
	}
}

// load_save_data deserializes the current (v12) save format only. Legacy v2–v11
// read support was intentionally dropped (pre-release; no shipped save contract),
// so any other version is rejected cleanly.
load_save_data :: proc(header: Save_Header, buf: []u8) -> (data: ^Save_Data, ok: bool) {
	if header.magic != SAVE_MAGIC {return nil, false}
	if header.version != SAVE_VERSION {return nil, false}

	// v12: full 12-byte header; payload starts at size_of(Save_Header).
	current_data_offset :: size_of(Save_Header)

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

// ─── Load ─────────────────────────────────────────────────────────────────────
