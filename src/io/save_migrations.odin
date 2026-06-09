package gameio

import gcore "../core"
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

load_save_data :: proc(header: Save_Header, buf: []u8) -> (data: ^Save_Data, ok: bool) {
	if header.magic != SAVE_MAGIC {return nil, false}

	data_offset :: size_of(Save_Header)

	if header.version == SAVE_VERSION {
		expected_size := size_of(Save_Header) + size_of(Save_Data)
		if len(buf) != expected_size {return nil, false}

		data = new(Save_Data)
		if data == nil {return nil, false}
		mem.copy(data, &buf[data_offset], size_of(Save_Data))
		return data, true
	}

	if header.version == SAVE_VERSION_V8 {
		expected_size := size_of(Save_Header) + size_of(Save_Data_V8)
		if len(buf) != expected_size {return nil, false}
		old := new(Save_Data_V8)
		if old == nil {return nil, false}
		defer free(old)
		mem.copy(old, &buf[data_offset], size_of(Save_Data_V8))
		data = new(Save_Data)
		if data == nil {return nil, false}
		// V9 is V8 + per-entity status. Copy V8 prefix; fold legacy scalars.
		mem.copy(data, old, size_of(Save_Data_V8))
		migrate_legacy_status_fields(data)
		return data, true
	}

	if header.version == SAVE_VERSION_V7 {
		expected_size := size_of(Save_Header) + size_of(Save_Data_V7)
		if len(buf) != expected_size {return nil, false}
		old := new(Save_Data_V7)
		if old == nil {return nil, false}
		defer free(old)
		mem.copy(old, &buf[data_offset], size_of(Save_Data_V7))
		data = new(Save_Data)
		if data == nil {return nil, false}
		// V8 is V7 + dialogue state. Copy V7 prefix; dialogue fields zero-init.
		mem.copy(data, old, size_of(Save_Data_V7))
		migrate_legacy_status_fields(data)
		return data, true
	}

	if header.version == SAVE_VERSION_V6 {
		expected_size := size_of(Save_Header) + size_of(Save_Data_V6)
		if len(buf) != expected_size {return nil, false}
		old := new(Save_Data_V6)
		if old == nil {return nil, false}
		defer free(old)
		mem.copy(old, &buf[data_offset], size_of(Save_Data_V6))
		data = new(Save_Data)
		if data == nil {return nil, false}
		mem.copy(data, old, size_of(Save_Data_V6))
		migrate_legacy_status_fields(data)
		return data, true
	}

	if header.version == SAVE_VERSION_V4 {
		expected_size := size_of(Save_Header) + size_of(Save_Data_V4)
		if len(buf) != expected_size {return nil, false}
		old := new(Save_Data_V4)
		if old == nil {return nil, false}
		defer free(old)
		mem.copy(old, &buf[data_offset], size_of(Save_Data_V4))
		data = new(Save_Data)
		if data == nil {return nil, false}
		// V5 is V4 + status timers. Copy V4 prefix; status timers zero-init.
		mem.copy(data, old, size_of(Save_Data_V4))
		migrate_legacy_status_fields(data)
		return data, true
	}

	if header.version == SAVE_VERSION_V3 {
		expected_size := size_of(Save_Header) + size_of(Save_Data_V3)
		if len(buf) != expected_size {return nil, false}
		old := new(Save_Data_V3)
		if old == nil {return nil, false}
		defer free(old)
		mem.copy(old, &buf[data_offset], size_of(Save_Data_V3))
		data = new(Save_Data)
		if data == nil {return nil, false}
		// V5 is V3 + items_found/status timers. Copy V3 prefix; additions zero-init.
		mem.copy(data, old, size_of(Save_Data_V3))
		migrate_legacy_status_fields(data)
		return data, true
	}

	if header.version == SAVE_VERSION_V2 {
		expected_size := size_of(Save_Header) + size_of(Save_Data_V2)
		if len(buf) != expected_size {return nil, false}
		old := new(Save_Data_V2)
		if old == nil {return nil, false}
		defer free(old)
		mem.copy(old, &buf[data_offset], size_of(Save_Data_V2))
		data = new(Save_Data)
		if data == nil {return nil, false}
		// V5 is a superset of V3 which is a prefix of V2. Copy V3-sized prefix.
		mem.copy(data, old, size_of(Save_Data_V3))
		migrate_legacy_status_fields(data)
		return data, true
	}

	return nil, false
}

// ─── Load ─────────────────────────────────────────────────────────────────────
