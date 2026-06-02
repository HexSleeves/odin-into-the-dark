package engine

import "core:math"
import "core:math/rand"

ENGINE_MAX_PARTICLES :: 256

Particle :: struct {
	pos:    [2]f32,
	vel:    [2]f32,
	color:  Engine_Color,
	life:   f32,
	decay:  f32,
	size:   f32,
	active: bool,
}

Particle_Manager :: struct {
	pool: [ENGINE_MAX_PARTICLES]Particle,
}

particle_manager_make :: proc() -> Particle_Manager {
	return Particle_Manager{}
}

particle_manager_active_count :: proc(particles: ^Particle_Manager) -> int {
	if particles == nil {
		return 0
	}
	count := 0
	for &particle in particles.pool {
		if particle.active {
			count += 1
		}
	}
	return count
}

particle_manager_spawn_pixels :: proc(
	particles: ^Particle_Manager,
	x, y: f32,
	color: Engine_Color,
	count: int,
	speed: f32 = 2.0,
) {
	if particles == nil {
		return
	}
	spawned := 0
	for &particle in particles.pool {
		if spawned >= count {break}
		if particle.active {continue}

		angle := rand.float32() * 2.0 * math.PI
		spd := speed * (0.5 + rand.float32() * 0.5)
		particle.pos = {x, y}
		particle.vel = {math.cos(angle) * spd, math.sin(angle) * spd}
		particle.color = color
		particle.life = 1.0
		particle.decay = 0.02 + rand.float32() * 0.02
		particle.size = 2.0 + f32(rand.int_max(3))
		particle.active = true
		spawned += 1
	}
}

particle_manager_update :: proc(particles: ^Particle_Manager) {
	if particles == nil {
		return
	}
	for &particle in particles.pool {
		if !particle.active {continue}

		particle.pos[0] += particle.vel[0]
		particle.pos[1] += particle.vel[1]
		particle.vel[0] *= 0.92
		particle.vel[1] *= 0.92
		particle.vel[1] += 0.1
		particle.life -= particle.decay

		if particle.life <= 0 {
			particle.active = false
		}
	}
}

particle_manager_render :: proc(engine: ^Engine, particles: ^Particle_Manager) {
	if particles == nil {
		return
	}
	for &particle in particles.pool {
		if !particle.active {continue}

		alpha := u8(particle.life * f32(particle.color.a))
		color := Engine_Color {
			r = particle.color.r,
			g = particle.color.g,
			b = particle.color.b,
			a = alpha,
		}
		size := i32(particle.size * particle.life)
		if size < 1 {size = 1}
		engine_render_draw_rectangle(engine, i32(particle.pos[0]), i32(particle.pos[1]), size, size, color)
	}
}

