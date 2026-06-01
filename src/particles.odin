package main

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

// Fixed-size particle pool — no dynamic allocation
MAX_PARTICLES :: 256

Particle :: struct {
	pos:    [2]f32, // screen pixel position
	vel:    [2]f32, // velocity in pixels per frame
	color:  rl.Color,
	life:   f32, // remaining life (0-1, decrements per frame)
	decay:  f32, // life decrement per frame
	size:   f32, // pixel size
	active: bool,
}

g_particles: [MAX_PARTICLES]Particle

// Spawn a burst of particles at a tile position (converted to screen-space)
spawn_particles :: proc(
	tile_x, tile_y: int,
	color: rl.Color,
	count: int,
	speed: f32 = 2.0,
	camera_x: int = 0,
	camera_y: int = 0,
) {
	// Convert tile position to screen pixel center
	cx := f32(tile_x * TILE_SIZE + TILE_SIZE / 2) - f32(camera_x)
	cy := f32(tile_y * TILE_SIZE + TILE_SIZE / 2) - f32(camera_y)

	spawned := 0
	for &p in g_particles {
		if spawned >= count {break}
		if p.active {continue}

		angle := rand.float32() * 2.0 * math.PI
		spd := speed * (0.5 + rand.float32() * 0.5)

		p.pos = {cx, cy}
		p.vel = {math.cos(angle) * spd, math.sin(angle) * spd}
		p.color = color
		p.life = 1.0
		p.decay = 0.02 + rand.float32() * 0.02 // 0.02-0.04 per frame
		p.size = 2.0 + f32(rand.int_max(3))
		p.active = true
		spawned += 1
	}
}

// Update all active particles (call once per frame)
update_particles :: proc() {
	for &p in g_particles {
		if !p.active {continue}

		p.pos[0] += p.vel[0]
		p.pos[1] += p.vel[1]
		p.vel[0] *= 0.92 // friction
		p.vel[1] *= 0.92
		p.vel[1] += 0.1 // slight gravity
		p.life -= p.decay

		if p.life <= 0 {
			p.active = false
		}
	}
}

// Render all active particles (call during drawing, inside scissor mode)
render_particles :: proc() {
	for &p in g_particles {
		if !p.active {continue}

		alpha := u8(p.life * f32(p.color.a))
		c := rl.Color{p.color.r, p.color.g, p.color.b, alpha}
		sz := i32(p.size * p.life)
		if sz < 1 {sz = 1}

		rl.DrawRectangle(i32(p.pos[0]), i32(p.pos[1]), sz, sz, c)
	}
}

// ─── Convenience spawners for specific events ─────────────────────────────────

spawn_hit_particles :: proc(tile_x, tile_y, cam_x, cam_y: int) {
	spawn_particles(tile_x, tile_y, rl.Color{255, 60, 60, 255}, 8, 2.5, cam_x, cam_y)
}

spawn_mine_particles :: proc(tile_x, tile_y, cam_x, cam_y: int) {
	spawn_particles(tile_x, tile_y, rl.Color{255, 200, 50, 255}, 12, 3.0, cam_x, cam_y)
}

spawn_pickup_particles :: proc(tile_x, tile_y, cam_x, cam_y: int) {
	spawn_particles(tile_x, tile_y, rl.Color{80, 255, 80, 255}, 6, 1.5, cam_x, cam_y)
}

spawn_death_particles :: proc(tile_x, tile_y, cam_x, cam_y: int) {
	spawn_particles(tile_x, tile_y, rl.Color{255, 0, 0, 255}, 30, 4.0, cam_x, cam_y)
}
