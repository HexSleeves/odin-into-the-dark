#+build !js
package gameio

import gcore "../core"
import "core:hash"
import "core:mem"
import "core:testing"

// ─── v14 on-disk payload helpers ──────────────────────────────────────────────
//
// v14 layout (after the 12-byte header):
//   Save_Data | floor_count:u32 | floor_count × Save_Floor_Record
// CRC covers the whole payload (everything after the header).

// build_v14_buf serializes a Save_Data + present floor records into a fully valid
// v14 buffer (correct sizing, floor count, and CRC). Caller owns the returned buf.
@(private = "file")
build_v14_buf :: proc(data: ^Save_Data, floors: []Save_Floor_Record) -> []u8 {
	data_offset := size_of(Save_Header)
	count_offset := data_offset + size_of(Save_Data)
	floors_offset := count_offset + size_of(u32)
	floor_count := u32(len(floors))
	total := floors_offset + int(floor_count) * size_of(Save_Floor_Record)

	buf := make([]u8, total)
	mem.copy(&buf[data_offset], data, size_of(Save_Data))
	mem.copy(&buf[count_offset], &floor_count, size_of(u32))
	if floor_count > 0 {
		mem.copy(
			&buf[floors_offset],
			raw_data(floors),
			int(floor_count) * size_of(Save_Floor_Record),
		)
	}
	crc := hash.crc32(buf[data_offset:])
	header := Save_Header {
		magic   = SAVE_MAGIC,
		version = SAVE_VERSION,
		crc32   = crc,
	}
	mem.copy(&buf[0], &header, size_of(Save_Header))
	return buf
}

// ─── v14 layout invariants ──────────────────────────────────────────────────────

@(test)
v14_save_data_no_longer_embeds_dense_floor_arrays :: proc(t: ^testing.T) {
	// v14's headline win: Save_Data no longer carries the dense [MAX_DEPTH+1]Save_Floor
	// (+ present flags + per-floor enemy status) arrays. Present floors move into a
	// length-prefixed list of Save_Floor_Record on disk. Guard that Save_Data is now
	// dramatically smaller than even one extra embedded floor would have made it: it
	// must be well under the size the old dense array alone contributed.
	one_floor := size_of(Save_Floor)
	dense_floor_array := one_floor * MAX_SAVE_FLOORS

	// The old Save_Data embedded the whole dense array; the new one embeds none of it.
	// size_of(Save_Data) must therefore be smaller than that array by itself.
	testing.expect(
		t,
		size_of(Save_Data) < dense_floor_array,
		"Save_Data must no longer embed the dense per-depth floor array",
	)

	// Sanity: a single floor record is roughly one floor (plus a depth tag + status),
	// and the whole file for a one-floor run is Save_Data + count + one record — far
	// below the old ~3.9 MB dense blob (Save_Data + MAX_SAVE_FLOORS floors).
	old_blob := size_of(Save_Data) + dense_floor_array
	new_one_floor_blob :=
		size_of(Save_Header) + size_of(Save_Data) + size_of(u32) + size_of(Save_Floor_Record)
	testing.expect(
		t,
		new_one_floor_blob < old_blob / 4,
		"a one-floor v14 save must be a small fraction of the old dense blob",
	)
}

@(test)
v14_save_floor_record_is_depth_tagged :: proc(t: ^testing.T) {
	// Each record must carry its depth tag plus the floor and per-floor enemy status.
	testing.expect_value(t, int(offset_of(Save_Floor_Record, depth)), 0)
	// The record must be at least one floor plus the depth tag.
	testing.expect(
		t,
		size_of(Save_Floor_Record) >= size_of(Save_Floor) + size_of(i32),
		"Save_Floor_Record must hold a depth tag plus the floor payload",
	)
	// MAX_SAVE_FLOORS bounds the list to one record per reachable depth.
	testing.expect_value(t, MAX_SAVE_FLOORS, gcore.MAX_DEPTH + 1)
}

@(test)
v14_save_data_layout_has_expected_byte_size_relationship :: proc(t: ^testing.T) {
	// v13 replaced per-cell Save_Ore_Vein{ore_type:Save_String, color} with a single
	// Ore_Kind byte. v14 left ore_veins untouched; guard the entry is still one byte.
	testing.expect_value(t, size_of(Save_Ore_Vein), size_of(gcore.Ore_Kind))

	data_tail_size := size_of(Save_Data) - int(offset_of(Save_Data, tutorial_flags))
	testing.expect(
		t,
		data_tail_size >= size_of(gcore.Tutorial_Flags),
		"trailing span must cover the tutorial_flags field",
	)

	data_tile_states_size :=
		int(offset_of(Save_Data, tutorial_flags)) - int(offset_of(Save_Data, tile_states))
	testing.expect(t, data_tile_states_size > 0, "tile_states array must carry the engine layer")

	// Save_Floor's trailing field is tile_states (no per-floor tutorial_flags copy).
	floor_tile_tail := size_of(Save_Floor) - int(offset_of(Save_Floor, tile_states))
	testing.expect(
		t,
		floor_tile_tail > 0,
		"Save_Floor tile_states must carry the trailing engine layer",
	)

	// the per-floor Light_Source array is gone, so palette sits immediately after the
	// rooms array with no light_source_count/light_sources gap between them.
	rooms_to_palette := int(offset_of(Save_Floor, palette)) - int(offset_of(Save_Floor, rooms))
	testing.expect_value(t, rooms_to_palette, size_of([MAX_SAVE_ROOMS]Room))
}

