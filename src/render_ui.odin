package main

import eng "./engine"
import "core:fmt"
import rl "vendor:raylib"

// ─── Shared overlay helpers ───────────────────────────────────────────────────

draw_centered_text :: proc(engine: ^eng.Engine, text: cstring, y, size: i32, color: rl.Color) {
	text_w := render_measure_text(engine, text, size)
	x := (i32(SCREEN_WIDTH) - text_w) / 2
	render_draw_text(engine, text, x, y, size, color)
}

draw_score_rows :: proc(
	engine: ^eng.Engine,
	scores: ^Score_Manager,
	base_y, row_size, row_h: i32,
	highlight_rank: int = -1,
) {
	table := score_manager_load(scores)
	defer score_table_destroy(&table)
	if table.count == 0 {
		draw_centered_text(
			engine,
			"No scores yet.",
			base_y,
			row_size,
			rl.Color{120, 120, 120, 255},
		)
		return
	}

	for i in 0 ..< table.count {
		y := base_y + i32(i) * row_h
		s := table.scores[i]
		is_current := (i == highlight_rank)
		color := rl.Color{255, 220, 100, 255} if is_current else rl.Color{180, 180, 180, 255}
		prefix := ">" if is_current else " "
		cause_display := s.cause if len(s.cause) > 0 else "Unknown"
		row_text := fmt.ctprintf(
			"%s #%d  Depth %d  Kills %d  Turns %d  %s",
			prefix,
			i + 1,
			s.depth,
			s.kills,
			s.turns,
			cause_display,
		)
		draw_centered_text(engine, row_text, y, row_size, color)
	}
}

// ─── Title and Scores screens ────────────────────────────────────────────────

render_title_screen :: proc(engine: ^eng.Engine, game: ^Game) {
	ui := ui_manager_state(game_engine_ui_manager(engine))
	render_draw_rectangle(
		engine,
		0,
		0,
		i32(SCREEN_WIDTH),
		i32(SCREEN_HEIGHT),
		rl.Color{0, 0, 0, 230},
	)

	draw_centered_text(engine, "INTO THE DEPTHS", 110, 48, rl.Color{255, 230, 120, 255})
	draw_centered_text(
		engine,
		"A turn-based mining roguelike",
		166,
		18,
		rl.Color{180, 180, 180, 255},
	)

	options := [TITLE_OPTION_COUNT]cstring{"New Game", "Continue", "High Scores", "Help", "Quit"}

	saves := game_engine_save_manager(engine)
	has_save := save_manager_save_exists(saves)
	base_y :: i32(245)
	row_h :: i32(38)
	for label, idx in options {
		y := base_y + i32(idx) * row_h
		disabled := idx == TITLE_CONTINUE && !has_save
		selected := idx == ui.title_choice
		color := rl.Color{90, 90, 90, 255} if disabled else rl.Color{220, 220, 220, 255}
		if selected && !disabled {
			color = rl.Color{255, 220, 100, 255}
		}
		text := fmt.ctprintf("%s %s", ">" if selected else " ", label)
		draw_centered_text(engine, text, y, 24, color)
	}

	if !has_save {
		draw_centered_text(
			engine,
			"No save file found — Continue is disabled",
			base_y + row_h * TITLE_OPTION_COUNT + 12,
			14,
			rl.Color{120, 120, 120, 255},
		)
	}

	draw_centered_text(
		engine,
		"Up/Down: Select  |  Enter: Confirm  |  N/C/H/?: Shortcuts  |  Esc/Q: Quit",
		i32(SCREEN_HEIGHT) - 48,
		14,
		rl.Color{150, 150, 150, 255},
	)
}

render_high_scores :: proc(engine: ^eng.Engine, game: ^Game) {
	_ = game
	scores := game_engine_score_manager(engine)
	render_draw_rectangle(
		engine,
		0,
		0,
		i32(SCREEN_WIDTH),
		i32(SCREEN_HEIGHT),
		rl.Color{0, 0, 0, 230},
	)
	draw_centered_text(engine, "HIGH SCORES", 80, 34, rl.Color{255, 220, 50, 255})
	draw_score_rows(engine, scores, 145, 16, 28)
	draw_centered_text(
		engine,
		"Press ESC or H to return",
		i32(SCREEN_HEIGHT) - 40,
		16,
		rl.Color{150, 150, 150, 255},
	)
}

