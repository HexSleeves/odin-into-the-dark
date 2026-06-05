package gameplay

import eng "../engine"
import "core:fmt"

footstep_sound_for_tile :: proc(tile_type: Tile_Type) -> Sound_Type {
	#partial switch tile_type {
	case .Water:
		return .Water
	case .Rubble:
		return .Step_Rubble
	case .Descent, .Anvil:
		return .Step_Stone
	}
	return .Footstep
}

handle_player_moved :: proc(engine: ^eng.Engine, game: ^Game, kills_before: int) {
	messages := game_engine_message_manager(engine)
	camera := game_engine_camera_manager(engine)
	if game.kills > kills_before {
		spawn_hit_particles(
			game_engine_particle_manager(engine),
			game.prev_player_pos.x,
			game.prev_player_pos.y,
			game_camera_x(camera),
			game_camera_y(camera),
		)
	}
	step_tile := tile_at(game, game.player.pos.x, game.player.pos.y)
	step_sfx := Sound_Type.Footstep
	if step_tile != nil {
		step_sfx = footstep_sound_for_tile(step_tile.type)
	}
	audio_manager_play_sfx(game_engine_audio_manager(engine), step_sfx)

	consume_web_if_present(messages, game)
	apply_current_tile_effects(engine, game)
	collapse_unstable_previous_tile(messages, game)
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
	eng.vfx_manager_flash(vfx, eng.Engine_Color{255, 255, 255, 255}, 0.5)
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
	if game.depth >= MAX_DEPTH {
		game.state = .Victory
		return
	}

	game.depth += 1

	min_light := MIN_LIGHT_RADIUS_DEFAULT
	if game.depth >= MIN_LIGHT_DEPTH {min_light = MIN_LIGHT_RADIUS_DEEP}
	player_def := content_manager_player_def(content)
	game.player.light_radius = max(player_def.light_radius - game.depth + 1, min_light)
	game.light_drain_timer = 0

	generate_map(content, game)
	compute_fov(game)
	game_camera_update(camera, game, true)

	add_message(
		messages,
		game,
		fmt.tprintf("You descend to depth %d...", game.depth),
		eng.Engine_Color{0, 200, 200, 255},
	)
}

start_mining_mode :: proc(ui: ^UI_Manager, messages: ^Message_Manager, game: ^Game) {
	can_mine := false
	if !game.equipped_weapon.occupied {
		add_message(messages, game, "You need a pickaxe to mine!", eng.Engine_Color{255, 100, 100, 255})
	} else if game.equipped_weapon.item.max_durability > 0 &&
	   game.equipped_weapon.item.durability <= 0 {
		add_message(
			messages,
			game,
			fmt.tprintf("Your %s is broken!", game.equipped_weapon.item.name),
			eng.Engine_Color{255, 100, 100, 255},
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
			eng.Engine_Color{200, 200, 100, 255},
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
	eng.turn_manager_advance(turns)
	process_enemy_turns(messages, game)
	process_enemy_abilities(messages, game)
	remove_dead_enemies(messages, game, particles, game_camera_x(camera), game_camera_y(camera))
	tick_timed_effects(messages, game)
	compute_fov(game)
	game_camera_update(camera, game)
	if game.player.hp < hp_before {
		eng.vfx_manager_flash(vfx, eng.Engine_Color{255, 0, 0, 255}, 0.3)
		eng.vfx_manager_shake(vfx, 4.0)
		spawn_hit_particles(
			particles,
			game.player.pos.x,
			game.player.pos.y,
			game_camera_x(camera),
			game_camera_y(camera),
		)
	}
}

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

// ─── Tile effect helpers ───────────────────────────────────────────────────────

consume_web_if_present :: proc(messages: ^Message_Manager, game: ^Game) {
	pidx := pos_to_idx(game.player.pos.x, game.player.pos.y)
	if web_tile_at_idx(game, pidx) {
		web_tile_set_idx(game, pidx, false)
		game.skip_next_turn = true
		add_message(messages, game, "You are stuck in a web!", eng.Engine_Color{180, 180, 180, 255})
	}
}

apply_current_tile_effects :: proc(engine: ^eng.Engine, game: ^Game) {
	if game.state == .Game_Over {return}
	cur_tile := tile_at(game, game.player.pos.x, game.player.pos.y)
	if cur_tile == nil {return}

	if cur_tile.type == .Water {
		messages := game_engine_message_manager(engine)
		game.water_slow_active = true
		audio_manager_play_sfx(game_engine_audio_manager(engine), .Water)
		add_message(messages, game, "You wade through water...", eng.Engine_Color{40, 80, 180, 255})
	}

	if cur_tile.type == .Gas_Vent {
		messages := game_engine_message_manager(engine)
		game.player.hp -= GAS_VENT_DAMAGE
		game.poison_turns = max(game.poison_turns, GAS_VENT_POISON_TURNS)
		eng.vfx_manager_flash(game_engine_vfx_manager(engine), eng.Engine_Color{160, 180, 40, 255}, 0.4)
		add_message(
			messages,
			game,
			fmt.tprintf("Toxic gas burns you! Poisoned! (-%d HP)", GAS_VENT_DAMAGE),
			eng.Engine_Color{160, 180, 40, 255},
		)
		if game.player.hp <= 0 {
			player_die(messages, game, "Suffocated by toxic gas")
			return
		}
	}

	if cur_tile.type == .Fountain {
		messages := game_engine_message_manager(engine)
		heal := min(FOUNTAIN_HEAL, game.player.max_hp - game.player.hp)
		if heal > 0 {
			game.player.hp += heal
			cur_tile.type = .Floor
			add_message(
				messages,
				game,
				fmt.tprintf("The fountain restores your health! (+%d HP)", heal),
				eng.Engine_Color{80, 180, 220, 255},
			)
		} else {
			add_message(messages, game, "You drink from the fountain. (Already at full health)", eng.Engine_Color{80, 180, 220, 255})
			cur_tile.type = .Floor
		}
	}

	if cur_tile.type == .Fire_Vent {
		messages := game_engine_message_manager(engine)
		game.player.hp -= FIRE_VENT_DAMAGE
		game.burning_turns = max(game.burning_turns, FIRE_VENT_BURNING_TURNS)
		eng.vfx_manager_flash(game_engine_vfx_manager(engine), eng.Engine_Color{255, 120, 20, 255}, 0.4)
		add_message(
			messages,
			game,
			fmt.tprintf("Flames scorch you! Burning! (-%d HP)", FIRE_VENT_DAMAGE),
			eng.Engine_Color{255, 120, 20, 255},
		)
		if game.player.hp <= 0 {
			player_die(messages, game, "Burned alive by a fire vent")
			return
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
		add_message(messages, game, "The ground collapses behind you!", eng.Engine_Color{180, 120, 60, 255})
	}
}

announce_item_under_player :: proc(messages: ^Message_Manager, game: ^Game) {
	it := item_at(game, game.player.pos.x, game.player.pos.y)
	if it == nil {return}
	add_message(
		messages,
		game,
		fmt.tprintf("You see a %s here.", item_display_name(it)),
		eng.Engine_Color{255, 255, 100, 255},
	)
}
