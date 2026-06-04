package main

import eng "./engine"
import clay "./vendor/clay"
import "base:runtime"
import "core:mem"

when USE_CLAY {
	Clay_UI_State :: struct {
		ctx:    ^clay.Context,
		memory: []u8,
	}

	g_clay_ui: Clay_UI_State

	clay_ui_init :: proc(engine: ^eng.Engine) -> bool {
		if g_clay_ui.ctx != nil {
			clay.SetCurrentContext(g_clay_ui.ctx)
			clay.SetMeasureTextFunction(clay_ui_measure_text, rawptr(engine))
			return true
		}

		capacity := int(clay.MinMemorySize())
		memory := make([]u8, capacity)
		if len(memory) == 0 {
			return false
		}

		arena := clay.CreateArenaWithCapacityAndMemory(uint(capacity), raw_data(memory))
		ctx := clay.Initialize(
			arena,
			{width = f32(SCREEN_WIDTH), height = f32(SCREEN_HEIGHT)},
			{handler = clay_ui_handle_error},
		)
		if ctx == nil {
			delete(memory)
			return false
		}

		g_clay_ui = Clay_UI_State {
			ctx    = ctx,
			memory = memory,
		}
		clay.SetCurrentContext(ctx)
		clay.SetMeasureTextFunction(clay_ui_measure_text, rawptr(engine))
		return true
	}

	clay_ui_destroy :: proc() {
		if g_clay_ui.ctx != nil {
			clay.SetCurrentContext(g_clay_ui.ctx)
		}
		if g_clay_ui.memory != nil {
			delete(g_clay_ui.memory)
		}
		g_clay_ui = {}
	}

	clay_ui_begin_frame :: proc(engine: ^eng.Engine) {
		if g_clay_ui.ctx == nil {
			return
		}

		clay.SetCurrentContext(g_clay_ui.ctx)
		clay.SetLayoutDimensions({width = f32(SCREEN_WIDTH), height = f32(SCREEN_HEIGHT)})

		input := eng.engine_input_backend(engine)
		mouse := eng.engine_input_mouse_position(input)
		mouse_down := eng.engine_input_mouse_button_down(input, .Left)
		clay.SetPointerState({mouse.x, mouse.y}, mouse_down)

		scroll := eng.engine_input_scroll_delta(input)
		delta_time := f32(0)
		frames := eng.engine_frame_manager(engine)
		if frames != nil {
			delta_time = eng.frame_manager_delta_time(frames^)
		}
		clay.UpdateScrollContainers(true, {0, scroll}, delta_time)
		clay.BeginLayout()
	}

	clay_ui_end_frame :: proc(delta_time: f32) -> clay.ClayArray(clay.RenderCommand) {
		if g_clay_ui.ctx == nil {
			return {}
		}
		clay.SetCurrentContext(g_clay_ui.ctx)
		return clay.EndLayout(delta_time)
	}

	clay_string_slice_to_cstring :: proc(
		text: clay.StringSlice,
		allocator := context.allocator,
	) -> cstring {
		if text.length <= 0 || text.chars == nil {
			return ""
		}

		length := int(text.length)
		buf := make([]u8, length + 1, allocator)
		if len(buf) == 0 {
			return ""
		}
		mem.copy(raw_data(buf), text.chars, length)
		buf[length] = 0
		return cast(cstring)raw_data(buf)
	}

	@(private = "file")
	clay_ui_measure_text :: proc "c" (
		text: clay.StringSlice,
		config: ^clay.TextElementConfig,
		user_data: rawptr,
	) -> clay.Dimensions {
		context = runtime.default_context()
		engine := cast(^eng.Engine)user_data
		if engine == nil || config == nil {
			return {}
		}
		allocator := context.allocator
		frames := eng.engine_frame_manager(engine)
		if frames != nil {
			allocator = eng.frame_manager_allocator(frames)
		}
		c_text := clay_string_slice_to_cstring(text, allocator)
		width := eng.engine_render_measure_text(engine, c_text, i32(config.fontSize))
		height := i32(config.lineHeight)
		if height <= 0 {
			height = i32(config.fontSize)
		}
		return {width = f32(width), height = f32(height)}
	}

	@(private = "file")
	clay_ui_handle_error :: proc "c" (error_data: clay.ErrorData) {}
}
