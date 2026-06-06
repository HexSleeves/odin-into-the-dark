#+build !js
package main

import eng "./engine"
import "core:os"
import "core:testing"

@(test)
save_load_round_trip_preserves_spawned_enemies :: proc(t: ^testing.T) {
	path := "/tmp/into-the-depths-enemy-save.dat"
	defer os.remove(path)

	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)
	game.state = .Playing
	generate_map(&content, game)
	testing.expect(t, len(game.enemies) > 0)
	original_enemy_count := len(game.enemies)

	turns := eng.turn_manager_make()
	testing.expect(t, save_game_to_path(&turns, game, path))

	loaded: Game
	loaded_turns := eng.turn_manager_make()
	camera := eng.camera_manager_make()
	vfx := eng.vfx_manager_make()
	ui := ui_manager_make(false)
	messages := message_manager_make()
	loaded_ok := load_game_from_path(
		&content,
		&loaded_turns,
		&camera,
		&vfx,
		&ui,
		&messages,
		&loaded,
		path,
	)
	defer game_cleanup(&loaded)

	testing.expect(t, loaded_ok)
	testing.expect_value(t, len(loaded.enemies), original_enemy_count)
}

@(test)
save_load_round_trip_preserves_status_effect_timers :: proc(t: ^testing.T) {
	path := "/tmp/into-the-depths-status-save.dat"
	defer os.remove(path)

	content := content_manager_make()
	defer content_manager_destroy(&content)
	testing.expect(t, content_manager_load_all(&content))

	game := game_init(&content)
	defer game_destroy(game)
	game.poison_turns = 5
	game.burning_turns = 4
	game.frozen_turns = 3

	turns := eng.turn_manager_make()
	testing.expect(t, save_game_to_path(&turns, game, path))

	loaded: Game
	loaded_turns := eng.turn_manager_make()
	camera := eng.camera_manager_make()
	vfx := eng.vfx_manager_make()
	ui := ui_manager_make(false)
	messages := message_manager_make()
	loaded_ok := load_game_from_path(
		&content,
		&loaded_turns,
		&camera,
		&vfx,
		&ui,
		&messages,
		&loaded,
		path,
	)
	defer game_cleanup(&loaded)

	testing.expect(t, loaded_ok)
	testing.expect_value(t, loaded.poison_turns, 5)
	testing.expect_value(t, loaded.burning_turns, 4)
	testing.expect_value(t, loaded.frozen_turns, 3)
}
