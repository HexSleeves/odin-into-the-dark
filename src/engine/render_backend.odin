package engine

Engine_Color :: struct {
	r, g, b, a: u8,
}

// Font family for text drawing. Body is the monospace default; Display is the
// serif face used for titles and panel headers. Backends without a display
// face fall back to Body.
Engine_Font :: enum u8 {
	Body,
	Display,
}

Engine_Rect :: struct {
	x, y, width, height: f32,
}

Engine_Vec2 :: struct {
	x, y: f32,
}

Engine_Render_Backend :: struct {
	ctx:                  rawptr,
	begin_frame:          proc(ctx: rawptr),
	end_frame:            proc(ctx: rawptr),
	shutdown:             proc(ctx: rawptr),
	clear:                proc(ctx: rawptr, color: Engine_Color),
	begin_scissor:        proc(ctx: rawptr, x, y, width, height: i32),
	end_scissor:          proc(ctx: rawptr),
	draw_rectangle:       proc(ctx: rawptr, x, y, width, height: i32, color: Engine_Color),
	draw_text:            proc(
		ctx: rawptr,
		text: cstring,
		x, y, size: i32,
		color: Engine_Color,
		font: Engine_Font,
	),
	measure_text:         proc(ctx: rawptr, text: cstring, size: i32, font: Engine_Font) -> i32,
	draw_rectangle_lines: proc(ctx: rawptr, x, y, width, height: i32, color: Engine_Color),
	draw_texture_region:  proc(
		ctx: rawptr,
		texture: Engine_Texture,
		source, dest: Engine_Rect,
		origin: Engine_Vec2,
		rotation: f32,
		tint: Engine_Color,
	),
}

engine_color_make :: proc(r, g, b, a: u8) -> Engine_Color {
	return Engine_Color{r = r, g = g, b = b, a = a}
}

engine_rect_make :: proc(x, y, width, height: f32) -> Engine_Rect {
	return Engine_Rect{x = x, y = y, width = width, height = height}
}

engine_vec2_make :: proc(x, y: f32) -> Engine_Vec2 {
	return Engine_Vec2{x = x, y = y}
}

engine_render_backend_is_valid :: proc(render: Engine_Render_Backend) -> bool {
	return(
		render.begin_frame != nil &&
		render.end_frame != nil &&
		render.clear != nil &&
		render.begin_scissor != nil &&
		render.end_scissor != nil &&
		render.draw_rectangle != nil &&
		render.draw_text != nil &&
		render.measure_text != nil &&
		render.draw_rectangle_lines != nil &&
		render.draw_texture_region != nil \
	)
}

engine_render_backend_or_default :: proc(render: Engine_Render_Backend) -> Engine_Render_Backend {
	if engine_render_backend_is_valid(render) {
		return render
	}
	return engine_render_backend_default()
}

// On desktop the default is Raylib (see render_backend_raylib.odin). On the JS
// target Raylib cannot link (no libraylib.a), and the game injects the karl2d
// render backend at config time, so the default here is the nil backend.
engine_render_backend_default :: proc() -> Engine_Render_Backend {
	when ODIN_OS == .JS {
		return engine_render_backend_nil()
	} else {
		return engine_render_backend_raylib()
	}
}

engine_render_backend_nil :: proc() -> Engine_Render_Backend {
	return Engine_Render_Backend {
		begin_frame = nil_render_begin_frame,
		end_frame = nil_render_end_frame,
		clear = nil_render_clear,
		begin_scissor = nil_render_begin_scissor,
		end_scissor = nil_render_end_scissor,
		draw_rectangle = nil_render_draw_rectangle,
		draw_text = nil_render_draw_text,
		measure_text = nil_render_measure_text,
		draw_rectangle_lines = nil_render_draw_rectangle_lines,
		draw_texture_region = nil_render_draw_texture_region,
		shutdown = nil_render_shutdown,
	}
}

