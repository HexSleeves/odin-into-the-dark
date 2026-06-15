#+build !js
package main

import eng "./engine"
import "core:mem"
import "core:os"
import "core:testing"

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
		// v11 serializes the engine tile-state layer via a dedicated array, not
		// via mirrored Tile fields (which no longer exist).
		testing.expect(t, data.tile_states[idx].visible)
		testing.expect(t, data.tile_states[idx].explored)
		testing.expect_value(t, data.tile_states[idx].light_level, f32(0.75))
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

@(test)
tile_struct_shrank_to_terrain_type_only :: proc(t: ^testing.T) {
	// The data-model diet dropped Tile.visible/explored/light_level; Tile now
	// carries only its terrain Tile_Type. Guard against the dead fields creeping
	// back in (which would re-inflate the ~32 KB tile grids on Game).
	testing.expect_value(t, size_of(Tile), size_of(Tile_Type))
}

@(test)
game_struct_shrank_after_tile_diet :: proc(t: ^testing.T) {
	// Game holds a full Tile grid plus per-cell ore + dijkstra grids. The tile diet
	// halved Tile (16->8 B); the data-model diet then (a) shrank each ore_veins entry
	// from a Save_String+color (24 B) to a single Ore_Kind byte — color/item ID are
	// derived from the kind — and (b) changed dijkstra_map from int (8 B) to i32 (4 B)
	// per cell. Together these cut the grid arrays by ~108 KB. Measured ~132 KB,
	// down from ~222 KB. Guard with headroom for later trailing-field appends.
	testing.expect(
		t,
		size_of(Game) < 160 * 1024,
		"Game struct must stay under 160 KB after the data-model diet",
	)
}

@(test)
ore_vein_is_a_single_kind_byte :: proc(t: ^testing.T) {
	// The data-model diet replaced Ore_Vein{ore_type:string, color} (24 B) with a
	// single Ore_Kind enum byte; the dropped per-cell string/color buffers were the
	// largest single contributor to Game's grid bloat. Guard against re-inflation.
	testing.expect_value(t, size_of(Ore_Vein), size_of(Ore_Kind))
	testing.expect_value(t, size_of(Ore_Vein), 1)
}
