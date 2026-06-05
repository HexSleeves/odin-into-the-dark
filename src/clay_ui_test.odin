package main

import eng "./engine"
import clay "./vendor/clay"
import "core:testing"
@(private = "file")
clay_ui_test_import_anchor :: proc() {
	_ = eng.Engine{}
	_ = clay.RenderCommand{}
	_ = testing.T{}
}


when USE_CLAY {
	@(test)
	clay_ui_emits_and_renders_basic_rectangle_command :: proc(t: ^testing.T) {
		render_state := Clay_Test_Render_State{}
		engine := eng.Engine {
			input  = eng.engine_input_backend_nil(),
			render = clay_test_render_backend(&render_state),
		}

		testing.expect(t, clay_ui_init(&engine))
		defer clay_ui_destroy()

		clay_ui_begin_frame(&engine)
		if clay.UI(clay.ID("test-root"))(
		clay.ElementDeclaration {
			layout = {sizing = {width = clay.SizingFixed(16), height = clay.SizingFixed(16)}},
			backgroundColor = {255, 0, 0, 255},
		},
		) {}
		commands := clay_ui_end_frame(0.016)
		clay_render_commands(&engine, commands)

		testing.expect(t, commands.length > 0)
		testing.expect(t, render_state.rectangle_count > 0)
	}

	@(test)
	clay_screen_dispatcher_playing_state_emits_hud_text_commands :: proc(t: ^testing.T) {
		render_state := Clay_Test_Render_State{}
		engine := eng.Engine {
			input  = eng.engine_input_backend_nil(),
			render = clay_test_render_backend(&render_state),
		}
		game := Game {
			state = .Playing,
			player = Player {
				hp = 7,
				max_hp = 10,
				light_radius = 6,
			},
			depth = 2,
		}

		testing.expect(t, clay_ui_init(&engine))
		defer clay_ui_destroy()

		clay_ui_begin_frame(&engine)
		clay_render_screen_ui(&engine, &game)
		commands := clay_ui_end_frame(0.016)
		clay_render_commands(&engine, commands)

		testing.expect(t, commands.length > 0)
		testing.expect(t, clay_test_text_command_count(commands) > 0)
		testing.expect(t, render_state.text_count > 0)
	}

	clay_test_text_command_count :: proc(commands: clay.ClayArray(clay.RenderCommand)) -> int {
		count := 0
		command_array := commands
		for i: i32 = 0; i < command_array.length; i += 1 {
			command := clay.RenderCommandArray_Get(&command_array, i)
			if command != nil && command.commandType == .Text {
				count += 1
			}
		}
		return count
	}

	Clay_Test_Render_State :: struct {
		rectangle_count: int,
		text_count:      int,
	}

	clay_test_render_backend :: proc(state: ^Clay_Test_Render_State) -> eng.Engine_Render_Backend {
		return eng.Engine_Render_Backend {
			ctx = state,
			begin_frame = clay_test_render_begin_frame,
			end_frame = clay_test_render_end_frame,
			clear = clay_test_render_clear,
			begin_scissor = clay_test_render_begin_scissor,
			end_scissor = clay_test_render_end_scissor,
			draw_rectangle = clay_test_render_draw_rectangle,
			draw_text = clay_test_render_draw_text,
			measure_text = clay_test_render_measure_text,
			draw_rectangle_lines = clay_test_render_draw_rectangle_lines,
			draw_texture_region = clay_test_render_draw_texture_region,
		}
	}

	clay_test_render_begin_frame :: proc(ctx: rawptr) {}
	clay_test_render_end_frame :: proc(ctx: rawptr) {}
	clay_test_render_clear :: proc(ctx: rawptr, color: eng.Engine_Color) {}
	clay_test_render_begin_scissor :: proc(ctx: rawptr, x, y, width, height: i32) {}
	clay_test_render_end_scissor :: proc(ctx: rawptr) {}
	clay_test_render_draw_rectangle :: proc(
		ctx: rawptr,
		x, y, width, height: i32,
		color: eng.Engine_Color,
	) {
		state := cast(^Clay_Test_Render_State)ctx
		state.rectangle_count += 1
	}
	clay_test_render_draw_text :: proc(
		ctx: rawptr,
		text: cstring,
		x, y, size: i32,
		color: eng.Engine_Color,
	) {
		state := cast(^Clay_Test_Render_State)ctx
		state.text_count += 1
	}
	clay_test_render_measure_text :: proc(ctx: rawptr, text: cstring, size: i32) -> i32 {return max(size * 4, 1)}
	clay_test_render_draw_rectangle_lines :: proc(
		ctx: rawptr,
		x, y, width, height: i32,
		color: eng.Engine_Color,
	) {}
	clay_test_render_draw_texture_region :: proc(
		ctx: rawptr,
		texture: eng.Engine_Texture,
		source, dest: eng.Engine_Rect,
		origin: eng.Engine_Vec2,
		rotation: f32,
		tint: eng.Engine_Color,
	) {}
}
