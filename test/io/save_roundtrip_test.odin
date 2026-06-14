#+build !js
package gameio

import gcore "../core"
import "core:hash"
import "core:mem"
import "core:testing"

// ─── v11 layout invariants ──────────────────────────────────────────────────────

@(test)
v11_save_data_layout_has_expected_byte_size_relationship :: proc(t: ^testing.T) {
	// The v11 diet removed the dead Tile vis/explored/light fields and instead
	// appends a dedicated tile_states array. Net: the per-cell tile-state bytes
	// moved out of every Tile grid and into a single trailing array. The payload
	// must still be exactly Save_Header + Save_Data on disk, and the tile_states
	// field is the LAST member so future appends do not disturb earlier offsets.
	// tile_states is the final field: its size equals the trailing bytes of the
	// struct, i.e. total size minus the field's offset. The same array type is
	// the last field of Save_Floor, so the trailing-byte count must match.
	data_tile_states_size := size_of(Save_Data) - int(offset_of(Save_Data, tile_states))
	floor_tile_states_size := size_of(Save_Floor) - int(offset_of(Save_Floor, tile_states))
	testing.expect_value(t, data_tile_states_size, floor_tile_states_size)

	// Each tile-state cell carries (visible, explored, light_level) for every map
	// cell; the array must be non-empty (the diet did not delete the carrier).
	testing.expect(t, data_tile_states_size > 0, "tile_states array must carry the engine layer")
}

// ─── v11 round-trip tests ───────────────────────────────────────────────────────

@(test)
v11_save_data_round_trips_correctly :: proc(t: ^testing.T) {
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

	buf := make([]u8, size_of(Save_Header) + size_of(Save_Data))
	defer delete(buf)

	// Copy payload first, compute CRC over it, then write header.
	mem.copy(&buf[size_of(Save_Header)], payload, size_of(Save_Data))
	crc := hash.crc32(buf[size_of(Save_Header):])

	header := Save_Header {
		magic   = SAVE_MAGIC,
		version = SAVE_VERSION,
		crc32   = crc,
	}
	mem.copy(&buf[0], &header, size_of(Save_Header))

	data, ok := load_save_data(header, buf)
	testing.expect(t, ok, "v11 round-trip must succeed")
	if data == nil {return}
	defer free(data)

	testing.expect_value(t, data.depth, 8)
	testing.expect_value(t, data.kills, 42)
	testing.expect_value(t, data.enemy_count, 3)
	testing.expect_value(t, data.item_count, 2)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Poison], 5)
	testing.expect(t, data.tile_states[idx].visible, "tile-state visibility must round-trip")
	testing.expect(t, data.tile_states[idx].explored, "tile-state exploration must round-trip")
	testing.expect_value(t, data.tile_states[idx].light_level, f32(0.5))
}

@(test)
v11_save_data_is_rejected_when_crc_does_not_match_payload :: proc(t: ^testing.T) {
	payload := new(Save_Data)
	defer free(payload)
	payload.depth = 2

	buf := make([]u8, size_of(Save_Header) + size_of(Save_Data))
	defer delete(buf)

	mem.copy(&buf[size_of(Save_Header)], payload, size_of(Save_Data))
	crc := hash.crc32(buf[size_of(Save_Header):])

	header := Save_Header {
		magic   = SAVE_MAGIC,
		version = SAVE_VERSION,
		crc32   = crc,
	}
	mem.copy(&buf[0], &header, size_of(Save_Header))

	// Corrupt one payload byte WITHOUT updating the CRC.
	buf[size_of(Save_Header)] ~= 0xFF

	data, ok := load_save_data(header, buf)
	testing.expect(t, !ok, "corrupted payload must be rejected")
	testing.expect(t, data == nil, "returned data must be nil on CRC mismatch")
}

@(test)
v11_save_data_is_rejected_when_buffer_is_truncated :: proc(t: ^testing.T) {
	payload := new(Save_Data)
	defer free(payload)

	// Build a valid-sized buf first, slice it shorter.
	full_size := size_of(Save_Header) + size_of(Save_Data)
	buf := make([]u8, full_size)
	defer delete(buf)

	mem.copy(&buf[size_of(Save_Header)], payload, size_of(Save_Data))
	crc := hash.crc32(buf[size_of(Save_Header):])
	header := Save_Header {
		magic   = SAVE_MAGIC,
		version = SAVE_VERSION,
		crc32   = crc,
	}
	mem.copy(&buf[0], &header, size_of(Save_Header))

	// Pass a truncated slice — load must reject it.
	truncated := buf[:full_size - 1]
	data, ok := load_save_data(header, truncated)
	testing.expect(t, !ok, "truncated buffer must be rejected")
	testing.expect(t, data == nil, "returned data must be nil on truncation")
}

@(test)
v11_save_data_is_rejected_when_buffer_is_oversized :: proc(t: ^testing.T) {
	payload := new(Save_Data)
	defer free(payload)

	// Build a buf one byte larger than the expected size.
	full_size := size_of(Save_Header) + size_of(Save_Data)
	buf := make([]u8, full_size + 1)
	defer delete(buf)

	mem.copy(&buf[size_of(Save_Header)], payload, size_of(Save_Data))
	crc := hash.crc32(buf[size_of(Save_Header):size_of(Save_Header) + size_of(Save_Data)])
	header := Save_Header {
		magic   = SAVE_MAGIC,
		version = SAVE_VERSION,
		crc32   = crc,
	}
	mem.copy(&buf[0], &header, size_of(Save_Header))

	data, ok := load_save_data(header, buf)
	testing.expect(t, !ok, "oversized buffer must be rejected")
	testing.expect(t, data == nil, "returned data must be nil on oversized buffer")
}

@(test)
v11_save_data_clamps_enemy_and_item_counts_above_capacity :: proc(t: ^testing.T) {
	payload := new(Save_Data)
	defer free(payload)
	// Set counts above their fixed-array capacities.
	payload.enemy_count = MAX_SAVE_ENEMIES + 999
	payload.item_count = MAX_SAVE_ITEMS + 999
	payload.room_count = MAX_SAVE_ROOMS + 999
	payload.depth = 6

	buf := make([]u8, size_of(Save_Header) + size_of(Save_Data))
	defer delete(buf)

	mem.copy(&buf[size_of(Save_Header)], payload, size_of(Save_Data))
	crc := hash.crc32(buf[size_of(Save_Header):])
	header := Save_Header {
		magic   = SAVE_MAGIC,
		version = SAVE_VERSION,
		crc32   = crc,
	}
	mem.copy(&buf[0], &header, size_of(Save_Header))

	data, ok := load_save_data(header, buf)
	testing.expect(t, ok, "load must succeed even with over-capacity counts")
	if data == nil {return}
	defer free(data)

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
}
