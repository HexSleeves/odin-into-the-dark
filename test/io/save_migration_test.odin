#+build !js
package gameio

import gcore "../core"
import "core:mem"
import "core:testing"

@(test)
v8_save_data_migrates_legacy_status_fields_into_player_status :: proc(t: ^testing.T) {
	old := new(Save_Data_V8)
	defer free(old)
	old.poison_turns = 5
	old.burning_turns = 4
	old.frozen_turns = 3
	old.web_stuck_turns = 2
	old.depth = 7

	buf := make([]u8, size_of(Save_Header) + size_of(Save_Data_V8))
	defer delete(buf)
	header := Save_Header {
		magic   = SAVE_MAGIC,
		version = SAVE_VERSION_V8,
	}
	mem.copy(&buf[0], &header, size_of(Save_Header))
	mem.copy(&buf[size_of(Save_Header)], old, size_of(Save_Data_V8))

	data, ok := load_save_data(header, buf)
	testing.expect(t, ok)
	if data == nil {return}
	defer free(data)

	testing.expect_value(t, data.player_status[gcore.Status_Kind.Poison], 5)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Burning], 4)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Frozen], 3)
	testing.expect_value(t, data.player_status[gcore.Status_Kind.Webbed], 2)
	testing.expect_value(t, data.depth, 7)

	// Enemy statuses did not exist pre-v9 — they must arrive zeroed.
	zero: gcore.Status_Turns
	testing.expect_value(t, data.enemy_status[0], zero)
	testing.expect_value(t, data.floor_enemy_status[0][0], zero)
}
