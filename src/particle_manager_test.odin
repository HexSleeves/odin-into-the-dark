package main

import "core:testing"
import rl "vendor:raylib"

@(test)
particle_manager_make_wraps_current_particle_pool :: proc(t: ^testing.T) {
	particles := particle_manager_make()

	testing.expect(t, particles.pool == &g_particles)
}

@(test)
particle_manager_active_count_reads_pool_state :: proc(t: ^testing.T) {
	particles := particle_manager_make()
	was_active := g_particles[0].active
	defer g_particles[0].active = was_active

	g_particles[0].active = false
	testing.expect_value(t, particle_manager_active_count(&particles), 0)

	g_particles[0].active = true
	testing.expect_value(t, particle_manager_active_count(&particles), 1)
}

@(test)
particle_handlers_accept_manager_context :: proc(t: ^testing.T) {
	spawn_handler: proc(particles: ^Particle_Manager, tile_x, tile_y: int, color: rl.Color, count: int, speed: f32, camera_x: int, camera_y: int) = particle_manager_spawn
	update_handler: proc(particles: ^Particle_Manager) = update_particles
	render_handler: proc(particles: ^Particle_Manager) = render_particles
	hit_handler: proc(particles: ^Particle_Manager, tile_x, tile_y, cam_x, cam_y: int) = spawn_hit_particles
	mine_handler: proc(particles: ^Particle_Manager, tile_x, tile_y, cam_x, cam_y: int) = spawn_mine_particles
	pickup_handler: proc(particles: ^Particle_Manager, tile_x, tile_y, cam_x, cam_y: int) = spawn_pickup_particles
	death_handler: proc(particles: ^Particle_Manager, tile_x, tile_y, cam_x, cam_y: int) = spawn_death_particles

	testing.expect(t, spawn_handler != nil)
	testing.expect(t, update_handler != nil)
	testing.expect(t, render_handler != nil)
	testing.expect(t, hit_handler != nil)
	testing.expect(t, mine_handler != nil)
	testing.expect(t, pickup_handler != nil)
	testing.expect(t, death_handler != nil)
}
