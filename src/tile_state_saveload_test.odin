package main

import "core:os"
import "core:testing"
import "core:mem"
import eng "./engine"

@(test)
save_load_preserves_engine_tile_state_layer :: proc(t: ^testing.T) {
	path := "/tmp/into-the-depths-tile-state-save.dat"
	defer os.remove(path)

	game: Game
	game_init_world(&game)
	game.player.pos = Vec2{1, 1}
	game.player.hp = 10
	game.player.max_hp = 10
	testing.expect(t, tile_state_set(&game, 2, 1, true, true, 0.75))

	turns := eng.turn_manager_make()
	testing.expect(t, save_game_to_path(&turns, &game, path))
	buf, read_err := os.read_entire_file(path, context.allocator)
	testing.expect(t, read_err == nil)
	defer delete(buf, context.allocator)

	header: Save_Header
	mem.copy(&header, &buf[0], size_of(Save_Header))
	data, data_ok := load_save_data(header, buf)
	testing.expect(t, data_ok)
	if data_ok {
		defer free(data)
		idx := pos_to_idx(2, 1)
		testing.expect(t, data.tiles[idx].visible)
		testing.expect(t, data.tiles[idx].explored)
		testing.expect_value(t, data.tiles[idx].light_level, f32(0.75))
	}

	content := content_manager_make()
	loaded: Game
	loaded_turns := eng.turn_manager_make()
	camera := eng.camera_manager_make()
	vfx := eng.vfx_manager_make()
	ui := ui_manager_make(false)
	messages := message_manager_make()

	testing.expect(
		t,
		load_game_from_path(&content, &loaded_turns, &camera, &vfx, &ui, &messages, &loaded, path),
	)
	testing.expect(t, tile_explored_at(&loaded, 2, 1))
}
