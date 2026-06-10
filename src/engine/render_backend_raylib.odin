#+build !js
package engine

import rl "vendor:raylib"

RAYLIB_TEXT_FONT_PATH :: "assets/fonts/SourceCodePro-Regular.ttf"
RAYLIB_TEXT_FONT_BUNDLE_PATH :: "../Resources/assets/fonts/SourceCodePro-Regular.ttf"
RAYLIB_TEXT_FONT_APP_RESOURCE_SUFFIX :: "../Resources/assets/fonts/SourceCodePro-Regular.ttf"
RAYLIB_DISPLAY_FONT_PATH :: "assets/fonts/Cinzel-Regular.ttf"
RAYLIB_DISPLAY_FONT_BUNDLE_PATH :: "../Resources/assets/fonts/Cinzel-Regular.ttf"
RAYLIB_DISPLAY_FONT_APP_RESOURCE_SUFFIX :: "../Resources/assets/fonts/Cinzel-Regular.ttf"
RAYLIB_TEXT_MAX_FONT_SIZE :: 96
RAYLIB_TEXT_SPACING :: f32(1)

@(private = "file")
raylib_text_fonts: [Engine_Font][RAYLIB_TEXT_MAX_FONT_SIZE + 1]rl.Font
@(private = "file")
raylib_text_font_loaded: [Engine_Font][RAYLIB_TEXT_MAX_FONT_SIZE + 1]bool

// Raylib render backend — desktop default. Excluded from the JS/WASM build,
// which cannot link libraylib.a; web uses the karl2d render backend instead.

engine_render_backend_raylib :: proc() -> Engine_Render_Backend {
	return Engine_Render_Backend {
		begin_frame = raylib_render_begin_frame,
		end_frame = raylib_render_end_frame,
		shutdown = raylib_render_shutdown,
		clear = raylib_render_clear,
		begin_scissor = raylib_render_begin_scissor,
		end_scissor = raylib_render_end_scissor,
		draw_rectangle = raylib_render_draw_rectangle,
		draw_text = raylib_render_draw_text,
		measure_text = raylib_render_measure_text,
		draw_rectangle_lines = raylib_render_draw_rectangle_lines,
		draw_texture_region = raylib_render_draw_texture_region,
	}
}

@(private = "file")
raylib_render_begin_frame :: proc(ctx: rawptr) {
	rl.BeginDrawing()
}

@(private = "file")
raylib_render_end_frame :: proc(ctx: rawptr) {
	rl.EndDrawing()
}

@(private = "file")
raylib_render_clear :: proc(ctx: rawptr, color: Engine_Color) {
	rl.ClearBackground(engine_color_to_raylib(color))
}

@(private = "file")
raylib_render_begin_scissor :: proc(ctx: rawptr, x, y, width, height: i32) {
	rl.BeginScissorMode(x, y, width, height)
}

@(private = "file")
raylib_render_end_scissor :: proc(ctx: rawptr) {
	rl.EndScissorMode()
}

@(private = "file")
raylib_render_draw_rectangle :: proc(ctx: rawptr, x, y, width, height: i32, color: Engine_Color) {
	rl.DrawRectangle(x, y, width, height, engine_color_to_raylib(color))
}

@(private = "file")
raylib_render_draw_rectangle_lines :: proc(
	ctx: rawptr,
	x, y, width, height: i32,
	color: Engine_Color,
) {
	rl.DrawRectangleLines(x, y, width, height, engine_color_to_raylib(color))
}

@(private = "file")
raylib_render_draw_text :: proc(
	ctx: rawptr,
	text: cstring,
	x, y, size: i32,
	color: Engine_Color,
	family: Engine_Font,
) {
	font, loaded := raylib_render_font_for_size(size, family)
	if !loaded {
		rl.DrawText(text, x, y, size, engine_color_to_raylib(color))
		return
	}
	rl.DrawTextEx(
		font,
		text,
		rl.Vector2{f32(x), f32(y)},
		f32(size),
		RAYLIB_TEXT_SPACING,
		engine_color_to_raylib(color),
	)
}

@(private = "file")
raylib_render_measure_text :: proc(
	ctx: rawptr,
	text: cstring,
	size: i32,
	family: Engine_Font,
) -> i32 {
	font, loaded := raylib_render_font_for_size(size, family)
	if !loaded {
		return rl.MeasureText(text, size)
	}
	measured := rl.MeasureTextEx(font, text, f32(size), RAYLIB_TEXT_SPACING)
	return i32(measured.x + 0.5)
}

