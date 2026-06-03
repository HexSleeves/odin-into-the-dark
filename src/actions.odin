package main

import eng "./engine"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"


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
	// Play tile-appropriate footstep sound
	{
		step_tile := tile_at(game, game.player.pos.x, game.player.pos.y)
		step_sfx := Sound_Type.Footstep
		if step_tile != nil {
			#partial switch step_tile.type {
			case .Water:
				step_sfx = .Water
			case .Rubble:
				step_sfx = .Step_Rubble
			case .Descent, .Anvil:
				step_sfx = .Step_Stone
			case:
				step_sfx = .Footstep
			}
		}
		audio_manager_play_sfx(game_engine_audio_manager(engine), step_sfx)
	}

	// Process tile effects (web, hazards, collapse) — no advance_turn here;
	// trigger_enemy_rounds is called by handle_player_action after this.
	consume_web_if_present(messages, game)
	apply_current_tile_effects(engine, game)
	collapse_unstable_previous_tile(messages, game)
}

handle_player_action :: proc(engine: ^eng.Engine, game: ^Game) -> (quit: bool) {
	messages := game_engine_message_manager(engine)
	game.prev_player_pos = game.player.pos
	kills_before := game.kills
	result := handle_input(
		game_engine_content_manager(engine),
		game_engine_turn_manager(engine),
		game_engine_camera_manager(engine),
		messages,
		game,
		game_engine_input_manager(engine),
		engine,
	)

	switch result {
	case .Quit:
		return true
	case .Moved:
		handle_player_moved(engine, game, kills_before)
		// Energy was deducted in handle_input; fire enemy rounds until player has AP
		trigger_enemy_rounds(engine, game)
		announce_item_under_player(messages, game)
	case .Waited:
		// Energy was deducted in handle_input
		trigger_enemy_rounds(engine, game)
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
	music_set_tier_by_depth(game.depth)
	audio_manager_set_master_volume(
		game_engine_audio_manager(engine),
		0.6 + min(f32(game.depth) * 0.02, 0.4),
	)
	eng.vfx_manager_flash(vfx, rl.Color{255, 255, 255, 255}, 0.5)
	hp_before := game.player.hp
	advance_turn(
		game_engine_turn_manager(engine),
		game_engine_camera_manager(engine),
		game_engine_vfx_manager(engine),
		messages,
		game,
		hp_before,
		game_engine_particle_manager(engine),
	)
}

// ─── Descent to next floor ───────────────────────────────────────────────────

descend :: proc(
	content: ^Content_Manager,
	camera: ^eng.Camera_Manager,
	messages: ^Message_Manager,
	game: ^Game,
) {
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
	game.light_drain_timer = 0

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

advance_turn :: proc(
	turns: ^eng.Turn_Manager,
	camera: ^eng.Camera_Manager,
	vfx: ^eng.Vfx_Manager,
	messages: ^Message_Manager,
	game: ^Game,
	hp_before: int,
	particles: ^eng.Particle_Manager = nil,
) {
	eng.turn_manager_advance(turns) // advance round counter
	process_enemy_turns(messages, game)
	process_enemy_abilities(messages, game)
	remove_dead_enemies(messages, game, particles, game_camera_x(camera), game_camera_y(camera))
	tick_timed_effects(messages, game)
	compute_fov(game)
	game_camera_update(camera, game)
	if game.player.hp < hp_before {
		eng.vfx_manager_flash(vfx, rl.Color{255, 0, 0, 255}, 0.3)
		eng.vfx_manager_shake(vfx, 4.0)
		spawn_hit_particles(
			particles,
			game.player.pos.x, game.player.pos.y,
			game_camera_x(camera), game_camera_y(camera),
		)
	}
}

// trigger_enemy_rounds fires one enemy round for each round of AP debt the
// player has accumulated, then grants the player a fresh round of AP.
// This is the Qud-style "player exhausts AP → all enemies act" flow.
trigger_enemy_rounds :: proc(engine: ^eng.Engine, game: ^Game) {
	for game.player.energy <= 0 {
		if game.state != .Playing {break}
		hp_before := game.player.hp
		advance_turn(
			game_engine_turn_manager(engine),
			game_engine_camera_manager(engine),
			game_engine_vfx_manager(engine),
			game_engine_message_manager(engine),
			game,
			hp_before,
			game_engine_particle_manager(engine),
		)
		game.player.energy += game.player.quickness * 10
	}
}

save_run_score :: proc(scores: ^Score_Manager, turns: ^eng.Turn_Manager, game: ^Game) {
	game.score_saved = true
	table := score_manager_load(scores)
	defer score_table_destroy(&table)
	cause := ""
	if len(game.death_cause) > 0 {
		cloned, clone_err := strings.clone(game.death_cause, context.allocator)
		if clone_err == nil {
			cause = cloned
		}
	}
	entry := Score_Entry {
		depth       = game.depth,
		kills       = game.kills,
		turns       = eng.turn_manager_current(turns),
		items_found = game.items_found,
		cause       = cause,
	}
	game.last_score_rank = insert_score(&table, entry)
	if game.last_score_rank < 0 && len(cause) > 0 {
		delete(cause, context.allocator)
	}
	score_manager_save(scores, &table)
}

restart_game :: proc(
	content: ^Content_Manager,
	turns: ^eng.Turn_Manager,
	camera: ^eng.Camera_Manager,
	vfx: ^eng.Vfx_Manager,
	ui: ^UI_Manager,
	messages: ^Message_Manager,
	game: ^Game,
) {
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
	if web_tile_at_idx(game, pidx) {
		web_tile_set_idx(game, pidx, false)
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
		game.poison_turns = max(game.poison_turns, 5)
		eng.vfx_manager_flash(game_engine_vfx_manager(engine), rl.Color{160, 180, 40, 255}, 0.4)
		add_message(messages, game, "Toxic gas burns you! Poisoned! (-3 HP)", rl.Color{160, 180, 40, 255})
		if game.player.hp <= 0 {
			game.death_cause = "Suffocated by toxic gas"
			game.state = .Game_Over
			add_message(messages, game, "You have been slain...", rl.Color{255, 0, 0, 255})
		}
	}

	if cur_tile.type == .Fountain {
		messages := game_engine_message_manager(engine)
		heal := min(5, game.player.max_hp - game.player.hp)
		if heal > 0 {
			game.player.hp += heal
			// Consume the fountain — one use only
			cur_tile.type = .Floor
			add_message(messages, game, fmt.tprintf("The fountain restores your health! (+%d HP)", heal), rl.Color{80, 180, 220, 255})
		} else {
			add_message(messages, game, "You drink from the fountain. (Already at full health)", rl.Color{80, 180, 220, 255})
			cur_tile.type = .Floor
		}
	}

	if cur_tile.type == .Fire_Vent {
		messages := game_engine_message_manager(engine)
		game.player.hp -= 2
		game.burning_turns = max(game.burning_turns, 4)
		eng.vfx_manager_flash(game_engine_vfx_manager(engine), rl.Color{255, 120, 20, 255}, 0.4)
		add_message(messages, game, "Flames scorch you! Burning! (-2 HP)", rl.Color{255, 120, 20, 255})
		if game.player.hp <= 0 {
			game.death_cause = "Burned alive by a fire vent"
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
		add_message(
			messages,
			game,
			"The ground collapses behind you!",
			rl.Color{180, 120, 60, 255},
		)
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
