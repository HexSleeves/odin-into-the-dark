package main

import eng "./engine"


tick_timed_effects :: proc(messages: ^Message_Manager, game: ^Game) {
	if game.state == .Game_Over {return}

	if game.light_boost_turns > 0 {
		game.light_boost_turns -= 1
		if game.light_boost_turns <= 0 {
			game.light_boost_bonus = 0
			add_message(
				messages,
				game,
				"The lantern oil burns out.",
				eng.Engine_Color{180, 130, 50, 255},
			)
		}
	}

	if game.poison_turns > 0 {
		game.poison_turns -= 1
		game.player.hp = max(game.player.hp - 1, 0)
		add_message(
			messages,
			game,
			"Poison damages you! (-1 HP)",
			eng.Engine_Color{120, 200, 40, 255},
		)
		if game.player.hp <= 0 {
			player_die(messages, game, "Died from poison")
			return
		}
	}

	if game.burning_turns > 0 {
		game.burning_turns -= 1
		game.player.hp = max(game.player.hp - 1, 0)
		add_message(
			messages,
			game,
			"You are burning! (-1 HP)",
			eng.Engine_Color{255, 120, 20, 255},
		)
		if game.player.hp <= 0 {
			player_die(messages, game, "Burned to death")
			return
		}
	}

	if game.frozen_turns > 0 {
		game.frozen_turns -= 1
		if game.frozen_turns > 0 {
			add_message(
				messages,
				game,
				"You are frozen! Movement costs double.",
				eng.Engine_Color{100, 180, 255, 255},
			)
		} else {
			add_message(
				messages,
				game,
				"The ice thaws. You can move freely.",
				eng.Engine_Color{150, 200, 255, 255},
			)
		}
	}

	// Passive light drain — darkness encroaches without a light source (depth 3+)
	if game.depth >= 3 && game.light_boost_turns <= 0 {
		game.light_drain_timer += 1
		if game.light_drain_timer >= LIGHT_DRAIN_INTERVAL {
			game.light_drain_timer = 0
			if game.player.light_radius > LIGHT_DRAIN_MIN {
				game.player.light_radius -= 1
				add_message(
					messages,
					game,
					"The darkness closes in... your light fades.",
					eng.Engine_Color{100, 100, 140, 255},
				)
			}
		}
	} else {
		// Reset drain timer while a light source is active
		game.light_drain_timer = 0
	}
}

// ─── Drop an item from inventory onto the map ────────────────────────────────
