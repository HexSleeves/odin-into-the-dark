#+build !js
package gameio

import gcore "../core"
import "core:hash"
import "core:mem"
import "core:testing"

// ─── Legacy migration tests ────────────────────────────────────────────────────

@(test)
v7_save_data_migrates_into_current_layout :: proc(t: ^testing.T) {
	old := new(Save_Data_V7)
	defer free(old)
	old.depth = 3
	old.kills = 11
	old.poison_turns = 6
	old.burning_turns = 2
	old.frozen_turns = 1
	// web_stuck_turns not in V7 — will be zero-init in migrated data

	buf := make([]u8, size_of(Save_Header_Legacy) + size_of(Save_Data_V7))
	defer delete(buf)
	legacy_header := Save_Header_Legacy {
		magic   = SAVE_MAGIC,
		version = SAVE_VERSION_V7,
	}
	mem.copy(&buf[0], &legacy_header, size_of(Save_Header_Legacy))
	mem.copy(&buf[size_of(Save_Header_Legacy)], old, size_of(Save_Data_V7))

	header := Save_Header {
		magic   = SAVE_MAGIC,
		version = SAVE_VERSION_V7,
	}
	data, ok := load_save_data(header, buf)
	testing.expect(t, ok, "V7 migration must succeed")
	if data == nil {return}
	defer free(data)

	testing.expect_value(t, data.depth, 3)
	testing.expect_value(t, data.kills, 11)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Poison], 6)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Burning], 2)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Frozen], 1)
	// V7 has no web_stuck_turns field — must arrive zero.
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Webbed], 0)
	// Dialogue state (v8 addition) must be zero-init.
	testing.expect_value(t, data.seen_conv_count, 0)
	testing.expect_value(t, data.dlg_flag_count, 0)
	// Enemy/floor status (v9 addition) must be zero-init.
	zero: gcore.Status_Turns
	testing.expect_value(t, data.enemy_status[0], zero)
}

@(test)
v6_save_data_migrates_into_current_layout :: proc(t: ^testing.T) {
	old := new(Save_Data_V6)
	defer free(old)
	old.depth = 5
	old.turn_count = 100
	old.poison_turns = 3
	old.burning_turns = 7
	old.frozen_turns = 0

	buf := make([]u8, size_of(Save_Header_Legacy) + size_of(Save_Data_V6))
	defer delete(buf)
	legacy_header := Save_Header_Legacy {
		magic   = SAVE_MAGIC,
		version = SAVE_VERSION_V6,
	}
	mem.copy(&buf[0], &legacy_header, size_of(Save_Header_Legacy))
	mem.copy(&buf[size_of(Save_Header_Legacy)], old, size_of(Save_Data_V6))

	header := Save_Header {
		magic   = SAVE_MAGIC,
		version = SAVE_VERSION_V6,
	}
	data, ok := load_save_data(header, buf)
	testing.expect(t, ok, "V6 migration must succeed")
	if data == nil {return}
	defer free(data)

	testing.expect_value(t, data.depth, 5)
	testing.expect_value(t, data.turn_count, 100)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Poison], 3)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Burning], 7)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Frozen], 0)
	// V6 has no web_stuck_turns field — must arrive zero.
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Webbed], 0)
	// Floor stack (v7 addition) must be zero-init.
	testing.expect_value(t, data.visited_floor_present[0], false)
	// Dialogue state (v8 addition) must be zero-init.
	testing.expect_value(t, data.seen_conv_count, 0)
}

@(test)
v4_save_data_migrates_into_current_layout :: proc(t: ^testing.T) {
	old := new(Save_Data_V4)
	defer free(old)
	old.depth = 2
	old.kills = 5
	old.items_found = 8
	// V4 has no poison_turns/burning_turns/frozen_turns/web_stuck_turns —
	// all status kinds must arrive zero after migration.

	buf := make([]u8, size_of(Save_Header_Legacy) + size_of(Save_Data_V4))
	defer delete(buf)
	legacy_header := Save_Header_Legacy {
		magic   = SAVE_MAGIC,
		version = SAVE_VERSION_V4,
	}
	mem.copy(&buf[0], &legacy_header, size_of(Save_Header_Legacy))
	mem.copy(&buf[size_of(Save_Header_Legacy)], old, size_of(Save_Data_V4))

	header := Save_Header {
		magic   = SAVE_MAGIC,
		version = SAVE_VERSION_V4,
	}
	data, ok := load_save_data(header, buf)
	testing.expect(t, ok, "V4 migration must succeed")
	if data == nil {return}
	defer free(data)

	testing.expect_value(t, data.depth, 2)
	testing.expect_value(t, data.kills, 5)
	testing.expect_value(t, data.items_found, 8)
	// Status timers are v5 additions — all must zero after folding zero scalars.
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Poison], 0)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Burning], 0)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Frozen], 0)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Webbed], 0)
	// Quest (v6 addition) must be zero-init.
	zero_quest: Quest_State
	testing.expect_value(t, data.quest, zero_quest)
}

