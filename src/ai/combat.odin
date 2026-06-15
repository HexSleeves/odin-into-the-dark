package ai

import "core:fmt"

import eng "../engine"

// ─── Combat resolution ──────────────────────────────────────────────────────

// Floating damage-number colors: hits on the player read red; hits on enemies
// read white; crits in either direction read gold.
@(private = "file")
FLOATING_DMG_ENEMY := eng.Engine_Color{235, 235, 235, 255}
@(private = "file")
FLOATING_DMG_PLAYER := eng.Engine_Color{255, 90, 90, 255}
@(private = "file")
FLOATING_DMG_CRIT := eng.Engine_Color{255, 220, 80, 255}

floating_text_spawn_damage :: proc(
	ft: ^eng.Floating_Text_Manager,
	tile_x, tile_y, damage: int,
	crit: bool,
	on_player: bool,
) {
	if ft == nil {return}
	color := FLOATING_DMG_PLAYER if on_player else FLOATING_DMG_ENEMY
	if crit {color = FLOATING_DMG_CRIT}
	text := fmt.tprintf("%d!", damage) if crit else fmt.tprintf("%d", damage)
	eng.floating_text_manager_spawn(ft, tile_x, tile_y, text, color)
}

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
	damage := damage_roll(effective_attack(game))
	crit := crit_roll(effective_crit_chance(game))
	if crit {
		damage = damage * CRIT_DAMAGE_MULT_PCT / 100
	}
	enemy.hp -= damage
	play_sfx(.Hit)
	if engine != nil {
		floating_text_spawn_damage(
			game_engine_floating_text_manager(engine),
			enemy.pos.x,
			enemy.pos.y,
			damage,
			crit,
			false,
		)
	}
	if crit {
		add_message(
			messages,
			game,
			fmt.tprintf(
				"Critical hit! You strike the %s for %d damage!",
				enemy_display_name(enemy),
				damage,
			),
			eng.Engine_Color{255, 220, 80, 255},
		)
	} else {
		add_message(
			messages,
			game,
			fmt.tprintf("You hit the %s for %d damage.", enemy_display_name(enemy), damage),
			eng.Engine_Color{200, 200, 200, 255},
		)
	}

	if engine != nil {
		vfx := game_engine_vfx_manager(engine)
		if crit {
			eng.vfx_manager_flash(vfx, eng.Engine_Color{255, 240, 120, 230}, 0.25)
			eng.vfx_manager_shake(vfx, 3.0)
		} else {
			eng.vfx_manager_flash(vfx, eng.Engine_Color{255, 220, 80, 200}, 0.15)
		}
	}

	if enemy.hp <= 0 {
		enemy.alive = false
		enemy_occupancy_mark_dirty(game)
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
		// Milestone level-ups (D3): the player chooses boons via the level-up menu
		// (check_level_up) instead of an auto-applied milestone buff.
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
resolve_attack_enemy_on_player :: proc(
	messages: ^Message_Manager,
	game: ^Game,
	enemy: ^Enemy,
	engine: ^eng.Engine = nil,
) {
	// Frozen enemies fight sluggishly: a chance to lose the swing entirely, and
	// any landed hit deals reduced damage (mirrors the movement penalty).
	frozen := status_active(&enemy.status, .Frozen)
	if frozen && chance_roll(FROZEN_SKIP_ATTACK_CHANCE_PCT) {
		add_message(
			messages,
			game,
			fmt.tprintf("The frozen %s is too sluggish to strike.", enemy_display_name(enemy)),
			eng.Engine_Color{120, 190, 255, 255},
		)
		return
	}

	raw_damage := damage_roll(enemy.attack)
	crit := crit_roll(enemy.crit_chance)
	if crit {
		raw_damage = raw_damage * CRIT_DAMAGE_MULT_PCT / 100
	}
	if frozen {
		raw_damage = max(raw_damage * FROZEN_DAMAGE_PCT / 100, 1)
	}
	damage := max(raw_damage - effective_defense(game), 1)
	game.player.hp = max(game.player.hp - damage, 0)
	if engine != nil {
		floating_text_spawn_damage(
			game_engine_floating_text_manager(engine),
			game.player.pos.x,
			game.player.pos.y,
			damage,
			crit,
			true,
		)
	}
	if crit {
		add_message(
			messages,
			game,
			fmt.tprintf(
				"The %s lands a vicious blow for %d damage!",
				enemy_display_name(enemy),
				damage,
			),
			eng.Engine_Color{255, 60, 60, 255},
		)
	} else {
		add_message(
			messages,
			game,
			fmt.tprintf("The %s hits you for %d damage!", enemy_display_name(enemy), damage),
			eng.Engine_Color{255, 100, 100, 255},
		)
	}

	if game.player.hp <= 0 {
		player_die(messages, game, fmt.tprintf("Killed by a %s", enemy_display_name(enemy)))
	}
}
