package main

import "core:fmt"

import eng "engine"
import rl "vendor:raylib"

// ─── Combat resolution ──────────────────────────────────────────────────────

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
		rl.Color{200, 200, 200, 255},
	)

	if engine != nil {
		vfx := game_engine_vfx_manager(engine)
		eng.vfx_manager_flash(vfx, rl.Color{255, 220, 80, 200}, 0.15)
	}

	if enemy.hp <= 0 {
		enemy.alive = false
		game.kills += 1
		if enemy.is_boss {
			game.boss_killed_this_turn = true
			play_sfx(.Boss_Kill)
			add_message(
				messages,
				game,
				fmt.tprintf("You defeated the %s!", enemy_display_name(enemy)),
				rl.Color{255, 220, 50, 255},
			)
			if engine != nil {
				vfx := game_engine_vfx_manager(engine)
				eng.vfx_manager_flash(vfx, rl.Color{255, 220, 50, 255}, 0.8)
				eng.vfx_manager_shake(vfx, 8.0)
			}
		} else {
			add_message(
				messages,
				game,
				fmt.tprintf("The %s is killed!", enemy_display_name(enemy)),
				rl.Color{0, 255, 0, 255},
			)
		}
	}
}

// Enemy attacks player
resolve_attack_enemy_on_player :: proc(messages: ^Message_Manager, game: ^Game, enemy: ^Enemy) {
	damage := max(enemy.attack - effective_defense(game), 1)
	game.player.hp -= damage
	add_message(
		messages,
		game,
		fmt.tprintf("The %s hits you for %d damage!", enemy_display_name(enemy), damage),
		rl.Color{255, 100, 100, 255},
	)

	if game.player.hp <= 0 {
		game.death_cause = fmt.tprintf("Killed by a %s", enemy_display_name(enemy))
		game.state = .Game_Over
		add_message(messages, game, "You have been slain...", rl.Color{255, 0, 0, 255})
	}
}
