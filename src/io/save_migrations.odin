package gameio

import "core:hash"
import "core:mem"

import gcore "../core"


// clamp_save_counts clamps all file-controlled count fields to their fixed-array
// capacities. Called after the payload copy to prevent out-of-bounds iteration on
// release builds that skip bounds checks (-no-bounds-check).
@(private = "file")
clamp_save_counts :: proc(data: ^Save_Data) {
	data.enemy_count = clamp(data.enemy_count, 0, MAX_SAVE_ENEMIES)
	data.item_count = clamp(data.item_count, 0, MAX_SAVE_ITEMS)
	data.room_count = clamp(data.room_count, 0, MAX_SAVE_ROOMS)
}

// clamp_floor_record_counts clamps a single floor record's file-controlled count
// fields to their fixed-array capacities (mirrors clamp_save_counts for floors).
@(private = "file")
clamp_floor_record_counts :: proc(rec: ^Save_Floor_Record) {
	rec.floor.enemy_count = clamp(rec.floor.enemy_count, 0, MAX_SAVE_ENEMIES)
	rec.floor.item_count = clamp(rec.floor.item_count, 0, MAX_SAVE_ITEMS)
	rec.floor.room_count = clamp(rec.floor.room_count, 0, MAX_SAVE_ROOMS)
}

// load_save_data deserializes the current (v14) save format only. Legacy v2–v13
// read support was intentionally dropped (pre-release; no shipped save contract),
// so any other version is rejected cleanly.
//
// On-disk payload layout (after the 12-byte header):
//   Save_Data (fixed part)                       — size_of(Save_Data) bytes
//   floor_count: u32                             — number of present floors
//   floor_count × Save_Floor_Record              — present floors, depth-tagged
// The CRC in the header covers the entire payload (everything after the header).
//
// Returns the fixed Save_Data plus a heap-allocated slice of present floor records
// (empty, never nil-iterating). The caller owns `floors` and must `delete` it.
load_save_data :: proc(
	header: Save_Header,
	buf: []u8,
) -> (
	data: ^Save_Data,
	floors: []Save_Floor_Record,
	ok: bool,
) {
	if header.magic != SAVE_MAGIC {return nil, nil, false}
	if header.version != SAVE_VERSION {return nil, nil, false}

	// v14: full 12-byte header; payload starts at size_of(Save_Header).
	data_offset :: size_of(Save_Header)
	count_offset :: data_offset + size_of(Save_Data)
	floors_offset :: count_offset + size_of(u32)

	// Must hold at least the fixed Save_Data + the floor-count prefix.
	if len(buf) < floors_offset {return nil, nil, false}

	// Read and validate the floor count BEFORE computing the expected size, so a
	// corrupt/oversize count can never overflow the size arithmetic or allocate.
	floor_count: u32
	mem.copy(&floor_count, &buf[count_offset], size_of(u32))
	if floor_count > u32(MAX_SAVE_FLOORS) {return nil, nil, false}

	expected_size := floors_offset + int(floor_count) * size_of(Save_Floor_Record)
	if len(buf) != expected_size {return nil, nil, false}

	// CRC covers the whole payload (fixed Save_Data + count + floor records).
	payload := buf[data_offset:]
	if hash.crc32(payload) != header.crc32 {return nil, nil, false}

	data = new(Save_Data)
	if data == nil {return nil, nil, false}
	mem.copy(data, &buf[data_offset], size_of(Save_Data))
	clamp_save_counts(data)

	out: []Save_Floor_Record
	if floor_count > 0 {
		out = make([]Save_Floor_Record, int(floor_count))
		mem.copy(raw_data(out), &buf[floors_offset], int(floor_count) * size_of(Save_Floor_Record))
		for i in 0 ..< len(out) {
			// Reject any out-of-range depth tag — a bad tag would otherwise write a
			// floor to an invalid visited_floors slot on restore.
			if out[i].depth < 0 || out[i].depth > i32(gcore.MAX_DEPTH) {
				delete(out)
				free(data)
				return nil, nil, false
			}
			clamp_floor_record_counts(&out[i])
		}
	}
	return data, out, true
}

// ─── Load ─────────────────────────────────────────────────────────────────────