engine_render_begin_frame :: proc(engine: ^Engine) {
	render := engine_render_backend(engine)
	render.begin_frame(render.ctx)
}

engine_render_end_frame :: proc(engine: ^Engine) {
	render := engine_render_backend(engine)
	render.end_frame(render.ctx)
}

engine_render_shutdown :: proc(engine: ^Engine) {
	render := engine_render_backend(engine)
	if render.shutdown != nil {
		render.shutdown(render.ctx)
	}
}

engine_render_clear :: proc(engine: ^Engine, color: Engine_Color) {
	render := engine_render_backend(engine)
	render.clear(render.ctx, color)
}

engine_render_begin_scissor :: proc(engine: ^Engine, x, y, width, height: i32) {
	render := engine_render_backend(engine)
	render.begin_scissor(render.ctx, x, y, width, height)
}

engine_render_end_scissor :: proc(engine: ^Engine) {
	render := engine_render_backend(engine)
	render.end_scissor(render.ctx)
}

engine_render_draw_rectangle :: proc(
	engine: ^Engine,
	x, y, width, height: i32,
	color: Engine_Color,
) {
	render := engine_render_backend(engine)
	render.draw_rectangle(render.ctx, x, y, width, height, color)
}

engine_render_draw_rectangle_lines :: proc(
	engine: ^Engine,
	x, y, width, height: i32,
	color: Engine_Color,
) {
	render := engine_render_backend(engine)
	render.draw_rectangle_lines(render.ctx, x, y, width, height, color)
}

engine_render_draw_text :: proc(
	engine: ^Engine,
	text: cstring,
	x, y, size: i32,
	color: Engine_Color,
	font := Engine_Font.Body,
) {
	render := engine_render_backend(engine)
	render.draw_text(render.ctx, text, x, y, size, color, font)
}

engine_render_measure_text :: proc(
	engine: ^Engine,
	text: cstring,
	size: i32,
	font := Engine_Font.Body,
) -> i32 {
	render := engine_render_backend(engine)
	return render.measure_text(render.ctx, text, size, font)
}

engine_render_draw_texture_region :: proc(
	engine: ^Engine,
	texture: Engine_Texture,
	source, dest: Engine_Rect,
	origin: Engine_Vec2,
	rotation: f32,
	tint: Engine_Color,
) {
	render := engine_render_backend(engine)
	render.draw_texture_region(render.ctx, texture, source, dest, origin, rotation, tint)
}

@(private = "file")
nil_render_begin_frame :: proc(ctx: rawptr) {}

@(private = "file")
nil_render_end_frame :: proc(ctx: rawptr) {}

@(private = "file")
nil_render_shutdown :: proc(ctx: rawptr) {}

@(private = "file")
nil_render_clear :: proc(ctx: rawptr, color: Engine_Color) {}

@(private = "file")
nil_render_begin_scissor :: proc(ctx: rawptr, x, y, width, height: i32) {}

@(private = "file")
nil_render_end_scissor :: proc(ctx: rawptr) {}

@(private = "file")
nil_render_draw_rectangle :: proc(ctx: rawptr, x, y, width, height: i32, color: Engine_Color) {}

@(private = "file")
nil_render_draw_text :: proc(
	ctx: rawptr,
	text: cstring,
	x, y, size: i32,
	color: Engine_Color,
	font: Engine_Font,
) {}

@(private = "file")
nil_render_measure_text :: proc(ctx: rawptr, text: cstring, size: i32, font: Engine_Font) -> i32 {
	return 0
}

@(private = "file")
nil_render_draw_rectangle_lines :: proc(
	ctx: rawptr,
	x, y, width, height: i32,
	color: Engine_Color,
) {}

@(private = "file")
nil_render_draw_texture_region :: proc(
	ctx: rawptr,
	texture: Engine_Texture,
	source, dest: Engine_Rect,
	origin: Engine_Vec2,
	rotation: f32,
	tint: Engine_Color,
) {}
