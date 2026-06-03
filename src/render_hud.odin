package main

import eng "./engine"
import "core:fmt"
import rl "vendor:raylib"

// ─── Sidebar palette ─────────────────────────────────────────────────────────

SB_BG         :: rl.Color{12, 12, 20, 255}
SB_DIVIDER    :: rl.Color{35, 35, 52, 255}
SB_TITLE      :: rl.Color{200, 175, 90, 255}
SB_HEADER     :: rl.Color{130, 130, 155, 255}
SB_TEXT       :: rl.Color{195, 195, 210, 255}
SB_DIM        :: rl.Color{75, 75, 90, 255}
SB_HP_BG      :: rl.Color{70, 15, 15, 255}
SB_HP_FG      :: rl.Color{45, 185, 55, 255}
SB_HP_LOW     :: rl.Color{200, 55, 40, 255}
SB_PICK_BG    :: rl.Color{35, 25, 15, 255}
SB_PICK_OK    :: rl.Color{75, 170, 75, 255}
SB_PICK_WARN  :: rl.Color{195, 175, 45, 255}
SB_PICK_CRIT  :: rl.Color{200, 55, 40, 255}
SB_WPN        :: rl.Color{195, 145, 70, 255}
SB_ARM        :: rl.Color{90, 155, 205, 255}
SB_HLM        :: rl.Color{195, 195, 50, 255}
SB_OIL        :: rl.Color{250, 195, 70, 255}
SB_POISON     :: rl.Color{115, 200, 40, 255}
SB_BOSS       :: rl.Color{210, 45, 45, 255}
SB_KEY        :: rl.Color{120, 180, 255, 255}

// ─── Sidebar geometry ────────────────────────────────────────────────────────

SB_X  :: i32(MAP_VIEW_WIDTH)
SB_W  :: i32(SIDEBAR_WIDTH)
SB_H  :: i32(MAP_VIEW_HEIGHT)
SB_PX :: i32(8)   // inner padding-x
SB_IW :: SB_W - SB_PX * 2  // inner content width

// ─── Helpers ─────────────────────────────────────────────────────────────────

sb_bar :: proc(
	engine: ^eng.Engine,
	y: i32,
	ratio: f32,
	h: i32,
	bg, fg: rl.Color,
) {
	render_draw_rectangle(engine, SB_X + SB_PX, y, SB_IW, h, bg)
	filled := i32(f32(SB_IW) * clamp(ratio, 0, 1))
	if filled > 0 {
		render_draw_rectangle(engine, SB_X + SB_PX, y, filled, h, fg)
	}
}

sb_divider :: proc(engine: ^eng.Engine, y: i32) {
	render_draw_rectangle(engine, SB_X, y, SB_W, 1, SB_DIVIDER)
}

sb_text :: proc(engine: ^eng.Engine, text: cstring, y, size: i32, color: rl.Color) {
	render_draw_text(engine, text, SB_X + SB_PX, y, size, color)
}

sb_text_right :: proc(engine: ^eng.Engine, text: cstring, y, size: i32, color: rl.Color) {
	w := render_measure_text(engine, text, size)
	render_draw_text(engine, text, SB_X + SB_W - SB_PX - w, y, size, color)
}

// ─── Main sidebar ─────────────────────────────────────────────────────────────

