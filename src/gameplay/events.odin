package gameplay

import gcore "../core"
import eng "../engine"
import "core:fmt"
import "core:math/rand"

// ─── Tile step trigger ───────────────────────────────────────────────────────

check_event_tile :: proc(engine: ^eng.Engine, game: ^Game) {
	if game.event_used {return}
	t := tile_at(game, game.player.pos.x, game.player.pos.y)
	if t == nil {return}

	messages := game_engine_message_manager(engine)
	#partial switch t.type {
	case .Shrine:
		game.state = .Viewing_Shrine
		game.shrine_choice = 0
		add_message(
			messages,
			game,
			"You stand before a glowing shrine...",
			eng.Engine_Color{100, 200, 255, 255},
		)
		tutorial_hint_once(
			messages,
			game,
			.First_Shrine,
			"A shrine offers power at a price. Choose a boon, but each costs some health.",
			eng.Engine_Color{255, 220, 130, 255},
		)
	case .Chest:
		open_chest(engine, game)
	case .Merchant:
		game.state = .Viewing_Merchant
		generate_merchant_stock(game_engine_content_manager(engine), game)
		add_message(
			messages,
			game,
			"A shadowy merchant beckons...",
			eng.Engine_Color{80, 220, 120, 255},
		)
	}
}

// ─── Shrine ──────────────────────────────────────────────────────────────────

Shrine_Buff :: enum {
	Max_HP,
	Attack,
	Light,
}

SHRINE_BUFF_COUNT :: 3

shrine_buff_label :: proc(buff: Shrine_Buff) -> string {
	switch buff {
	case .Max_HP:
		return fmt.tprintf("+%d Max HP", gcore.SHRINE_BUFF_MAX_HP)
	case .Attack:
		return fmt.tprintf("+%d Attack", gcore.SHRINE_BUFF_ATTACK)
	case .Light:
		return fmt.tprintf("+%d Light Radius", gcore.SHRINE_BUFF_LIGHT)
	}
	return "???"
}

apply_shrine_buff :: proc(engine: ^eng.Engine, game: ^Game, buff: Shrine_Buff) {
	messages := game_engine_message_manager(engine)
	hp_cost := max(1, game.player.hp * gcore.SHRINE_HP_COST_PERCENT / 100)
	game.player.hp -= hp_cost

	switch buff {
	case .Max_HP:
		game.player.max_hp += gcore.SHRINE_BUFF_MAX_HP
		game.player.hp += gcore.SHRINE_BUFF_MAX_HP // net gain = buff - cost
		add_message(
			messages,
			game,
			fmt.tprintf(
				"The shrine empowers you! +%d Max HP (-%d HP sacrifice)",
				gcore.SHRINE_BUFF_MAX_HP,
				hp_cost,
			),
			eng.Engine_Color{100, 200, 255, 255},
		)
	case .Attack:
		game.player.attack += gcore.SHRINE_BUFF_ATTACK
		add_message(
			messages,
			game,
			fmt.tprintf(
				"The shrine empowers you! +%d Attack (-%d HP sacrifice)",
				gcore.SHRINE_BUFF_ATTACK,
				hp_cost,
			),
			eng.Engine_Color{100, 200, 255, 255},
		)
	case .Light:
		game.player.light_radius += gcore.SHRINE_BUFF_LIGHT
		add_message(
			messages,
			game,
			fmt.tprintf(
				"The shrine empowers you! +%d Light (-%d HP sacrifice)",
				gcore.SHRINE_BUFF_LIGHT,
				hp_cost,
			),
			eng.Engine_Color{100, 200, 255, 255},
		)
	}

	if game.player.hp <= 0 {
		player_die(messages, game, "Sacrificed too much at a shrine")
		return
	}

	// Consume the shrine
	t := tile_at(game, game.player.pos.x, game.player.pos.y)
	if t != nil {t.type = .Floor}
	game.event_used = true
	game.state = .Playing
}

// ─── Milestone level-ups (D3) ─────────────────────────────────────────────────