// ─── Inventory overlay screen ─────────────────────────────────────────────────

render_inventory :: proc(engine: ^eng.Engine, game: ^Game) {
	content := game_engine_content_manager(engine)
	ui := ui_manager_state(game_engine_ui_manager(engine))
	sprites := game_engine_sprite_manager(engine)
	render_draw_rectangle(
		engine,
		0,
		0,
		i32(SCREEN_WIDTH),
		i32(SCREEN_HEIGHT),
		rl.Color{0, 0, 0, 200},
	)

	title := cstring("INVENTORY")
	title_size :: i32(30)
	title_w := render_measure_text(engine, title, title_size)
	title_x := (i32(SCREEN_WIDTH) - title_w) / 2
	render_draw_text(engine, title, title_x, 100, title_size, rl.WHITE)

	subtitle := cstring("1-9=Use | D=Drop | E=Equip | Up/Down=Inspect | I/ESC=Close")
	subtitle_size :: i32(14)
	sub_w := render_measure_text(engine, subtitle, subtitle_size)
	sub_x := (i32(SCREEN_WIDTH) - sub_w) / 2
	render_draw_text(engine, subtitle, sub_x, 140, subtitle_size, rl.Color{150, 150, 150, 255})

	// Drop mode indicator
	if ui.dropping {
		drop_text := cstring("[DROP MODE] Press 1-9 to drop")
		drop_size :: i32(16)
		drop_w := render_measure_text(engine, drop_text, drop_size)
		drop_x := (i32(SCREEN_WIDTH) - drop_w) / 2
		render_draw_text(engine, drop_text, drop_x, 160, drop_size, rl.Color{255, 200, 80, 255})
	}

	// Equip mode indicator
	if ui.equipping {
		equip_text := cstring("[EQUIP MODE] Press 1-9 to equip")
		equip_size :: i32(16)
		equip_w := render_measure_text(engine, equip_text, equip_size)
		equip_x := (i32(SCREEN_WIDTH) - equip_w) / 2
		render_draw_text(
			engine,
			equip_text,
			equip_x,
			160,
			equip_size,
			rl.Color{100, 200, 255, 255},
		)
	}

	slot_size :: i32(16)
	slot_x :: i32(440)
	empty_color :: rl.Color{80, 80, 80, 255}

	for idx in 0 ..< MAX_INVENTORY {
		y_pos := i32(180) + i32(idx) * 28

		// Highlight selected slot
		if idx == ui.inspect_slot {
			render_draw_rectangle(
				engine,
				slot_x - 4,
				y_pos - 2,
				260,
				22,
				rl.Color{60, 60, 80, 200},
			)
			render_draw_text(
				engine,
				">",
				slot_x - 14,
				y_pos,
				slot_size,
				rl.Color{255, 220, 100, 255},
			)
		}

		if game.inventory[idx].occupied {
			it := game.inventory[idx].item
			name := item_display_name(&it)
			text_x := slot_x
			if ui.use_sprites {
				spr := sprite_manager_item(sprites, it.item_type)
				sprite_manager_draw(engine, sprites, spr, slot_x, y_pos, rl.WHITE)
				text_x = slot_x + 20
			}
			if it.quantity > 1 {
				render_draw_text(
					engine,
					fmt.ctprintf("%d. %s x%d", idx + 1, name, it.quantity),
					text_x,
					y_pos,
					slot_size,
					it.color,
				)
			} else {
				render_draw_text(
					engine,
					fmt.ctprintf("%d. %s", idx + 1, name),
					text_x,
					y_pos,
					slot_size,
					it.color,
				)
			}
		} else {
			render_draw_text(
				engine,
				fmt.ctprintf("%d. [empty]", idx + 1),
				slot_x,
				y_pos,
				slot_size,
				empty_color,
			)
		}
	}

	// Equipment section
	eq_y := i32(180) + i32(MAX_INVENTORY) * 28 + 20
	render_draw_text(engine, "EQUIPMENT", slot_x, eq_y, 18, rl.Color{200, 200, 100, 255})
	eq_y += 24

	// Equipment slots with cursor support (slots 9, 10, 11)
	equip_slots := [3]struct {
		label: cstring,
		slot:  ^Equipment,
		color: rl.Color,
		idx:   int,
	} {
		{
			label = "Weapon:",
			slot = &game.equipped_weapon,
			color = rl.Color{200, 150, 80, 255},
			idx = MAX_INVENTORY,
		},
		{
			label = "Armor: ",
			slot = &game.equipped_armor,
			color = rl.Color{100, 160, 200, 255},
			idx = MAX_INVENTORY + 1,
		},
		{
			label = "Helmet:",
			slot = &game.equipped_helmet,
			color = rl.Color{200, 200, 50, 255},
			idx = MAX_INVENTORY + 2,
		},
	}
	for es in equip_slots {
		// Highlight if cursor is on this equipment slot
		if ui.inspect_slot == es.idx {
			render_draw_rectangle(engine, slot_x - 4, eq_y - 2, 260, 22, rl.Color{60, 60, 80, 200})
			render_draw_text(
				engine,
				">",
				slot_x - 14,
				eq_y,
				slot_size,
				rl.Color{255, 220, 100, 255},
			)
		}
		if es.slot.occupied {
			eq_text_x := slot_x
			if ui.use_sprites {
				spr := sprite_manager_item(sprites, es.slot.item.item_type)
				sprite_manager_draw(engine, sprites, spr, slot_x, eq_y, rl.WHITE)
				eq_text_x = slot_x + 20
			}
			bonus_label: cstring
			if es.idx ==
			   MAX_INVENTORY {bonus_label = "atk"} else if es.idx == MAX_INVENTORY + 1 {bonus_label = "def"} else {bonus_label = "light"}
			render_draw_text(
				engine,
				fmt.ctprintf(
					"%s %s (+%d %s)",
					es.label,
					es.slot.item.name,
					es.slot.item.stat_bonus,
					bonus_label,
				),
				eq_text_x,
				eq_y,
				slot_size,
				es.color,
			)
		} else {
			render_draw_text(
				engine,
				fmt.ctprintf("%s [empty]", es.label),
				slot_x,
				eq_y,
				slot_size,
				empty_color,
			)
		}
		eq_y += 22
	}

	// ── Inspect detail panel (right side) ──
	// Determine which item to inspect
	inspect_item: ^Item = nil
	if ui.inspect_slot >= 0 && ui.inspect_slot < MAX_INVENTORY {
		if game.inventory[ui.inspect_slot].occupied {
			inspect_item = &game.inventory[ui.inspect_slot].item
		}
	} else if ui.inspect_slot == MAX_INVENTORY && game.equipped_weapon.occupied {
		inspect_item = &game.equipped_weapon.item
	} else if ui.inspect_slot == MAX_INVENTORY + 1 && game.equipped_armor.occupied {
		inspect_item = &game.equipped_armor.item
	} else if ui.inspect_slot == MAX_INVENTORY + 2 && game.equipped_helmet.occupied {
		inspect_item = &game.equipped_helmet.item
	}

	if inspect_item != nil {
		it := inspect_item
		def := content_manager_item_def(content, it.item_type)

		panel_x :: i32(720)
		panel_y :: i32(175)
		panel_w :: i32(320)
		panel_h :: i32(280)

		render_draw_rectangle(
			engine,
			panel_x,
			panel_y,
			panel_w,
			panel_h,
			rl.Color{30, 30, 40, 230},
		)
		render_draw_rectangle_lines(
			engine,
			panel_x,
			panel_y,
			panel_w,
			panel_h,
			rl.Color{80, 80, 100, 255},
		)

		dy := panel_y + 8

		// Item name
		render_draw_text(engine, fmt.ctprintf("%s", it.name), panel_x + 10, dy, 18, it.color)
		dy += 24

		// Type/category
		if it.equipment_slot != "" {
			render_draw_text(
				engine,
				fmt.ctprintf("Type: Equipment (%s)", it.equipment_slot),
				panel_x + 10,
				dy,
				14,
				rl.Color{150, 150, 150, 255},
			)
		} else if def != nil && def.effect.type == "material" {
			render_draw_text(
				engine,
				"Type: Crafting Material",
				panel_x + 10,
				dy,
				14,
				rl.Color{150, 150, 150, 255},
			)
		} else if def != nil && def.effect.type == "heal" {
			render_draw_text(
				engine,
				"Type: Consumable (Healing)",
				panel_x + 10,
				dy,
				14,
				rl.Color{150, 150, 150, 255},
			)
		} else if def != nil &&
		   (def.effect.type == "light_boost" || def.effect.type == "timed_light_boost") {
			render_draw_text(
				engine,
				"Type: Consumable (Light)",
				panel_x + 10,
				dy,
				14,
				rl.Color{150, 150, 150, 255},
			)
		} else {
			render_draw_text(
				engine,
				"Type: Item",
				panel_x + 10,
				dy,
				14,
				rl.Color{150, 150, 150, 255},
			)
		}
		dy += 20

		// Effect description
		if def != nil {
			if def.effect.type == "heal" {
				render_draw_text(
					engine,
					fmt.ctprintf("Heals %d HP", def.effect.value),
					panel_x + 10,
					dy,
					14,
					rl.Color{100, 255, 100, 255},
				)
				dy += 18
			} else if def.effect.type == "light_boost" {
				render_draw_text(
					engine,
					fmt.ctprintf("Permanently +%d light radius", def.effect.value),
					panel_x + 10,
					dy,
					14,
					rl.Color{255, 200, 80, 255},
				)
				dy += 18
			} else if def.effect.type == "timed_light_boost" {
				render_draw_text(
					engine,
					fmt.ctprintf("+%d light for %d turns", def.effect.value, def.effect.duration),
					panel_x + 10,
					dy,
					14,
					rl.Color{255, 200, 80, 255},
				)
				dy += 18
			} else if def.effect.type == "equip" {
				if it.equipment_slot == "weapon" {
					render_draw_text(
						engine,
						fmt.ctprintf("+%d Attack", it.stat_bonus),
						panel_x + 10,
						dy,
						14,
						rl.Color{200, 150, 80, 255},
					)
				} else if it.equipment_slot == "armor" {
					render_draw_text(
						engine,
						fmt.ctprintf("+%d Defense", it.stat_bonus),
						panel_x + 10,
						dy,
						14,
						rl.Color{100, 160, 200, 255},
					)
				} else if it.equipment_slot == "helmet" {
					render_draw_text(
						engine,
						fmt.ctprintf("+%d Light Radius", it.stat_bonus),
						panel_x + 10,
						dy,
						14,
						rl.Color{200, 200, 50, 255},
					)
				}
				dy += 18
			} else if def.effect.type == "material" {
				render_draw_text(
					engine,
					"Used for crafting at anvils.",
					panel_x + 10,
					dy,
					14,
					rl.Color{180, 180, 100, 255},
				)
				dy += 18
			}
		}

		// Stack info
		if it.quantity > 1 {
			render_draw_text(
				engine,
				fmt.ctprintf("Quantity: %d", it.quantity),
				panel_x + 10,
				dy,
				14,
				rl.Color{180, 180, 180, 255},
			)
			dy += 18
		}

		// Durability bar (for equipment)
		if it.max_durability > 0 {
			dy += 6
			render_draw_text(
				engine,
				"Durability:",
				panel_x + 10,
				dy,
				14,
				rl.Color{180, 180, 180, 255},
			)
			dy += 18
			bar_w :: i32(200)
			bar_h :: i32(14)
			bar_x := panel_x + 10
			ratio := f32(it.durability) / f32(max(it.max_durability, 1))
			// Background
			render_draw_rectangle(engine, bar_x, dy, bar_w, bar_h, rl.Color{40, 30, 20, 255})
			// Fill
			bar_color: rl.Color
			if ratio >
			   0.5 {bar_color = rl.Color{80, 180, 80, 255}} else if ratio > 0.25 {bar_color = rl.Color{200, 180, 50, 255}} else {bar_color = rl.Color{200, 60, 60, 255}}
			if it.durability > 0 {
				render_draw_rectangle(engine, bar_x, dy, i32(f32(bar_w) * ratio), bar_h, bar_color)
			}
			render_draw_text(
				engine,
				fmt.ctprintf("%d / %d", it.durability, it.max_durability),
				bar_x + 4,
				dy + 1,
				12,
				rl.WHITE,
			)
			dy += 20
			if it.durability <= 0 {
				render_draw_text(
					engine,
					"BROKEN - Repair at an anvil!",
					panel_x + 10,
					dy,
					14,
					rl.Color{255, 80, 80, 255},
				)
			}
		}
	}
}

