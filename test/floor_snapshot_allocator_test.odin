package main

import "core:mem"
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
