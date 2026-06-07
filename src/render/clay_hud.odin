package renderer

import ui_pkg "../ui"

import gcore "../core"

import eng "../engine"
import "core:fmt"
import clay "libs:clay"

@(private = "file")
clay_hud_import_anchor :: proc() {
	_ = fmt.tprintf
	_ = clay.ElementDeclaration{}
	_ = eng.Engine{}
}

CLAY_HUD_FONT :: CLAY_FONT_SMALL
CLAY_HUD_ROW_FONT :: CLAY_FONT_BODY

clay_render_hud :: proc(engine: ^eng.Engine, game: ^gcore.Game) {
	turns := game_engine_turn_manager(engine)
	if clay.UI(clay.ID("hud-root"))(
	clay.ElementDeclaration {
		layout = {
			sizing = {
				width = clay.SizingFixed(f32(gcore.SCREEN_WIDTH)),
				height = clay.SizingFixed(f32(gcore.MAP_VIEW_HEIGHT)),
			},
			layoutDirection = .LeftToRight,
		},
	},
	) {
		clay_spacer_fixed("hud-map-spacer", f32(gcore.MAP_VIEW_WIDTH), f32(gcore.MAP_VIEW_HEIGHT))

		if clay.UI(clay.ID("hud-sidebar"))(
		clay.ElementDeclaration {
			layout = {
				sizing = {
					width = clay.SizingFixed(f32(gcore.SIDEBAR_WIDTH)),
					height = clay.SizingFixed(f32(gcore.MAP_VIEW_HEIGHT)),
				},
				padding = clay.Padding {
					left = CLAY_SPACE_MD,
					right = CLAY_SPACE_MD,
					top = CLAY_SPACE_SM,
					bottom = 0,
				},
				layoutDirection = .TopToBottom,
				childGap = CLAY_SPACE_SM,
			},
			backgroundColor = clay_color(ui_pkg.SB_BG),
		},
		) {
			clay_text_centered("INTO THE DEPTHS", CLAY_FONT_TITLE, ui_pkg.SB_TITLE)

			// VITALS panel
			if clay_panel_begin("hud-vitals", "VITALS") {
				hp_ratio := f32(max(game.player.hp, 0)) / f32(max(game.player.max_hp, 1))
				hp_fg := ui_pkg.SB_HP_FG if hp_ratio > 0.3 else ui_pkg.SB_HP_LOW
				clay_row(
					"hud-hp-row",
					"HP",
					fmt.tprintf("%d / %d", i32(game.player.hp), i32(game.player.max_hp)),
					CLAY_HUD_FONT,
					ui_pkg.SB_HEADER,
					ui_pkg.SB_TEXT,
				)
				clay_bar_segmented("hud-hp-bar", hp_ratio, 10, 8, ui_pkg.SB_HP_BG, hp_fg)

				cost := gcore.effective_attack_cost(game)
				spd_label: string
				spd_color: eng.Engine_Color
				if cost <= 700 {
					spd_label = "Fast"
					spd_color = ui_pkg.SB_HP_FG
				} else if cost <= 1100 {
					spd_label = "Normal"
					spd_color = ui_pkg.SB_TEXT
				} else if cost <= 1600 {
					spd_label = "Slow"
					spd_color = ui_pkg.SB_PICK_WARN
				} else {
					spd_label = "Very Slow"
					spd_color = ui_pkg.SB_HP_LOW
				}
				clay_row("hud-atk-row", "ATK", spd_label, CLAY_HUD_FONT, ui_pkg.SB_HEADER, spd_color)

				if game.equipped_weapon.occupied {
					wpn := game.equipped_weapon.item
					if wpn.max_durability > 0 {
						pick_ratio := f32(wpn.durability) / f32(max(wpn.max_durability, 1))
						pick_fg: eng.Engine_Color
						if wpn.durability <= 0 {
							pick_fg = ui_pkg.SB_PICK_CRIT
						} else if pick_ratio > 0.5 {
							pick_fg = ui_pkg.SB_PICK_OK
						} else if pick_ratio > 0.25 {
							pick_fg = ui_pkg.SB_PICK_WARN
						} else {
							pick_fg = ui_pkg.SB_PICK_CRIT
						}
						if wpn.durability <= 0 {
							clay_text("PICK  BROKEN", CLAY_HUD_FONT, ui_pkg.SB_PICK_CRIT)
						} else {
							clay_row(
								"hud-pick-row",
								"PICK",
								fmt.tprintf("%d / %d", i32(wpn.durability), i32(wpn.max_durability)),
								CLAY_HUD_FONT,
								ui_pkg.SB_HEADER,
								ui_pkg.SB_TEXT,
							)
						}
						clay_bar_segmented("hud-pick-bar", pick_ratio, 10, 8, ui_pkg.SB_PICK_BG, pick_fg)
					}
				}
			}

			// EXPEDITION panel
			if clay_panel_begin("hud-expedition", "EXPEDITION") {
				depth_label := fmt.tprintf("DEPTH  %d", i32(game.depth))
				if game.depth == gcore.SURFACE_DEPTH {
					depth_label = "SURFACE"
				}
				clay_row(
					"hud-depth-row",
					depth_label,
					fmt.tprintf("TURN %d", i32(eng.turn_manager_current(turns))),
					CLAY_HUD_ROW_FONT,
					ui_pkg.SB_TEXT,
					ui_pkg.SB_DIM,
				)
				clay_row(
					"hud-pos-row",
					fmt.tprintf("POS  %d,%d", i32(game.player.pos.x), i32(game.player.pos.y)),
					"",
					CLAY_HUD_ROW_FONT,
					ui_pkg.SB_DIM,
					ui_pkg.SB_DIM,
				)

				alive_count: i32 = 0
				for &e in game.enemies {
					if e.alive {alive_count += 1}
				}
				clay_row(
					"hud-kills-row",
					fmt.tprintf("KILLS  %d", i32(game.kills)),
					fmt.tprintf("NEAR %d", alive_count),
					CLAY_HUD_ROW_FONT,
					ui_pkg.SB_TEXT,
					ui_pkg.SB_DIM,
				)
				if game.light_boost_turns > 0 {
					clay_row(
						"hud-light-row",
						fmt.tprintf("LIGHT  %d", i32(game.player.light_radius)),
						fmt.tprintf("%dt fuel", i32(game.light_boost_turns)),
						CLAY_HUD_ROW_FONT,
						ui_pkg.SB_OIL,
						ui_pkg.SB_OIL,
					)
				} else {
					clay_row(
						"hud-light-row",
						fmt.tprintf("LIGHT  %d", i32(game.player.light_radius)),
						fmt.tprintf("ITEMS %d", i32(game.items_found)),
						CLAY_HUD_ROW_FONT,
						ui_pkg.SB_TEXT,
						ui_pkg.SB_DIM,
					)
				}
			}

			// QUEST panel (amber, not gold)
			if game.quest != .Complete {
				if clay_panel_begin("hud-quest", "QUEST") {
					clay_text(gcore.quest_objective_text(game), CLAY_HUD_ROW_FONT, ui_pkg.SB_OIL)
				}
			}

			// GEAR panel
			if clay_panel_begin("hud-gear", "GEAR") {
				if game.equipped_weapon.occupied {
					wpn := &game.equipped_weapon.item
					clay_text(
						fmt.tprintf("WPN  %s (+%d)", wpn.name, i32(wpn.stat_bonus)),
						CLAY_HUD_FONT,
						ui_pkg.SB_WPN,
					)
				} else {
					clay_text("WPN  ---", CLAY_HUD_FONT, ui_pkg.SB_DIM)
				}
				if game.equipped_armor.occupied {
					arm := &game.equipped_armor.item
					clay_text(
						fmt.tprintf("ARM  %s (+%d)", arm.name, i32(arm.stat_bonus)),
						CLAY_HUD_FONT,
						ui_pkg.SB_ARM,
					)
				} else {
					clay_text("ARM  ---", CLAY_HUD_FONT, ui_pkg.SB_DIM)
				}
				if game.equipped_helmet.occupied {
					hlm := &game.equipped_helmet.item
					clay_text(
						fmt.tprintf("HLM  %s (+%d)", hlm.name, i32(hlm.stat_bonus)),
						CLAY_HUD_FONT,
						ui_pkg.SB_HLM,
					)
				} else {
					clay_text("HLM  ---", CLAY_HUD_FONT, ui_pkg.SB_DIM)
				}
			}

			// STATUS panel (only when active)
			has_status :=
				game.light_boost_turns > 0 ||
				game.poison_turns > 0 ||
				game.burning_turns > 0 ||
				game.frozen_turns > 0
			if has_status {
				if clay_panel_begin("hud-status", "STATUS") {
					if game.light_boost_turns >
					   0 {clay_text(fmt.tprintf("OIL   %dt remaining", i32(game.light_boost_turns)), CLAY_HUD_FONT, ui_pkg.SB_OIL)}
					if game.poison_turns >
					   0 {clay_text(fmt.tprintf("POISON  %dt remaining", i32(game.poison_turns)), CLAY_HUD_FONT, ui_pkg.SB_POISON)}
					if game.burning_turns >
					   0 {clay_text(fmt.tprintf("BURNING (%d)", i32(game.burning_turns)), CLAY_HUD_FONT, eng.Engine_Color{255, 120, 20, 255})}
					if game.frozen_turns >
					   0 {clay_text(fmt.tprintf("FROZEN (%d)", i32(game.frozen_turns)), CLAY_HUD_FONT, eng.Engine_Color{100, 180, 255, 255})}
				}
			}

			// BOSS panel (only when a boss is alive)
			for &enemy in game.enemies {
				if !enemy.alive || !enemy.is_boss {continue}
				if clay_panel_begin("hud-boss", "BOSS") {
					clay_row(
						"hud-boss-row",
						fmt.tprintf("%s", enemy.name),
						fmt.tprintf("%d/%d", i32(enemy.hp), i32(enemy.max_hp)),
						CLAY_HUD_FONT,
						ui_pkg.SB_BOSS,
						ui_pkg.SB_TEXT,
					)
					boss_ratio := f32(max(enemy.hp, 0)) / f32(max(enemy.max_hp, 1))
					clay_bar_segmented(
						"hud-boss-bar",
						boss_ratio,
						10,
						8,
						eng.Engine_Color{50, 15, 15, 255},
						ui_pkg.SB_BOSS,
					)
				}
				break
			}

			clay_spacer_grow("hud-controls-spacer")

			// CONTROLS panel
			if clay_panel_begin("hud-controls", "CONTROLS") {
				clay_text("[I]nv  [G]rab  [X]Mine", CLAY_HUD_FONT, ui_pkg.SB_KEY)
				clay_text("[M]ap  [?]Help  [.]Wait", CLAY_HUD_FONT, ui_pkg.SB_KEY)
				clay_text("[F1]Mute  [ ]/[ ] Vol", CLAY_HUD_FONT, ui_pkg.SB_KEY)
			}
		}
	}
}