// ─── v14 round-trip tests ───────────────────────────────────────────────────────

@(test)
v14_save_data_round_trips_correctly :: proc(t: ^testing.T) {
	payload := new(Save_Data)
	defer free(payload)
	payload.depth = 8
	payload.kills = 42
	payload.enemy_count = 3
	payload.item_count = 2
	payload.player_status[gcore.Status_Kind.Poison] = 5
	idx := 5 * MAP_WIDTH + 7
	payload.tile_states[idx].visible = true
	payload.tile_states[idx].explored = true
	payload.tile_states[idx].light_level = 0.5
	ore_idx := 9 * MAP_WIDTH + 3
	payload.ore_veins[ore_idx].kind = .Gold

	buf := build_v14_buf(payload, nil)
	defer delete(buf)

	header: Save_Header
	mem.copy(&header, &buf[0], size_of(Save_Header))
	data, floors, ok := load_save_data(header, buf)
	testing.expect(t, ok, "v14 round-trip must succeed")
	if data == nil {return}
	defer free(data)
	defer delete(floors)

	testing.expect_value(t, len(floors), 0)
	testing.expect_value(t, data.depth, 8)
	testing.expect_value(t, data.kills, 42)
	testing.expect_value(t, data.enemy_count, 3)
	testing.expect_value(t, data.item_count, 2)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Poison], 5)
	testing.expect(t, data.tile_states[idx].visible, "tile-state visibility must round-trip")
	testing.expect(t, data.tile_states[idx].explored, "tile-state exploration must round-trip")
	testing.expect_value(t, data.tile_states[idx].light_level, f32(0.5))
	testing.expect_value(t, data.ore_veins[ore_idx].kind, gcore.Ore_Kind.Gold)
}

@(test)
v14_sparse_present_floors_round_trip_with_correct_depths :: proc(t: ^testing.T) {
	// Build a sparse set of present floors at non-contiguous depths. The list must
	// round-trip exactly, preserving each record's depth tag and payload, so restore
	// can place each floor back at its original visited_floors slot.
	payload := new(Save_Data)
	defer free(payload)
	payload.depth = 5

	floors := make([]Save_Floor_Record, 3)
	defer delete(floors)
	// Depths chosen to be non-contiguous and out of natural order.
	floors[0].depth = 0
	floors[0].floor.enemy_count = 2
	floors[0].floor.player_pos = Vec2{3, 4}
	floors[0].enemy_status[1][gcore.Status_Kind.Poison] = 7

	floors[1].depth = 5
	floors[1].floor.item_count = 1
	floors[1].floor.tiles[2 * MAP_WIDTH + 2] = Tile {
		type = .Wall,
	}

	floors[2].depth = i32(gcore.MAX_DEPTH) // boundary depth must survive
	floors[2].floor.room_count = 1
	floors[2].floor.player_pos = Vec2{9, 9}

	buf := build_v14_buf(payload, floors)
	defer delete(buf)

	header: Save_Header
	mem.copy(&header, &buf[0], size_of(Save_Header))
	data, got, ok := load_save_data(header, buf)
	testing.expect(t, ok, "sparse floor list must round-trip")
	if data == nil {return}
	defer free(data)
	defer delete(got)

	testing.expect_value(t, len(got), 3)
	if len(got) != 3 {return}

	testing.expect_value(t, got[0].depth, 0)
	testing.expect_value(t, got[0].floor.enemy_count, 2)
	testing.expect_value(t, got[0].floor.player_pos, Vec2{3, 4})
	testing.expect_value(t, got[0].enemy_status[1][gcore.Status_Kind.Poison], 7)

	testing.expect_value(t, got[1].depth, 5)
	testing.expect_value(t, got[1].floor.item_count, 1)
	testing.expect_value(t, got[1].floor.tiles[2 * MAP_WIDTH + 2].type, gcore.Tile_Type.Wall)

	testing.expect_value(t, got[2].depth, i32(gcore.MAX_DEPTH))
	testing.expect_value(t, got[2].floor.room_count, 1)
	testing.expect_value(t, got[2].floor.player_pos, Vec2{9, 9})
}