@(test)
v3_save_data_migrates_into_current_layout :: proc(t: ^testing.T) {
	old := new(Save_Data_V3)
	defer free(old)
	old.depth = 1
	old.seed = 0xDEADBEEF
	// V3 has no items_found, no status timers.

	buf := make([]u8, size_of(Save_Header_Legacy) + size_of(Save_Data_V3))
	defer delete(buf)
	legacy_header := Save_Header_Legacy {
		magic   = SAVE_MAGIC,
		version = SAVE_VERSION_V3,
	}
	mem.copy(&buf[0], &legacy_header, size_of(Save_Header_Legacy))
	mem.copy(&buf[size_of(Save_Header_Legacy)], old, size_of(Save_Data_V3))

	header := Save_Header {
		magic   = SAVE_MAGIC,
		version = SAVE_VERSION_V3,
	}
	data, ok := load_save_data(header, buf)
	testing.expect(t, ok, "V3 migration must succeed")
	if data == nil {return}
	defer free(data)

	testing.expect_value(t, data.depth, 1)
	testing.expect_value(t, data.seed, u64(0xDEADBEEF))
	// items_found (v4 addition) must be zero.
	testing.expect_value(t, data.items_found, 0)
	// All status timers (v5 addition) must be zero.
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Poison], 0)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Burning], 0)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Frozen], 0)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Webbed], 0)
}

@(test)
v2_save_data_migrates_into_current_layout :: proc(t: ^testing.T) {
	old := new(Save_Data_V2)
	defer free(old)
	old.depth = 4
	old.kills = 9
	old.pickaxe_durability = 99 // must be dropped; not present in migrated struct
	old.pickaxe_max_dur = 100 // must be dropped

	buf := make([]u8, size_of(Save_Header_Legacy) + size_of(Save_Data_V2))
	defer delete(buf)
	legacy_header := Save_Header_Legacy {
		magic   = SAVE_MAGIC,
		version = SAVE_VERSION_V2,
	}
	mem.copy(&buf[0], &legacy_header, size_of(Save_Header_Legacy))
	mem.copy(&buf[size_of(Save_Header_Legacy)], old, size_of(Save_Data_V2))

	header := Save_Header {
		magic   = SAVE_MAGIC,
		version = SAVE_VERSION_V2,
	}
	data, ok := load_save_data(header, buf)
	testing.expect(t, ok, "V2 migration must succeed")
	if data == nil {return}
	defer free(data)

	testing.expect_value(t, data.depth, 4)
	testing.expect_value(t, data.kills, 9)
	// Migration copies only Save_Data_V3-sized prefix — pickaxe fields are outside
	// that prefix and must NOT bleed into items_found or status timers.
	testing.expect_value(t, data.items_found, 0)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Poison], 0)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Burning], 0)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Frozen], 0)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Webbed], 0)
}

// ─── v10 round-trip tests ──────────────────────────────────────────────────────

@(test)
v10_save_data_round_trips_correctly :: proc(t: ^testing.T) {
	payload := new(Save_Data)
	defer free(payload)
	payload.depth = 8
	payload.kills = 42
	payload.enemy_count = 3
	payload.item_count = 2
	payload.player_status[gcore.Status_Kind.Poison] = 5

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
	testing.expect(t, ok, "v10 round-trip must succeed")
	if data == nil {return}
	defer free(data)

	testing.expect_value(t, data.depth, 8)
	testing.expect_value(t, data.kills, 42)
	testing.expect_value(t, data.enemy_count, 3)
	testing.expect_value(t, data.item_count, 2)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Poison], 5)
}

@(test)
v10_save_data_is_rejected_when_crc_does_not_match_payload :: proc(t: ^testing.T) {
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
v10_save_data_is_rejected_when_buffer_is_truncated :: proc(t: ^testing.T) {
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
v10_save_data_is_rejected_when_buffer_is_oversized :: proc(t: ^testing.T) {
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
v10_save_data_clamps_enemy_and_item_counts_above_capacity :: proc(t: ^testing.T) {
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
