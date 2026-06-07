package renderer

import gcore "../core"

import eng "../engine"
import ui_pkg "../ui"
import clay "libs:clay"

@(private = "file")
clay_minimap_import_anchor :: proc() {
	_ = clay.ElementDeclaration{}
	_ = eng.Engine_Color{}
}

MINIMAP_TILE_SIZE :: i32(2)
MINIMAP_MARGIN :: i32(8)

minimap_should_draw_enemy_dot :: proc(game: ^gcore.Game, enemy: ^gcore.Enemy) -> bool {
	if game == nil || enemy == nil || !enemy.alive {
		return false
	}
	if gcore.tile_visible_at(game, enemy.pos.x, enemy.pos.y) {
		return true
	}
	return game.minimap_reveal_enemies && gcore.tile_explored_at(game, enemy.pos.x, enemy.pos.y)
}

clay_render_minimap :: proc(game: ^gcore.Game) {
	if game == nil {
		return
	}
	if clay.UI(clay.ID("minimap-floating"))(
	clay.ElementDeclaration {
		layout = {
			sizing = {
				width = clay.SizingFixed(f32(i32(gcore.MAP_WIDTH) * MINIMAP_TILE_SIZE + 4)),
				height = clay.SizingFixed(f32(i32(gcore.MAP_HEIGHT) * MINIMAP_TILE_SIZE + 4)),
			},
			padding = clay.Padding{left = 2, right = 2, top = 2, bottom = 2},
			layoutDirection = .TopToBottom,
			childGap = 0,
		},
		backgroundColor = clay_color(
			eng.Engine_Color{ui_pkg.SB_BG.r, ui_pkg.SB_BG.g, ui_pkg.SB_BG.b, 180},
		),
		floating = {
			offset = {
				f32(
					gcore.MAP_VIEW_WIDTH -
					i32(gcore.MAP_WIDTH) * MINIMAP_TILE_SIZE -
					MINIMAP_MARGIN -
					2,
				),
				f32(MINIMAP_MARGIN - 2),
			},
			attachTo = .Parent,
			attachment = {element = .LeftTop, parent = .LeftTop},
			pointerCaptureMode = .Passthrough,
		},
	},
	) {
		for y in 0 ..< gcore.MAP_HEIGHT {
			if clay.UI(clay.ID("minimap-row", u32(y)))(
			clay.ElementDeclaration {
				layout = {
					sizing = {
						width = clay.SizingFit(),
						height = clay.SizingFixed(f32(MINIMAP_TILE_SIZE)),
					},
					layoutDirection = .LeftToRight,
					childGap = 0,
				},
			},
			) {
				for x in 0 ..< gcore.MAP_WIDTH {
					if clay.UI(clay.ID("minimap-cell", u32(y * gcore.MAP_WIDTH + x)))(
					clay.ElementDeclaration {
						layout = {
							sizing = {
								width = clay.SizingFixed(f32(MINIMAP_TILE_SIZE)),
								height = clay.SizingFixed(f32(MINIMAP_TILE_SIZE)),
							},
						},
						backgroundColor = clay_color(clay_minimap_cell_color(game, x, y)),
					},
					) {}
				}
			}
		}
	}
}

@(private = "file")
clay_minimap_cell_color :: proc(game: ^gcore.Game, x, y: int) -> eng.Engine_Color {
	if game.player.pos.x == x && game.player.pos.y == y {
		return ui_pkg.SB_TITLE // player — gold
	}
	enemy := gcore.enemy_at(game, x, y)
	if enemy != nil && minimap_should_draw_enemy_dot(game, enemy) {
		return ui_pkg.SB_BOSS // enemy / boss
	}
	if gcore.npc_at(game, x, y) >= 0 && gcore.tile_explored_at(game, x, y) {
		return ui_pkg.SB_POISON // NPC — soft green
	}

	idx := gcore.pos_to_idx(x, y)
	tile := game.tiles[idx]
	state := gcore.tile_state_at_idx(game, idx)
	if state.visible {
		#partial switch tile.type {
		case .Wall:
			return ui_pkg.SB_DIVIDER
		case .Floor:
			return ui_pkg.SB_OIL
		case .Rubble:
			return ui_pkg.SB_HLM
		case .Descent:
			return ui_pkg.SB_ARM
		case .Ascent:
			return eng.Engine_Color{180, 120, 255, 255}
		case .Shrine:
			return eng.Engine_Color{100, 200, 255, 255}
		case .Chest:
			return ui_pkg.SB_TITLE
		case .Merchant:
			return ui_pkg.SB_POISON
		case:
			return ui_pkg.SB_LAMP_LOW
		}
	}
	if state.explored {
		#partial switch tile.type {
		case .Wall:
			return ui_pkg.SB_PANEL
		case .Descent:
			return eng.Engine_Color{0, 80, 80, 255}
		case .Ascent:
			return eng.Engine_Color{80, 40, 120, 255}
		case:
			return ui_pkg.SB_DIM
		}
	}
	return ui_pkg.SB_BG
}
