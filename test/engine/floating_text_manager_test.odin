#+build !js
package engine

import "core:testing"

@(test)
floating_text_manager_spawns_and_expires_a_damage_number :: proc(t: ^testing.T) {
	ft := floating_text_manager_make()
	testing.expect_value(t, floating_text_manager_active_count(&ft), 0)

	floating_text_manager_spawn(&ft, 4, 7, "12", engine_color_make(255, 90, 90, 255))
	testing.expect_value(t, floating_text_manager_active_count(&ft), 1)

	entry := &ft.pool[0]
	testing.expect_value(t, entry.tile_x, 4)
	testing.expect_value(t, entry.tile_y, 7)
	testing.expect_value(t, floating_text_text(entry), "12")

	// Run enough update ticks to fully decay the entry (life starts at 1.0).
	for _ in 0 ..< 60 {
		floating_text_manager_update(&ft)
	}
	testing.expect_value(t, floating_text_manager_active_count(&ft), 0)
}

@(test)
floating_text_manager_caps_at_pool_size :: proc(t: ^testing.T) {
	ft := floating_text_manager_make()

	// Spawn more than the pool can hold; extras are dropped silently.
	for i in 0 ..< ENGINE_MAX_FLOATING_TEXTS + 5 {
		floating_text_manager_spawn(&ft, i, 0, "9", engine_color_make(255, 255, 255, 255))
	}

	testing.expect_value(t, floating_text_manager_active_count(&ft), ENGINE_MAX_FLOATING_TEXTS)
}

@(test)
floating_text_manager_truncates_text_to_buffer_capacity :: proc(t: ^testing.T) {
	ft := floating_text_manager_make()

	long := "0123456789ABCDEFGHIJ" // longer than ENGINE_FLOATING_TEXT_MAX_LEN
	floating_text_manager_spawn(&ft, 0, 0, long, engine_color_make(1, 1, 1, 1))

	testing.expect_value(t, ft.pool[0].len, ENGINE_FLOATING_TEXT_MAX_LEN)
	testing.expect_value(t, len(floating_text_text(&ft.pool[0])), ENGINE_FLOATING_TEXT_MAX_LEN)
}