@(private = "file")
raylib_render_draw_texture_region :: proc(
	ctx: rawptr,
	texture: Engine_Texture,
	source, dest: Engine_Rect,
	origin: Engine_Vec2,
	rotation: f32,
	tint: Engine_Color,
) {
	if texture.handle == nil {
		return
	}
	rl.DrawTexturePro(
		(cast(^rl.Texture2D)texture.handle)^,
		engine_rect_to_raylib(source),
		engine_rect_to_raylib(dest),
		engine_vec2_to_raylib(origin),
		rotation,
		engine_color_to_raylib(tint),
	)
}

@(private = "file")
raylib_render_shutdown :: proc(ctx: rawptr) {
	for family in Engine_Font {
		for i in 0 ..< len(raylib_text_font_loaded[family]) {
			if raylib_text_font_loaded[family][i] {
				rl.UnloadFont(raylib_text_fonts[family][i])
				raylib_text_fonts[family][i] = {}
				raylib_text_font_loaded[family][i] = false
			}
		}
	}
}

@(private = "file")
raylib_font_paths :: proc(family: Engine_Font) -> (primary, bundle, app_suffix: string) {
	switch family {
	case .Display:
		return RAYLIB_DISPLAY_FONT_PATH,
			RAYLIB_DISPLAY_FONT_BUNDLE_PATH,
			RAYLIB_DISPLAY_FONT_APP_RESOURCE_SUFFIX
	case .Body:
	}
	return RAYLIB_TEXT_FONT_PATH,
		RAYLIB_TEXT_FONT_BUNDLE_PATH,
		RAYLIB_TEXT_FONT_APP_RESOURCE_SUFFIX
}

@(private = "file")
raylib_render_font_for_size :: proc(size: i32, family: Engine_Font) -> (rl.Font, bool) {
	if size <= 0 || size > RAYLIB_TEXT_MAX_FONT_SIZE {
		return rl.GetFontDefault(), false
	}

	index := int(size)
	if raylib_text_font_loaded[family][index] {
		return raylib_text_fonts[family][index], true
	}

	primary, bundle, app_suffix := raylib_font_paths(family)
	font, loaded := raylib_render_load_font(primary, size)
	if !loaded {
		font, loaded = raylib_render_load_font(bundle, size)
	}
	if !loaded {
		font, loaded = raylib_render_load_app_resource_font(app_suffix, size)
	}
	if !loaded {
		// Display face missing → fall back to the body face rather than the
		// raylib default bitmap font.
		if family == .Display {
			return raylib_render_font_for_size(size, .Body)
		}
		return rl.GetFontDefault(), false
	}

	raylib_text_fonts[family][index] = font
	raylib_text_font_loaded[family][index] = true
	return font, true
}

@(private = "file")
raylib_render_load_font :: proc(path: string, size: i32) -> (rl.Font, bool) {
	path_buf: [1024]u8
	copy_len := min(len(path), len(path_buf) - 1)
	for i in 0 ..< copy_len {
		path_buf[i] = path[i]
	}
	path_buf[copy_len] = 0

	font := rl.LoadFontEx(cast(cstring)&path_buf[0], size, nil, 0)
	return font, rl.IsFontValid(font)
}

@(private = "file")
raylib_render_load_app_resource_font :: proc(suffix: string, size: i32) -> (rl.Font, bool) {
	app_dir := string(rl.GetApplicationDirectory())
	path_buf: [1024]u8
	cursor := 0
	for cursor < len(app_dir) && cursor < len(path_buf) - 1 {
		path_buf[cursor] = app_dir[cursor]
		cursor += 1
	}
	if cursor > 0 && path_buf[cursor - 1] != '/' && cursor < len(path_buf) - 1 {
		path_buf[cursor] = '/'
		cursor += 1
	}
	for i in 0 ..< len(suffix) {
		if cursor >= len(path_buf) - 1 {
			break
		}
		path_buf[cursor] = suffix[i]
		cursor += 1
	}
	path_buf[cursor] = 0

	font := rl.LoadFontEx(cast(cstring)&path_buf[0], size, nil, 0)
	return font, rl.IsFontValid(font)
}

@(private = "file")
engine_color_to_raylib :: proc(color: Engine_Color) -> rl.Color {
	return rl.Color{color.r, color.g, color.b, color.a}
}

@(private = "file")
engine_rect_to_raylib :: proc(rect: Engine_Rect) -> rl.Rectangle {
	return rl.Rectangle{x = rect.x, y = rect.y, width = rect.width, height = rect.height}
}

@(private = "file")
engine_vec2_to_raylib :: proc(vec: Engine_Vec2) -> rl.Vector2 {
	return rl.Vector2{vec.x, vec.y}
}