// check_level_up reconciles game.player_level with the kills-derived level. For
// every level newly reached it queues a level-up menu and opens it. No-op when
// LEVELUP_ENABLED is off. Pure-derivation procs live in gcore.
check_level_up :: proc(engine: ^eng.Engine, game: ^Game) {
	if !gcore.LEVELUP_ENABLED || game == nil {return}
	derived := gcore.levelup_level_for_kills(game.kills)
	if derived <= game.player_level {return}

	gained := derived - game.player_level
	game.player_level = derived
	game.pending_level_ups += gained

	messages := game_engine_message_manager(engine)
	add_message(
		messages,
		game,
		fmt.tprintf("You reached level %d! Choose a boon.", derived),
		eng.Engine_Color{255, 220, 80, 255},
	)
	if game.state == .Playing {
		game.level_choice = 0
		game.state = .Viewing_Level_Up
	}
}

// apply_levelup_buff applies one level-up reward (no HP cost — unlike a shrine),
// decrements the pending count, and either re-opens the menu for the next queued
// level-up or returns to play. Mirrors the Shrine_Buff cases.
apply_levelup_buff :: proc(engine: ^eng.Engine, game: ^Game, buff: Shrine_Buff) {
	if game == nil {return}
	messages := game_engine_message_manager(engine)

	switch buff {
	case .Max_HP:
		game.player.max_hp += gcore.LEVELUP_BUFF_MAX_HP
		game.player.hp += gcore.LEVELUP_BUFF_MAX_HP
		add_message(
			messages,
			game,
			fmt.tprintf("You feel hardier! +%d Max HP", gcore.LEVELUP_BUFF_MAX_HP),
			eng.Engine_Color{255, 220, 80, 255},
		)
	case .Attack:
		game.player.attack += gcore.LEVELUP_BUFF_ATTACK
		add_message(
			messages,
			game,
			fmt.tprintf("Your strikes sharpen! +%d Attack", gcore.LEVELUP_BUFF_ATTACK),
			eng.Engine_Color{255, 220, 80, 255},
		)
	case .Light:
		game.player.light_radius += gcore.LEVELUP_BUFF_LIGHT
		add_message(
			messages,
			game,
			fmt.tprintf("Your sight sharpens! +%d Light Radius", gcore.LEVELUP_BUFF_LIGHT),
			eng.Engine_Color{255, 220, 80, 255},
		)
	}

	if game.pending_level_ups > 0 {game.pending_level_ups -= 1}

	if game.pending_level_ups > 0 {
		// More queued — keep the menu open for the next choice.
		game.level_choice = 0
		game.state = .Viewing_Level_Up
	} else {
		game.state = .Playing
	}
}

// ─── Chest ───────────────────────────────────────────────────────────────────

open_chest :: proc(engine: ^eng.Engine, game: ^Game) {
	messages := game_engine_message_manager(engine)
	content := game_engine_content_manager(engine)

	// Always give loot
	def := gcore.content_manager_pick_item_def_for_depth(content, game.depth)
	if def != nil {
		loot := item_make_from_def(def, game.player.pos)
		append(&game.items, loot)
		add_message(
			messages,
			game,
			fmt.tprintf("You open the chest and find a %s!", def.name),
			eng.Engine_Color{220, 180, 50, 255},
		)
	}

	// Chance of trap
	if rand.int_max(100) < gcore.CHEST_TRAP_CHANCE {
		trap_roll := rand.int_max(2)
		if trap_roll == 0 {
			game.player.hp -= gcore.CHEST_TRAP_DAMAGE
			add_message(
				messages,
				game,
				fmt.tprintf("A needle trap! -%d HP", gcore.CHEST_TRAP_DAMAGE),
				eng.Engine_Color{255, 100, 100, 255},
			)
			eng.vfx_manager_flash(
				game_engine_vfx_manager(engine),
				eng.Engine_Color{255, 0, 0, 255},
				0.3,
			)
			if game.player.hp <= 0 {
				player_die(messages, game, "Killed by a trapped chest")
				return
			}
		} else {
			status_apply(&game.player_status, .Poison, gcore.CHEST_TRAP_POISON_TURNS)
			add_message(
				messages,
				game,
				"Poison gas! You feel sick...",
				eng.Engine_Color{120, 200, 40, 255},
			)
		}
	}

	// Consume the chest
	t := tile_at(game, game.player.pos.x, game.player.pos.y)
	if t != nil {t.type = .Floor}
	game.event_used = true
	audio_manager_play_sfx(game_engine_audio_manager(engine), .Pickup)
}

