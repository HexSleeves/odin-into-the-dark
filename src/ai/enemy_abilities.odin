package ai

import "core:fmt"

import eng "../engine"


process_enemy_abilities :: proc(messages: ^Message_Manager, game: ^Game) {
	if game.state == .Game_Over {return}

	for &enemy in game.enemies {
		if game.state == .Game_Over {return}
		if !enemy.alive {continue}
		if enemy.ability_type == "" {continue}

		// Decrement cooldown
		if enemy.ability_cooldown > 0 {
			enemy.ability_cooldown -= 1
			continue
		}

		if enemy.ability_type == ENEMY_ABILITY_WEB {
			// Web: place web on a floor tile adjacent to enemy if player is nearby
			dist := abs(enemy.pos.x - game.player.pos.x) + abs(enemy.pos.y - game.player.pos.y)
			if dist <= 3 {
				dx := CARDINAL_DX
				dy := CARDINAL_DY
				for dir in 0 ..< 4 {
					wx := enemy.pos.x + dx[dir]
					wy := enemy.pos.y + dy[dir]
					if is_walkable(game, wx, wy) && !web_tile_at(game, wx, wy) {
						web_tile_set(game, wx, wy, true)
						enemy.ability_cooldown = enemy.ability_max_cd
						add_message(
							messages,
							game,
							fmt.tprintf("The %s spins a web!", enemy_display_name(&enemy)),
							eng.Engine_Color{100, 200, 100, 255},
						)
						break
					}
				}
			}
		} else if enemy.ability_type == ENEMY_ABILITY_PULL {
			// Pull: if player is in LOS within range but not adjacent, pull 1 tile closer
			dist := abs(enemy.pos.x - game.player.pos.x) + abs(enemy.pos.y - game.player.pos.y)
			if dist >= 2 && dist <= enemy.ability_range {
				if tile_visible_at(game, enemy.pos.x, enemy.pos.y) {
					// Pull player 1 tile toward enemy along the longer axis
					pull_dx := 0
					pull_dy := 0
					if enemy.pos.x > game.player.pos.x {
						pull_dx = 1
					} else if enemy.pos.x < game.player.pos.x {
						pull_dx = -1
					}
					if enemy.pos.y > game.player.pos.y {
						pull_dy = 1
					} else if enemy.pos.y < game.player.pos.y {
						pull_dy = -1
					}

					// Only pull along one axis (prefer the longer distance)
					if abs(enemy.pos.x - game.player.pos.x) >=
					   abs(enemy.pos.y - game.player.pos.y) {
						pull_dy = 0
					} else {
						pull_dx = 0
					}

					new_x := game.player.pos.x + pull_dx
					new_y := game.player.pos.y + pull_dy
					if is_walkable(game, new_x, new_y) && enemy_at(game, new_x, new_y) == nil {
						game.player.pos.x = new_x
						game.player.pos.y = new_y
						enemy.ability_cooldown = enemy.ability_max_cd
						add_message(
							messages,
							game,
							"The Deep Watcher pulls you closer!",
							eng.Engine_Color{180, 50, 220, 255},
						)
					}
				}
			}
		} else if enemy.ability_type == ENEMY_ABILITY_TELEPORT {
			dist := abs(enemy.pos.x - game.player.pos.x) + abs(enemy.pos.y - game.player.pos.y)
			if dist >= 3 && dist <= enemy.ability_range {
				if tile_visible_at(game, enemy.pos.x, enemy.pos.y) {
					dx := CARDINAL_DX
					dy := CARDINAL_DY
					for dir in 0 ..< 4 {
						tx := game.player.pos.x + dx[dir]
						ty := game.player.pos.y + dy[dir]
						if is_walkable(game, tx, ty) && enemy_at(game, tx, ty) == nil {
							enemy.pos = Vec2{tx, ty}
							enemy.ability_cooldown = enemy.ability_max_cd
							add_message(
								messages,
								game,
								fmt.tprintf(
									"The %s appears from the shadows!",
									enemy_display_name(&enemy),
								),
								eng.Engine_Color{80, 40, 120, 255},
							)
							break
						}
					}
				}
			}
		} else if enemy.ability_type == ENEMY_ABILITY_SLAM {
			dist := abs(enemy.pos.x - game.player.pos.x) + abs(enemy.pos.y - game.player.pos.y)
			if dist <= 2 {
				if dist == 1 {
					game.player.hp -= 4
					add_message(
						messages,
						game,
						"The Mine Guardian slams the ground! (-4 HP)",
						eng.Engine_Color{220, 180, 60, 255},
					)
					if game.player.hp <= 0 {
						player_die(messages, game, "Crushed by the Mine Guardian")
					}
				}
				enemy.ability_cooldown = enemy.ability_max_cd
			}
		} else if enemy.ability_type == ENEMY_ABILITY_DARKNESS {
			dist := abs(enemy.pos.x - game.player.pos.x) + abs(enemy.pos.y - game.player.pos.y)
			if dist <= enemy.ability_range {
				game.light_boost_bonus = max(game.light_boost_bonus - 2, -3)
				game.light_boost_turns = max(game.light_boost_turns, 5)
				enemy.ability_cooldown = enemy.ability_max_cd
				add_message(
					messages,
					game,
					"The Abyssal Lord shrouds you in darkness!",
					eng.Engine_Color{150, 30, 200, 255},
				)
			}
		} else if enemy.ability_type == ENEMY_ABILITY_RANGED_SHOOT {
			dist := abs(enemy.pos.x - game.player.pos.x) + abs(enemy.pos.y - game.player.pos.y)
			if dist >= 2 && dist <= enemy.ability_range {
				if tile_visible_at(game, enemy.pos.x, enemy.pos.y) {
					dmg := enemy.attack
					game.player.hp -= dmg
					enemy.ability_cooldown = enemy.ability_max_cd
					add_message(
						messages,
						game,
						fmt.tprintf(
							"The %s throws a stone at you! (%d damage)",
							enemy_display_name(&enemy),
							dmg,
						),
						eng.Engine_Color{200, 160, 80, 255},
					)
					if game.player.hp <= 0 {
						player_die(
							messages,
							game,
							fmt.tprintf("Pelted to death by a %s", enemy_display_name(&enemy)),
						)
					}
				}
			}
		} else if enemy.ability_type == ENEMY_ABILITY_FREEZE {
			dist := abs(enemy.pos.x - game.player.pos.x) + abs(enemy.pos.y - game.player.pos.y)
			if dist <= enemy.ability_range {
				if tile_visible_at(game, enemy.pos.x, enemy.pos.y) {
					game.frozen_turns = max(game.frozen_turns, 3)
					enemy.ability_cooldown = enemy.ability_max_cd
					add_message(
						messages,
						game,
						fmt.tprintf(
							"The %s freezes you with its gaze!",
							enemy_display_name(&enemy),
						),
						eng.Engine_Color{100, 180, 255, 255},
					)
				}
			}
		}
	}
}

// ─── Remove dead enemies ────────────────────────────────────────────────────
