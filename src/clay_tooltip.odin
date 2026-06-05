package main

import eng "./engine"
import clay "./vendor/clay"
import "core:fmt"

@(private = "file")
clay_tooltip_import_anchor :: proc() {
	_ = fmt.tprintf
	_ = clay.ElementDeclaration{}
	_ = eng.Engine{}
}

TOOLTIP_BG_COLOR :: eng.Engine_Color{20, 20, 25, 230}
TOOLTIP_TEXT_COLOR :: eng.Engine_Color{255, 255, 255, 255}
TOOLTIP_FONT_SIZE :: i32(14)
TOOLTIP_PAD_X :: i32(6)
TOOLTIP_PAD_Y :: i32(4)
TOOLTIP_OFFSET_X :: i32(12)
TOOLTIP_OFFSET_Y :: i32(-20)

clay_render_tooltip :: proc(engine: ^eng.Engine, game: ^Game) {
	tooltip_text := tooltip_text_for_mouse(engine, game)
	if len(tooltip_text) == 0 {
		return
	}
	mouse := eng.engine_mouse_position(engine)
	text_cstr := fmt.ctprintf("%s", tooltip_text)
	text_w := render_measure_text(engine, text_cstr, TOOLTIP_FONT_SIZE)
	box_w := text_w + TOOLTIP_PAD_X * 2
	box_h := TOOLTIP_FONT_SIZE + TOOLTIP_PAD_Y * 2
	box_x := i32(mouse.x) + TOOLTIP_OFFSET_X
	box_y := i32(mouse.y) + TOOLTIP_OFFSET_Y
	if box_x + box_w > i32(MAP_VIEW_WIDTH) {box_x = i32(MAP_VIEW_WIDTH) - box_w}
	if box_x < 0 {box_x = 0}
	if box_y < 0 {box_y = 0}
	if box_y + box_h > i32(SCREEN_HEIGHT) {box_y = i32(SCREEN_HEIGHT) - box_h}

	if clay.UI(clay.ID("map-tooltip"))(
	clay.ElementDeclaration {
		layout = {
			sizing = {width = clay.SizingFixed(f32(box_w)), height = clay.SizingFixed(f32(box_h))},
			padding = clay.Padding {
				left = u16(TOOLTIP_PAD_X),
				right = u16(TOOLTIP_PAD_X),
				top = u16(TOOLTIP_PAD_Y),
				bottom = u16(TOOLTIP_PAD_Y),
			},
		},
		backgroundColor = clay_color(TOOLTIP_BG_COLOR),
		floating = {
			offset = {f32(box_x), f32(box_y)},
			attachTo = .Parent,
			attachment = {element = .LeftTop, parent = .LeftTop},
			pointerCaptureMode = .Passthrough,
		},
	},
	) {
		clay.TextDynamic(
			tooltip_text,
			{
				textColor = clay_color(TOOLTIP_TEXT_COLOR),
				fontSize = u16(TOOLTIP_FONT_SIZE),
				lineHeight = u16(TOOLTIP_FONT_SIZE),
			},
		)
	}
}

clay_render_gameplay_hints :: proc(engine: ^eng.Engine, game: ^Game) {
	ui := ui_manager_state(game_engine_ui_manager(engine))
	if ui != nil && ui.mining_mode {
		clay_render_hint_banner(
			"mining-hint",
			"[MINING] Direction (WASD/arrows) | ESC cancel",
			4,
			eng.Engine_Color{255, 200, 80, 255},
		)
	}
	cur := tile_at(game, game.player.pos.x, game.player.pos.y)
	if cur != nil && cur.type == .Anvil {
		clay_render_hint_banner(
			"anvil-hint",
			"[C = Craft]",
			i32(MAP_VIEW_HEIGHT) - 22,
			eng.Engine_Color{160, 160, 170, 255},
		)
	}
	if cur != nil && cur.type == .Fountain {
		clay_render_hint_banner(
			"fountain-hint",
			"[Fountain — restores HP]",
			i32(MAP_VIEW_HEIGHT) - 22,
			eng.Engine_Color{80, 180, 220, 255},
		)
	}
}

@(private = "file")
clay_render_hint_banner :: proc(id: string, text: string, y: i32, color: eng.Engine_Color) {
	if clay.UI(clay.ID(id))(
	clay.ElementDeclaration {
		layout = {sizing = {width = clay.SizingFit(), height = clay.SizingFit()}},
		floating = {
			offset = {f32(MAP_VIEW_WIDTH / 2), f32(y)},
			attachTo = .Parent,
			attachment = {element = .CenterTop, parent = .LeftTop},
			pointerCaptureMode = .Passthrough,
		},
	},
	) {
		clay.TextDynamic(text, {textColor = clay_color(color), fontSize = 14, lineHeight = 14})
	}
}

tooltip_text_for_mouse :: proc(engine: ^eng.Engine, game: ^Game) -> string {
	mouse := eng.engine_mouse_position(engine)
	camera := game_engine_camera_manager(engine)
	if int(mouse.x) >= MAP_VIEW_WIDTH || int(mouse.y) >= MAP_VIEW_HEIGHT {
		return ""
	}
	zoom := camera_zoom(camera)
	tile_x := (int(f32(mouse.x) / zoom) + game_camera_x(camera)) / TILE_SIZE
	tile_y := (int(f32(mouse.y) / zoom) + game_camera_y(camera)) / TILE_SIZE
	if tile_x < 0 || tile_x >= MAP_WIDTH || tile_y < 0 || tile_y >= MAP_HEIGHT {
		return ""
	}
	tile := tile_at(game, tile_x, tile_y)
	if tile == nil || !tile_visible_at(game, tile_x, tile_y) {
		return ""
	}
	if game.player.pos.x == tile_x && game.player.pos.y == tile_y {
		return fmt.tprintf("You (%d/%d HP)", game.player.hp, game.player.max_hp)
	}
	enemy := enemy_at(game, tile_x, tile_y)
	if enemy == nil {
		return ""
	}
	return fmt.tprintf("%s (%d/%d HP)", enemy_display_name(enemy), enemy.hp, enemy.max_hp)
}