@(test)
tutorial_flags_survive_a_v14_save_and_restore_roundtrip :: proc(t: ^testing.T) {
	payload := new(Save_Data)
	defer free(payload)
	payload.depth = 4
	payload.tutorial_flags = {.First_Enemy, .First_Ore, .First_Shrine}

	buf := build_v14_buf(payload, nil)
	defer delete(buf)

	header: Save_Header
	mem.copy(&header, &buf[0], size_of(Save_Header))
	data, floors, ok := load_save_data(header, buf)
	testing.expect(t, ok, "v14 round-trip must succeed")
	if data == nil {return}
	defer free(data)
	defer delete(floors)

	testing.expect(t, .First_Enemy in data.tutorial_flags, "First_Enemy hint must round-trip")
	testing.expect(t, .First_Ore in data.tutorial_flags, "First_Ore hint must round-trip")
	testing.expect(t, .First_Shrine in data.tutorial_flags, "First_Shrine hint must round-trip")
	testing.expect(
		t,
		.First_Torch not_in data.tutorial_flags,
		"unset hints must stay unset across the round-trip",
	)
	testing.expect(t, .First_Status not_in data.tutorial_flags, "unset hints must stay unset")
}

// ─── v14 rejection / robustness tests ─────────────────────────────────────────

@(test)
v14_save_data_is_rejected_when_crc_does_not_match_payload :: proc(t: ^testing.T) {
	payload := new(Save_Data)
	defer free(payload)
	payload.depth = 2

	buf := build_v14_buf(payload, nil)
	defer delete(buf)

	// Corrupt one payload byte WITHOUT updating the CRC.
	buf[size_of(Save_Header)] ~= 0xFF

	header: Save_Header
	mem.copy(&header, &buf[0], size_of(Save_Header))
	data, floors, ok := load_save_data(header, buf)
	testing.expect(t, !ok, "corrupted payload must be rejected")
	testing.expect(t, data == nil, "returned data must be nil on CRC mismatch")
	testing.expect(t, floors == nil, "returned floors must be nil on CRC mismatch")
}

@(test)
v14_save_data_is_rejected_when_a_floor_record_is_truncated :: proc(t: ^testing.T) {
	// A file that claims a floor but is short by one byte of the record must be
	// rejected — a torn write must not let a partial floor through.
	payload := new(Save_Data)
	defer free(payload)
	floors := make([]Save_Floor_Record, 1)
	defer delete(floors)
	floors[0].depth = 3

	buf := build_v14_buf(payload, floors)
	defer delete(buf)

	header: Save_Header
	mem.copy(&header, &buf[0], size_of(Save_Header))

	truncated := buf[:len(buf) - 1]
	data, got, ok := load_save_data(header, truncated)
	testing.expect(t, !ok, "truncated floor record must be rejected")
	testing.expect(t, data == nil, "returned data must be nil on truncation")
	testing.expect(t, got == nil, "returned floors must be nil on truncation")
}

@(test)
v14_save_data_is_rejected_when_buffer_is_truncated_before_floor_count :: proc(t: ^testing.T) {
	payload := new(Save_Data)
	defer free(payload)

	buf := build_v14_buf(payload, nil)
	defer delete(buf)

	header: Save_Header
	mem.copy(&header, &buf[0], size_of(Save_Header))

	// Slice away the floor-count prefix entirely — buffer is now too short to hold
	// even the fixed Save_Data + count.
	truncated := buf[:size_of(Save_Header) + size_of(Save_Data)]
	data, got, ok := load_save_data(header, truncated)
	testing.expect(t, !ok, "buffer missing the floor count must be rejected")
	testing.expect(t, data == nil, "returned data must be nil on truncation")
	testing.expect(t, got == nil, "returned floors must be nil on truncation")
}

@(test)
v14_save_data_is_rejected_when_buffer_is_oversized :: proc(t: ^testing.T) {
	payload := new(Save_Data)
	defer free(payload)

	good := build_v14_buf(payload, nil)
	defer delete(good)

	// Build a buf one byte larger than the expected size; keep header + payload CRC
	// valid for the in-spec prefix so only the oversize is the defect.
	buf := make([]u8, len(good) + 1)
	defer delete(buf)
	mem.copy(raw_data(buf), raw_data(good), len(good))

	header: Save_Header
	mem.copy(&header, &buf[0], size_of(Save_Header))
	data, got, ok := load_save_data(header, buf)
	testing.expect(t, !ok, "oversized buffer must be rejected")
	testing.expect(t, data == nil, "returned data must be nil on oversized buffer")
	testing.expect(t, got == nil, "returned floors must be nil on oversized buffer")
}

