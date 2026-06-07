package main

import eng "./engine"
import "core:mem"
import "core:os"
import "core:testing"

@(test)
save_current_floor_uses_heap_allocator_even_under_frame_allocator :: proc(t: ^testing.T) {
	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)
	game.depth = SURFACE_DEPTH
	generate_map(&content, game)

	track: mem.Tracking_Allocator
	previous_allocator := context.allocator
	mem.tracking_allocator_init(&track, previous_allocator)
	defer mem.tracking_allocator_destroy(&track)

	context.allocator = mem.tracking_allocator(&track)
	ok := save_current_floor(game)
	context.allocator = previous_allocator
	testing.expect(t, ok)
	testing.expect_value(t, len(track.allocation_map), 0)
}

@(test)
load_game_from_path_uses_heap_allocator_for_persistent_loaded_state :: proc(t: ^testing.T) {
	path := "/tmp/into-the-depths-allocator-load.dat"
	defer os.remove(path)

	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)
	game.depth = SURFACE_DEPTH
	generate_map(&content, game)
	messages := message_manager_make()
	camera := eng.camera_manager_make()
	descend(&content, &camera, &messages, game)

	turns := eng.turn_manager_make()
	testing.expect(t, save_game_to_path(&turns, game, path))

	loaded: Game
	loaded_turns := eng.turn_manager_make()
	loaded_camera := eng.camera_manager_make()
	vfx := eng.vfx_manager_make()
	ui := ui_manager_make(false)
	loaded_messages := message_manager_make()

	track: mem.Tracking_Allocator
	previous_allocator := context.allocator
	mem.tracking_allocator_init(&track, previous_allocator)
	defer mem.tracking_allocator_destroy(&track)

	context.allocator = mem.tracking_allocator(&track)
	ok := load_game_from_path(
		&content,
		&loaded_turns,
		&loaded_camera,
		&vfx,
		&ui,
		&loaded_messages,
		&loaded,
		path,
	)
	context.allocator = previous_allocator

	testing.expect(t, ok)
	testing.expect_value(t, len(track.allocation_map), 0)
	game_cleanup(&loaded)
}
