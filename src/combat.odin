package main

import "core:fmt"

// ─── Combat resolution ──────────────────────────────────────────────────────

// Player attacks enemy (bump-to-attack from input)
resolve_attack_player_on_enemy :: proc(game: ^Game, enemy: ^Enemy) {
	damage := game.player.attack
	enemy.hp -= damage
	fmt.printfln("[combat] player hits %v for %v damage (hp: %v/%v)", enemy.glyph, damage, enemy.hp, enemy.max_hp)

	if enemy.hp <= 0 {
		enemy.alive = false
		fmt.printfln("[combat] %v killed!", enemy.glyph)
	}
}

// Enemy attacks player
resolve_attack_enemy_on_player :: proc(game: ^Game, enemy: ^Enemy) {
	damage := enemy.attack
	game.player.hp -= damage
	fmt.printfln("[combat] %v hits player for %v damage (hp: %v/%v)", enemy.glyph, damage, game.player.hp, game.player.max_hp)

	if game.player.hp <= 0 {
		game.state = .Game_Over
		fmt.printfln("[combat] player killed! Game Over.")
	}
}
