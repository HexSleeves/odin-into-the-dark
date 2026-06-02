package main

import "core:fmt"
import rl "vendor:raylib"
import eng "./engine"


handle_player_moved :: proc(engine: ^eng.Engine, game: ^Game, kills_before: int) {
	messages := game_engine_message_manager(engine)
	camera := game_engine_camera_manager(engine)
	// Combat hit particles when a kill happened this turn
	if game.kills > kills_before {
		spawn_hit_particles(
			game_engine_particle_manager(engine),
			game.prev_player_pos.x,
			game.prev_player_pos.y,
			game_camera_x(camera),
			game_camera_y(camera),
		)
	}
	audio_manager_play_sfx(game_engine_audio_manager(engine), .Footstep)

	consume_web_if_present(messages, game)
	apply_current_tile_effects(engine, game)
	collapse_unstable_previous_tile(messages, game)

	hp_before := game.player.hp
	advance_turn(game_engine_turn_manager(engine), game_engine_camera_manager(engine), game_engine_vfx_manager(engine), messages, game, hp_before)
	announce_item_under_player(messages, game)
}

handle_player_action :: proc(engine: ^eng.Engine, game: ^Game) -> (quit: bool) {
	messages := game_engine_message_manager(engine)
	game.prev_player_pos = game.player.pos
	kills_before := game.kills
	result := handle_input(game_engine_content_manager(engine), game_engine_turn_manager(engine), game_engine_camera_manager(engine), messages, game, game_engine_input_manager(engine))

	switch result {
	case .Quit:
		return true
	case .Moved:
		handle_player_moved(engine, game, kills_before)
	case .Waited:
		hp_before := game.player.hp
		advance_turn(game_engine_turn_manager(engine), game_engine_camera_manager(engine), game_engine_vfx_manager(engine), messages, game, hp_before)
	case .Descended:
		handle_player_descended(engine, game)
	case .None:
	}

	return false
}

handle_player_descended :: proc(engine: ^eng.Engine, game: ^Game) {
	messages := game_engine_message_manager(engine)
	vfx := game_engine_vfx_manager(engine)
	audio_manager_play_sfx(game_engine_audio_manager(engine), .Descent)
	eng.vfx_manager_flash(vfx, rl.Color{255, 255, 255, 255}, 0.5)
	hp_before := game.player.hp
	advance_turn(game_engine_turn_manager(engine), game_engine_camera_manager(engine), game_engine_vfx_manager(engine), messages, game, hp_before)
}

// ─── Descent to next floor ───────────────────────────────────────────────────

descend :: proc(content: ^Content_Manager, camera: ^eng.Camera_Manager, messages: ^Message_Manager, game: ^Game) {
	// Victory condition: escaping from depth 12
	if game.depth >= 12 {
		game.state = .Victory
		return
	}

	game.depth += 1

	// Reduce light radius with depth (min 2 at depth 8+, min 3 otherwise)
	min_light := 3
	if game.depth >= 8 {min_light = 2}
	player_def := content_manager_player_def(content)
	game.player.light_radius = max(player_def.light_radius - game.depth + 1, min_light)

	// Regenerate the map (clears tiles, web_tiles, rooms, spawns enemies)
	generate_map(content, game)

	// Recompute FOV and snap camera to the new spawn before the next frame.
	compute_fov(game)
	game_camera_update(camera, game, true)

	add_message(
		messages,
		game,
		fmt.tprintf("You descend to depth %d...", game.depth),
		rl.Color{0, 200, 200, 255},
	)
}

start_mining_mode :: proc(ui: ^UI_Manager, messages: ^Message_Manager, game: ^Game) {
	can_mine := false
	if !game.equipped_weapon.occupied {
		add_message(messages, game, "You need a pickaxe to mine!", rl.Color{255, 100, 100, 255})
	} else if game.equipped_weapon.item.max_durability > 0 &&
	   game.equipped_weapon.item.durability <= 0 {
		add_message(
			messages,
			game,
			fmt.tprintf("Your %s is broken!", game.equipped_weapon.item.name),
			rl.Color{255, 100, 100, 255},
		)
	} else {
		can_mine = true
	}

	if can_mine {
		ui_manager_state(ui).mining_mode = true
		add_message(
			messages,
			game,
			"Mine which direction? (WASD/arrows, ESC cancel)",
			rl.Color{200, 200, 100, 255},
		)
	}
}