clay_text :: proc(text: string, size: u16, color: eng.Engine_Color) {
	clay.TextDynamic(text, {textColor = clay_color(color), fontSize = size, lineHeight = size})
}

clay_text_centered :: proc(text: string, size: u16, color: eng.Engine_Color) {
	if clay.UI(clay.ID_LOCAL("centered-text"))(
	clay.ElementDeclaration {
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingFit()},
			childAlignment = {x = .Center, y = .Top},
		},
	},
	) {clay_text(text, size, color)}
}

clay_row :: proc(
	id: string,
	left, right: string,
	size: u16,
	left_color, right_color: eng.Engine_Color,
) {
	if clay.UI(clay.ID(id))(
	clay.ElementDeclaration {
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingFit()},
			layoutDirection = .LeftToRight,
			childGap = 2,
		},
	},
	) {
		clay_text(left, size, left_color)
		clay_spacer_grow("row-spacer")
		clay_text(right, size, right_color)
	}
}

clay_bar :: proc(id: string, ratio: f32, height: u16, bg, fg: eng.Engine_Color) {
	if clay.UI(clay.ID(id))(
	clay.ElementDeclaration {
		layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(f32(height))}},
		backgroundColor = clay_color(bg),
	},
	) {
		filled := f32(ui_pkg.SB_IW) * clamp(ratio, 0, 1)
		if filled > 0 {
			if clay.UI(clay.ID_LOCAL("fill"))(
			clay.ElementDeclaration {
				layout = {sizing = {width = clay.SizingFixed(filled), height = clay.SizingGrow()}},
				backgroundColor = clay_color(fg),
			},
			) {}
		}
	}
}


clay_bar_segmented :: proc(
	id: string,
	ratio: f32,
	segments: int,
	height: u16,
	bg, fg: eng.Engine_Color,
) {
	filled := bar_segment_fill_count(ratio, segments)
	if clay.UI(clay.ID(id))(
	clay.ElementDeclaration {
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(f32(height))},
			layoutDirection = .LeftToRight,
			childGap = 1,
		},
	},
	) {
		for i in 0 ..< segments {
			cell_color := bg
			if i < filled {cell_color = fg}
			if clay.UI(clay.ID_LOCAL("seg"))(
			clay.ElementDeclaration {
				layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()}},
				backgroundColor = clay_color(cell_color),
			},
			) {}
		}
	}
}

clay_spacer_fixed :: proc(id: string, width, height: f32) {
	if clay.UI(clay.ID(id))(
	clay.ElementDeclaration {
		layout = {sizing = {width = clay.SizingFixed(width), height = clay.SizingFixed(height)}},
	},
	) {}
}

clay_spacer_grow :: proc(id: string) {
	if clay.UI(clay.ID_LOCAL(id))(
	clay.ElementDeclaration {
		layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()}},
	},
	) {}
}
