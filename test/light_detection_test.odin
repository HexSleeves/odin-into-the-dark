#+build !js
package main

import "core:testing"

// ─── D1: player light → enemy detection ───────────────────────────────────────

// Build a floored game with the player at (1,1) in pitch darkness (light_radius 0)
// and one enemy at `enemy_pos` with the given detection_radius. Returns the game.
light_detection_test_setup :: proc(game: ^Game, enemy_pos: Vec2, detection_radius: int) {
	game_init_world(game)
	for &tile in game.tiles {
		tile.type = .Floor
	}
	game.state = .Playing
	game.player.hp = 20
	game.player.max_hp = 20
	game.player.pos = Vec2{1, 1}
	game.player.light_radius = 0
	game.enemies = make([dynamic]Enemy)
	append(
		&game.enemies,
		Enemy {
			pos              = enemy_pos,
			hp               = 5,
			max_hp           = 5,
			alive            = true,
			// One move's worth of AP so the per-action loop (which runs awareness
			// updates) executes at least once.
			energy           = BASE_MOVE_COST,
			quickness        = 0,
			move_speed       = 100,
			detection_radius = detection_radius,
			memory_turns     = 5,
		},
	)
}

@(test)
enemy_in_darkness_falls_back_to_hearing_radius_when_flag_on :: proc(t: ^testing.T) {
	// An enemy beyond the hearing radius with no light reaching it is NOT
	// detected, even though it is within detection_radius.
	game: Game
	// Distance 6 > DETECTION_HEARING_RADIUS, detection_radius 8, player light 0.
	light_detection_test_setup(&game, Vec2{7, 1}, 8)
	defer delete(game.enemies)
	messages := message_manager_make()

	game.dijkstra_dirty = true
	process_enemy_turns(&messages, &game)

	testing.expect(t, !game.enemies[0].aware)
}

@(test)
enemy_inside_player_light_becomes_aware_at_full_radius_when_flag_on :: proc(t: ^testing.T) {
	// With a wide light radius, the enemy is lit and detected at the full
	// detection_radius.
	game: Game
	light_detection_test_setup(&game, Vec2{7, 1}, 8)
	defer delete(game.enemies)
	game.player.light_radius = 8 // light now reaches the enemy (dist 6)
	messages := message_manager_make()

	game.dijkstra_dirty = true
	process_enemy_turns(&messages, &game)

	testing.expect(t, game.enemies[0].aware)
}

@(test)
enemy_within_hearing_radius_in_darkness_is_detected_when_flag_on :: proc(t: ^testing.T) {
	// An adjacent enemy is heard even in total darkness.
	game: Game
	// Distance 2 <= DETECTION_HEARING_RADIUS.
	light_detection_test_setup(&game, Vec2{3, 1}, 8)
	defer delete(game.enemies)
	messages := message_manager_make()

	game.dijkstra_dirty = true
	process_enemy_turns(&messages, &game)

	testing.expect(t, game.enemies[0].aware)
}
