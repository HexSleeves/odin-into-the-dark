package renderer

import gcore "../core"

import eng "../engine"
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
		backgroundColor = clay_color(eng.Engine_Color{0, 0, 0, 180}),
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
		return eng.Engine_Color{255, 255, 0, 255}
	}
	enemy := gcore.enemy_at(game, x, y)
	if enemy != nil && minimap_should_draw_enemy_dot(game, enemy) {
		return eng.Engine_Color{255, 60, 60, 255}
	}

	idx := gcore.pos_to_idx(x, y)
	tile := game.tiles[idx]
	state := gcore.tile_state_at_idx(game, idx)
	if state.visible {
		#partial switch tile.type {
		case .Wall:
			return eng.Engine_Color{80, 80, 90, 255}
		case .Floor:
			return eng.Engine_Color{160, 120, 60, 255}
		case .Rubble:
			return eng.Engine_Color{140, 130, 90, 255}
		case .Descent:
			return eng.Engine_Color{0, 255, 255, 255}
		case:
			return eng.Engine_Color{120, 100, 80, 255}
		}
	}
	if state.explored {
		#partial switch tile.type {
		case .Wall:
			return eng.Engine_Color{30, 30, 35, 255}
		case .Floor:
			return eng.Engine_Color{60, 45, 25, 255}
		case .Rubble:
			return eng.Engine_Color{55, 50, 35, 255}
		case .Descent:
			return eng.Engine_Color{0, 80, 80, 255}
		case:
			return eng.Engine_Color{50, 40, 30, 255}
		}
	}
	return eng.Engine_Color{}
}