// ─── Turn helpers ─────────────────────────────────────────────────────────────

advance_turn :: proc(turns: ^eng.Turn_Manager, camera: ^eng.Camera_Manager, vfx: ^eng.Vfx_Manager, messages: ^Message_Manager, game: ^Game, hp_before: int) {
	_ = turns
	process_enemy_turns(messages, game)
	process_enemy_abilities(messages, game)
	remove_dead_enemies(messages, game)
	tick_timed_effects(messages, game)
	compute_fov(game)
	game_camera_update(camera, game)
	if game.player.hp < hp_before {
		eng.vfx_manager_flash(vfx, rl.Color{255, 0, 0, 255}, 0.3)
	}
}

save_run_score :: proc(scores: ^Score_Manager, turns: ^eng.Turn_Manager, game: ^Game) {
	game.score_saved = true
	table := score_manager_load(scores)
	entry := Score_Entry {
		depth = game.depth,
		kills = game.kills,
		turns = eng.turn_manager_current(turns),
		cause = game.death_cause,
	}
	game.last_score_rank = insert_score(&table, entry)
	score_manager_save(scores, &table)
}

restart_game :: proc(content: ^Content_Manager, turns: ^eng.Turn_Manager, camera: ^eng.Camera_Manager, vfx: ^eng.Vfx_Manager, ui: ^UI_Manager, messages: ^Message_Manager, game: ^Game) {
	game_cleanup(game)
	game^ = {}
	eng.turn_manager_reset(turns)
	eng.vfx_manager_reset(vfx)
	ui_manager_reset_for_new_game(ui, g_sprites.loaded)
	game_reinit(content, messages, game)
	compute_fov(game)
	game_camera_update(camera, game, true)
	game.score_saved = false
	game.death_cause = ""
	game.last_score_rank = -1
	add_message(messages, game, "A new journey begins...", rl.Color{200, 200, 100, 255})
}

// ─── Tile effect helpers ───────────────────────────────────────────────────────

consume_web_if_present :: proc(messages: ^Message_Manager, game: ^Game) {
	pidx := pos_to_idx(game.player.pos.x, game.player.pos.y)
	if game.web_tiles[pidx] {
		game.web_tiles[pidx] = false
		game.skip_next_turn = true
		add_message(messages, game, "You are stuck in a web!", rl.Color{180, 180, 180, 255})
	}
}

apply_current_tile_effects :: proc(engine: ^eng.Engine, game: ^Game) {
	cur_tile := tile_at(game, game.player.pos.x, game.player.pos.y)
	if cur_tile == nil {return}

	if cur_tile.type == .Water {
		messages := game_engine_message_manager(engine)
		game.water_slow_active = true
		audio_manager_play_sfx(game_engine_audio_manager(engine), .Water)
		add_message(messages, game, "You wade through water...", rl.Color{40, 80, 180, 255})
	}

	if cur_tile.type == .Gas_Vent {
		messages := game_engine_message_manager(engine)
		game.player.hp -= 3
		eng.vfx_manager_flash(game_engine_vfx_manager(engine), rl.Color{160, 180, 40, 255}, 0.4)
		add_message(messages, game, "Toxic gas burns you! (-3 HP)", rl.Color{160, 180, 40, 255})
		if game.player.hp <= 0 {
			game.death_cause = "Suffocated by toxic gas"
			game.state = .Game_Over
			add_message(messages, game, "You have been slain...", rl.Color{255, 0, 0, 255})
		}
	}
}

collapse_unstable_previous_tile :: proc(messages: ^Message_Manager, game: ^Game) {
	if game.prev_player_pos.x == game.player.pos.x && game.prev_player_pos.y == game.player.pos.y {
		return
	}

	prev_tile := tile_at(game, game.prev_player_pos.x, game.prev_player_pos.y)
	if prev_tile != nil && prev_tile.type == .Unstable {
		prev_tile.type = .Chasm
		add_message(messages, game, "The ground collapses behind you!", rl.Color{180, 120, 60, 255})
	}
}

announce_item_under_player :: proc(messages: ^Message_Manager, game: ^Game) {
	it := item_at(game, game.player.pos.x, game.player.pos.y)
	if it == nil {return}
	add_message(
		messages,
		game,
		fmt.tprintf("You see a %s here.", item_display_name(it)),
		rl.Color{255, 255, 100, 255},
	)
}