// ─── Game Over screen ─────────────────────────────────────────────────────────

render_game_over :: proc(engine: ^eng.Engine, game: ^Game) {
	scores := game_engine_score_manager(engine)
	turns := game_engine_turn_manager(engine)
	render_draw_rectangle(
		engine,
		0,
		0,
		i32(SCREEN_WIDTH),
		i32(SCREEN_HEIGHT),
		rl.Color{0, 0, 0, 220},
	)

	sw := i32(SCREEN_WIDTH)

	// Title
	title := cstring("GAME OVER")
	title_size :: i32(36)
	title_w := render_measure_text(engine, title, title_size)
	render_draw_text(engine, title, (sw - title_w) / 2, 40, title_size, rl.RED)

	// Death cause
	cause_text := fmt.ctprintf(
		"%s",
		game.death_cause if len(game.death_cause) > 0 else "Unknown cause of death",
	)
	cause_size :: i32(18)
	cause_w := render_measure_text(engine, cause_text, cause_size)
	render_draw_text(engine, cause_text, (sw - cause_w) / 2, 82, cause_size, rl.WHITE)

	// Run stats
	stats_text := rl.TextFormat(
		"Depth: %d  |  Kills: %d  |  Turns: %d",
		i32(game.depth),
		i32(game.kills),
		i32(eng.turn_manager_current(turns)),
	)
	stats_size :: i32(16)
	stats_w := render_measure_text(engine, stats_text, stats_size)
	render_draw_text(
		engine,
		stats_text,
		(sw - stats_w) / 2,
		110,
		stats_size,
		rl.Color{180, 180, 180, 255},
	)

	// High Scores header
	hs_title := cstring("HIGH SCORES")
	hs_size :: i32(18)
	hs_w := render_measure_text(engine, hs_title, hs_size)
	render_draw_text(engine, hs_title, (sw - hs_w) / 2, 145, hs_size, rl.Color{255, 220, 50, 255})

	// Load and display score table
	table := score_manager_load(scores)
	defer score_table_destroy(&table)
	row_h :: i32(22)
	base_y :: i32(170)
	row_size :: i32(14)

	if table.count == 0 {
		empty := cstring("No scores yet.")
		empty_w := render_measure_text(engine, empty, row_size)
		render_draw_text(
			engine,
			empty,
			(sw - empty_w) / 2,
			base_y,
			row_size,
			rl.Color{120, 120, 120, 255},
		)
	} else {
		for i in 0 ..< table.count {
			y := base_y + i32(i) * row_h
			s := table.scores[i]

			is_current := (i == game.last_score_rank)
			color := rl.Color{255, 220, 100, 255} if is_current else rl.Color{180, 180, 180, 255}
			prefix := ">" if is_current else " "

			cause_display := s.cause if len(s.cause) > 0 else "Unknown"

			row_text := fmt.ctprintf(
				"%s #%d  Depth %d  Kills %d  Turns %d  %s",
				prefix,
				i + 1,
				s.depth,
				s.kills,
				s.turns,
				cause_display,
			)
			row_w := render_measure_text(engine, row_text, row_size)
			render_draw_text(engine, row_text, (sw - row_w) / 2, y, row_size, color)
		}
	}

	// Footer
	footer := cstring("Press R to restart  |  ESC to quit")
	footer_size :: i32(16)
	footer_w := render_measure_text(engine, footer, footer_size)
	render_draw_text(
		engine,
		footer,
		(sw - footer_w) / 2,
		i32(SCREEN_HEIGHT) - 30,
		footer_size,
		rl.Color{150, 150, 150, 255},
	)
}

