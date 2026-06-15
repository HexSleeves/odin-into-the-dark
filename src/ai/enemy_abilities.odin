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

		// Fix 1: abilities respect the same awareness contract as movement.
		// detection_radius <= 0 means always-aware (legacy enemies) — let them fire.
		if enemy.detection_radius > 0 && !enemy.aware {continue}

		// Fix 4: Frozen doubles the AP cost of using an ability, mirroring movement.
		ability_cost := BASE_ACTION_COST
		if status_active(&enemy.status, .Frozen) {ability_cost *= 2}

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
						enemy.energy -= ability_cost
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
		} else if enemy.ability_type == ENEMY_ABILITY_POISON_CLOUD {
			// Poison cloud: vent toxic gas onto a floor tile adjacent to the enemy
			// when the player is within range, creating a lingering Gas_Vent hazard.
			dist := abs(enemy.pos.x - game.player.pos.x) + abs(enemy.pos.y - game.player.pos.y)
			if dist <= enemy.ability_range {
				dx := CARDINAL_DX
				dy := CARDINAL_DY
				for dir in 0 ..< 4 {
					gx := enemy.pos.x + dx[dir]
					gy := enemy.pos.y + dy[dir]
					t := tile_at(game, gx, gy)
					if t != nil && t.type == .Floor {
						t.type = .Gas_Vent
						enemy.ability_cooldown = enemy.ability_max_cd
						enemy.energy -= ability_cost
						add_message(
							messages,
							game,
							fmt.tprintf(
								"The %s belches a cloud of toxic spores!",
								enemy_display_name(&enemy),
							),
							eng.Engine_Color{120, 200, 40, 255},
						)
						break
					}
				}
			}
		} else if enemy.ability_type == ENEMY_ABILITY_PULL {
			// Pull: if player is in LOS within range but not adjacent, pull 1 tile closer
			dist := abs(enemy.pos.x - game.player.pos.x) + abs(enemy.pos.y - game.player.pos.y)
			if dist >= 2 && dist <= enemy.ability_range {
				if enemy_has_los_to_player(game, enemy.pos) {
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
						enemy.energy -= ability_cost
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
				if enemy_has_los_to_player(game, enemy.pos) {
					dx := CARDINAL_DX
					dy := CARDINAL_DY
					for dir in 0 ..< 4 {
						tx := game.player.pos.x + dx[dir]
						ty := game.player.pos.y + dy[dir]
						if is_walkable(game, tx, ty) && enemy_at(game, tx, ty) == nil {
							enemy.pos = Vec2{tx, ty}
							enemy_occupancy_mark_dirty(game)
							enemy.ability_cooldown = enemy.ability_max_cd
							enemy.energy -= ability_cost
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
					base := enemy.ability_damage if enemy.ability_damage > 0 else SLAM_BASE_DAMAGE
					dmg := max(damage_roll(base) - effective_defense(game), 1)
					game.player.hp = max(game.player.hp - dmg, 0)
					add_message(
						messages,
						game,
						fmt.tprintf(
							"The %s slams the ground! (-%d HP)",
							enemy_display_name(&enemy),
							dmg,
						),
						eng.Engine_Color{220, 180, 60, 255},
					)
					if game.player.hp <= 0 {
						player_die(
							messages,
							game,
							fmt.tprintf("Crushed by the %s", enemy_display_name(&enemy)),
						)
					}
				}
				enemy.ability_cooldown = enemy.ability_max_cd
				enemy.energy -= ability_cost
			}
		} else if enemy.ability_type == ENEMY_ABILITY_DARKNESS {
			dist := abs(enemy.pos.x - game.player.pos.x) + abs(enemy.pos.y - game.player.pos.y)
			if dist <= enemy.ability_range {
				// Write to debuff fields (negative bonus) — never clobbers the oil boost.
				game.light_debuff_bonus = max(game.light_debuff_bonus - 2, -3)
				game.light_debuff_turns = max(game.light_debuff_turns, 5)
				enemy.ability_cooldown = enemy.ability_max_cd
				enemy.energy -= ability_cost
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
				if enemy_has_los_to_player(game, enemy.pos) {
					base := enemy.ability_damage if enemy.ability_damage > 0 else enemy.attack
					dmg := max(damage_roll(base) - effective_defense(game), 1)
					game.player.hp = max(game.player.hp - dmg, 0)
					enemy.ability_cooldown = enemy.ability_max_cd
					enemy.energy -= ability_cost
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
				if enemy_has_los_to_player(game, enemy.pos) {
					status_apply(&game.player_status, .Frozen, 3)
					enemy.ability_cooldown = enemy.ability_max_cd
					enemy.energy -= ability_cost
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
