package main


import eng "./engine"
import "core:sync"
import "core:testing"
import clay "libs:clay"
@(private = "file")
clay_ui_test_import_anchor :: proc() {
	_ = eng.Engine{}
	_ = clay.RenderCommand{}
	_ = testing.T{}
}

@(private = "file")
clay_ui_test_mutex: sync.Mutex


@(test)
clay_ui_emits_and_renders_basic_rectangle_command :: proc(t: ^testing.T) {
	sync.mutex_lock(&clay_ui_test_mutex)
	defer sync.mutex_unlock(&clay_ui_test_mutex)
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
	sync.mutex_lock(&clay_ui_test_mutex)
	defer sync.mutex_unlock(&clay_ui_test_mutex)
	render_state := Clay_Test_Render_State{}
	engine := eng.Engine {
		input         = eng.engine_input_backend_nil(),
		render        = clay_test_render_backend(&render_state),
		frame_manager = eng.frame_manager_make(),
	}
	content := content_manager_make()
	game := game_init(&content)
	defer game_destroy(game)
	game.state = .Playing
	game.player.hp = 7
	game.player.max_hp = 10
	game.player.light_radius = 6
	game.depth = 2

	testing.expect(t, clay_ui_init(&engine))
	defer clay_ui_destroy()

	clay_ui_begin_frame(&engine)
	clay_render_screen_ui(&engine, game)
	commands := clay_ui_end_frame(0.016)
	clay_render_commands(&engine, commands)

	testing.expect(t, commands.length > 0)
	testing.expect(t, clay_test_text_command_count(commands) > 0)
	testing.expect(t, render_state.text_count > 0)
}

@(test)
clay_gameplay_surfaces_emit_message_and_minimap_commands :: proc(t: ^testing.T) {
	sync.mutex_lock(&clay_ui_test_mutex)
	defer sync.mutex_unlock(&clay_ui_test_mutex)
	render_state := Clay_Test_Render_State{}
	engine := eng.Engine {
		input         = eng.engine_input_backend_nil(),
		render        = clay_test_render_backend(&render_state),
		frame_manager = eng.frame_manager_make(),
	}
	content := content_manager_make()
	game := game_init(&content)
	defer game_destroy(game)
	messages := message_manager_make()
	eng.message_manager_add(&messages, "hello", eng.Engine_Color{255, 255, 255, 255})

	testing.expect(t, clay_ui_init(&engine))
	defer clay_ui_destroy()

	clay_ui_begin_frame(&engine)
	clay_render_messages(&messages)
	clay_render_minimap(game)
	commands := clay_ui_end_frame(0.016)

	testing.expect(t, commands.length > 0)
	testing.expect(t, clay_test_text_command_count(commands) > 0)
	testing.expect(t, clay_test_rectangle_command_count(commands) > 0)
}

@(test)
clay_title_overlay_emits_visible_ember_rectangles :: proc(t: ^testing.T) {
	sync.mutex_lock(&clay_ui_test_mutex)
	defer sync.mutex_unlock(&clay_ui_test_mutex)
	render_state := Clay_Test_Render_State{}
	engine := eng.Engine {
		input         = eng.engine_input_backend_nil(),
		render        = clay_test_render_backend(&render_state),
		frame_manager = eng.frame_manager_make(),
	}
	game: Game
	game.state = .Title_Screen

	testing.expect(t, clay_ui_init(&engine))
	defer clay_ui_destroy()

	clay_ui_begin_frame(&engine)
	clay_render_screen_ui(&engine, &game)
	commands := clay_ui_end_frame(0.016)
	clay_render_commands(&engine, commands)

	testing.expect(t, commands.length > 0)
	testing.expect(t, render_state.ember_rectangle_count > 0)
}


clay_test_rectangle_command_count :: proc(commands: clay.ClayArray(clay.RenderCommand)) -> int {
	count := 0
	command_array := commands
	for i: i32 = 0; i < command_array.length; i += 1 {
		command := clay.RenderCommandArray_Get(&command_array, i)
		if command != nil && command.commandType == .Rectangle {
			count += 1
		}
	}
	return count
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
	rectangle_count:       int,
	ember_rectangle_count: int,
	text_count:            int,
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
	if color.r == 255 && color.g == 158 && color.b == 61 {
		state.ember_rectangle_count += 1
	}
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
clay_test_render_measure_text :: proc(ctx: rawptr, text: cstring, size: i32) -> i32 {return max(
		size * 4,
		1,
	)}
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
