package main

import "core:fmt"

import eng "./engine"


remove_dead_enemies :: proc(
	messages: ^Message_Manager,
	game: ^Game,
	particles: ^eng.Particle_Manager,
	cam_x, cam_y: int,
) {
	i := 0
	for i < len(game.enemies) {
		if !game.enemies[i].alive {
			if game.enemies[i].is_boss {
				game.boss_killed_this_turn = true
			}
			if game.enemies[i].ability_type == ENEMY_ABILITY_POISON_CLOUD {
				t := tile_at(game, game.enemies[i].pos.x, game.enemies[i].pos.y)
				if t != nil && (t.type == .Floor || t.type == .Rubble) {
					t.type = .Gas_Vent
					add_message(
						messages,
						game,
						fmt.tprintf("The %s releases toxic gas!", game.enemies[i].name),
						eng.Engine_Color{120, 200, 40, 255},
					)
				}
			}
			spawn_death_particles(
				particles,
				game.enemies[i].pos.x,
				game.enemies[i].pos.y,
				cam_x,
				cam_y,
			)
			unordered_remove(&game.enemies, i)
		} else {
			i += 1
		}
	}
}
