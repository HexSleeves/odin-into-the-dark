package gameinput

import gp "../gameplay"
import eng "../engine"

// ─── Shrine input ────────────────────────────────────────────────────────────

update_viewing_shrine :: proc(engine: ^eng.Engine, game: ^Game, im: ^Input_Manager) {
	if action_pressed(im, .Menu_Back) {
		game.state = .Playing
		add_message(game_engine_message_manager(engine), game,
			"You leave the shrine untouched.", eng.Engine_Color{120, 120, 120, 255})
		return
	}

	if action_pressed(im, .Menu_Up) {
		game.shrine_choice = (game.shrine_choice + gp.SHRINE_BUFF_COUNT - 1) % gp.SHRINE_BUFF_COUNT
	}
	if action_pressed(im, .Menu_Down) {
		game.shrine_choice = (game.shrine_choice + 1) % gp.SHRINE_BUFF_COUNT
	}

	// Number keys 1-3
	if action_pressed(im, .Inv_Slot_1) {
		gp.apply_shrine_buff(engine, game, .Max_HP)
		return
	}
	if action_pressed(im, .Inv_Slot_2) {
		gp.apply_shrine_buff(engine, game, .Attack)
		return
	}
	if action_pressed(im, .Inv_Slot_3) {
		gp.apply_shrine_buff(engine, game, .Light)
		return
	}

	if action_pressed(im, .Menu_Confirm) {
		buffs := [3]gp.Shrine_Buff{.Max_HP, .Attack, .Light}
		if game.shrine_choice >= 0 && game.shrine_choice < len(buffs) {
			gp.apply_shrine_buff(engine, game, buffs[game.shrine_choice])
		}
	}
}

// ─── Merchant input ──────────────────────────────────────────────────────────

update_viewing_merchant :: proc(engine: ^eng.Engine, game: ^Game, im: ^Input_Manager) {
	if action_pressed(im, .Menu_Back) {
		if game.depth == SURFACE_DEPTH {
			gp.merchant_leave_shop(engine, game)
		} else {
			gp.merchant_leave(engine, game)
		}
		return
	}

	if action_pressed(im, .Inv_Slot_1) {gp.merchant_buy(engine, game, 0)}
	if action_pressed(im, .Inv_Slot_2) {gp.merchant_buy(engine, game, 1)}
	if action_pressed(im, .Inv_Slot_3) {gp.merchant_buy(engine, game, 2)}
}
