#+build !js
package engine

import "core:testing"

@(test)
camera_manager_snaps_to_centered_focus :: proc(t: ^testing.T) {
	camera := camera_manager_make()

	camera_manager_update(&camera, 500, 400, 200, 100, 1000, 800, true)

	testing.expect_value(t, camera.x, 400)
	testing.expect_value(t, camera.y, 350)
	testing.expect_value(t, camera.target_x, 400)
	testing.expect_value(t, camera.target_y, 350)
}

@(test)
camera_manager_smooths_toward_target :: proc(t: ^testing.T) {
	camera := camera_manager_make()

	camera_manager_update(&camera, 500, 400, 200, 100, 1000, 800)

	testing.expect_value(t, camera.x, 80)
	testing.expect_value(t, camera.y, 70)
	testing.expect_value(t, camera.target_x, 400)
	testing.expect_value(t, camera.target_y, 350)
}

@(test)
camera_manager_centers_world_smaller_than_viewport :: proc(t: ^testing.T) {
	camera := camera_manager_make()

	camera_manager_update(&camera, 50, 50, 300, 200, 100, 80, true)

	testing.expect_value(t, camera.x, -100)
	testing.expect_value(t, camera.y, -60)
}
