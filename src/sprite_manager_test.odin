package main

import "core:testing"

@(test)
sprite_manager_make_wraps_current_sprite_atlas :: proc(t: ^testing.T) {
	sprites := sprite_manager_make()

	testing.expect(t, sprites.backend == &g_sprites)
}

@(test)
sprite_manager_reports_loaded_state_from_backend :: proc(t: ^testing.T) {
	sprites := sprite_manager_make()
	was_loaded := g_sprites.loaded
	defer g_sprites.loaded = was_loaded

	g_sprites.loaded = false
	testing.expect(t, !sprite_manager_is_loaded(&sprites))

	g_sprites.loaded = true
	testing.expect(t, sprite_manager_is_loaded(&sprites))
}

