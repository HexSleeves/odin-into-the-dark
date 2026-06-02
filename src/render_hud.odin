package main

import "core:fmt"
import rl "vendor:raylib"
import eng "./engine"

// ─── HUD rendering (fixed region below map viewport) ──────────────────────────

render_hud :: proc(engine: ^eng.Engine, game: ^Game) {
	turns := game_engine_turn_manager(engine)
	ui := ui_manager_state(game_engine_ui_manager(engine))
	hud_y := i32(MAP_VIEW_HEIGHT)

	// Background bar
	rl.DrawRectangle(
		0,
		hud_y,
		i32(SCREEN_WIDTH),
		i32(HUD_REGION_HEIGHT),
		rl.Color{20, 20, 25, 255},
	)

	// HP bar
	hp_ratio := f32(max(game.player.hp, 0)) / f32(game.player.max_hp)
	hp_bar_w :: i32(200)
	hp_bar_h :: i32(16)
	hp_x :: i32(8)
	hp_y := hud_y + 4

	// Background (red)
	rl.DrawRectangle(hp_x, hp_y, hp_bar_w, hp_bar_h, rl.Color{80, 20, 20, 255})
	// Foreground (green)
	rl.DrawRectangle(
		hp_x,
		hp_y,
		i32(f32(hp_bar_w) * hp_ratio),
		hp_bar_h,
		rl.Color{40, 180, 40, 255},
	)

	// HP text
	rl.DrawText(
		rl.TextFormat("HP: %d/%d", i32(game.player.hp), i32(game.player.max_hp)),
		hp_x + 4,
		hp_y + 1,
		14,
		rl.WHITE,
	)

	// Stats line
	stats_y := hp_y + hp_bar_h + 4

	alive_count: i32 = 0
	for &e in game.enemies {
		if e.alive {alive_count += 1}
	}

	rl.DrawText(
		rl.TextFormat(
			"Depth: %d  |  Light: %d  |  Enemies: %d  |  Turn: %d  |  G=Grab  I=Inv  X=Mine  M=Map  ?=Help",
			i32(game.depth),
			i32(game.player.light_radius),
			alive_count,
			i32(eng.turn_manager_current(turns)),
		),
		hp_x,
		stats_y,
		14,
		rl.Color{180, 180, 180, 255},
	)

	// Oil buff indicator
	if game.light_boost_turns > 0 {
		oil_text := rl.TextFormat("Oil: %dt", i32(game.light_boost_turns))
		oil_x := hp_x + hp_bar_w + 16
		rl.DrawText(oil_text, oil_x, hp_y + 1, 14, rl.Color{255, 200, 80, 255})
	}

	// Pickaxe durability bar
	pick_x := hp_x + hp_bar_w + 120
	pick_bar_w :: i32(80)
	pick_bar_h :: i32(12)
	pick_y := hp_y + 2

	// Background
	rl.DrawRectangle(pick_x, pick_y, pick_bar_w, pick_bar_h, rl.Color{40, 30, 20, 255})

	if game.equipped_weapon.occupied && game.equipped_weapon.item.max_durability > 0 {
		wpn := game.equipped_weapon.item
		pick_ratio := f32(wpn.durability) / f32(max(wpn.max_durability, 1))
		// Color gradient: green -> yellow -> red
		pick_color: rl.Color
		if pick_ratio > 0.5 {
			pick_color = rl.Color{80, 180, 80, 255} // green
		} else if pick_ratio > 0.25 {
			pick_color = rl.Color{200, 180, 50, 255} // yellow
		} else {
			pick_color = rl.Color{200, 60, 60, 255} // red
		}
		if wpn.durability > 0 {
			rl.DrawRectangle(
				pick_x,
				pick_y,
				i32(f32(pick_bar_w) * pick_ratio),
				pick_bar_h,
				pick_color,
			)
			rl.DrawText(
				rl.TextFormat("Pick: %d/%d", i32(wpn.durability), i32(wpn.max_durability)),
				pick_x + 2,
				pick_y,
				12,
				rl.WHITE,
			)
		} else {
			rl.DrawText("Pick: BROKEN", pick_x + 2, pick_y, 12, rl.Color{255, 80, 80, 255})
		}
	} else if !game.equipped_weapon.occupied {
		rl.DrawText("Pick: ---", pick_x + 2, pick_y, 12, rl.Color{80, 80, 80, 255})
	}

	// Mining mode indicator (centered at top of screen)
	if ui.mining_mode {
		mine_text := cstring("[MINING] Choose direction (WASD/arrows) | ESC cancel")
		mine_w := rl.MeasureText(mine_text, 14)
		rl.DrawText(
			mine_text,
			(i32(SCREEN_WIDTH) - mine_w) / 2,
			2,
			14,
			rl.Color{255, 200, 80, 255},
		)
	}

	// Contextual hint: C=Craft when standing on anvil
	cur := tile_at(game, game.player.pos.x, game.player.pos.y)
	if cur != nil && cur.type == .Anvil {
		anvil_text := cstring("[C=Craft]")
		anvil_w := rl.MeasureText(anvil_text, 14)
		rl.DrawText(
			anvil_text,
			(i32(SCREEN_WIDTH) - anvil_w) / 2,
			hud_y - 18,
			14,
			rl.Color{160, 160, 170, 255},
		)
	}

	// Equipment indicators (right side of HUD)
	eq_x := i32(hp_x) + 600
	if game.equipped_weapon.occupied {
		rl.DrawText(
			fmt.ctprintf(
				"Wpn: %s (+%d)",
				game.equipped_weapon.item.name,
				game.equipped_weapon.item.stat_bonus,
			),
			eq_x,
			hp_y + 1,
			14,
			rl.Color{200, 150, 80, 255},
		)
	} else {
		rl.DrawText("Wpn: ---", eq_x, hp_y + 1, 14, rl.Color{80, 80, 80, 255})
	}
	if game.equipped_armor.occupied {
		rl.DrawText(
			fmt.ctprintf(
				"Arm: %s (+%d)",
				game.equipped_armor.item.name,
				game.equipped_armor.item.stat_bonus,
			),
			eq_x,
			hp_y + 18,
			14,
			rl.Color{100, 160, 200, 255},
		)
	} else {
		rl.DrawText("Arm: ---", eq_x, hp_y + 18, 14, rl.Color{80, 80, 80, 255})
	}
	if game.equipped_helmet.occupied {
		rl.DrawText(
			fmt.ctprintf(
				"Hlm: %s (+%d)",
				game.equipped_helmet.item.name,
				game.equipped_helmet.item.stat_bonus,
			),
			eq_x + 200,
			hp_y + 1,
			14,
			rl.Color{200, 200, 50, 255},
		)
	} else {
		rl.DrawText("Hlm: ---", eq_x + 200, hp_y + 1, 14, rl.Color{80, 80, 80, 255})
	}

	// Boss health bar
	for &enemy in game.enemies {
		if !enemy.alive || !enemy.is_boss {continue}

		boss_bar_w :: i32(300)
		boss_bar_h :: i32(16)
		boss_bar_x := (i32(SCREEN_WIDTH) - boss_bar_w) / 2
		boss_bar_y := i32(18)

		rl.DrawRectangle(boss_bar_x - 2, boss_bar_y - 2, boss_bar_w + 4, boss_bar_h + 4, rl.Color{10, 10, 15, 200})
		rl.DrawRectangle(boss_bar_x, boss_bar_y, boss_bar_w, boss_bar_h, rl.Color{60, 20, 20, 255})

		ratio := f32(max(enemy.hp, 0)) / f32(enemy.max_hp)
		rl.DrawRectangle(boss_bar_x, boss_bar_y, i32(f32(boss_bar_w) * ratio), boss_bar_h, rl.Color{200, 40, 40, 255})

		rl.DrawText(
			fmt.ctprintf("%s  %d/%d", enemy.name, enemy.hp, enemy.max_hp),
			boss_bar_x + 4, boss_bar_y + 1, 14, rl.WHITE,
		)
		break
	}
}
