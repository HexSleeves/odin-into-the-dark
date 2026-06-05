package main

import eng "./engine"
import clay "./vendor/clay"
import "core:fmt"

@(private = "file")
clay_hud_import_anchor :: proc() {
	_ = fmt.tprintf
	_ = clay.ElementDeclaration{}
	_ = eng.Engine{}
}

when USE_CLAY {
	CLAY_HUD_FONT :: CLAY_FONT_SMALL
	CLAY_HUD_ROW_FONT :: CLAY_FONT_BODY

	clay_render_hud :: proc(engine: ^eng.Engine, game: ^Game) {
		turns := game_engine_turn_manager(engine)
		if clay.UI(clay.ID("hud-root"))(
		clay.ElementDeclaration {
			layout = {
				sizing = {
					width = clay.SizingFixed(f32(SCREEN_WIDTH)),
					height = clay.SizingFixed(f32(MAP_VIEW_HEIGHT)),
				},
				layoutDirection = .LeftToRight,
			},
		},
		) {
			clay_spacer_fixed("hud-map-spacer", f32(MAP_VIEW_WIDTH), f32(MAP_VIEW_HEIGHT))

			if clay.UI(clay.ID("hud-sidebar"))(
			clay.ElementDeclaration {
				layout = {
					sizing = {
						width = clay.SizingFixed(f32(SIDEBAR_WIDTH)),
						height = clay.SizingFixed(f32(MAP_VIEW_HEIGHT)),
					},
					padding = clay.Padding{left = CLAY_SPACE_MD, right = CLAY_SPACE_MD, top = CLAY_SPACE_SM, bottom = 0},
					layoutDirection = .TopToBottom,
					childGap = CLAY_SPACE_SM,
				},
				backgroundColor = clay_color(SB_BG),
			},
			) {
				clay_text_centered("INTO THE DEPTHS", CLAY_FONT_TITLE, SB_TITLE)
				clay_theme_divider("hud-title-divider")

				hp_ratio := f32(max(game.player.hp, 0)) / f32(max(game.player.max_hp, 1))
				hp_fg := SB_HP_FG if hp_ratio > 0.3 else SB_HP_LOW
				clay_row(
					"hud-hp-row",
					"HP",
					fmt.tprintf("%d / %d", i32(game.player.hp), i32(game.player.max_hp)),
					CLAY_HUD_FONT,
					SB_HEADER,
					SB_TEXT,
				)
				clay_bar("hud-hp-bar", hp_ratio, 10, SB_HP_BG, hp_fg)

				cost := effective_attack_cost(game)
				spd_label: string
				spd_color: eng.Engine_Color
				if cost <= 700 {
					spd_label = "Fast"
					spd_color = eng.Engine_Color{80, 220, 100, 255}
				} else if cost <= 1100 {
					spd_label = "Normal"
					spd_color = SB_TEXT
				} else if cost <= 1600 {
					spd_label = "Slow"
					spd_color = eng.Engine_Color{220, 170, 60, 255}
				} else {
					spd_label = "Very Slow"
					spd_color = eng.Engine_Color{220, 80, 60, 255}
				}
				clay_row("hud-atk-row", "ATK", spd_label, CLAY_HUD_FONT, SB_HEADER, spd_color)

				if game.equipped_weapon.occupied {
					wpn := game.equipped_weapon.item
					if wpn.max_durability > 0 {
						pick_ratio := f32(wpn.durability) / f32(max(wpn.max_durability, 1))
						pick_fg: eng.Engine_Color
						if wpn.durability <= 0 {
							pick_fg = SB_PICK_CRIT
						} else if pick_ratio > 0.5 {
							pick_fg = SB_PICK_OK
						} else if pick_ratio > 0.25 {
							pick_fg = SB_PICK_WARN
						} else {
							pick_fg = SB_PICK_CRIT
						}
						if wpn.durability <= 0 {
							clay_text("PICK  BROKEN", CLAY_HUD_FONT, SB_PICK_CRIT)
						} else {
							clay_row(
								"hud-pick-row",
								"PICK",
								fmt.tprintf(
									"%d / %d",
									i32(wpn.durability),
									i32(wpn.max_durability),
								),
								CLAY_HUD_FONT,
								SB_HEADER,
								SB_TEXT,
							)
						}
						clay_bar("hud-pick-bar", pick_ratio, 6, SB_PICK_BG, pick_fg)
					}
				}

				clay_theme_divider("hud-stats-divider")
				clay_row(
					"hud-depth-row",
					fmt.tprintf("DEPTH  %d", i32(game.depth)),
					fmt.tprintf("TURN %d", i32(eng.turn_manager_current(turns))),
					CLAY_HUD_ROW_FONT,
					SB_TEXT,
					SB_DIM,
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
					SB_TEXT,
					SB_DIM,
				)
				if game.light_boost_turns > 0 {
					clay_row(
						"hud-light-row",
						fmt.tprintf("LIGHT  %d", i32(game.player.light_radius)),
						fmt.tprintf("%dt fuel", i32(game.light_boost_turns)),
						CLAY_HUD_ROW_FONT,
						SB_OIL,
						SB_OIL,
					)
				} else {
					clay_row(
						"hud-light-row",
						fmt.tprintf("LIGHT  %d", i32(game.player.light_radius)),
						fmt.tprintf("ITEMS %d", i32(game.items_found)),
						CLAY_HUD_ROW_FONT,
						SB_TEXT,
						SB_DIM,
					)
				}

				clay_theme_divider("hud-equipment-divider")
				clay_text("EQUIPMENT", CLAY_HUD_FONT, SB_HEADER)
				if game.equipped_weapon.occupied {
					wpn := &game.equipped_weapon.item
					clay_text(
						fmt.tprintf("WPN  %s (+%d)", wpn.name, i32(wpn.stat_bonus)),
						CLAY_HUD_FONT,
						SB_WPN,
					)
				} else {
					clay_text("WPN  ---", CLAY_HUD_FONT, SB_DIM)
				}
				if game.equipped_armor.occupied {
					arm := &game.equipped_armor.item
					clay_text(
						fmt.tprintf("ARM  %s (+%d)", arm.name, i32(arm.stat_bonus)),
						CLAY_HUD_FONT,
						SB_ARM,
					)
				} else {
					clay_text("ARM  ---", CLAY_HUD_FONT, SB_DIM)
				}
				if game.equipped_helmet.occupied {
					hlm := &game.equipped_helmet.item
					clay_text(
						fmt.tprintf("HLM  %s (+%d)", hlm.name, i32(hlm.stat_bonus)),
						CLAY_HUD_FONT,
						SB_HLM,
					)
				} else {
					clay_text("HLM  ---", CLAY_HUD_FONT, SB_DIM)
				}

				has_status :=
					game.light_boost_turns > 0 ||
					game.poison_turns > 0 ||
					game.burning_turns > 0 ||
					game.frozen_turns > 0
				if has_status {
					clay_theme_divider("hud-status-divider")
					clay_text("STATUS", CLAY_HUD_FONT, SB_HEADER)
					if game.light_boost_turns >
					   0 {clay_text(fmt.tprintf("OIL   %dt remaining", i32(game.light_boost_turns)), CLAY_HUD_FONT, SB_OIL)}
					if game.poison_turns >
					   0 {clay_text(fmt.tprintf("POISON  %dt remaining", i32(game.poison_turns)), CLAY_HUD_FONT, SB_POISON)}
					if game.burning_turns >
					   0 {clay_text(fmt.tprintf("BURNING (%d)", i32(game.burning_turns)), CLAY_HUD_FONT, eng.Engine_Color{255, 120, 20, 255})}
					if game.frozen_turns >
					   0 {clay_text(fmt.tprintf("FROZEN (%d)", i32(game.frozen_turns)), CLAY_HUD_FONT, eng.Engine_Color{100, 180, 255, 255})}
				}

				for &enemy in game.enemies {
					if !enemy.alive || !enemy.is_boss {continue}
					clay_theme_divider("hud-boss-divider")
					clay_row(
						"hud-boss-row",
						fmt.tprintf("%s", enemy.name),
						fmt.tprintf("%d/%d", i32(enemy.hp), i32(enemy.max_hp)),
						CLAY_HUD_FONT,
						SB_BOSS,
						SB_TEXT,
					)
					boss_ratio := f32(max(enemy.hp, 0)) / f32(max(enemy.max_hp, 1))
					clay_bar(
						"hud-boss-bar",
						boss_ratio,
						8,
						eng.Engine_Color{50, 15, 15, 255},
						SB_BOSS,
					)
					break
				}

				clay_spacer_grow("hud-controls-spacer")
				clay_theme_divider("hud-controls-divider")
				clay_text("CONTROLS", CLAY_HUD_FONT, SB_HEADER)
				clay_text("[I]nv  [G]rab  [X]Mine", CLAY_HUD_FONT, SB_KEY)
				clay_text("[M]ap  [?]Help  [.]Wait", CLAY_HUD_FONT, SB_KEY)
				clay_text("[F1]Mute  [ ]/[ ] Vol", CLAY_HUD_FONT, SB_KEY)
			}
		}
	}

	clay_text :: proc(text: string, size: u16, color: eng.Engine_Color) {
		clay.TextDynamic(
			text,
			{textColor = clay_color(color), fontSize = size, lineHeight = size},
		)
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
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(f32(height))},
			},
			backgroundColor = clay_color(bg),
		},
		) {
			filled := f32(SB_IW) * clamp(ratio, 0, 1)
			if filled > 0 {
				if clay.UI(clay.ID_LOCAL("fill"))(
				clay.ElementDeclaration {
					layout = {
						sizing = {width = clay.SizingFixed(filled), height = clay.SizingGrow()},
					},
					backgroundColor = clay_color(fg),
				},
				) {}
			}
		}
	}


	clay_spacer_fixed :: proc(id: string, width, height: f32) {
		if clay.UI(clay.ID(id))(
		clay.ElementDeclaration {
			layout = {
				sizing = {width = clay.SizingFixed(width), height = clay.SizingFixed(height)},
			},
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

}
