package engine

import "core:math"

Vfx_Manager :: struct {
	flash_color:  Engine_Color,
	flash_alpha:  f32,
	anim_frame:   int,
	shake_amount: f32,
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
	vfx.shake_amount *= 0.75
	if vfx.shake_amount < 0.2 {
		vfx.shake_amount = 0
	}
	return vfx.anim_frame
}

vfx_manager_flash :: proc(vfx: ^Vfx_Manager, color: Engine_Color, alpha: f32) {
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

vfx_manager_shake :: proc(vfx: ^Vfx_Manager, amount: f32) {
	if vfx == nil {
		return
	}
	vfx.shake_amount = max(vfx.shake_amount, amount)
}

vfx_manager_shake_offset :: proc(vfx: ^Vfx_Manager) -> [2]f32 {
	if vfx == nil || vfx.shake_amount < 0.1 {
		return {0, 0}
	}
	f := f32(vfx.anim_frame)
	return {
		math.sin(f * 13.9898) * vfx.shake_amount,
		math.sin(f * 78.2330 + 1.1) * vfx.shake_amount,
	}
}
