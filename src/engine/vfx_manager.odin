package engine

import rl "vendor:raylib"

Vfx_Manager :: struct {
	flash_color: rl.Color,
	flash_alpha: f32,
	anim_frame:  int,
}

vfx_manager_make :: proc() -> Vfx_Manager {
	return Vfx_Manager{}
}

vfx_manager_frame :: proc(vfx: ^Vfx_Manager) -> int {
	if vfx == nil {
		return 0
	}
	return vfx.anim_frame
}

vfx_manager_tick_frame :: proc(vfx: ^Vfx_Manager) -> int {
	if vfx == nil {
		return 0
	}
	vfx.anim_frame += 1
	return vfx.anim_frame
}

vfx_manager_flash :: proc(vfx: ^Vfx_Manager, color: rl.Color, alpha: f32) {
	if vfx == nil {
		return
	}
	vfx.flash_color = color
	vfx.flash_alpha = alpha
}

vfx_manager_fade_flash :: proc(vfx: ^Vfx_Manager, factor: f32) {
	if vfx == nil {
		return
	}
	vfx.flash_alpha *= factor
	if vfx.flash_alpha < 0.01 {
		vfx.flash_alpha = 0
	}
}

vfx_manager_reset :: proc(vfx: ^Vfx_Manager) {
	if vfx == nil {
		return
	}
	vfx^ = {}
}
