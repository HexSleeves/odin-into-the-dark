#+build !js
package engine

import "core:testing"

@(test)
vfx_manager_tracks_frame_and_flash :: proc(t: ^testing.T) {
	vfx := vfx_manager_make()

	testing.expect_value(t, vfx_manager_frame(&vfx), 0)
	vfx_manager_tick_frame(&vfx)
	vfx_manager_tick_frame(&vfx)
	testing.expect_value(t, vfx_manager_frame(&vfx), 2)

	red := Engine_Color{230, 41, 55, 255} // rl.RED
	vfx_manager_flash(&vfx, red, 0.5)
	testing.expect_value(t, vfx.flash_color, red)
	testing.expect_value(t, vfx.flash_alpha, f32(0.5))
}

@(test)
vfx_manager_fades_and_resets_flash :: proc(t: ^testing.T) {
	vfx := vfx_manager_make()
	vfx_manager_flash(&vfx, Engine_Color{255, 255, 255, 255}, 0.005)

	vfx_manager_fade_flash(&vfx, 0.85)

	testing.expect_value(t, vfx.flash_alpha, f32(0))
	vfx_manager_tick_frame(&vfx)
	vfx_manager_reset(&vfx)
	testing.expect_value(t, vfx_manager_frame(&vfx), 0)
}

@(test)
vfx_manager_shake_decays_each_tick :: proc(t: ^testing.T) {
	vfx := vfx_manager_make()
	vfx_manager_shake(&vfx, 8.0)
	testing.expect(t, vfx.shake_amount == 8.0)

	// Offset is non-zero while shaking
	off := vfx_manager_shake_offset(&vfx)
	testing.expect(t, off[0] != 0 || off[1] != 0)

	// Decays toward zero over ticks
	for _ in 0 ..< 30 {
		vfx_manager_tick_frame(&vfx)
	}
	testing.expect(t, vfx.shake_amount == 0)
	off2 := vfx_manager_shake_offset(&vfx)
	testing.expect(t, off2[0] == 0 && off2[1] == 0)
}

@(test)
vfx_manager_shake_does_not_downgrade :: proc(t: ^testing.T) {
	vfx := vfx_manager_make()
	vfx_manager_shake(&vfx, 4.0)
	vfx_manager_shake(&vfx, 2.0) // weaker hit should not reduce existing shake
	testing.expect(t, vfx.shake_amount == 4.0)
	vfx_manager_shake(&vfx, 6.0) // stronger hit should upgrade
	testing.expect(t, vfx.shake_amount == 6.0)
}