render_hud :: proc(engine: ^eng.Engine, game: ^Game) {
	turns := game_engine_turn_manager(engine)

	// Background
	render_draw_rectangle(engine, SB_X, 0, SB_W, SB_H, SB_BG)

	y := i32(4)

	// ── Title ──────────────────────────────────────────────────────────────
	title := cstring("INTO THE DEPTHS")
	tw := render_measure_text(engine, title, 14)
	render_draw_text(engine, title, SB_X + (SB_W - tw) / 2, y, 14, SB_TITLE)
	y += 20
	sb_divider(engine, y)
	y += 6

	// ── HP ──────────────────────────────────────────────────────────────────
	hp_ratio := f32(max(game.player.hp, 0)) / f32(game.player.max_hp)
	hp_fg := SB_HP_FG if hp_ratio > 0.3 else SB_HP_LOW
	sb_text(engine, "HP", y, 12, SB_HEADER)
	sb_text_right(
		engine,
		rl.TextFormat("%d / %d", i32(game.player.hp), i32(game.player.max_hp)),
		y,
		12,
		SB_TEXT,
	)
	y += 14
	sb_bar(engine, y, hp_ratio, 10, SB_HP_BG, hp_fg)
	y += 15
	// ── Weapon speed ─────────────────────────────────────────────────────────
	// Show attack cadence relative to BASE_ACTION_COST (1000 AP) so the player
	// understands how their equipped weapon affects timing — not raw AP numbers.
	{
		cost := effective_attack_cost(game)
		spd_label: cstring
		spd_color: rl.Color
		if cost <= 700 {
			spd_label = "Fast"
			spd_color = rl.Color{80, 220, 100, 255}
		} else if cost <= 1100 {
			spd_label = "Normal"
			spd_color = SB_TEXT
		} else if cost <= 1600 {
			spd_label = "Slow"
			spd_color = rl.Color{220, 170, 60, 255}
		} else {
			spd_label = "Very Slow"
			spd_color = rl.Color{220, 80, 60, 255}
		}
		sb_text(engine, "ATK", y, 12, SB_HEADER)
		sb_text_right(engine, spd_label, y, 12, spd_color)
		y += 14
	}


	// ── Pickaxe durability (only when equipped) ──────────────────────────────
	if game.equipped_weapon.occupied {
		wpn := game.equipped_weapon.item
		if wpn.max_durability > 0 {
			pick_ratio := f32(wpn.durability) / f32(max(wpn.max_durability, 1))
			pick_fg: rl.Color
			if wpn.durability <= 0 {
				pick_fg = SB_PICK_CRIT
			} else if pick_ratio > 0.5 {
				pick_fg = SB_PICK_OK
			} else if pick_ratio > 0.25 {
				pick_fg = SB_PICK_WARN
			} else {
				pick_fg = SB_PICK_CRIT
			}
			pick_label: cstring = "PICK"
			if wpn.durability <= 0 {
				sb_text(engine, "PICK  BROKEN", y, 12, SB_PICK_CRIT)
			} else {
				sb_text(engine, pick_label, y, 12, SB_HEADER)
				sb_text_right(
					engine,
					rl.TextFormat("%d / %d", i32(wpn.durability), i32(wpn.max_durability)),
					y,
					12,
					SB_TEXT,
				)
			}
			y += 14
			sb_bar(engine, y, pick_ratio, 6, SB_PICK_BG, pick_fg)
			y += 11
		}
	}

	y += 3
	sb_divider(engine, y)
	y += 6

	// ── Depth / Turn / Kills / Light ─────────────────────────────────────────
	sb_text(
		engine,
		rl.TextFormat("DEPTH  %d", i32(game.depth)),
		y,
		13,
		SB_TEXT,
	)
	sb_text_right(
		engine,
		rl.TextFormat("TURN %d", i32(eng.turn_manager_current(turns))),
		y,
		13,
		SB_DIM,
	)
	y += 17

	alive_count: i32 = 0
	for &e in game.enemies {
		if e.alive {alive_count += 1}
	}
	sb_text(
		engine,
		rl.TextFormat("KILLS  %d", i32(game.kills)),
		y,
		13,
		SB_TEXT,
	)
	sb_text_right(
		engine,
		rl.TextFormat("NEAR %d", alive_count),
		y,
		13,
		SB_DIM,
	)
	y += 17

	if game.light_boost_turns > 0 {
		// Show light radius + remaining fuel turns
		sb_text(
			engine,
			rl.TextFormat("LIGHT  %d", i32(game.player.light_radius)),
			y,
			13,
			SB_OIL,
		)
		sb_text_right(
			engine,
			rl.TextFormat("%dt fuel", i32(game.light_boost_turns)),
			y,
			13,
			SB_OIL,
		)
	} else {
		sb_text(
			engine,
			rl.TextFormat("LIGHT  %d", i32(game.player.light_radius)),
			y,
			13,
			SB_TEXT,
		)
		sb_text_right(
			engine,
			rl.TextFormat("ITEMS %d", i32(game.items_found)),
			y,
			13,
			SB_DIM,
		)
	}
	y += 17

	y += 2
	sb_divider(engine, y)
	y += 6

	// ── Equipment ────────────────────────────────────────────────────────────
	sb_text(engine, "EQUIPMENT", y, 12, SB_HEADER)
	y += 16

	if game.equipped_weapon.occupied {
		wpn := &game.equipped_weapon.item
		sb_text(
			engine,
			rl.TextFormat("WPN  %s (+%d)", wpn.name, i32(wpn.stat_bonus)),
			y,
			12,
			SB_WPN,
		)
	} else {
		sb_text(engine, "WPN  ---", y, 12, SB_DIM)
	}
	y += 15

	if game.equipped_armor.occupied {
		arm := &game.equipped_armor.item
		sb_text(
			engine,
			rl.TextFormat("ARM  %s (+%d)", arm.name, i32(arm.stat_bonus)),
			y,
			12,
			SB_ARM,
		)
	} else {
		sb_text(engine, "ARM  ---", y, 12, SB_DIM)
	}
	y += 15

	if game.equipped_helmet.occupied {
		hlm := &game.equipped_helmet.item
		sb_text(
			engine,
			rl.TextFormat("HLM  %s (+%d)", hlm.name, i32(hlm.stat_bonus)),
			y,
			12,
			SB_HLM,
		)
	} else {
		sb_text(engine, "HLM  ---", y, 12, SB_DIM)
	}
	y += 15

	// ── Status effects ───────────────────────────────────────────────────────
	has_status := game.light_boost_turns > 0 || game.poison_turns > 0 || game.burning_turns > 0 || game.frozen_turns > 0
	if has_status {
		y += 2
		sb_divider(engine, y)
		y += 6
		sb_text(engine, "STATUS", y, 12, SB_HEADER)
		y += 16

		if game.light_boost_turns > 0 {
			sb_text(
				engine,
				rl.TextFormat("OIL   %dt remaining", i32(game.light_boost_turns)),
				y,
				12,
				SB_OIL,
			)
			y += 15
		}
		if game.poison_turns > 0 {
			sb_text(
				engine,
				rl.TextFormat("POISON  %dt remaining", i32(game.poison_turns)),
				y,
				12,
				SB_POISON,
			)
			y += 15
		}
		if game.burning_turns > 0 {
			sb_text(
				engine,
				rl.TextFormat("BURNING (%d)", i32(game.burning_turns)),
				y,
				12,
				rl.Color{255, 120, 20, 255},
			)
			y += 14
		}
		if game.frozen_turns > 0 {
			sb_text(
				engine,
				rl.TextFormat("FROZEN (%d)", i32(game.frozen_turns)),
				y,
				12,
				rl.Color{100, 180, 255, 255},
			)
			y += 14
		}
	}

	// ── Boss health bar (in sidebar, not overlaying the map) ─────────────────
	for &enemy in game.enemies {
		if !enemy.alive || !enemy.is_boss {continue}

		y += 2
		sb_divider(engine, y)
		y += 6
		sb_text(engine, rl.TextFormat("%s", enemy.name), y, 12, SB_BOSS)
		sb_text_right(
			engine,
			rl.TextFormat("%d/%d", i32(enemy.hp), i32(enemy.max_hp)),
			y,
			12,
			SB_TEXT,
		)
		y += 16
		boss_ratio := f32(max(enemy.hp, 0)) / f32(max(enemy.max_hp, 1))
		sb_bar(engine, y, boss_ratio, 8, rl.Color{50, 15, 15, 255}, SB_BOSS)
		y += 12
		break
	}

	// ── Controls (near bottom, only if room) ─────────────────────────────────
	controls_y := SB_H - 82
	if y < controls_y {
		// Draw divider+controls only when there's space — avoids overlap with
		// long equipment/status sections
		sb_divider(engine, controls_y)
		sb_text(engine, "CONTROLS", controls_y + 6, 12, SB_HEADER)
		sb_text(engine, "[I]nv  [G]rab  [X]Mine", controls_y + 22, 12, SB_KEY)
		sb_text(engine, "[M]ap  [?]Help  [.]Wait", controls_y + 38, 12, SB_KEY)
		sb_text(engine, "[F1]Mute  [ ]/[ ] Vol", controls_y + 54, 12, SB_KEY)
	}

	// ── Contextual overlays (these draw ON the map, not in sidebar) ──────────

	// Mining mode — top-center of map area
	ui := ui_manager_state(game_engine_ui_manager(engine))
	if ui.mining_mode {
		mine_text := cstring("[MINING] Direction (WASD/arrows) | ESC cancel")
		mine_w := render_measure_text(engine, mine_text, 14)
		render_draw_text(
			engine,
			mine_text,
			(i32(MAP_VIEW_WIDTH) - mine_w) / 2,
			4,
			14,
			rl.Color{255, 200, 80, 255},
		)
	}

	// Anvil hint — just above the message log
	cur := tile_at(game, game.player.pos.x, game.player.pos.y)
	if cur != nil && cur.type == .Anvil {
		anvil_text := cstring("[C = Craft]")
		anvil_w := render_measure_text(engine, anvil_text, 14)
		render_draw_text(
			engine,
			anvil_text,
			(i32(MAP_VIEW_WIDTH) - anvil_w) / 2,
			i32(MAP_VIEW_HEIGHT) - 22,
			14,
			rl.Color{160, 160, 170, 255},
		)
	}

	// Fountain hint
	if cur != nil && cur.type == .Fountain {
		fount_text := cstring("[Fountain — restores HP]")
		fount_w := render_measure_text(engine, fount_text, 14)
		render_draw_text(
			engine,
			fount_text,
			(i32(MAP_VIEW_WIDTH) - fount_w) / 2,
			i32(MAP_VIEW_HEIGHT) - 22,
			14,
			rl.Color{80, 180, 220, 255},
		)
	}
}
