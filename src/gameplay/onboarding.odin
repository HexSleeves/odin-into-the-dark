package gameplay

import gcore "../core"
import eng "../engine"

// ─── First-encounter onboarding hints (D4) ───────────────────────────────────
//
// tutorial_hint_once surfaces a one-time tutorial message via the message log.
// The first call for a given hint sets its flag, emits the message, and returns
// true; every later call for the same hint is a no-op and returns false. Flags
// live on the Game struct, are persisted in the save (so a hint already seen
// stays suppressed across a descent or a save/reload), and are cleared on game
// reinit/restart so each fresh run re-teaches the basics.

Tutorial_Hint :: gcore.Tutorial_Hint
Tutorial_Flags :: gcore.Tutorial_Flags

tutorial_hint_once :: proc(
	messages: ^Message_Manager,
	game: ^Game,
	hint: Tutorial_Hint,
	text: string,
	color: eng.Engine_Color,
) -> bool {
	if game == nil {return false}
	if hint in game.tutorial_flags {return false}
	game.tutorial_flags += {hint}
	add_message(messages, game, text, color)
	return true
}

// ─── Hint colors ─────────────────────────────────────────────────────────────

@(private = "file")
HINT_COLOR :: eng.Engine_Color{255, 220, 130, 255}

// check_visibility_onboarding fires the "first enemy seen" hint once any living
// enemy stands on a currently-visible tile. Call it AFTER compute_fov so the
// tile-state visibility layer is up to date.
check_visibility_onboarding :: proc(messages: ^Message_Manager, game: ^Game) {
	if game == nil {return}
	if .First_Enemy in game.tutorial_flags {return}
	for &enemy in game.enemies {
		if !enemy.alive {continue}
		if gcore.tile_visible_at(game, enemy.pos.x, enemy.pos.y) {
			tutorial_hint_once(
				messages,
				game,
				.First_Enemy,
				"A creature lurks ahead. Step into it to attack, or back away to avoid it.",
				HINT_COLOR,
			)
			return
		}
	}
}

// check_status_onboarding fires the "first status effect" hint once any status
// turns are active on the player.
check_status_onboarding :: proc(messages: ^Message_Manager, game: ^Game) {
	if game == nil {return}
	if .First_Status in game.tutorial_flags {return}
	for kind in gcore.Status_Kind {
		if game.player_status[kind] > 0 {
			tutorial_hint_once(
				messages,
				game,
				.First_Status,
				"A status effect grips you. It wears off over the next few turns.",
				HINT_COLOR,
			)
			return
		}
	}
}
