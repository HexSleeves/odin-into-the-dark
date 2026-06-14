package gameplay

import gcore "../core"
import eng "../engine"
import "core:fmt"

LIGHT_DRAIN_START_DEPTH :: gcore.LIGHT_DRAIN_START_DEPTH
LIGHT_DRAIN_INTERVAL :: gcore.LIGHT_DRAIN_INTERVAL
LIGHT_DRAIN_MIN :: gcore.LIGHT_DRAIN_MIN

STATUS_TICK_DAMAGE :: 1

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

	if game.light_debuff_turns > 0 {
		game.light_debuff_turns -= 1
		if game.light_debuff_turns <= 0 {
			game.light_debuff_bonus = 0
		}
	}

	tick_player_statuses(messages, game)
	if game.state == .Game_Over {return}
	tick_enemy_statuses(messages, game)

	if game.depth >= LIGHT_DRAIN_START_DEPTH && game.light_boost_turns <= 0 {
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
		game.light_drain_timer = 0
	}
}

@(private = "file")
tick_player_statuses :: proc(messages: ^Message_Manager, game: ^Game) {
	s := &game.player_status

	if s[.Poison] > 0 {
		s[.Poison] -= 1
		game.player.hp = max(game.player.hp - STATUS_TICK_DAMAGE, 0)
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

	if s[.Burning] > 0 {
		s[.Burning] -= 1
		game.player.hp = max(game.player.hp - STATUS_TICK_DAMAGE, 0)
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

	if s[.Frozen] > 0 {
		s[.Frozen] -= 1
		if s[.Frozen] > 0 {
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

	// Webbed turns are decremented by the forced-turn handler when the player
	// struggles, not here — ticking both places would halve the stuck duration.
}

// Enemies share the same status semantics as the player: poison and burning
// deal 1 HP per round, frozen doubles movement cost, webbed skips the round.
// Frozen/webbed gating lives in the ai package; this proc handles the
// damage-over-time ticks and turn countdowns.
@(private = "file")
tick_enemy_statuses :: proc(messages: ^Message_Manager, game: ^Game) {
	for &enemy in game.enemies {
		if !enemy.alive {continue}
		s := &enemy.status

		if s[.Poison] > 0 {
			s[.Poison] -= 1
			damage_enemy_with_status(messages, game, &enemy, "succumbs to poison")
			if !enemy.alive {continue}
		}

		if s[.Burning] > 0 {
			s[.Burning] -= 1
			damage_enemy_with_status(messages, game, &enemy, "is consumed by flames")
			if !enemy.alive {continue}
		}

		if s[.Frozen] > 0 {s[.Frozen] -= 1}
		if s[.Webbed] > 0 {s[.Webbed] -= 1}
	}
}

@(private = "file")
damage_enemy_with_status :: proc(
	messages: ^Message_Manager,
	game: ^Game,
	enemy: ^Enemy,
	death_verb: string,
) {
	enemy.hp -= STATUS_TICK_DAMAGE
	if enemy.hp <= 0 {
		enemy.alive = false
		game.kills += 1
		add_message(
			messages,
			game,
			fmt.tprintf("The %s %s!", enemy_display_name(enemy), death_verb),
			eng.Engine_Color{0, 255, 0, 255},
		)
		if milestone_msg := apply_kill_milestone_buff(game); milestone_msg != "" {
			add_message(messages, game, milestone_msg, eng.Engine_Color{255, 220, 80, 255})
		}
	}
}