// ─── Crafting overlay screen ──────────────────────────────────────────────────

render_crafting :: proc(engine: ^eng.Engine, game: ^Game) {
	content := game_engine_content_manager(engine)
	render_draw_rectangle(
		engine,
		0,
		0,
		i32(SCREEN_WIDTH),
		i32(SCREEN_HEIGHT),
		rl.Color{0, 0, 0, 200},
	)

	title := cstring("CRAFTING")
	title_size :: i32(30)
	title_w := render_measure_text(engine, title, title_size)
	title_x := (i32(SCREEN_WIDTH) - title_w) / 2
	render_draw_text(engine, title, title_x, 100, title_size, rl.WHITE)

	subtitle := cstring("Press 1-4 to craft | C or ESC to close")
	subtitle_size :: i32(14)
	sub_w := render_measure_text(engine, subtitle, subtitle_size)
	sub_x := (i32(SCREEN_WIDTH) - sub_w) / 2
	render_draw_text(engine, subtitle, sub_x, 140, subtitle_size, rl.Color{150, 150, 150, 255})

	recipes := RECIPES
	slot_x :: i32(340)

	for idx in 0 ..< len(recipes) {
		recipe := recipes[idx]
		y_pos := i32(180) + i32(idx) * 40

		have := count_material(game, recipe.material_id)
		can_craft := have >= recipe.material_qty

		color := rl.Color{100, 255, 100, 255} if can_craft else rl.Color{150, 80, 80, 255}

		// Get material display name
		mat_def := content_manager_item_def(content, recipe.material_id)
		mat_name := recipe.material_id
		if mat_def != nil {mat_name = mat_def.name}

		render_draw_text(
			engine,
			fmt.ctprintf(
				"%d. %s  [%d/%d %s]",
				idx + 1,
				recipe.name,
				have,
				recipe.material_qty,
				mat_name,
			),
			slot_x,
			y_pos,
			16,
			color,
		)
	}
}

