package main

import "core:fmt"
import rl "vendor:raylib"


handle_player_moved :: proc(game: ^Game, kills_before: int) {
	// Combat hit particles when a kill happened this turn
	if game.kills > kills_before {
		spawn_hit_particles(
			game.prev_player_pos.x,
			game.prev_player_pos.y,
			game.camera_x,
			game.camera_y,
		)
	}
	play_sfx(.Footstep)

	consume_web_if_present(game)
	apply_current_tile_effects(game)
	collapse_unstable_previous_tile(game)

	hp_before := game.player.hp
	advance_turn(game, hp_before)
	announce_item_under_player(game)
}

handle_player_action :: proc(game: ^Game) -> (quit: bool) {
	game.prev_player_pos = game.player.pos
	kills_before := game.kills
	result := handle_input(game)

	switch result {
	case .Quit:
		return true
	case .Moved:
		handle_player_moved(game, kills_before)
	case .Waited:
		hp_before := game.player.hp
		advance_turn(game, hp_before)
	case .Descended:
		handle_player_descended(game)
	case .None:
	}

	return false
}

handle_player_descended :: proc(game: ^Game) {
	play_sfx(.Descent)
	game.vfx.flash_color = rl.Color{255, 255, 255, 255}
	game.vfx.flash_alpha = 0.5
	hp_before := game.player.hp
	advance_turn(game, hp_before)
}

// ─── Descent to next floor ───────────────────────────────────────────────────

descend :: proc(game: ^Game) {
	// Victory condition: escaping from depth 12
	if game.depth >= 12 {
		game.state = .Victory
		return
	}

	game.depth += 1

	// Reduce light radius with depth (min 2 at depth 8+, min 3 otherwise)
	min_light := 3
	if game.depth >= 8 {min_light = 2}
	game.player.light_radius = max(g_data.player.light_radius - game.depth + 1, min_light)

	// Regenerate the map (clears tiles, web_tiles, rooms, spawns enemies)
	generate_map(game)

	// Recompute FOV and snap camera to the new spawn before the next frame.
	compute_fov(game)
	camera_update(game, snap = true)

	add_message(
		game,
		fmt.tprintf("You descend to depth %d...", game.depth),
		rl.Color{0, 200, 200, 255},
	)
}

start_mining_mode :: proc(game: ^Game) {
	can_mine := false
	if !game.equipped_weapon.occupied {
		add_message(game, "You need a pickaxe to mine!", rl.Color{255, 100, 100, 255})
	} else if game.equipped_weapon.item.max_durability > 0 &&
	   game.equipped_weapon.item.durability <= 0 {
		add_message(
			game,
			fmt.tprintf("Your %s is broken!", game.equipped_weapon.item.name),
			rl.Color{255, 100, 100, 255},
		)
	} else {
		can_mine = true
	}

	if can_mine {
		game.ui.mining_mode = true
		add_message(
			game,
			"Mine which direction? (WASD/arrows, ESC cancel)",
			rl.Color{200, 200, 100, 255},
		)
	}
}

// ─── Turn helpers ─────────────────────────────────────────────────────────────

advance_turn :: proc(game: ^Game, hp_before: int) {
	process_enemy_turns(game)
	process_enemy_abilities(game)
	remove_dead_enemies(game)
	tick_timed_effects(game)
	compute_fov(game)
	camera_update(game)
	if game.player.hp < hp_before {
		game.vfx.flash_color = rl.Color{255, 0, 0, 255}
		game.vfx.flash_alpha = 0.3
	}
}

save_run_score :: proc(game: ^Game) {
	game.score_saved = true
	table := load_scores()
	entry := Score_Entry {
		depth = game.depth,
		kills = game.kills,
		turns = game.turn_count,
		cause = game.death_cause,
	}
	game.last_score_rank = insert_score(&table, entry)
	save_scores(&table)
}

restart_game :: proc(game: ^Game) {
	game_cleanup(game)
	game^ = {}
	game_reinit(game)
	compute_fov(game)
	camera_update(game, snap = true)
	game.score_saved = false
	game.death_cause = ""
	game.last_score_rank = -1
	add_message(game, "A new journey begins...", rl.Color{200, 200, 100, 255})
}

// ─── Tile effect helpers ───────────────────────────────────────────────────────

consume_web_if_present :: proc(game: ^Game) {
	pidx := pos_to_idx(game.player.pos.x, game.player.pos.y)
	if game.web_tiles[pidx] {
		game.web_tiles[pidx] = false
		game.skip_next_turn = true
		add_message(game, "You are stuck in a web!", rl.Color{180, 180, 180, 255})
	}
}

apply_current_tile_effects :: proc(game: ^Game) {
	cur_tile := tile_at(game, game.player.pos.x, game.player.pos.y)
	if cur_tile == nil {return}

	if cur_tile.type == .Water {
		game.water_slow_active = true
		play_sfx(.Water)
		add_message(game, "You wade through water...", rl.Color{40, 80, 180, 255})
	}

	if cur_tile.type == .Gas_Vent {
		game.player.hp -= 3
		game.vfx.flash_color = rl.Color{160, 180, 40, 255}
		game.vfx.flash_alpha = 0.4
		add_message(game, "Toxic gas burns you! (-3 HP)", rl.Color{160, 180, 40, 255})
		if game.player.hp <= 0 {
			game.death_cause = "Suffocated by toxic gas"
			game.state = .Game_Over
			add_message(game, "You have been slain...", rl.Color{255, 0, 0, 255})
		}
	}
}

collapse_unstable_previous_tile :: proc(game: ^Game) {
	if game.prev_player_pos.x == game.player.pos.x && game.prev_player_pos.y == game.player.pos.y {
		return
	}

	prev_tile := tile_at(game, game.prev_player_pos.x, game.prev_player_pos.y)
	if prev_tile != nil && prev_tile.type == .Unstable {
		prev_tile.type = .Chasm
		add_message(game, "The ground collapses behind you!", rl.Color{180, 120, 60, 255})
	}
}

announce_item_under_player :: proc(game: ^Game) {
	it := item_at(game, game.player.pos.x, game.player.pos.y)
	if it == nil {return}
	add_message(
		game,
		fmt.tprintf("You see a %s here.", item_display_name(it)),
		rl.Color{255, 255, 100, 255},
	)
}
