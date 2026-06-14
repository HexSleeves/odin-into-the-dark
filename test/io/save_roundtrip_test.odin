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
	// appends a dedicated tile_states array. D4 appended tutorial_flags (game-global
	// onboarding hints) as Save_Data's trailing field, immediately after tile_states.
	// (The dead per-floor Save_Floor.tutorial_flags symmetry field was removed; its
	// trailing field is now tile_states itself.)
	data_tail_size := size_of(Save_Data) - int(offset_of(Save_Data, tutorial_flags))

	// tutorial_flags is a bit_set[Tutorial_Hint; u8]; the trailing span is at least
	// the field size (the struct may pad to its alignment after the last field).
	testing.expect(
		t,
		data_tail_size >= size_of(gcore.Tutorial_Flags),
		"trailing span must cover the tutorial_flags field",
	)

	// The tile-state array still carries the engine layer (the diet did not delete
	// the carrier); in Save_Data it sits immediately before the trailing tutorial_flags.
	data_tile_states_size :=
		int(offset_of(Save_Data, tutorial_flags)) - int(offset_of(Save_Data, tile_states))
	testing.expect(t, data_tile_states_size > 0, "tile_states array must carry the engine layer")

	// Save_Floor's trailing field is now tile_states (no per-floor tutorial_flags copy).
	floor_tile_tail := size_of(Save_Floor) - int(offset_of(Save_Floor, tile_states))
	testing.expect(t, floor_tile_tail > 0, "Save_Floor tile_states must carry the trailing engine layer")
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
tutorial_flags_survive_a_v11_save_and_restore_roundtrip :: proc(t: ^testing.T) {
	payload := new(Save_Data)
	defer free(payload)
	payload.depth = 4
	payload.tutorial_flags = {.First_Enemy, .First_Ore, .First_Shrine}

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
	testing.expect(t, ok, "v11 round-trip must succeed")
	if data == nil {return}
	defer free(data)

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