@(test)
v14_save_data_is_rejected_when_floor_count_exceeds_max :: proc(t: ^testing.T) {
	// A file claiming more floors than reachable depths must be rejected before any
	// allocation — an oversize count could otherwise overflow the size arithmetic.
	payload := new(Save_Data)
	defer free(payload)

	buf := build_v14_buf(payload, nil)
	defer delete(buf)

	// Overwrite the floor-count prefix with an impossible value.
	count_offset := size_of(Save_Header) + size_of(Save_Data)
	bad_count := u32(MAX_SAVE_FLOORS) + 1
	mem.copy(&buf[count_offset], &bad_count, size_of(u32))
	// Re-checksum so only the count is the defect (not a CRC mismatch).
	crc := hash.crc32(buf[size_of(Save_Header):])
	header := Save_Header {
		magic   = SAVE_MAGIC,
		version = SAVE_VERSION,
		crc32   = crc,
	}
	mem.copy(&buf[0], &header, size_of(Save_Header))

	data, got, ok := load_save_data(header, buf)
	testing.expect(t, !ok, "an over-max floor count must be rejected")
	testing.expect(t, data == nil, "returned data must be nil on over-max floor count")
	testing.expect(t, got == nil, "returned floors must be nil on over-max floor count")
}

@(test)
v14_save_data_is_rejected_when_a_floor_depth_is_out_of_range :: proc(t: ^testing.T) {
	// A floor record tagged with a depth outside 0..=MAX_DEPTH must be rejected so it
	// can never write into an invalid visited_floors slot on restore.
	payload := new(Save_Data)
	defer free(payload)
	floors := make([]Save_Floor_Record, 1)
	defer delete(floors)
	floors[0].depth = i32(gcore.MAX_DEPTH) + 1 // out of range

	buf := build_v14_buf(payload, floors)
	defer delete(buf)

	header: Save_Header
	mem.copy(&header, &buf[0], size_of(Save_Header))
	data, got, ok := load_save_data(header, buf)
	testing.expect(t, !ok, "an out-of-range floor depth must be rejected")
	testing.expect(t, data == nil, "returned data must be nil on bad depth")
	testing.expect(t, got == nil, "returned floors must be nil on bad depth")

	// Negative depth must also be rejected.
	floors[0].depth = -1
	buf2 := build_v14_buf(payload, floors)
	defer delete(buf2)
	header2: Save_Header
	mem.copy(&header2, &buf2[0], size_of(Save_Header))
	data2, got2, ok2 := load_save_data(header2, buf2)
	testing.expect(t, !ok2, "a negative floor depth must be rejected")
	testing.expect(t, data2 == nil, "returned data must be nil on negative depth")
	testing.expect(t, got2 == nil, "returned floors must be nil on negative depth")
}

@(test)
v14_save_data_clamps_enemy_and_item_counts_above_capacity :: proc(t: ^testing.T) {
	// Over-capacity counts in both Save_Data and a floor record must be clamped.
	payload := new(Save_Data)
	defer free(payload)
	payload.enemy_count = MAX_SAVE_ENEMIES + 999
	payload.item_count = MAX_SAVE_ITEMS + 999
	payload.room_count = MAX_SAVE_ROOMS + 999
	payload.depth = 6

	floors := make([]Save_Floor_Record, 1)
	defer delete(floors)
	floors[0].depth = 2
	floors[0].floor.enemy_count = MAX_SAVE_ENEMIES + 999
	floors[0].floor.item_count = MAX_SAVE_ITEMS + 999
	floors[0].floor.room_count = MAX_SAVE_ROOMS + 999

	buf := build_v14_buf(payload, floors)
	defer delete(buf)

	header: Save_Header
	mem.copy(&header, &buf[0], size_of(Save_Header))
	data, got, ok := load_save_data(header, buf)
	testing.expect(t, ok, "load must succeed even with over-capacity counts")
	if data == nil {return}
	defer free(data)
	defer delete(got)

	testing.expect(
		t,
		data.enemy_count <= MAX_SAVE_ENEMIES,
		"enemy_count must be clamped to MAX_SAVE_ENEMIES",
	)
	testing.expect(
		t,
		data.item_count <= MAX_SAVE_ITEMS,
		"item_count must be clamped to MAX_SAVE_ITEMS",
	)
	testing.expect(
		t,
		data.room_count <= MAX_SAVE_ROOMS,
		"room_count must be clamped to MAX_SAVE_ROOMS",
	)
	testing.expect_value(t, data.depth, 6)

	if len(got) == 1 {
		testing.expect(
			t,
			got[0].floor.enemy_count <= MAX_SAVE_ENEMIES,
			"floor enemy_count must be clamped",
		)
		testing.expect(
			t,
			got[0].floor.item_count <= MAX_SAVE_ITEMS,
			"floor item_count must be clamped",
		)
		testing.expect(
			t,
			got[0].floor.room_count <= MAX_SAVE_ROOMS,
			"floor room_count must be clamped",
		)
	}
}
