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

// ─── Per-frame entity scratch buffer ─────────────────────────────────────────
// Minimap used to call gcore.enemy_at / gcore.npc_at for every cell, giving
// O(MAP_WIDTH * MAP_HEIGHT * entity_count) linear scans.  Instead we do one
// pass over enemies + NPCs before the cell loop and stamp their colors into a
// flat array, so each cell lookup is O(1).

@(private = "file")
Minimap_Entity_Kind :: enum u8 {
	None,
	Enemy,
	NPC,
}

@(private = "file")
Minimap_Cell_Entity :: struct {
	kind: Minimap_Entity_Kind,
}

@(private = "file")
g_minimap_entity_scratch: [gcore.MAP_WIDTH * gcore.MAP_HEIGHT]Minimap_Cell_Entity

@(private = "file")
minimap_build_entity_scratch :: proc(game: ^gcore.Game) {
	// Zero out previous frame's stamps
	for &cell in g_minimap_entity_scratch {
		cell = {}
	}
	// Stamp enemies (alive + should draw)
	for &enemy in game.enemies {
		if !enemy.alive {continue}
		if !minimap_should_draw_enemy_dot(game, &enemy) {continue}
		idx := gcore.pos_to_idx(enemy.pos.x, enemy.pos.y)
		if idx >= 0 && idx < len(g_minimap_entity_scratch) {
			g_minimap_entity_scratch[idx].kind = .Enemy
		}
	}
	// Stamp NPCs (explored tile)
	for i in 0 ..< game.npc_count {
		npc := &game.npcs[i]
		if !gcore.tile_explored_at(game, npc.pos.x, npc.pos.y) {continue}
		idx := gcore.pos_to_idx(npc.pos.x, npc.pos.y)
		if idx >= 0 && idx < len(g_minimap_entity_scratch) {
			// Don't overwrite an enemy stamp
			if g_minimap_entity_scratch[idx].kind == .None {
				g_minimap_entity_scratch[idx].kind = .NPC
			}
		}
	}
}

clay_render_minimap :: proc(game: ^gcore.Game) {
	if game == nil {
		return
	}

	// Build entity scratch once per minimap render (not once per cell)
	minimap_build_entity_scratch(game)

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

	// O(1) entity lookup via scratch buffer (built once before this loop)
	idx := gcore.pos_to_idx(x, y)
	entity := g_minimap_entity_scratch[idx]
	switch entity.kind {
	case .Enemy:
		return ui_pkg.SB_BOSS // enemy / boss
	case .NPC:
		return ui_pkg.SB_POISON // NPC — soft green
	case .None:
	}

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
