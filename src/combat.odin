package main

import "core:fmt"

import rl "vendor:raylib"

// ─── Combat resolution ──────────────────────────────────────────────────────

// Player attacks enemy (bump-to-attack from input)
resolve_attack_player_on_enemy :: proc(game: ^Game, enemy: ^Enemy) {
	damage := game.player.attack
	enemy.hp -= damage
	add_message(
		game,
		fmt.tprintf("You hit the %s for %d damage.", enemy_display_name(enemy), damage),
		rl.Color{200, 200, 200, 255},
	)

	if enemy.hp <= 0 {
		enemy.alive = false
		game.kills += 1
		add_message(
			game,
			fmt.tprintf("The %s is killed!", enemy_display_name(enemy)),
			rl.Color{0, 255, 0, 255},
		)
	}
}

// Enemy attacks player
resolve_attack_enemy_on_player :: proc(game: ^Game, enemy: ^Enemy) {
	damage := enemy.attack
	game.player.hp -= damage
	add_message(
		game,
		fmt.tprintf("The %s hits you for %d damage!", enemy_display_name(enemy), damage),
		rl.Color{255, 100, 100, 255},
	)

	if game.player.hp <= 0 {
		game.state = .Game_Over
		add_message(game, "You have been slain...", rl.Color{255, 0, 0, 255})
	}
}
