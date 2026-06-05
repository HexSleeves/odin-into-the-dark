package renderer

import gcore "../core"

import eng "../engine"

MAX_PARTICLES :: eng.ENGINE_MAX_PARTICLES
Particle :: eng.Particle
Particle_Manager :: eng.Particle_Manager

particle_manager_make :: proc() -> Particle_Manager {
	return eng.particle_manager_make()
}

particle_manager_active_count :: proc(particles: ^Particle_Manager) -> int {
	return eng.particle_manager_active_count(particles)
}

// Spawn a burst of particles at a tile position (converted to screen-space)
particle_manager_spawn :: proc(
	particles: ^Particle_Manager,
	tile_x, tile_y: int,
	color: eng.Engine_Color,
	count: int,
	speed: f32 = 2.0,
	camera_x: int = 0,
	camera_y: int = 0,
) {
	// Convert tile position to screen pixel center
	cx := f32(tile_x * gcore.TILE_SIZE + gcore.TILE_SIZE / 2) - f32(camera_x)
	cy := f32(tile_y * gcore.TILE_SIZE + gcore.TILE_SIZE / 2) - f32(camera_y)
	eng.particle_manager_spawn_pixels(particles, cx, cy, color, count, speed)
}

// Update all active particles (call once per frame)
update_particles :: proc(particles: ^Particle_Manager) {
	eng.particle_manager_update(particles)
}

// Render all active particles (call during drawing, inside scissor mode)
render_particles :: proc(engine: ^eng.Engine, particles: ^Particle_Manager) {
	eng.particle_manager_render(engine, particles)
}

// ─── Convenience spawners for specific events ─────────────────────────────────

spawn_hit_particles :: proc(particles: ^Particle_Manager, tile_x, tile_y, cam_x, cam_y: int) {
	particle_manager_spawn(
		particles,
		tile_x,
		tile_y,
		eng.Engine_Color{255, 60, 60, 255},
		8,
		2.5,
		cam_x,
		cam_y,
	)
}

spawn_mine_particles :: proc(particles: ^Particle_Manager, tile_x, tile_y, cam_x, cam_y: int) {
	particle_manager_spawn(
		particles,
		tile_x,
		tile_y,
		eng.Engine_Color{255, 200, 50, 255},
		12,
		3.0,
		cam_x,
		cam_y,
	)
}

spawn_pickup_particles :: proc(particles: ^Particle_Manager, tile_x, tile_y, cam_x, cam_y: int) {
	particle_manager_spawn(
		particles,
		tile_x,
		tile_y,
		eng.Engine_Color{80, 255, 80, 255},
		6,
		1.5,
		cam_x,
		cam_y,
	)
}

spawn_death_particles :: proc(particles: ^Particle_Manager, tile_x, tile_y, cam_x, cam_y: int) {
	particle_manager_spawn(
		particles,
		tile_x,
		tile_y,
		eng.Engine_Color{255, 0, 0, 255},
		30,
		4.0,
		cam_x,
		cam_y,
	)
}