// ─── Victory screen overlay ──────────────────────────────────────────────────

render_victory :: proc(engine: ^eng.Engine, game: ^Game) {
	scores := game_engine_score_manager(engine)
	turns := game_engine_turn_manager(engine)
	render_draw_rectangle(
		engine,
		0,
		0,
		i32(SCREEN_WIDTH),
		i32(SCREEN_HEIGHT),
		rl.Color{0, 0, 0, 220},
	)

	sw := i32(SCREEN_WIDTH)

	// Title
	title := cstring("VICTORY!")
	title_size :: i32(48)
	title_w := render_measure_text(engine, title, title_size)
	render_draw_text(engine, title, (sw - title_w) / 2, 80, title_size, rl.Color{255, 215, 0, 255})

	// Subtitle
	sub := cstring("You have conquered the depths!")
	sub_size :: i32(20)
	sub_w := render_measure_text(engine, sub, sub_size)
	render_draw_text(engine, sub, (sw - sub_w) / 2, 140, sub_size, rl.Color{200, 200, 100, 255})

	// Stats
	stats_y :: i32(190)
	center_x := sw / 2

	render_draw_text(
		engine,
		rl.TextFormat("Depth Reached: %d", i32(game.depth)),
		center_x - 100,
		stats_y,
		18,
		rl.Color{200, 200, 200, 255},
	)
	render_draw_text(
		engine,
		rl.TextFormat("Enemies Slain: %d", i32(game.kills)),
		center_x - 100,
		stats_y + 25,
		18,
		rl.Color{200, 200, 200, 255},
	)
	render_draw_text(
		engine,
		rl.TextFormat("Turns Survived: %d", i32(eng.turn_manager_current(turns))),
		center_x - 100,
		stats_y + 50,
		18,
		rl.Color{200, 200, 200, 255},
	)
	render_draw_text(
		engine,
		rl.TextFormat("HP Remaining: %d/%d", i32(game.player.hp), i32(game.player.max_hp)),
		center_x - 100,
		stats_y + 75,
		18,
		rl.Color{100, 255, 100, 255},
	)

	// High Scores
	hs_title := cstring("HIGH SCORES")
	hs_size :: i32(18)
	hs_w := render_measure_text(engine, hs_title, hs_size)
	render_draw_text(
		engine,
		hs_title,
		(sw - hs_w) / 2,
		stats_y + 115,
		hs_size,
		rl.Color{255, 220, 50, 255},
	)

	table := score_manager_load(scores)
	defer score_table_destroy(&table)
	row_h :: i32(22)
	base_y := stats_y + 140
	row_size :: i32(14)

	if table.count == 0 {
		empty := cstring("No scores yet.")
		empty_w := render_measure_text(engine, empty, row_size)
		render_draw_text(
			engine,
			empty,
			(sw - empty_w) / 2,
			base_y,
			row_size,
			rl.Color{120, 120, 120, 255},
		)
	} else {
		for i in 0 ..< table.count {
			y := base_y + i32(i) * row_h
			s := table.scores[i]

			is_current := (i == game.last_score_rank)
			color := rl.Color{255, 220, 100, 255} if is_current else rl.Color{180, 180, 180, 255}
			prefix := ">" if is_current else " "

			cause_display := s.cause if len(s.cause) > 0 else "Unknown"

			row_text := fmt.ctprintf(
				"%s #%d  Depth %d  Kills %d  Turns %d  %s",
				prefix,
				i + 1,
				s.depth,
				s.kills,
				s.turns,
				cause_display,
			)
			row_w := render_measure_text(engine, row_text, row_size)
			render_draw_text(engine, row_text, (sw - row_w) / 2, y, row_size, color)
		}
	}

	// Footer
	footer := cstring("Press R to play again  |  ESC to quit")
	footer_size :: i32(16)
	footer_w := render_measure_text(engine, footer, footer_size)
	render_draw_text(
		engine,
		footer,
		(sw - footer_w) / 2,
		i32(SCREEN_HEIGHT) - 30,
		footer_size,
		rl.Color{150, 150, 150, 255},
	)
}

