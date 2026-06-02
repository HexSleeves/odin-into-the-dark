package engine

import "core:testing"
import rl "vendor:raylib"

@(test)
vfx_manager_tracks_frame_and_flash :: proc(t: ^testing.T) {
	vfx := vfx_manager_make()

	testing.expect_value(t, vfx_manager_frame(&vfx), 0)
	vfx_manager_tick_frame(&vfx)
	vfx_manager_tick_frame(&vfx)
	testing.expect_value(t, vfx_manager_frame(&vfx), 2)

	vfx_manager_flash(&vfx, rl.RED, 0.5)
	testing.expect_value(t, vfx.flash_color, rl.RED)
	testing.expect_value(t, vfx.flash_alpha, f32(0.5))
}

@(test)
vfx_manager_fades_and_resets_flash :: proc(t: ^testing.T) {
	vfx := vfx_manager_make()
	vfx_manager_flash(&vfx, rl.WHITE, 0.005)

	vfx_manager_fade_flash(&vfx, 0.85)

	testing.expect_value(t, vfx.flash_alpha, f32(0))
	vfx_manager_tick_frame(&vfx)
	vfx_manager_reset(&vfx)
	testing.expect_value(t, vfx_manager_frame(&vfx), 0)
}
