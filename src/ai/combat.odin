package ai

import "core:fmt"

import eng "../engine"

// ─── Combat resolution ──────────────────────────────────────────────────────

game_set_death_cause :: proc(game: ^Game, cause: string) {
	if game == nil {return}

	copy_len := min(len(cause), DEATH_CAUSE_MAX_LEN)
	for i in 0 ..< copy_len {
		game.death_cause_storage[i] = cause[i]
	}
	game.death_cause = string(game.death_cause_storage[:copy_len])
}

player_die :: proc(messages: ^Message_Manager, game: ^Game, cause: string) -> bool {
	if game == nil || game.state == .Game_Over {return false}

	game.player.hp = 0
	game_set_death_cause(game, cause)
	logger_debugf(
		.Enemy,
		"player died: cause='%s' depth=%v kills=%v",
		cause,
		game.depth,
		game.kills,
	)
	game.state = .Game_Over
	add_message(messages, game, "You have been slain...", eng.Engine_Color{255, 0, 0, 255})
	return true
}

// Player attacks enemy (bump-to-attack from input)
resolve_attack_player_on_enemy :: proc(
	messages: ^Message_Manager,
	game: ^Game,
	enemy: ^Enemy,
	engine: ^eng.Engine = nil,
) {
	damage := effective_attack(game)
	enemy.hp -= damage
	play_sfx(.Hit)
	add_message(
		messages,
		game,
		fmt.tprintf("You hit the %s for %d damage.", enemy_display_name(enemy), damage),
		eng.Engine_Color{200, 200, 200, 255},
	)

	if engine != nil {
		vfx := game_engine_vfx_manager(engine)
		eng.vfx_manager_flash(vfx, eng.Engine_Color{255, 220, 80, 200}, 0.15)
	}

	if enemy.hp <= 0 {
		enemy.alive = false
		logger_debugf(
			.Enemy,
			"killed '%s' at (%v,%v) hp_was=%v kills=%v",
			enemy_display_name(enemy),
			enemy.pos.x,
			enemy.pos.y,
			enemy.max_hp,
			game.kills,
		)
		game.kills += 1
		if enemy.is_boss {
			game.boss_killed_this_turn = true
			play_sfx(.Boss_Kill)
			add_message(
				messages,
				game,
				fmt.tprintf("You defeated the %s!", enemy_display_name(enemy)),
				eng.Engine_Color{255, 220, 50, 255},
			)
			if engine != nil {
				vfx := game_engine_vfx_manager(engine)
				eng.vfx_manager_flash(vfx, eng.Engine_Color{255, 220, 50, 255}, 0.8)
				eng.vfx_manager_shake(vfx, 8.0)
			}
		} else {
			add_message(
				messages,
				game,
				fmt.tprintf("The %s is killed!", enemy_display_name(enemy)),
				eng.Engine_Color{0, 255, 0, 255},
			)
		}
	}
}

// Enemy attacks player
resolve_attack_enemy_on_player :: proc(messages: ^Message_Manager, game: ^Game, enemy: ^Enemy) {
	damage := max(enemy.attack - effective_defense(game), 1)
	game.player.hp = max(game.player.hp - damage, 0)
	add_message(
		messages,
		game,
		fmt.tprintf("The %s hits you for %d damage!", enemy_display_name(enemy), damage),
		eng.Engine_Color{255, 100, 100, 255},
	)

	if game.player.hp <= 0 {
		player_die(messages, game, fmt.tprintf("Killed by a %s", enemy_display_name(enemy)))
	}
}