// ─── Merchant ────────────────────────────────────────────────────────────────

MERCHANT_OFFER_COUNT :: 3

generate_merchant_stock :: proc(content: ^Content_Manager, game: ^Game) {
	for i in 0 ..< MERCHANT_OFFER_COUNT {
		def := gcore.content_manager_pick_item_def_for_depth(content, game.depth)
		if def != nil {
			cost_qty := 2 + game.depth / 3
			game.merchant_stock[i] = gcore.Merchant_Offer {
				item_id  = def.id,
				cost_id  = "iron_ore",
				cost_qty = cost_qty,
				sold     = false,
			}
		}
	}
}

generate_shopkeeper_stock :: proc(game: ^Game) {
	game.merchant_stock = [3]gcore.Merchant_Offer {
		{item_id = ITEM_ID_BANDAGE, cost_id = "iron_ore", cost_qty = 1},
		{item_id = ITEM_ID_TORCH, cost_id = "copper_ore", cost_qty = 1},
		{item_id = "health_potion", cost_id = "iron_ore", cost_qty = 2},
	}
}

merchant_buy :: proc(engine: ^eng.Engine, game: ^Game, offer_index: int) -> bool {
	if offer_index < 0 || offer_index >= MERCHANT_OFFER_COUNT {return false}
	offer := &game.merchant_stock[offer_index]
	if offer.sold || offer.item_id == "" {return false}

	messages := game_engine_message_manager(engine)
	content := game_engine_content_manager(engine)

	have := inventory_count_item_type(game, offer.cost_id)
	if have < offer.cost_qty {
		add_message(
			messages,
			game,
			fmt.tprintf("Need %d %s (have %d).", offer.cost_qty, offer.cost_id, have),
			eng.Engine_Color{255, 100, 100, 255},
		)
		return false
	}

	slot := inventory_first_empty_slot(game)
	if slot < 0 {
		add_message(messages, game, "Inventory full!", eng.Engine_Color{255, 100, 100, 255})
		return false
	}

	inventory_consume_item_type(game, offer.cost_id, offer.cost_qty)
	def := content_manager_item_def(content, offer.item_id)
	if def != nil {
		item := item_make_from_def(def, game.player.pos)
		item.picked_up = true
		inventory_put_slot(game, slot, item, 1)
		offer.sold = true
		add_message(
			messages,
			game,
			fmt.tprintf("Purchased %s!", def.name),
			eng.Engine_Color{80, 220, 120, 255},
		)
		audio_manager_play_sfx(game_engine_audio_manager(engine), .Pickup)
		return true
	}
	return false
}

merchant_leave :: proc(engine: ^eng.Engine, game: ^Game) {
	messages := game_engine_message_manager(engine)
	add_message(
		messages,
		game,
		"The merchant vanishes into shadow.",
		eng.Engine_Color{120, 120, 120, 255},
	)
	t := tile_at(game, game.player.pos.x, game.player.pos.y)
	if t != nil {t.type = .Floor}
	game.event_used = true
	game.state = .Playing
}

merchant_leave_shop :: proc(engine: ^eng.Engine, game: ^Game) {
	messages := game_engine_message_manager(engine)
	add_message(
		messages,
		game,
		"Bram closes the shop ledger.",
		eng.Engine_Color{120, 120, 120, 255},
	)
	game.state = .Playing
}
