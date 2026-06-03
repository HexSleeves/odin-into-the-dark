#+build !js
package engine

import "core:testing"

@(test)
world_manager_tracks_grid_and_pixel_extents :: proc(t: ^testing.T) {
	world := world_manager_make(80, 50, 32)

	testing.expect(t, world_manager_is_valid(world))
	testing.expect_value(t, world_manager_width(world), 80)
	testing.expect_value(t, world_manager_height(world), 50)
	testing.expect_value(t, world_manager_tile_size(world), 32)
	testing.expect_value(t, world_manager_cell_count(world), 4000)
	testing.expect_value(t, world_manager_pixel_width(world), 2560)
	testing.expect_value(t, world_manager_pixel_height(world), 1600)
}

@(test)
world_manager_delegates_bounds_and_indexing_to_grid :: proc(t: ^testing.T) {
	world := world_manager_make(4, 3, 16)

	testing.expect(t, world_manager_contains(world, 0, 0))
	testing.expect(t, world_manager_contains(world, 3, 2))
	testing.expect(t, !world_manager_contains(world, 4, 2))
	testing.expect(t, !world_manager_contains(world, -1, 0))
	testing.expect_value(t, world_manager_index(world, 3, 2), 11)

	pos := world_manager_position(world, 11)
	testing.expect_value(t, pos.x, 3)
	testing.expect_value(t, pos.y, 2)
}

@(test)
world_manager_rejects_invalid_dimensions_or_tile_size :: proc(t: ^testing.T) {
	missing_width := world_manager_make(0, 3, 16)
	missing_height := world_manager_make(3, 0, 16)
	missing_tile := world_manager_make(3, 3, 0)

	testing.expect(t, !world_manager_is_valid(missing_width))
	testing.expect(t, !world_manager_is_valid(missing_height))
	testing.expect(t, !world_manager_is_valid(missing_tile))
	testing.expect_value(t, world_manager_pixel_width(missing_tile), 0)
	testing.expect_value(t, world_manager_pixel_height(missing_tile), 0)
}