// ─── Help screen overlay ──────────────────────────────────────────────────────

render_help :: proc(engine: ^eng.Engine, game: ^Game) {
	_ = game
	render_draw_rectangle(
		engine,
		0,
		0,
		i32(SCREEN_WIDTH),
		i32(SCREEN_HEIGHT),
		rl.Color{0, 0, 0, 220},
	)

	title := cstring("CONTROLS & HELP")
	title_size :: i32(28)
	title_w := render_measure_text(engine, title, title_size)
	title_x := (i32(SCREEN_WIDTH) - title_w) / 2
	render_draw_text(engine, title, title_x, 60, title_size, rl.WHITE)

	col1_x :: i32(180)
	col2_x :: i32(580)
	start_y :: i32(110)
	line_h :: i32(22)
	head_color :: rl.Color{255, 220, 100, 255}
	key_color :: rl.Color{100, 200, 255, 255}
	desc_color :: rl.Color{200, 200, 200, 255}

	// ── Column 1: Movement & Actions ──
	render_draw_text(engine, "MOVEMENT", col1_x, start_y, 16, head_color)
	render_draw_text(engine, "WASD / Arrows    Move", col1_x, start_y + line_h * 1, 14, desc_color)
	render_draw_text(
		engine,
		".  (period)      Wait a turn",
		col1_x,
		start_y + line_h * 2,
		14,
		desc_color,
	)
	render_draw_text(
		engine,
		"Walk into enemy  Attack",
		col1_x,
		start_y + line_h * 3,
		14,
		desc_color,
	)

	render_draw_text(engine, "ITEMS", col1_x, start_y + line_h * 5, 16, head_color)
	render_draw_text(
		engine,
		"G                Pick up item",
		col1_x,
		start_y + line_h * 6,
		14,
		desc_color,
	)
	render_draw_text(
		engine,
		"I                Open inventory",
		col1_x,
		start_y + line_h * 7,
		14,
		desc_color,
	)
	render_draw_text(
		engine,
		"  1-9            Use item",
		col1_x,
		start_y + line_h * 8,
		14,
		desc_color,
	)
	render_draw_text(
		engine,
		"  D + 1-9        Drop item",
		col1_x,
		start_y + line_h * 9,
		14,
		desc_color,
	)
	render_draw_text(
		engine,
		"  E + 1-9        Equip item",
		col1_x,
		start_y + line_h * 10,
		14,
		desc_color,
	)

	render_draw_text(engine, "MINING", col1_x, start_y + line_h * 12, 16, head_color)
	render_draw_text(
		engine,
		"X + direction    Mine adjacent wall",
		col1_x,
		start_y + line_h * 13,
		14,
		desc_color,
	)
	render_draw_text(
		engine,
		"C  (on anvil)    Open crafting",
		col1_x,
		start_y + line_h * 14,
		14,
		desc_color,
	)

	// ── Column 2: UI & Info ──
	render_draw_text(engine, "DISPLAY", col2_x, start_y, 16, head_color)
	render_draw_text(
		engine,
		"M                Toggle minimap",
		col2_x,
		start_y + line_h * 1,
		14,
		desc_color,
	)
	render_draw_text(
		engine,
		"?                This help screen",
		col2_x,
		start_y + line_h * 2,
		14,
		desc_color,
	)
	render_draw_text(
		engine,
		"ESC              Close menu / Quit",
		col2_x,
		start_y + line_h * 3,
		14,
		desc_color,
	)
	render_draw_text(
		engine,
		"R  (game over)   Restart",
		col2_x,
		start_y + line_h * 4,
		14,
		desc_color,
	)
	render_draw_text(
		engine,
		"F1               Toggle sound",
		col2_x,
		start_y + line_h * 5,
		14,
		key_color,
	)
	render_draw_text(
		engine,
		"F2               Toggle ASCII/Sprites",
		col2_x,
		start_y + line_h * 6,
		14,
		key_color,
	)
	render_draw_text(
		engine,
		"F5               Save game",
		col2_x,
		start_y + line_h * 7,
		14,
		key_color,
	)
	render_draw_text(
		engine,
		"F9               Load game",
		col2_x,
		start_y + line_h * 8,
		14,
		key_color,
	)
	render_draw_text(
		engine,
		"[ / ]            Adjust volume",
		col2_x,
		start_y + line_h * 9,
		14,
		key_color,
	)

	render_draw_text(engine, "TILE LEGEND", col2_x, start_y + line_h * 10, 16, head_color)
	render_draw_text(engine, "@  You", col2_x, start_y + line_h * 11, 14, rl.YELLOW)
	render_draw_text(
		engine,
		">  Descent to next depth",
		col2_x,
		start_y + line_h * 12,
		14,
		rl.Color{0, 200, 200, 255},
	)
	render_draw_text(
		engine,
		"*  Ore vein (colored dot on wall)",
		col2_x,
		start_y + line_h * 13,
		14,
		rl.Color{200, 120, 50, 255},
	)
	render_draw_text(
		engine,
		"~  Water (slows movement)",
		col2_x,
		start_y + line_h * 14,
		14,
		rl.Color{40, 80, 180, 255},
	)
	render_draw_text(
		engine,
		"!  Gas vent (damages you)",
		col2_x,
		start_y + line_h * 15,
		14,
		rl.Color{160, 180, 40, 255},
	)
	render_draw_text(
		engine,
		"^  Unstable ground (collapses)",
		col2_x,
		start_y + line_h * 16,
		14,
		rl.Color{180, 120, 60, 255},
	)
	render_draw_text(
		engine,
		"#  Anvil (stand on it, press C)",
		col2_x,
		start_y + line_h * 17,
		14,
		rl.Color{160, 160, 170, 255},
	)

	render_draw_text(engine, "TIPS", col2_x, start_y + line_h * 19, 16, head_color)
	render_draw_text(
		engine,
		"Mine walls to find ores!",
		col2_x,
		start_y + line_h * 20,
		14,
		desc_color,
	)
	render_draw_text(
		engine,
		"Craft at anvils with materials.",
		col2_x,
		start_y + line_h * 21,
		14,
		desc_color,
	)
	render_draw_text(
		engine,
		"Light shrinks as you go deeper.",
		col2_x,
		start_y + line_h * 22,
		14,
		desc_color,
	)

	// Footer
	footer := cstring("Press ESC or ? to close")
	footer_w := render_measure_text(engine, footer, 14)
	render_draw_text(
		engine,
		footer,
		(i32(SCREEN_WIDTH) - footer_w) / 2,
		i32(SCREEN_HEIGHT) - 40,
		14,
		rl.Color{120, 120, 120, 255},
	)
}
